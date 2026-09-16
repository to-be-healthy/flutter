import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/home/api/home_api.dart';
import '../../entity/home/model/trainer_home.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/member_info.dart';
import '../../entity/notification/api/notification_api.dart';
import '../../shared/ui/app_card.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_bottom_navigation.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/home/ui/TrainerHomePage.tsx` 대응.
///
/// 로그인이 착지하던 자리표시자 셋 중 마지막(`/select-gym` → `/student` →
/// 여기)이다.
///
/// ## 요청 3건 — 학생 홈과 모양이 다르다
///
/// 골든 `home-trainer`는 `members/me` → `home/trainer` → `red-dot` 순서다.
/// **세 건 전부 이 페이지가 쏜다** — 학생 홈의 1번(`trainer-mapping`)은
/// 하단 네비가 쐈지만 `AppTrainerBottomNavigation`에는 요청이 없다.
/// 그래서 학생 홈이 순서를 맞추려고 쓴 `addPostFrameCallback`이 여기서는
/// 필요 없고, `initState`에서 선언 순서대로 개시하면 골든과 같아진다.
///
/// `members/me`는 **헤더의 헬스장 이름 하나** 때문에 붙는 왕복이다.
/// 백엔드 `TrainerHomeResult`에도 `gym`이 있지만 웹은 쓰지 않는다 —
/// 요청을 줄이면 골든이 깨진다.
///
/// ## Phase A 범위
///
/// 진입 렌더 + 위 3건까지다. 회원 추가 모달, 수강권 지급 확인 모달과 그
/// `PATCH /api/v1/course/{courseId}`, FCM 토큰 등록은 Phase B다 — 수강권
/// 지급은 **공유 체험 계정의 실제 데이터를 바꾸는 뮤테이션**이라 골든도
/// 만들 수 없다.
class TrainerHomePage extends StatefulWidget {
  const TrainerHomePage({
    required this.homeApi,
    required this.memberApi,
    required this.notificationApi,
    required this.onNavigate,
    super.key,
  });

  /// 웹 `absolute left-0 top-0 h-[170px] w-full bg-primary`.
  ///
  /// **이 170은 헤더를 포함한 높이다.** 웹의 배너는 `<Layout className='relative'>`
  /// 안쪽 div(헤더 + 본문을 함께 담는다)를 기준으로 `top-0`이라, 화면 맨
  /// 위에서부터 170px가 파랗다 — 그중 56px가 헤더 자리다.
  static const double bannerHeight = 170;

  /// 본문에 그릴 배너 높이.
  ///
  /// 헤더(`AppBar`)는 본문과 **별개 레이어**라 본문이 그 뒤를 칠할 수 없다.
  /// 헤더를 `primary500`으로 직접 칠하고, 본문에는 남은 만큼만 그린다 —
  /// 본문에 170을 그대로 그리면 헤더까지 더해져 **226px**가 되어 웹보다
  /// 56px 더 파래진다.
  static const double bannerBodyHeight = bannerHeight - AppLayoutHeader.height;

  /// 웹 `<IconAlarmWhite />` — 자산 고유 크기 21×19.
  static const double alarmIconWidth = 21;
  static const double alarmIconHeight = 19;

  /// 웹 빨간 점 `h-1 w-1`(스케일 1 = 4px)과 `-right-[2px]`.
  static const double redDotSize = 4;
  static const double redDotRightOffset = -2;

  /// 웹 오늘의 수업 카드 `h-[100px] w-[100px]`.
  static const double lessonCardSize = 100;

  /// 웹 "예약된 수업이 없습니다." 카드 `h-[100px]`.
  static const double emptyScheduleHeight = 100;

  /// 웹 `<IconCalendarX width={42} />`.
  ///
  /// **자산 고유 크기(28×28)가 아니다.** `calendar_x.svg`는
  /// `width="28" height="28"`인데 `viewBox`가 `0 0 42 42`이고, 웹은 42px로
  /// 그린다.
  static const double calendarXSize = 42;

