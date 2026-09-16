import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/date/korean_date_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/home/api/home_api.dart';
import '../../entity/diet/model/diet.dart';
import '../../entity/home/model/student_home.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/notification/api/notification_api.dart';
import '../../feature/course/ui/course_card.dart';
import '../../feature/diet/ui/today_diet_tile.dart';
import '../../shared/ui/app_card.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_bottom_navigation.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/home/ui/StudentHomePage.tsx` 대응.
///
/// 로그인한 회원이 착지하는 화면이고, 회원 화면 25개의 기반이 된다.
///
/// ## 요청 3건과 그 순서
///
/// 골든 `home-student`는 **순서가 있는** 3건이다:
/// `trainer-mapping` → `home/student` → `red-dot`.
///
/// 웹에서 이 순서가 나오는 이유는 React의 effect가 **자식부터** 실행되기
/// 때문이다(하단 네비가 자식). Flutter의 `initState`는 반대로 부모가 먼저라,
/// 그대로 두면 `home/student` → `red-dot` → `trainer-mapping`이 되어
/// `expectParity`가 떨어진다.
///
/// 그래서 **이 화면은 자기 요청 둘을 첫 프레임 뒤로 미룬다.** 네비는
/// 첫 빌드 중 `initState`에서 자기 요청을 보내므로 순서가 골든과 같아진다.
/// 웹의 effect 순서를 재현하려는 것이 아니라 **골든 순서를 요구사항으로
/// 받아 호출 개시 순서를 명시적으로 고정하는** 것이다
/// (`student_home_page_test.dart`가 순서를 단언한다).
///
/// ## Phase A 범위
///
/// 진입 렌더 + 위 3건까지다. FCM 토큰 등록(`POST /api/v1/push`), 식단 사진
/// 업로드(S3 presigned), 401 리프레시는 Phase B다.
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({
    required this.homeApi,
    required this.notificationApi,
    required this.memberApi,
    required this.onNavigate,
    super.key,
  });

  /// 웹 로딩 자리의 `h-[500px]`.
  static const double loadingHeight = 500;

  /// 웹 `<IconLogo width={28} height={28} />`.
  static const double logoSize = 28;

  /// 웹 `<IconAlarm width={24} height={24} />`.
  static const double alarmIconSize = 24;

  /// 웹 빨간 점 `h-1 w-1`(스케일 1 = 4px).
  static const double redDotSize = 4;

  /// 웹 "수강권 없음" 박스의 `h-[127px]`.
  static const double emptyCourseHeight = 127;

  /// 웹 미확인 배지의 `h-7 w-7` — 스케일이라 **20px이지 28px이 아니다.**
  static const double unreadBadgeSize = 20;

  /// 웹 트레이너 프로필 원의 `h-9 w-9`(28) 과 그 안 이미지 28×28.
  static const double trainerProfileSize = 28;

  /// 웹 `<IconArrowRightSmall />` 자산 고유 크기.
  static const double arrowRightWidth = 7;
  static const double arrowRightHeight = 10;

  /// 웹 수업일지 프로필 사진 URL의 `?w=100&h=100&q=90`.
  static const String profileThumbnailQuery = '?w=100&h=100&q=90';

  /// 헤더 알림 버튼을 지목하는 키.
  ///
  /// 헤더에는 SVG가 둘(로고·알림 아이콘)이라 타입으로는 구분되지 않는다
  /// (`AppLayoutHeader.closeButtonKey`와 같은 이유).
  static const Key alarmButtonKey = ValueKey('StudentHomePage.alarm');

  final HomeApi homeApi;
  final NotificationApi notificationApi;
  final MemberApi memberApi;

  /// 라우터로 나가는 유일한 통로. 화면 테스트에 라우터를 끼우지 않기 위해
  /// 콜백으로 받는다(`next-steps.md` §7-3).
  final ValueChanged<String> onNavigate;

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  StudentHome? _home;
  bool _isLoading = true;
  bool _hasUnreadNotification = false;

  /// 웹 `const [isOpen, setIsOpen] = useState(false)`.
  ///
  /// 웹은 이 값과 Radix Collapsible 내부 상태를 **이중으로** 관리한다(같은
  /// 클릭으로 함께 움직여 버그는 아니다). Flutter에서는 bool 하나로 합쳤다.
  bool _isPointOpen = false;

  @override
  void initState() {
    super.initState();
    // **첫 프레임 뒤로 미룬다.** 위 클래스 주석의 "요청 3건과 그 순서" 참고 —
    // 여기서 바로 부르면 네비보다 먼저 나가 골든 순서가 깨진다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // **개시 순서만 골든이고, 기다리는 것은 함께다.**
    //
    // 골든은 `home/student` 다음에 `red-dot`이므로 그 순서로 **시작**한다.
    // 하지만 앞의 것을 `await`하고 뒤를 시작하면 홈 응답이 올 때까지
    // red-dot이 나가지도 않아서, 느린 네트워크에서 헤더 빨간 점이 웹보다
    // 늦게 뜬다 — 웹은 react-query effect 둘이 같은 틱에 나간다.
    //
    // `Future.wait`가 실패를 전파하는 것은 여기서 문제가 되지 않는다.
    // `_loadHome`·`_loadRedDot`이 각자 안에서 try/catch로 삼키므로 던지는
    // 쪽이 없다(웹도 쿼리 둘이 독립적으로 실패한다).
    final home = _loadHome();
    final redDot = _loadRedDot();
    await Future.wait(<Future<void>>[home, redDot]);
  }

  Future<void> _loadHome() async {
    try {
      final home = await widget.homeApi.studentHome();
      if (mounted) {
        setState(() {
          _home = home;
          _isLoading = false;
        });
      }
    } catch (_) {
      // 웹 `useStudentHomeDataQuery`에는 **`isError` 분기가 없다** —
      // 실패하면 `isPending`이 false가 되고 `data`가 undefined라, 네트워크
      // 에러 화면이 "수강권 없음" 화면과 **시각적으로 동일해진다.**
      // 명시적 이탈 없이 그 동작을 옮긴다(`deferred-minors.md`에 기록).
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRedDot() async {
    try {
      final hasUnread = await widget.notificationApi.redDot();
      if (mounted) {
        setState(() => _hasUnreadNotification = hasUnread);
      }
    } catch (_) {
      // 웹 `useHomeAlarmQuery`도 에러 처리가 전혀 없다 — 실패하면 점이
      // 안 찍힐 뿐이다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return AppLayout(
      header: _HomeHeader(
        hasUnreadNotification: _hasUnreadNotification,
        onOpenAlarm: () => widget.onNavigate('/student/alarm'),
      ),
      bottomNavigation: AppBottomNavigation(
        currentLocation: '/student',
        // 이 호출이 골든의 **첫 번째** 요청이다(네비 `initState`).
        loadTrainerMapping: widget.memberApi.trainerMapping,
        onSelect: widget.onNavigate,
        onScheduleBlocked: () => AppToastScope.read(
          context,
        ).showError(AppBottomNavigation.scheduleBlockedMessage),
      ),
      contents: Padding(
        // 웹 `<Layout.Contents className='p-7 pt-6'>` = 사방 20, 위 16.
        padding: EdgeInsets.fromLTRB(
          spacing.s7,
          spacing.s6,
          spacing.s7,
          spacing.s7,
        ),
        child: _isLoading
            ? const _Loading()
            : _Body(
                home: _home,
                isPointOpen: _isPointOpen,
                onTogglePoint: () =>
                    setState(() => _isPointOpen = !_isPointOpen),
                onNavigate: widget.onNavigate,
              ),
      ),
    );
  }
}

/// 웹 로딩 자리 — `h-[500px]` 안에 가운데 정렬한 `loading.gif` 20×20.
///
/// **명시적 이탈:** gif 자산을 가져오지 않고 Material 인디케이터로 대체한다
/// (`/select-gym` 선례, 규율 #8 — 애니메이션은 검증할 수단이 없다).
///
/// 높이를 `Expanded`가 아니라 고정 박스로 잡는 것이 중요하다. `AppLayout`이
/// 본문을 `SingleChildScrollView`로 감싸 세로 제약이 unbounded라
/// `Expanded`는 `RenderFlex ... unbounded`로 터진다(규율 #12).
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: StudentHomePage.loadingHeight,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 웹 `<Layout.Header>` — 로고 왼쪽, 알림 아이콘 오른쪽(빨간 점 포함).
class _HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const _HomeHeader({
    required this.hasUnreadNotification,
    required this.onOpenAlarm,
  });

  final bool hasUnreadNotification;
  final VoidCallback onOpenAlarm;

  @override
  Size get preferredSize => const Size.fromHeight(AppLayoutHeader.height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return AppBar(
      toolbarHeight: AppLayoutHeader.height,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      // 웹 헤더는 `px-7`(20). AppBar 기본 여백을 끄고 직접 준다.
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.s7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: StudentHomePage.logoSize,
              height: StudentHomePage.logoSize,
            ),
            GestureDetector(
              key: StudentHomePage.alarmButtonKey,
              behavior: HitTestBehavior.opaque,
              onTap: onOpenAlarm,
              // 웹 `<Link className='relative'>` — 점이 아이콘 우상단에
              // 겹친다(`absolute right-0 t-0`).
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.asset(
                    'assets/images/alarm.svg',
                    width: StudentHomePage.alarmIconSize,
                    height: StudentHomePage.alarmIconSize,
                  ),
                  if (hasUnreadNotification)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: StudentHomePage.redDotSize,
                        height: StudentHomePage.redDotSize,
                        decoration: BoxDecoration(
                          // 웹 `bg-point`.
                          color: colors.point,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로딩이 끝난 뒤의 본문 — 카드 5종.
class _Body extends StatelessWidget {
  const _Body({
    required this.home,
    required this.isPointOpen,
    required this.onTogglePoint,
    required this.onNavigate,
  });

  final StudentHome? home;
  final bool isPointOpen;
  final VoidCallback onTogglePoint;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final data = home;
    final course = data?.course;

    void toast(String message) =>
        AppToastScope.read(context).showError(message);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      // 웹은 `<article className='mb-7'>`(20)로 블록을 띄운다. 마지막
      // 블록(개인 운동 기록)에는 `mb-7`이 없어 `spacing`으로 균일하게
      // 두면 아래 여백이 하나 더 생기는데, 본문 패딩(`p-7`)이 같은 20이라
      // 결과가 웹과 같다.
      spacing: spacing.s7,
      children: [
        if (course != null)
          CourseCard(
            course: course,
            // 웹 `gymName={data?.gym.name}` — 가드 없이 접근한다.
            gymName: data?.gymName ?? '',
            point: data?.point,
            rank: data?.rank,
            isPointOpen: isPointOpen,
            onTogglePoint: onTogglePoint,
            // 웹 `href='./student/course-history'` — **상대 경로**라
            // `/student`에서 `/student/course-history`로 해석된다.
            onOpenCourseHistory: () => onNavigate('/student/course-history'),
            onOpenPointHistory: () => onNavigate('/student/point-history'),
          )
        else
          // 웹 `{!data?.course && (<div className='h-[127px] ... bg-gray-500'>)}`.
          //
          // **포인트·랭킹이 여기서 사라진다.** 웹은 그 UI를
          // `{data?.course && (...)}` 블록 안쪽에 중첩해 놓아서, 응답에
          // `point`·`rank`가 있어도 `course`가 null이면 이 박스만 남는다.
          // 사용자 결정(2026-09-15): 버그째 이관하고 기록한다.
          Container(
            height: StudentHomePage.emptyCourseHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.gray500,
              borderRadius: BorderRadius.circular(radius.l),
            ),
            child: Text(
              '현재 등록된 수강권이 없습니다.',
              style: AppTypography.title3.copyWith(color: Colors.white),
            ),
          ),

        if (data?.myReservation != null)
          _ReservationCard(
            reservation: data!.myReservation!,
            onTap: () => onNavigate('/student/schedule?tab=myReservation'),
          ),

        if (data?.lessonHistory != null)
          _LessonHistoryCard(
            lessonHistory: data!.lessonHistory!,
            onOpenAll: () => onNavigate('/student/log'),
            onOpenOne: () =>
                onNavigate('/student/log/${data.lessonHistory!.id}'),
          ),

        _TodayDietCard(
          diet: data?.diet,
          onOpenAll: () => onNavigate(
            '/student/diet?month=${KoreanDateFormat.month(DateTime.now())}',
          ),
          onTapTile: () => toast(_dietUnimplementedMessage),
        ),

        _WorkoutCard(onTap: () => onNavigate('/student/workout')),
      ],
    );
  }

  /// Phase A에서 식단 타일을 눌렀을 때. 웹은 바텀시트가 열린다.
  static const String _dietUnimplementedMessage = '식단 사진 등록은 준비 중입니다.';
}

/// 웹 "다음 PT예정일" 카드(`StudentHomePage.tsx:352-370`).
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onTap});

  /// 웹 `<IconCheck fill={'var(--primary-500)'} width={17} height={17} />`.
  static const double checkIconSize = 17;

  final MyReservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    // 웹 `dayjs(lessonDt).format('MM.DD (ddd)')` + `dayjs(lessonStartTime,
    // 'HH:mm:ss').format('A hh:mm')`. 서버가 포맷해 주는 `lessonHistory` 쪽과
    // 달리 **여기는 원시 값**이라 앱이 포맷한다.
    final day = reservation.lessonDt == null
        ? ''
        : KoreanDateFormat.reservationDay(reservation.lessonDt!);
    final hour = KoreanDateFormat.reservationHour(reservation.lessonStartTime);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AppCard(
        // 웹 `gap-y-8 px-6 py-7` = 24 / 16 / 20.
        gap: spacing.s8,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s6,
          vertical: spacing.s7,
        ),
        children: [
          AppCardHeader(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '다음 PT예정일',
                style: AppTypography.title2.copyWith(color: colors.gray800),
              ),
            ),
          ),
          AppCardContent(
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/check.svg',
                  width: checkIconSize,
                  height: checkIconSize,
                  theme: SvgTheme(currentColor: colors.primary500),
                ),
                // 웹 `ml-3` = 8.
                SizedBox(width: spacing.s3),
                // 폰 너비(390pt)에서 `09.15 (화) 오후 02:30`(18px bold)이
                // 카드 내용 폭을 35px 넘긴다. 웹에서는 이 `<p>`가 flex
                // 자식이라 **줄바꿈된다**(`flex-shrink: 1` 기본값).
                // `Flexible` 없이 두면 `RenderFlex overflowed`다 —
                // `_PointTitle`과 같은 종류의 자리다.
                Flexible(
                  child: Text(
                    // 웹은 `{nextScheduledDay} {nextScheduledHour}` — 값이
                    // 없으면 빈 문자열이라 공백 하나만 남는다.
                    '$day $hour',
                    style: AppTypography.heading4.copyWith(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 웹 "수업 일지" 카드(`StudentHomePage.tsx:372-421`).
class _LessonHistoryCard extends StatelessWidget {
  const _LessonHistoryCard({
    required this.lessonHistory,
    required this.onOpenAll,
    required this.onOpenOne,
  });

  final LessonHistory lessonHistory;
  final VoidCallback onOpenAll;
  final VoidCallback onOpenOne;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return AppCard(
      gap: spacing.s8,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s6,
        vertical: spacing.s7,
      ),
      children: [
        AppCardHeader(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '수업 일지',
                    style: AppTypography.title1.copyWith(color: Colors.black),
                  ),
                  if (lessonHistory.isUnread) ...[
                    // 웹 `ml-1` = 4.
                    SizedBox(width: spacing.s1),
                    Container(
                      // 웹 `h-7 w-7` — **스케일이라 20px**이다(28이 아니다).
                      width: StudentHomePage.unreadBadgeSize,
                      height: StudentHomePage.unreadBadgeSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary500,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '1',
                        style: AppTypography.heading5.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenAll,
                child: const Text(
                  '수업전체',
                  // 웹 `cn(Typography.BODY_3, 'gray-500 h-auto')` —
                  // `gray-500`은 **Tailwind 클래스가 아니다**(`text-` 접두사가
                  // 빠졌다). 색이 지정되지 않아 상속색으로 렌더된다. 카드
                  // 기본 본문색을 그대로 쓴다.
                  style: AppTypography.body3,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpenOne,
          child: AppCardContent(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lessonHistory.trainerProfile != null)
                  ClipOval(
                    child: Image.network(
                      '${lessonHistory.trainerProfile}'
                      '${StudentHomePage.profileThumbnailQuery}',
                      width: StudentHomePage.trainerProfileSize,
                      height: StudentHomePage.trainerProfileSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _AvatarFallback(),
                    ),
                  )
                else
                  const _AvatarFallback(),
                // 웹 `ml-2` = 6.
                SizedBox(width: spacing.s2),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(spacing.s6),
                    decoration: BoxDecoration(
                      color: colors.gray100,
                      // 웹 `rounded-lg rounded-tl-none` — 말풍선처럼 왼쪽 위만 각지다.
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(radius.l),
                        bottomLeft: Radius.circular(radius.l),
                        bottomRight: Radius.circular(radius.l),
                      ),
                    ),
                    child: Text(
                      lessonHistory.content,
                      // 웹 `line-clamp-2`.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body4.copyWith(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 웹 `<IconAvatar width={28} height={28} />`.
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/avatar.svg',
      width: StudentHomePage.trainerProfileSize,
      height: StudentHomePage.trainerProfileSize,
    );
  }
}

/// 웹 "오늘 식단" 카드(`StudentHomePage.tsx:423-445`).
class _TodayDietCard extends StatelessWidget {
  const _TodayDietCard({
    required this.diet,
    required this.onOpenAll,
    required this.onTapTile,
  });

  /// 웹 타일 너비 `calc((100% - 12px) / 3)` — 타일 셋 사이 간격 총합 12px.
  static const double tileGap = 6;

  final HomeDiet? diet;
  final VoidCallback onOpenAll;
  final VoidCallback onTapTile;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return AppCard(
      gap: spacing.s8,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s6,
        vertical: spacing.s7,
      ),
      children: [
        AppCardHeader(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '오늘 식단',
                style: AppTypography.title1.copyWith(color: Colors.black),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenAll,
                child: const Text('식단전체', style: AppTypography.body3),
              ),
            ],
          ),
        ),
        AppCardContent(
          // 웹은 `data?.diet`가 없으면 **카드는 남기고 내용만 비운다.**
          child: diet == null
              ? const SizedBox.shrink()
              : Row(
                  spacing: tileGap,
                  children: [
                    for (final meal in diet!.meals)
                      // 가로 `Expanded`는 Row의 폭이 유한해서 안전하다 —
                      // 규율 #12가 막는 것은 세로 unbounded 쪽이다.
                      Expanded(
                        child: TodayDietTile(
                          meal: meal,
                          onTapUnimplemented: onTapTile,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 웹 "개인 운동 기록" 카드(`StudentHomePage.tsx:447-463`).
///
/// 웹은 `<Card className='w-full p-0'>` 안의 `<Link>`가 `px-6 py-7`을 갖는다 —
/// 패딩이 카드가 아니라 링크에 있어서 카드 전체가 터치 영역이 된다.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AppCard(
        padding: EdgeInsets.zero,
        children: [
          AppCardHeader(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.s6,
                vertical: spacing.s7,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '개인 운동 기록',
                    style: AppTypography.title1.copyWith(color: Colors.black),
                  ),
                  SvgPicture.asset(
                    'assets/images/arrow_right_small.svg',
                    width: StudentHomePage.arrowRightWidth,
                    height: StudentHomePage.arrowRightHeight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
