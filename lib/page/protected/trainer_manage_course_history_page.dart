import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/date/korean_date_format.dart';
import '../../core/network/server_message.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/course/api/course_api.dart';
import '../../entity/course/model/course.dart';
import '../../entity/course/model/course_history.dart';
import '../../entity/course/model/course_history_page.dart';
import '../../feature/course/ui/course_card.dart';
import '../../shared/ui/app_card.dart';
import '../../shared/ui/app_dropdown_menu.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_bottom_navigation.dart';
import '../../widget/app_layout.dart';
import '../../widget/app_month_picker.dart';

/// 웹 `page/manage/ui/StudentCourseDetailPage.tsx`(391줄).
/// `/trainer/manage/[memberId]/course-history` — "{name}님 수강권".
///
/// 치수는 2026-09-18 브라우저 실측이다
/// (`docs/trainer-manage-s3-measurements.md`, 뷰포트 440×900).
///
/// ## 요청
///
/// 진입 시 `GET /api/v1/members/{memberId}/course?page=0&size=20&searchDate=`
/// **1건**뿐이다(골든 `trainer-manage-course-history`). `<Layout type='trainer'>`
/// 의 트레이너 네비는 쿼리 훅이 없어 요청을 쏘지 않는다(서베이 §0.3).
///
/// 뮤테이션 셋(등록 `POST /course` · 연장 `PATCH /course/{id}` · 삭제
/// `DELETE /course/{id}`)은 **골든을 만들지 않았다** — 삭제는 그 회원 수강권을
/// 통째로 지우고(서베이 §2.1 복구 불가) 나머지 둘은 데이터를 만든다.
/// `/select-gym` 등록 POST와 같은 판단이고, 요청 모양은 계약 테스트가 고정한다.
///
/// ## 헤더 `+`는 "만료일 때만"이 아니다
///
/// 웹 조건이 `course?.totalLessonCnt === course?.completedLessonCnt`라
/// **수강권이 없으면 `undefined === undefined` → true**다. 즉 `+`는
/// **만료 · 수강권없음 · 로딩중**(아직 `historyData`가 없다) 셋 다 렌더된다.
/// 서베이는 "만료일 때만"이라고 적었지만 소스와 실측이 위와 같아 그대로 옮긴다
/// ([_showRegisterAction] 참고).
///
/// ## 웹 버그
///
/// - **BUG-9은 도달 불가다.** 웹이 `Number(course?.courseId)`로 `courseId`를
///   만들어 수강권이 없으면 `NaN`이 되지만, 그 값을 쓰는 두 버튼(`수업 횟수
///   추가`·`수강권 삭제`)은 **`course &&` 분기 안에만 있다**(웹 `:202`).
///   수강권이 없을 때 눌리는 것은 등록(POST)뿐이고 거기엔 `courseId`가 없다.
///   그래서 Dart에 `NaN` 대응물을 만들지 않았다 — 만들면 웹에 없는 경로가 된다.
/// - **BUG-22·41과 달리 여기서 옮기는 표시 버그는 없다.**
class TrainerManageCourseHistoryPage extends StatefulWidget {
  const TrainerManageCourseHistoryPage({
    required this.courseApi,
    required this.memberId,
    required this.name,
    required this.onBack,
    required this.onNavigate,
    this.initialMonth,
    super.key,
  });

  /// 웹 `Layout.Contents`의 첫 블록 `bg-white p-7 pb-0` — 20/20/20/0.
  static const double contentPadding = 20;

  /// 카드 아래 `mb-6`(커스텀 스케일 6 = 16). 실측: 카드 하단 217 → 바 상단 233.
  static const double cardBottomGap = 16;

  /// 액션 바 `mb-7`(= 20). 실측: 바 하단 279 → 월 선택 상단 299.
  static const double actionBarBottomGap = 20;

  /// 액션 바 `rounded-lg bg-gray-100` — 실측 400 × 46.
  static const double actionBarHeight = 46;

  /// 액션 버튼 `h-[46px] w-[160px]` — 둘 다 같다.
  static const double actionButtonWidth = 160;

  /// 세로 구분선 `h-[30px] w-[1px] bg-gray-200`.
  static const double actionDividerWidth = 1;
  static const double actionDividerHeight = 30;