  /// 웹 숏컷 카드 `h-[140px]`.
  static const double shortcutCardHeight = 140;

  /// 웹 숏컷 카드 우하단 이미지 `h-[60px] w-[60px]`.
  static const double shortcutImageSize = 60;

  /// 웹 `mt-[19px]` — 스케일에 없는 임의값.
  static const double shortcutTopGap = 19;

  /// 웹 `<IconPlus width={20} />`.
  static const double plusIconSize = 20;

  /// 웹 `<IconMedalGold />` — 자산 고유 크기 28×29.
  static const double medalWidth = 28;
  static const double medalHeight = 29;

  /// 하이라이트된 수업 카드의 테두리(웹 `border-[#00D1FF]`).
  ///
  /// 이 팔레트에 없는 색이다 — 웹이 임의값으로 박아 둔 자리라 그대로 옮긴다.
  static const Color closestLessonBorder = Color(0xFF00D1FF);

  /// 헤더 알림 버튼을 지목하는 키(`StudentHomePage.alarmButtonKey`와 같은 이유 —
  /// 헤더에 SVG가 둘이면 타입으로 구분되지 않는다).
  static const Key alarmButtonKey = ValueKey('TrainerHomePage.alarm');

  /// Phase A에서 다이얼로그 자리를 눌렀을 때.
  static const String dialogUnimplementedMessage = '준비 중인 기능입니다.';

  final HomeApi homeApi;
  final MemberApi memberApi;
  final NotificationApi notificationApi;

  /// 라우터로 나가는 유일한 통로(`next-steps.md` §7-3 — 화면 테스트에
  /// 라우터를 끼우지 않는다).
  final ValueChanged<String> onNavigate;

  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage> {
  MemberInfo? _me;
  TrainerHome? _home;
  bool _hasUnreadNotification = false;

  @override
  void initState() {
    super.initState();
    // 개시 순서가 곧 골든 순서다: `members/me` → `home/trainer` → `red-dot`.
    // 하단 네비가 요청을 쏘지 않으므로 학생 홈처럼 첫 프레임 뒤로 미룰
    // 필요가 없다.
    //
    // **`isLoading` 상태를 두지 않는다.** 웹 트레이너 홈에는 `isPending`
    // 분기가 아예 없어서(학생 홈은 `h-[500px]` 스피너로 가린다) 데이터가
    // 오기 전에도 본문을 그대로 그린다 — 자식 없는 빈 카드가 잠깐 보인다.
    // 스피너를 넣으면 웹에 없는 화면이 된다(`deferred-minors.md`에 기록).
    _load();
  }

  Future<void> _load() async {
    // 개시 순서는 지키되 함께 기다린다. 앞의 것을 `await`하면 헤더 헬스장명이
    // 홈 응답을 기다리게 되는데, 웹은 세 쿼리가 같은 렌더 패스에서 동시에
    // 나간다. 각 로더가 자기 실패를 삼키므로 `Future.wait`가 전파할 예외는
    // 없다.
    final me = _loadMe();
    final home = _loadHome();
    final redDot = _loadRedDot();
    await Future.wait(<Future<void>>[me, home, redDot]);
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.memberApi.me();
      if (mounted) {
        setState(() => _me = me);
      }
    } catch (_) {
      // 웹 `useMyInfoQuery`에 에러 처리가 없다 — 실패하면 헤더의 헬스장
      // 이름 자리가 빈 채로 남는다.
    }
  }

  Future<void> _loadHome() async {
    try {
      final home = await widget.homeApi.trainerHome();
      if (mounted) {
        setState(() => _home = home);
      }
    } catch (_) {
      // 웹 `useTrainerHomeQuery`에도 `isError` 분기가 없다. 실패는
      // "데이터가 아직 안 온 상태"와 구별되지 않는다.
    }
  }