  /// 내역 항목 `px-7 py-8` — 실측 padding 24 / 20.
  static const double itemHorizontalPadding = 20;
  static const double itemVerticalPadding = 24;

  /// 내역 0건 블록 `py-28`. **Tailwind 기본값이라 112다**(규율 #5) —
  /// 커스텀 스케일에 28이 없다.
  static const double emptyVerticalPadding = 112;

  /// 빈 상태 아이콘 `<IconNotification width={33} height={33}>`.
  static const double emptyIconSize = 33;

  /// 아이콘을 감싼 `span.mb-5.w-[35px]` — 폭이 아이콘보다 2 넓고
  /// `mb-5`는 커스텀 스케일이라 **20이 아니라 12**다.
  static const double emptyIconBoxWidth = 35;
  static const double emptyIconBottomGap = 12;

  /// 수강권 없음 블록 `bg-white py-[88px]` — 임의값이라 그대로 옮긴다.
  ///
  /// **미실측**: 이 트레이너의 회원 둘 다 수강권이 있어 브라우저에서 이 분기를
  /// 띄우지 못했다. 웹 소스(`StudentCourseDetailPage.tsx:302-320`)에서 읽은
  /// 값이다.
  static const double noCourseVerticalPadding = 88;

  /// `등록된 수강권이 없습니다.` 아래 `mb-3`(= 8). 미실측.
  static const double noCourseTextBottomGap = 8;

  /// `수강권 등록` 버튼 `h-[37px] w-[112px] rounded-full`. 미실측.
  static const double noCourseButtonHeight = 37;
  static const double noCourseButtonWidth = 112;

  /// 웹 `ITEMS_PER_PAGE` — 다음 페이지를 언제 부를지의 기준이 아니라 요청 값.
  /// 실제 값은 [CourseApi.pageSize]가 갖는다.
  ///
  /// 다음 페이지를 부르기 시작하는 스크롤 여유분. 웹은 바닥 감지용 div를
  /// `useInView({threshold: 0.5})`로 관찰하는데(`:381`), 위젯 테스트에서
  /// 재현·검증할 수단이 없어 **스크롤 여유분으로 대체한다**(규율 #8과 같은
  /// 종류의 명시적 이탈). 부르는 시점만 다르고 요청 모양은 같다.
  static const double loadMoreThreshold = 200;

  final CourseApi courseApi;
  final Object memberId;

  /// 웹은 이 이름을 **쿼리스트링에서 읽는다**(`:55`). 헤더 제목에만 쓴다.
  final String name;

  /// 웹 `router.back()`.
  final VoidCallback onBack;
  final ValueChanged<String> onNavigate;

  /// `YYYY-MM`. null이면 오늘 기준 이번 달.
  ///
  /// **테스트가 골든의 `searchDate=2026-09`를 고정하려고 넘긴다.**
  /// 기본값을 그대로 두면 10월이 되는 순간 패리티 테스트가 깨진다
  /// (`/student/mypage/last-reservation`과 같은 처리).
  final String? initialMonth;

  @override
  State<TrainerManageCourseHistoryPage> createState() =>
      _TrainerManageCourseHistoryPageState();
}

class _TrainerManageCourseHistoryPageState
    extends State<TrainerManageCourseHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  final List<CourseHistoryPage> _pages = [];

  /// 웹 `useState<Date>(new Date())` — 항상 유효한 달이다.
  /// (`/student/mypage/last-reservation`의 `Invalid Date` 경로가 여기엔 없다.)
  late DateTime _month;
  bool _isPending = true;
  bool _isLoadingMore = false;

  /// 서버에 보낼 `searchDate` — 웹 `dayjs(searchMonth).format('YYYY-MM')`.
  String get _searchDate => KoreanDateFormat.month(_month);

  @override
  void initState() {
    super.initState();
    // 테스트가 `initialMonth`로 골든의 `searchDate`를 고정한다.
    _month = DateTime.tryParse('${widget.initialMonth}-01') ?? DateTime.now();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// 웹 `pages[0].mainData.course` — 첫 페이지의 것만 본다.
  Course? get _course => _pages.isEmpty ? null : _pages.first.course;

  String get _gymName => _pages.isEmpty ? '' : _pages.first.gymName;

  /// 웹 `course?.totalLessonCnt === course?.completedLessonCnt`.
  ///
  /// **수강권이 없거나 아직 안 왔을 때도 참이다**(`undefined === undefined`).
  /// 클래스 주석의 "헤더 `+`" 절 참고 — 이 한 줄이 그 동작을 옮긴 것이다.
  bool get _showRegisterAction {
    final course = _course;
    return course == null || course.isExpired;
  }

  bool get _hasNextPage => _pages.isNotEmpty && !_pages.last.isLast;

  List<CourseHistory> get _items => [
    for (final page in _pages) ...page.content,
  ];

  Future<void> _load() async {
    setState(() {
      _isPending = true;
      _pages.clear();
    });
    try {
      final page = await widget.courseApi.history(
        memberId: widget.memberId,
        searchDate: _searchDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pages
          ..clear()
          ..add(page);
        _isPending = false;
      });
    } on Object {
      // 웹에 에러 분기가 없다 — 쿼리가 실패하면 `historyData`가 undefined로
      // 남아 "수강권 없음" 블록이 뜬다. 같은 상태로 떨어뜨린다.
      if (!mounted) {
        return;
      }
      setState(() => _isPending = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels <
        position.maxScrollExtent -
            TrainerManageCourseHistoryPage.loadMoreThreshold) {
      return;
    }
    _maybeLoadMore();
  }

  void _maybeLoadMore() {
    if (_isLoadingMore || !_hasNextPage) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final page = await widget.courseApi.history(
        memberId: widget.memberId,
        searchDate: _searchDate,
        // 웹 `getNextPageParam: (lastPage, allPages) => allPages.length`.
        page: _pages.length,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pages.add(page);
        _isLoadingMore = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingMore = false);
    }
  }

  /// 웹은 월이 바뀌면 queryKey가 바뀌어 **`page=0`부터 새로 받는다.**
  void _onMonthChanged(DateTime month) {
    setState(() => _month = month);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppLayout(
      backgroundColor: colors.gray100,
      // 웹 `main`이 `overflow-y-auto`인 스크롤 상자다. 셸의 스크롤뷰를 쓰면
      // 무한스크롤에 필요한 `ScrollController`를 끼울 자리가 없어 직접 만든다
      // (규율 #12의 전제가 사라지므로 이 안에서는 `Expanded`도 쓸 수 있다).
      scrollable: false,
      header: AppLayoutHeader(
        title: '${widget.name}님 수강권',
        backgroundColor: Colors.white,
        onBack: widget.onBack,
        trailing: _showRegisterAction
            ? _HeaderPlusButton(onPressed: _openRegisterSheet)
            : null,
      ),
      bottomNavigation: AppTrainerBottomNavigation(
        // 활성 판정이 **완전 일치**라 이 경로는 어느 탭에도 걸리지 않는다 —
        // 2026-09-18 실측에서도 웹의 네 라벨이 전부 같은 색(gray700/500)으로,
        // **켜진 탭이 없었다**. 빈 문자열로 같은 결과를 만들 수 있지만 실제
        // 경로를 넘겨야 네비 매칭 규칙이 바뀔 때 이 화면이 함께 드러난다.
        currentLocation: AppRoutes.trainerManageMemberCourseHistory(
          widget.memberId,
        ),
        onSelect: widget.onNavigate,
      ),
      contents: _isPending
          ? const _FullScreenLoading()
          : SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_course != null) _courseBlock(_course!) else _noCourse(),
                  _HistoryList(
                    items: _items,
                    isLoadingMore: _isLoadingMore,
                    hasNextPage: _hasNextPage,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _courseBlock(Course course) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        // 웹 `p-7 pb-0`.
        padding: const EdgeInsets.fromLTRB(
          TrainerManageCourseHistoryPage.contentPadding,
          TrainerManageCourseHistoryPage.contentPadding,
          TrainerManageCourseHistoryPage.contentPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 웹은 여기서 `CourseCard` 컨테이너 안에 헤더/본문 **둘만** 넣는다.
            // 학생 홈·S2의 카드와 달리 포인트 바가 없고 카드를 눌러도
            // 이동하지 않는다.
            _CourseSummaryCard(course: course, gymName: _gymName),
            const SizedBox(
              height: TrainerManageCourseHistoryPage.cardBottomGap,
            ),
            _ActionBar(
              isExpired: course.isExpired,
              onAdd: () => _openAddSheet(course),
              onDelete: () => _confirmDelete(course),
            ),
            const SizedBox(
              height: TrainerManageCourseHistoryPage.actionBarBottomGap,
            ),
            // 웹 `<div className='flex justify-end'>`.
            Align(
              alignment: Alignment.centerRight,
              child: AppMonthPicker(date: _month, onChanged: _onMonthChanged),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noCourse() => _NoCourseBlock(onRegister: _openRegisterSheet);

  Future<void> _openRegisterSheet() async {
    final count = await _openCourseSheet(
      title: '등록할 수업횟수',
      buttonLabel: '수강권 등록',
    );
    if (count == null || !mounted) {
      return;
    }
    final toast = AppToastScope.read(context);
    try {
      final message = await widget.courseApi.register(
        memberId: widget.memberId,
        lessonCnt: count,
      );
      if (!mounted) {
        return;
      }
      // 웹 `successToast(reslut.message)` — 서버 문구를 그대로 띄운다.
      if (message != null && message.isNotEmpty) {
        toast.showSuccess(message);
      }
      await _load();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      toast.showError(serverMessage(error));
    }
  }

  Future<void> _openAddSheet(Course course) async {
    final count = await _openCourseSheet(
      title: '추가할 수업횟수',
      buttonLabel: '수업 횟수 추가',
    );
    if (count == null || !mounted) {
      return;
    }
    final toast = AppToastScope.read(context);
    try {
      await widget.courseApi.addCount(
        courseId: course.courseId,
        memberId: widget.memberId,
        updateCnt: count,
      );
      if (!mounted) {
        return;
      }
      // 웹 `successToast(\`${addInput}회가 연장되었습니다.\`)` — 서버 문구가
      // 아니라 **입력값으로 만든 문자열**이다.
      toast.showSuccess('$count회가 연장되었습니다.');
      await _load();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      toast.showError(serverMessage(error));
    }
  }

  Future<int?> _openCourseSheet({
    required String title,
    required String buttonLabel,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: _CourseSheet.barrier,
      // 웹 시트는 `fixed bottom-0`이라 높이 상한이 없다(S2 환불 시트와 같은
      // 이유 — 기본값 9/16에 걸리면 내용이 잘린다).
      isScrollControlled: true,
      builder: (context) =>
          _CourseSheet(title: title, buttonLabel: buttonLabel),
    );
  }

  Future<void> _confirmDelete(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: _DeleteCourseAlert.barrier,
      builder: (context) => const _DeleteCourseAlert(),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final toast = AppToastScope.read(context);
    try {
      final message = await widget.courseApi.delete(course.courseId);
      if (!mounted) {
        return;
      }
      // 웹 `successToast(result.message)`.
      if (message != null && message.isNotEmpty) {
        toast.showSuccess(message);
      }
      await _load();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      toast.showError(serverMessage(error));
    }
  }
}

/// 웹 로딩 자리 — `flex h-full items-center justify-center` + `loading.gif` 30×30.
///
/// **명시적 이탈:** gif 자산을 가져오지 않고 Material 인디케이터로 대체한다
/// (학생 홈·`/select-gym` 선례, 규율 #8 — 애니메이션은 검증할 수단이 없다).
class _FullScreenLoading extends StatelessWidget {
  const _FullScreenLoading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// 헤더 오른쪽 `+`. 웹 `<IconPlus width={20} height={20} fill='black' />`.
class _HeaderPlusButton extends StatelessWidget {
  const _HeaderPlusButton({required this.onPressed});

  static const Key buttonKey = ValueKey(
    'TrainerManageCourseHistoryPage.register',
  );

  /// 웹 아이콘 크기이자 `<button>`의 히트 영역(패딩 0).
  static const double size = 20;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SvgPicture.asset(
        'assets/images/plus.svg',
        width: size,
        height: size,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      ),
    );
  }
}

/// 웹 `<CourseCard>` 안에 헤더/본문 둘만 넣은 형태.
///
/// 학생 홈·S2가 쓰는 [CourseCard]와 달리 **포인트 바가 없고 탭도 없다.**
/// 공유하는 두 조각([CourseCardHeader]·[CourseCardContent])은 웹에서도 같은
/// 컴포넌트다.
class _CourseSummaryCard extends StatelessWidget {
  const _CourseSummaryCard({required this.course, required this.gymName});

  final Course course;
  final String gymName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppCard(
      // 웹 `cn(expiration ? 'bg-gray-500' : 'bg-primary-500', 'w-full gap-y-0 p-0')`.
      backgroundColor: course.isExpired ? colors.gray500 : colors.primary500,
      padding: EdgeInsets.zero,
      gap: 0,
      children: [
        CourseCardHeader(course: course, gymName: gymName),
        CourseCardContent(course: course),
      ],
    );
  }
}

/// `수업 횟수 추가` | `수강권 삭제` — 웹 `rounded-lg bg-gray-100` 2열 바.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isExpired,
    required this.onAdd,
    required this.onDelete,
  });

  static const Key addKey = ValueKey('TrainerManageCourseHistoryPage.add');
  static const Key deleteKey = ValueKey(
    'TrainerManageCourseHistoryPage.delete',
  );

  /// 만료면 `수업 횟수 추가`가 눌리지 않는다(웹 `disabled`).
  final bool isExpired;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      height: TrainerManageCourseHistoryPage.actionBarHeight,
      decoration: BoxDecoration(
        color: colors.gray100,
        borderRadius: BorderRadius.circular(radius.l),
      ),
      child: Row(
        // 웹 `justify-center` — 두 버튼 묶음이 바 가운데 놓인다(실측: 첫
        // 버튼 x = 59.5 = 20 + (400 − 321)/2).
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionButton(
            key: addKey,
            label: '수업 횟수 추가',
            // 웹 `disabled:text-gray-400`.
            color: isExpired ? colors.gray400 : Colors.black,
            onPressed: isExpired ? null : onAdd,
          ),
          Container(
            width: TrainerManageCourseHistoryPage.actionDividerWidth,
            height: TrainerManageCourseHistoryPage.actionDividerHeight,
            color: colors.gray200,
          ),
          _ActionButton(
            key: deleteKey,
            label: '수강권 삭제',
            color: Colors.black,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color color;

  /// null이면 비활성(웹 `disabled`).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: TrainerManageCourseHistoryPage.actionButtonWidth,
        height: TrainerManageCourseHistoryPage.actionBarHeight,
        child: Center(
          child: Text(
            label,
            // 웹 `Typography.HEADING_5`(13/150/600).
            style: AppTypography.heading5.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

/// 웹 `{!course && <div className='… bg-white py-[88px]'>}`.
///
/// **미실측 분기다** — 클래스 주석과 페이지 상수의 "미실측" 표시 참고.
class _NoCourseBlock extends StatelessWidget {
  const _NoCourseBlock({required this.onRegister});

  static const Key registerKey = ValueKey(
    'TrainerManageCourseHistoryPage.registerEmpty',
  );

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: TrainerManageCourseHistoryPage.noCourseVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '등록된 수강권이 없습니다.',
              // 웹 `cn('mb-3 text-gray-500', Typography.TITLE_3)`.
              style: AppTypography.title3.copyWith(color: colors.gray500),
            ),
            const SizedBox(
              height: TrainerManageCourseHistoryPage.noCourseTextBottomGap,
            ),
            GestureDetector(
              key: registerKey,
              onTap: onRegister,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: TrainerManageCourseHistoryPage.noCourseButtonWidth,
                height: TrainerManageCourseHistoryPage.noCourseButtonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // 웹 `rounded-full border border-primary-500`.
                  borderRadius: BorderRadius.circular(
                    TrainerManageCourseHistoryPage.noCourseButtonHeight / 2,
                  ),
                  border: Border.all(color: colors.primary500),
                ),
                child: Text(
                  '수강권 등록',
                  style: AppTypography.title3.copyWith(
                    color: colors.primary500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `<ul className='bg-gray-100'>` — 항목 목록 또는 빈 상태 하나.
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.items,
    required this.isLoadingMore,
    required this.hasNextPage,
  });

  final List<CourseHistory> items;
  final bool isLoadingMore;
  final bool hasNextPage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ColoredBox(
      color: colors.gray100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (items.isEmpty)
            const _EmptyHistory()
          else
            ...items.map((item) => _HistoryTile(item: item)),
          // 웹 `{!마지막페이지.isLast && hasNextPage && <div ref={ref} …>}`.
          if (hasNextPage)
            Padding(
              // 웹 `py-3`(커스텀 스케일 3 = 8).
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: isLoadingMore
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 웹 빈 상태 `<li className='… py-28 text-gray-700'>`.
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TrainerManageCourseHistoryPage.emptyVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            // 웹 `span.w-[35px]` — 아이콘(33)보다 2 넓다.
            width: TrainerManageCourseHistoryPage.emptyIconBoxWidth,
            child: SvgPicture.asset(
              'assets/images/notification.svg',
              width: TrainerManageCourseHistoryPage.emptyIconSize,
              height: TrainerManageCourseHistoryPage.emptyIconSize,
              // 웹 `stroke='var(--gray-300)'`. 자산의 `stroke="current"`를
              // `currentColor`로 정규화해 들여왔다(규율 #13) — 그대로 뒀으면
              // 아이콘이 통째로 안 그려진다.
              theme: SvgTheme(currentColor: colors.gray300),
            ),
          ),
          const SizedBox(
            height: TrainerManageCourseHistoryPage.emptyIconBottomGap,
          ),
          Text(
            '수강권 내역이 없습니다.',
            // 웹 `Typography.TITLE_1_BOLD` + `text-gray-700`.
            style: AppTypography.title1.copyWith(color: colors.gray700),
          ),
        ],
      ),
    );
  }
}