  Future<void> _loadRedDot() async {
    try {
      final hasUnread = await widget.notificationApi.redDot();
      if (mounted) {
        setState(() => _hasUnreadNotification = hasUnread);
      }
    } catch (_) {
      // 웹 `useHomeAlarmQuery`도 에러 처리가 없다 — 점이 안 찍힐 뿐이다.
    }
  }

  void _toastUnimplemented() => AppToastScope.read(
    context,
  ).showError(TrainerHomePage.dialogUnimplementedMessage);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final home = _home;

    return AppLayout(
      // 웹 `<Layout className='relative'>` 루트 배경은 셸 기본값 gray100이다.
      header: _TrainerHeader(
        gymName: _me?.gymName ?? '',
        hasUnreadNotification: _hasUnreadNotification,
        onOpenAlarm: () => widget.onNavigate('/trainer/alarm'),
      ),
      // 웹은 `<Layout.BottomArea className='p-0'>` 안에 네비를 직접 넣는다
      // (학생 홈은 `type='student'`로 자동 주입). 결과가 같으므로 Flutter는
      // 슬롯 하나로 통일한다 — 이 슬롯은 패딩을 주지 않아 `p-0`과 같다.
      bottomNavigation: AppTrainerBottomNavigation(
        currentLocation: AppTrainerBottomNavigation.homeRoute,
        onSelect: widget.onNavigate,
      ),
      contents: Stack(
        children: [
          // 웹 `absolute left-0 top-0 z-0 h-[170px] w-full bg-primary`.
          //
          // 웹은 z-index가 일부 요소에만 붙어 있어 나머지는 렌더 순서에
          // 의존하는데(배너 z-0, 헤더·제목 z-10, 숏컷 영역 미지정),
          // `Stack`은 순서가 곧 z라 여기서 명시적으로 잡는다.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              // 헤더(56)를 뺀 나머지. 위 상수 주석 참고.
              height: TrainerHomePage.bannerBodyHeight,
              // 웹 `bg-primary`. Tailwind 설정의 `primary`는 `primary-500`과
              // 같은 `var(--primary-500)`을 가리킨다.
              color: colors.primary500,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TodayLessons(
                home: home,
                onOpenMember: (memberId) =>
                    widget.onNavigate('/trainer/manage/$memberId'),
              ),
              _Shortcuts(
                studentCount: home?.studentCount,
                onOpenManage: () => widget.onNavigate('/trainer/manage'),
                onOpenFeedback: () =>
                    widget.onNavigate('/trainer/manage/feedback'),
                onAddStudent: _toastUnimplemented,
              ),
              if (home != null && home.bestStudents.isNotEmpty)
                _BestStudents(
                  students: home.bestStudents,
                  onOpenMember: (memberId) =>
                      widget.onNavigate('/trainer/manage/$memberId'),
                  onGrantCourse: _toastUnimplemented,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 웹 `<Layout.Header className='z-10'>` — 헬스장 이름(흰색) + 알림.
class _TrainerHeader extends StatelessWidget implements PreferredSizeWidget {
  const _TrainerHeader({
    required this.gymName,
    required this.hasUnreadNotification,
    required this.onOpenAlarm,
  });

  final String gymName;
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
      // 헤더 자체는 색이 없고 뒤의 파란 배너가 비쳐야 한다 — 배너는 본문
      // `Stack` 안에 있으므로 여기서 같은 색을 직접 칠한다. transparent로
      // 두면 Scaffold 배경(gray100) 위에 흰 글씨가 놓여 읽히지 않는다.
      backgroundColor: colors.primary500,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        // 웹 헤더의 `px-7`(20).
        padding: EdgeInsets.symmetric(horizontal: spacing.s7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                // 웹 `{userInfo?.gym.name}` — 아직 안 왔으면 빈 자리다.
                gymName,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title2.copyWith(color: Colors.white),
              ),
            ),
            GestureDetector(
              key: TrainerHomePage.alarmButtonKey,
              behavior: HitTestBehavior.opaque,
              onTap: onOpenAlarm,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.asset(
                    // 학생 홈의 `alarm.svg`가 아니다 — 파란 배너 위라
                    // 흰색 자산을 쓴다.
                    'assets/images/alarm_white.svg',
                    width: TrainerHomePage.alarmIconWidth,
                    height: TrainerHomePage.alarmIconHeight,
                  ),
                  if (hasUnreadNotification)
                    Positioned(
                      // 웹 `-right-[2px]` — 아이콘 밖으로 2px 나간다
                      // (학생 홈은 `right-0`이다).
                      right: TrainerHomePage.redDotRightOffset,
                      top: 0,
                      child: Container(
                        width: TrainerHomePage.redDotSize,
                        height: TrainerHomePage.redDotSize,
                        decoration: BoxDecoration(
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

/// 웹 "오늘의 수업" 블록(`TrainerHomePage.tsx:177-228`).
class _TodayLessons extends StatelessWidget {
  const _TodayLessons({required this.home, required this.onOpenMember});

  final TrainerHome? home;
  final ValueChanged<int?> onOpenMember;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final lessons = home?.todaySchedule ?? const <TrainerLesson>[];

    return Padding(
      // 웹 `pt-8 pb-10` = 24 / 32.
      padding: EdgeInsets.only(top: spacing.s8, bottom: spacing.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        // 웹 `gap-y-5` = 12.
        spacing: spacing.s5,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.s7),
            child: Text(
              '오늘의 수업',
              style: AppTypography.heading4.copyWith(color: Colors.white),
            ),
          ),
          if (lessons.isNotEmpty)
            SizedBox(
              height: TrainerHomePage.lessonCardSize,
              child: ListView.separated(
                // 웹 `hide-scrollbar overflow-x-auto`.
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: spacing.s7),
                itemCount: lessons.length,
                // 웹은 카드마다 `mr-4`(10)를 붙인다 — 마지막 카드에도
                // 붙지만 스크롤 컨테이너라 시각 차이가 없다.
                separatorBuilder: (context, index) =>
                    SizedBox(width: spacing.s4),
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  return _LessonCard(
                    lesson: lesson,
                    // **웹이 실제로 고르는 것은 "가장 가까운 수업"이 아니라
                    // 첫 번째다** — `TrainerHome.highlightedLesson` 주석 참고.
                    isHighlighted:
                        lesson.scheduleId ==
                        home?.highlightedLesson?.scheduleId,
                    onTap: () => onOpenMember(lesson.applicantId),
                  );
                },
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.s7),
              child: AppCard(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: TrainerHomePage.emptyScheduleHeight,
                    child: Center(
                      // **로딩 중에는 자식이 없는 빈 카드다.** 웹
                      // `homeInfo?.todaySchedule.schedule.length === 0`이
                      // 데이터가 오기 전에는 `undefined === 0` → 거짓이라
                      // 아이콘도 문구도 그리지 않는다. `isPending` 분기가
                      // 없어서 생기는 상태이고, 그대로 옮긴다.
                      child: home == null
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              // 웹 `gap-1` = 4.
                              spacing: spacing.s1,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/calendar_x.svg',
                                  // 자산 고유 크기(28)가 아니라 웹이 지정한 42.
                                  width: TrainerHomePage.calendarXSize,
                                  height: TrainerHomePage.calendarXSize,
                                ),
                                Text(
                                  '예약된 수업이 없습니다.',
                                  style: AppTypography.heading5.copyWith(
                                    color: colors.gray500,
                                  ),
                                ),
                              ],
                            ),
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

/// 오늘의 수업 카드 한 장.
class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.isHighlighted,
    required this.onTap,
  });

  final TrainerLesson lesson;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: TrainerHomePage.lessonCardSize,
        height: TrainerHomePage.lessonCardSize,
        decoration: BoxDecoration(
          color: Colors.white,
          // 웹 `rounded-md` = 8.
          borderRadius: BorderRadius.circular(radius.m),
          border: Border.all(
            color: isHighlighted
                ? TrainerHomePage.closestLessonBorder
                : colors.gray200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // 웹 `gap-4` = 10.
          spacing: spacing.s4,
          children: [
            Text(
              // 웹은 서버 문자열(`"09:00:00"`)을 **그대로 찍는다** —
              // 트레이너 홈에는 dayjs `format()` 호출이 한 번도 없다.
              lesson.lessonStartTime,
              style: AppTypography.body2.copyWith(color: colors.gray500),
            ),
            Text(
              // `applicantName`이 null이면 웹도 빈 칸이다(가드 없음).
              lesson.applicantName ?? '',
              style: AppTypography.title1,
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 2열 숏컷 그리드(`TrainerHomePage.tsx:230-278`).
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({
    required this.studentCount,
    required this.onOpenManage,
    required this.onOpenFeedback,
    required this.onAddStudent,
  });

  final int? studentCount;
  final VoidCallback onOpenManage;
  final VoidCallback onOpenFeedback;
  final VoidCallback onAddStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.s7,
        TrainerHomePage.shortcutTopGap,
        spacing.s7,
        0,
      ),
      // `CrossAxisAlignment.stretch`를 쓰지 않는다. `AppLayout`이 본문을
      // `SingleChildScrollView`로 감싸 세로 제약이 unbounded라
      // `BoxConstraints forces an infinite height`로 터진다(규율 #12).
      // 웹 `grid-cols-2`의 두 칸은 `h-[140px]`로 높이가 이미 같으므로
      // 늘릴 필요도 없다 — 각 카드가 `SizedBox`로 그 높이를 갖는다.
      child: Row(
        // 웹 `gap-2` = 6 (커스텀 스케일. Tailwind 기본 8이 아니다).
        spacing: spacing.s2,
        children: [
          Expanded(
            child: _ShortcutCard(
              onTap: onOpenManage,
              image: 'assets/images/icon_profile_coin_shadow.png',
              body: '간편한 회원 관리와\n운동 일지 공유',
              title: Stack(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('회원'),
                      // 웹 `ml-1` = 4.
                      SizedBox(width: spacing.s1),
                      Text(
                        // 아직 안 왔으면 빈 자리다(웹 `{homeInfo?.studentCount}`).
                        studentCount?.toString() ?? '',
                        style: TextStyle(color: colors.primary500),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // 웹은 부모 `<Link>` 안에서 `e.preventDefault()`로
                      // 이동만 막는다. Flutter는 제스처가 가장 안쪽
                      // 디텍터에 먼저 잡히므로 자연히 분리된다.
                      onTap: onAddStudent,
                      child: SvgPicture.asset(
                        'assets/images/plus.svg',
                        width: TrainerHomePage.plusIconSize,
                        height: TrainerHomePage.plusIconSize,
                        // 웹 `fill={'#CBCFD3'}` = 이 팔레트의 gray300.
                        theme: SvgTheme(currentColor: colors.gray300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _ShortcutCard(
              onTap: onOpenFeedback,
              image: 'assets/images/icon_calendar_shadow.png',
              body: '수업 내역 관리와\n피드백 작성',
              title: const Text('피드백 작성'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.body,
    required this.image,
    required this.onTap,
  });

  final Widget title;

  /// 줄바꿈이 들어 있다. 웹이 템플릿 리터럴의 `\n`을 그대로 넣고
  /// `CardContent`가 `whitespace-pre-wrap`이라 두 줄로 보인다.
  final String body;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: TrainerHomePage.shortcutCardHeight,
        child: AppCard(
          children: [
            AppCardHeader(child: title),
            AppCardContent(
              child: Stack(
                children: [
                  Text(body),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Image.asset(
                      image,
                      width: TrainerHomePage.shortcutImageSize,
                      height: TrainerHomePage.shortcutImageSize,
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

/// 웹 우수 회원 카드(`TrainerHomePage.tsx:279-346`).
///
/// **웹 버그를 그대로 옮긴다(BUG-2).** 섹션 헤더("{월}월의 우수 회원")와
/// 메달 안 숫자가 `bestStudents.map()` **안쪽**에 있어서, 회원이 N명이면
/// 그 블록이 N번 반복된다. 메달 숫자도 `item.ranking`이 아니라 하드코딩
/// `'1'`이다. 학생 홈의 "포인트·랭킹 중첩" 버그와 같은 계열이고, 사용자
/// 결정(2026-09-15)에 따라 버그째 옮기고 `deferred-minors.md`에 기록한다.
class _BestStudents extends StatelessWidget {
  const _BestStudents({
    required this.students,
    required this.onOpenMember,
    required this.onGrantCourse,
  });

  /// 웹 `{new Date().getMonth() + 1}월의 우수 회원`.
  ///
  /// **서버가 아니라 기기 시계 기준이다**(BUG-6). 응답에 기준 월 필드가
  /// 아예 없다. 학생 홈의 문자열 파싱 버그와는 다른 부류이고 10~12월
  /// 표시는 정상이다.
  static String monthLabel(DateTime now) => '${now.month}월의 우수 회원';

  final List<BestStudent> students;
  final ValueChanged<int> onOpenMember;
  final VoidCallback onGrantCourse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final label = monthLabel(DateTime.now());

    return Padding(
      // 웹 `mt-6` = 16. 좌우는 바깥 `px-7`과 같다.
      padding: EdgeInsets.fromLTRB(spacing.s7, spacing.s6, spacing.s7, 0),
      child: AppCard(
        // 웹 `gap-6` = 16.
        gap: spacing.s6,
        children: [
          for (final student in students)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // 웹 `gap-3` = 8.
                    spacing: spacing.s3,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/medal_gold.svg',
                            width: TrainerHomePage.medalWidth,
                            height: TrainerHomePage.medalHeight,
                          ),
                          Text(
                            // 웹이 하드코딩한 `'1'`. `item.ranking`이
                            // 응답에 있는데 쓰지 않는다(BUG-2).
                            '1',
                            style: AppTypography.heading5.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              // 반복 안에 있다 — 회원이 N명이면 N번 나온다.
                              label,
                              style: AppTypography.body3.copyWith(
                                color: colors.gray600,
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onOpenMember(student.memberId),
                              child: Text(
                                student.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.title2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Phase A에서는 확인 모달과 `PATCH /api/v1/course/{courseId}`
                // 를 넣지 않는다 — 공유 체험 계정의 실제 수강권을 늘리는
                // 뮤테이션이라 골든도 만들 수 없다.
                _GrantCourseButton(onTap: onGrantCourse),
              ],
            ),
        ],
      ),
    );
  }
}

/// 웹 `<Button variant='secondary'>수강권 지급</Button>`.
///
/// 기존 `AppButton`을 쓰지 않는다 — 그 컴포넌트는 화면 폭을 채우는 제출
/// 버튼용(높이 44~57, 라벨 `title1`)이고, 이것은 카드 안에 들어가는 작은
/// 보조 버튼이다. 웹 `button.tsx`의 `secondary` variant를 옮길 화면이
/// 더 나오면 그때 공용으로 올린다.
class _GrantCourseButton extends StatelessWidget {
  const _GrantCourseButton({required this.onTap});

  /// 웹 `button.tsx`의 기본 높이(`h-[40px]`)와 `px-4`.
  static const double height = 40;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: spacing.s4),
        decoration: BoxDecoration(
          // 웹 `secondary` variant = `bg-gray-100 text-black`.
          color: colors.gray100,
          borderRadius: BorderRadius.circular(radius.m),
        ),
        child: const Text('수강권 지급', style: AppTypography.title3),
      ),
    );
  }
}