/// 웹 내역 항목 `<li className='px-7 py-8'>`.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final CourseHistory item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TrainerManageCourseHistoryPage.itemHorizontalPadding,
        vertical: TrainerManageCourseHistoryPage.itemVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // 웹 `dayjs(item.createdAt).format('YY.MM.DD')`.
            item.createdAt == null
                ? ''
                : KoreanDateFormat.historyDate(item.createdAt!),
            // 웹 `cn(Typography.BODY_4_MEDIUM, 'text-gray-500')`.
            style: AppTypography.body4Medium.copyWith(color: colors.gray500),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  item.typeLabel,
                  // 웹 `cn(Typography.TITLE_3, 'text-gray-700')`.
                  style: AppTypography.title3.copyWith(color: colors.gray700),
                ),
              ),
              Text(
                item.signedCount,
                // 웹 `cn(Typography.TITLE_3, 'text-black')`.
                style: AppTypography.title3.copyWith(color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 웹 `CourseSheet` — 수강권 등록 / 수업 횟수 추가.
///
/// **두 분기를 각각 실측한 결과 상자가 완전히 같았다**(420 × 233.4, 패딩
/// 24/20/28/20, 입력 100 × 57, 버튼 380 × 52). 다른 것은 제목 문구와 버튼
/// 라벨 둘뿐이라 위젯 하나가 파라미터로 받는다.
///
/// 확인을 누르면 입력한 횟수를 돌려준다. 닫으면 null이다.
class _CourseSheet extends StatefulWidget {
  const _CourseSheet({required this.title, required this.buttonLabel});

  static const Key inputKey = ValueKey('TrainerManageCourseHistoryPage.input');
  static const Key submitKey = ValueKey(
    'TrainerManageCourseHistoryPage.submit',
  );
  static const Key closeKey = ValueKey('TrainerManageCourseHistoryPage.close');

  /// 웹 `bg-black/80`.
  static const Color barrier = Color(0xCC000000);

  /// 웹 `w-[calc(100%-20px)]` — 440 − 20.
  static const double maxWidth = 420;

  /// 웹 `mb-7`(= 20) — 시트가 화면 바닥에서 띄워져 있다.
  static const double bottomMargin = 20;

  /// 웹 `px-7 pb-9 pt-8` — 실측 24 / 20 / 28 / 20.
  static const double horizontalPadding = 20;
  static const double topPadding = 24;
  static const double bottomPadding = 28;

  /// 제목 아래 `mb-8`.
  static const double titleBottomGap = 24;

  /// 입력 `w-[100px]`, `text-[40px] font-bold leading-[130%]`, `py-[2px]`.
  static const double inputWidth = 100;
  static const double inputFontSize = 40;
  static const double inputVerticalPadding = 2;

  /// 입력 아래 `mb-8`.
  static const double inputBottomGap = 24;

  /// 에러 문구 위 `mt-3`(= 8).
  static const double errorTopGap = 8;

  /// 버튼 `h-[52px] w-full`.
  static const double buttonHeight = 52;

  /// 웹 `absolute right-7 top-7` + `close.svg` 고유 크기 — 실측 14 × 14
  /// @ `396,667.6`(패널 좌상단에서 오른쪽 20 / 위 20 + 테두리 1).
  static const double closeIconSize = 14;
  static const double closeInset = 20;

  /// shadcn `SheetContent side='bottom'`의 `border-t` — 실측 1px `#E2E8F0`.
  ///
  /// 이 1px이 높이를 맞춘다: 24 + 23.4 + 24 + 57 + 24 + 52 + 28 = 232.4에
  /// 테두리를 더해야 실측 **233.4**가 된다.
  static const double topBorderWidth = 1;

  /// 웹 `maxLength` 대신 `slice(0, 3)` — 3자를 넘기면 잘라낸다(`:78-80`).
  static const int maxInputLength = 3;

  /// 웹 `Number(courseInput) > 500`.
  static const int maxCount = 500;

  final String title;
  final String buttonLabel;

  @override
  State<_CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends State<_CourseSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _count => int.tryParse(_controller.text);

  /// 웹 `Number(courseInput) > 500` — 에러 문구를 띄우는 조건.
  bool get _isOverMax => (_count ?? 0) > _CourseSheet.maxCount;

  /// 웹 `disabled={courseInput === '' || Number(courseInput) > 500}`.
  bool get _canSubmit => _controller.text.isNotEmpty && !_isOverMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            _CourseSheet.bottomMargin + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _CourseSheet.maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius.l),
              // 웹 shadcn `SheetContent side='bottom'`의 `border-t`.
              border: const Border(
                top: BorderSide(
                  color: AppDropdownMenu.border,
                  width: _CourseSheet.topBorderWidth,
                ),
              ),
            ),
            // 닫기 X는 제목 행이 아니라 **패널 기준 절대 배치**다 — 실측에서
            // X(667.6)가 제목(671.6)보다 4 위에 있다(`top-7` 20 vs 패딩 24).
            // 제목을 Row에 넣으면 폭이 줄고 위치도 어긋난다.
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _CourseSheet.horizontalPadding,
                    _CourseSheet.topPadding,
                    _CourseSheet.horizontalPadding,
                    _CourseSheet.bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        // 웹 `text-left text-black text-[18px]/[130%] font-bold`.
                        style: AppTypography.heading4.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: _CourseSheet.titleBottomGap),
                      Center(child: _input(colors)),
                      if (_isOverMax) ...[
                        const SizedBox(height: _CourseSheet.errorTopGap),
                        Text(
                          '500회 이하로 입력해주세요.',
                          textAlign: TextAlign.center,
                          // 웹 `text-point` + `BODY_4`.
                          style: AppTypography.body4.copyWith(
                            color: colors.point,
                          ),
                        ),
                      ],
                      const SizedBox(height: _CourseSheet.inputBottomGap),
                      _submitButton(colors, radius),
                    ],
                  ),
                ),
                Positioned(
                  right: _CourseSheet.closeInset,
                  top: _CourseSheet.closeInset,
                  child: GestureDetector(
                    key: _CourseSheet.closeKey,
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      'assets/images/close.svg',
                      width: _CourseSheet.closeIconSize,
                      height: _CourseSheet.closeIconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(AppColors colors) {
    return SizedBox(
      width: _CourseSheet.inputWidth,
      child: TextField(
        key: _CourseSheet.inputKey,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          // 웹 `if (value.length > 3) return;` — 4자째부터 무시한다.
          LengthLimitingTextInputFormatter(_CourseSheet.maxInputLength),
        ],
        style: AppTypography.title1.copyWith(
          fontSize: _CourseSheet.inputFontSize,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: _CourseSheet.inputVerticalPadding,
          ),
          // 웹은 밑줄만 있다(`border-b`). 비포커스 gray400 → 포커스 primary500.
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.gray400),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.primary500),
          ),
        ),
      ),
    );
  }

  Widget _submitButton(AppColors colors, AppRadius radius) {
    return GestureDetector(
      key: _CourseSheet.submitKey,
      onTap: _canSubmit ? () => Navigator.of(context).pop(_count) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _CourseSheet.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 웹 `disabled:bg-gray-300` — 흐려지는 게 아니라 배경색만 바뀐다.
          color: _canSubmit ? colors.primary500 : colors.gray300,
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Text(
          widget.buttonLabel,
          style: AppTypography.title1.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// 웹 `AlertDialog` — `수강권을 삭제하시겠습니까?`. `true`면 삭제를 진행한다.
///
/// **S2의 `_DeleteAlert`와 합치지 않았다.** 상자(폭 400 · 패딩 36/20 ·
/// 라운드 8 · 제목~버튼 34 · 버튼 높이 48 · 간격 8)는 같지만 버튼이 다르다 —
/// S2는 `TITLE_1_SEMIBOLD`(600)에 `flex`라 테두리 탓에 폭이 175.55/174.45로
/// 어긋나고, 여기는 `text-base font-normal`(16/24/400)에 `grid grid-cols-2`라
/// **175/175로 균등**하다(둘 다 실측). 공용으로 올리면 글꼴과 폭 분배를
/// 옵션으로 받아야 해서, 회원 탈퇴 `Dialog`를 합치지 않은 것과 같은 판단으로
/// 사설로 둔다. 네 번째 알럿이 생기면 상자만 올리는 것을 재검토한다.
class _DeleteCourseAlert extends StatelessWidget {
  const _DeleteCourseAlert();

  static const Key cancelKey = ValueKey(
    'TrainerManageCourseHistoryPage.deleteCancel',
  );
  static const Key confirmKey = ValueKey(
    'TrainerManageCourseHistoryPage.deleteConfirm',
  );

  /// 웹 `w-[calc(100%-20px*2)]` → 440 − 40.
  static const double maxWidth = 400;

  /// 웹 `px-7 py-11` — 세로가 36이다(커스텀 스케일 11 = 36).
  static const double horizontalPadding = 20;
  static const double verticalPadding = 36;

  /// 제목 래퍼 `mb-8`(24) + 다이얼로그 `gap-4`(10) = **34**.
  static const double titleToButtonsGap = 34;

  /// 버튼 `h-[48px]`, 사이 `gap-3`(= 8).
  static const double buttonHeight = 48;
  static const double buttonGap = 8;

  /// 웹 `bg-black/80`.
  static const Color barrier = Color(0xCC000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius.m),
            border: Border.all(color: AppDropdownMenu.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '수강권을 삭제하시겠습니까?',
                textAlign: TextAlign.center,
                // 웹 `Typography.TITLE_1`(16/140/700).
                style: AppTypography.title1.copyWith(color: colors.gray800),
              ),
              const SizedBox(height: titleToButtonsGap),
              Row(
                children: [
                  Expanded(
                    child: _AlertButton(
                      buttonKey: cancelKey,
                      label: '아니요',
                      background: colors.gray100,
                      foreground: colors.gray600,
                      // 웹 `AlertDialogCancel`은 outline 변형이라 테두리가 남는다.
                      border: AppDropdownMenu.border,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: buttonGap),
                  Expanded(
                    child: _AlertButton(
                      buttonKey: confirmKey,
                      label: '예',
                      background: colors.point,
                      foreground: Colors.white,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.buttonKey,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border,
  });

  final Key buttonKey;
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      key: buttonKey,
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _DeleteCourseAlert.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          // 웹 `rounded-md`.
          borderRadius: BorderRadius.circular(radius.m),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(
          label,
          // 웹 `text-base font-normal` — S2 알럿(`TITLE_1_SEMIBOLD`)과
          // 다르다. 16 / 줄높이 24(=1.5) / 400 → `BODY_1`.
          style: AppTypography.body1.copyWith(color: foreground),
        ),
      ),
    );
  }
}
