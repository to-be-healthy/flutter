import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/date/korean_date_format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/point/api/point_api.dart';
import '../../entity/point/model/point_history.dart';
import '../../entity/point/model/point_history_page.dart';
import '../../entity/point/model/student_point.dart';
import '../../entity/trainer/api/trainer_api.dart';
import '../../shared/ui/app_card.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_bottom_navigation.dart';
import '../../widget/app_layout.dart';
import '../../widget/app_month_picker.dart';

/// 웹 `page/manage/ui/StudentPointDetailPage.tsx`(179줄).
/// `/trainer/manage/[memberId]/point-history` — "{name}님 포인트".
///
/// 치수는 2026-09-18 브라우저 실측이다
/// (`docs/trainer-manage-s4-measurements.md`, 뷰포트 440×900).
///
/// ## 요청 3건 — **1번이 화면이 아니라 하단바다**
///
/// ```
/// 1. GET /api/v1/members/trainer-mapping            ← 학생 하단바 (BUG-1)
/// 2. GET /api/v1/trainers/members/{memberId}        ← 제목에 쓸 이름 하나 때문
/// 3. GET /api/v1/members/{memberId}/point?page&size&searchDate
/// ```
///
/// **서베이는 이 순서를 반대로 추론했다**(화면 본체 → 네비). 실측에서 두 번
/// 모두 `trainer-mapping`이 먼저였다. Flutter는 부모 `initState`가 먼저 돌아
/// 그대로 두면 순서가 뒤집히므로, 학생 홈과 같이
/// **[WidgetsBinding.addPostFrameCallback]으로 화면 요청을 한 프레임 미룬다.**
///
/// ## BUG-1 — 트레이너 화면인데 학생 하단바다
///
/// 웹이 `<Layout type='student'>`를 써서(`:67`) 학생 네비가 붙고, 그 안의
/// 훅이 `trainer-mapping`을 마운트 즉시 쏜다. 트레이너 계정에는 의미 없는
/// 요청이지만 **골든이 3건이라 재현이 강제된다.** 실측에서도 네비 링크가
/// `/student`·`/student/community`·`/student/mypage`였다.
///
/// ## 헤더 X는 뒤로가기가 아니다
///
/// 웹이 `<Link href='./'>`라 **현재 경로의 디렉터리**로 간다 —
/// `/trainer/manage/6/point-history` → `/trainer/manage/6`(회원 정보).
/// 어디서 들어왔든 S2로 가므로 `pop`이 아니라 **go**다(실측으로 확인).
///
/// 그 링크는 `h-full w-full`이라 폭이 400인데, **제목이 위에 그려져 가운데를
/// 가로챈다**(실측: 링크 가운데 클릭이 제목에 막혔다). 제목 자리만 죽은
/// 영역인 것까지 그대로 옮긴다 — Flutter `Stack`도 같은 순서면 같은 결과다
/// ([_Header] 참고).
///
/// ## 옮기는 웹 버그
///
/// - **BUG-3** — `{M}월 활동 포인트`의 월이
///   `searchDate.split('-')[1].split('')[1]`이라 10·11·12월이 `0`·`1`·`2`월이
///   된다. 학생 홈에서 이미 정한 [StudentPoint.webMonthLabel]을 그대로 쓴다.
/// - **BUG-13** — 로딩 중 스타일 없는 raw `Loading..` 텍스트.
/// - **BUG-14는 버그가 아니었다.** 서베이가 `text-blue-100`이 생성되지 않는다고
///   적었지만 `theme.extend`라 Tailwind 기본 `blue-100`(#DBEAFE)이 그대로
///   산다(실측 `rgb(219,234,254)`). 그 색을 그린다.
class TrainerManagePointHistoryPage extends StatefulWidget {
  const TrainerManagePointHistoryPage({
    required this.trainerApi,
    required this.pointApi,
    required this.memberApi,
    required this.memberId,
    required this.onNavigate,
    this.initialMonth,
    super.key,
  });

  /// 웹 `bg-white p-7 pb-11 pt-6` — 실측 padding 16 / 20 / 36 / 20.
  static const double topBlockHorizontalPadding = 20;
  static const double topBlockTopPadding = 16;
  static const double topBlockBottomPadding = 36;

  /// 포인트 카드 `px-6 py-7` — 실측 20 / 16.
  static const double cardHorizontalPadding = 16;
  static const double cardVerticalPadding = 20;

  /// 카드 두 줄 사이 `gap-y-1`.
  static const double cardRowGap = 4;

  /// 카드 아래 `mb-6`.
  static const double cardBottomGap = 16;

  /// 웹 `<Image src='/images/point.png' width={21} height={21} />`.
  static const double pointIconSize = 21;

  /// 아이콘과 숫자 사이 `ml-1`, 안내문 아이콘과 글자 사이도 같다.
  static const double inlineGap = 4;

  /// 안내문 아이콘 `<IconNotification width={12} height={12} stroke='black'>`.
  static const double noticeIconSize = 12;

  /// 내역 항목 `px-7 py-8` — S3와 같다(실측 87px 높이).
  static const double itemHorizontalPadding = 20;
  static const double itemVerticalPadding = 24;

  /// 빈 상태 `py-28`(Tailwind 기본 112) + 아이콘 33 + `mb-5`(커스텀 12).
  static const double emptyVerticalPadding = 112;
  static const double emptyIconSize = 33;
  static const double emptyIconBoxWidth = 35;
  static const double emptyIconBottomGap = 12;

  /// 다음 페이지를 부르기 시작하는 스크롤 여유분(S3와 같은 명시적 이탈).
  static const double loadMoreThreshold = 200;

  final TrainerApi trainerApi;
  final PointApi pointApi;

  /// 하단바가 쏘는 `trainer-mapping` 때문에 필요하다 — 화면 본체는 안 쓴다.
  final MemberApi memberApi;

  final Object memberId;
  final ValueChanged<String> onNavigate;

  /// `YYYY-MM`. null이면 오늘 기준 이번 달. 테스트가 골든의 `searchDate`를
  /// 고정하려고 넘긴다(S3와 같은 처리).
  final String? initialMonth;

  @override
  State<TrainerManagePointHistoryPage> createState() =>
      _TrainerManagePointHistoryPageState();
}

class _TrainerManagePointHistoryPageState
    extends State<TrainerManagePointHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  final List<PointHistoryPage> _pages = [];

  late DateTime _month;
  String _name = '';
  bool _isPending = true;
  bool _isLoadingMore = false;

  String get _searchDate => KoreanDateFormat.month(_month);

  @override
  void initState() {
    super.initState();
    _month = DateTime.tryParse('${widget.initialMonth}-01') ?? DateTime.now();
    _scrollController.addListener(_onScroll);
    // **첫 프레임 뒤로 미룬다.** 여기서 바로 부르면 하단바보다 먼저 나가
    // 골든 순서(트레이너 매핑이 1번)가 깨진다 — 학생 홈과 같은 처리다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  StudentPoint? get _point => _pages.isEmpty ? null : _pages.first.point;

  bool get _hasNextPage => _pages.isNotEmpty && !_pages.last.isLast;

  List<PointHistory> get _items => [for (final page in _pages) ...page.content];

  /// **개시 순서만 골든이고 기다리는 것은 함께다**(학생 홈과 같은 판단).
  ///
  /// 골든이 `trainers/members` 다음 `point`이므로 그 순서로 **시작**하되,
  /// 앞을 `await`하고 뒤를 시작하면 이름이 올 때까지 내역이 나가지도 않는다.
  Future<void> _load() async {
    final name = _loadName();
    final history = _loadHistory();
    await Future.wait(<Future<void>>[name, history]);
  }

  Future<void> _loadName() async {
    try {
      final detail = await widget.trainerApi.member(widget.memberId);
      if (mounted && detail != null) {
        setState(() => _name = detail.name);
      }
    } on Object {
      // 웹 `memberInfo?.name` — 실패하면 undefined라 "님 포인트"가 된다.
      // 에러 분기가 없다.
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isPending = true;
      _pages.clear();
    });
    try {
      final page = await widget.pointApi.history(
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
      // 웹에 에러 분기가 없다 — `isPending`만 풀리고 데이터가 없는 화면이 된다.
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
            TrainerManagePointHistoryPage.loadMoreThreshold) {
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
      final page = await widget.pointApi.history(
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

  void _onMonthChanged(DateTime month) {
    setState(() => _month = month);
    // 월이 바뀌면 `page=0`부터 새로 받는다. 이름은 다시 받지 않는다(실측).
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppLayout(
      backgroundColor: colors.gray100,
      // 웹 `main`이 `overflow-y-auto`다. 무한스크롤에 컨트롤러가 필요해
      // 셸의 스크롤뷰 대신 직접 만든다(S3와 같다).
      scrollable: false,
      header: _Header(
        title: '$_name님 포인트',
        // 웹 `<Link href='./'>` — pop이 아니라 회원 정보로 간다.
        onClose: () =>
            widget.onNavigate(AppRoutes.trainerManageMember(widget.memberId)),
      ),
      // **BUG-1: 트레이너 화면인데 학생 네비다.** 이 위젯의 `initState`가
      // 골든의 첫 번째 요청(`trainer-mapping`)을 쏜다.
      bottomNavigation: AppBottomNavigation(
        // 활성 판정이 완전 일치라 이 경로는 어느 탭에도 걸리지 않는다.
        currentLocation: AppRoutes.trainerManageMemberPointHistory(
          widget.memberId,
        ),
        loadTrainerMapping: widget.memberApi.trainerMapping,
        onSelect: widget.onNavigate,
        onScheduleBlocked: () => AppToastScope.read(
          context,
        ).showError(AppBottomNavigation.scheduleBlockedMessage),
      ),
      contents: _isPending
          ? const _WebLoadingText()
          : SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopBlock(
                    point: _point,
                    month: _month,
                    onMonthChanged: _onMonthChanged,
                  ),
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
}

/// 웹 `<div className='loading'>Loading..</div>` — **스타일이 없는 raw 텍스트**다
/// (BUG-13). `.loading` 클래스가 어디에도 정의돼 있지 않아 기본 글꼴로 그려진다.
///
/// S3는 `loading.gif`라 인디케이터로 바꿨지만, 여기는 **글자 자체가 웹 화면에
/// 보이는 것**이라 문구를 그대로 옮긴다.
class _WebLoadingText extends StatelessWidget {
  const _WebLoadingText();

  @override
  Widget build(BuildContext context) => const Center(child: Text('Loading..'));
}

/// 웹 헤더 — X 링크 + 가운데 제목.
///
/// **제목이 링크 위에 그려져 가운데를 가로챈다**(실측). Flutter `Text`는
/// 기본적으로 히트 테스트를 통과시키므로 [AbsorbPointer]로 그 동작을
/// 재현한다 — 없으면 제목을 눌러도 이동해서 웹과 달라진다.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({required this.title, required this.onClose});

  static const Key closeKey = ValueKey('TrainerManagePointHistoryPage.close');

  /// 웹 `h-[56px]`.
  static const double height = 56;

  /// 웹 `<IconClose width={14} height={14} />`.
  static const double iconSize = 14;

  /// 웹 `px-7`.
  static const double horizontalPadding = 20;

  final String title;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppBar(
      toolbarHeight: height,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Stack(
        alignment: Alignment.center,
        children: [
          // 웹 `<a className='h-full w-full'>` — 헤더 폭 전체가 탭 영역이다.
          GestureDetector(
            key: closeKey,
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: horizontalPadding),
                  child: SvgPicture.asset(
                    'assets/images/close.svg',
                    width: iconSize,
                    height: iconSize,
                  ),
                ),
              ),
            ),
          ),
          // 제목이 링크 **뒤에 선언돼 위에 그려지고**, 그 자리만 눌리지 않는다.
          //
          // 웹과 같은 동작이고 **Flutter가 저절로 그렇게 한다** — `Stack`은
          // 뒤 자식부터 히트 테스트하고 `Text`가 자기 영역에서 히트를
          // 보고한다(직접 확인: 제목 탭 0회 / X 자리 탭 1회). 처음에
          // `AbsorbPointer`로 감쌌다가, **빼도 동작이 같아** 걷어냈다 —
          // 뮤테이션이 그 위젯을 통과시켜서 드러났다.
          //
          // 순서를 뒤집어 링크를 위로 올리면 제목도 눌리게 되므로, 그 회귀는
          // `제목 자리는 눌리지 않는다` 테스트가 잡는다.
          Text(
            title,
            // 웹 `HEADING_4_SEMIBOLD` + `layout-header-title`.
            style: AppTypography.heading4SemiBold.copyWith(
              color: colors.gray800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 웹 `<div className='bg-white p-7 pb-11 pt-6'>` — 월 선택 + 포인트 카드 + 안내문.
class _TopBlock extends StatelessWidget {
  const _TopBlock({
    required this.point,
    required this.month,
    required this.onMonthChanged,
  });

  final StudentPoint? point;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TrainerManagePointHistoryPage.topBlockHorizontalPadding,
          TrainerManagePointHistoryPage.topBlockTopPadding,
          TrainerManagePointHistoryPage.topBlockHorizontalPadding,
          TrainerManagePointHistoryPage.topBlockBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // **좌측 정렬이다** — S3 수강권 화면과 달리 `justify-end`가 없다.
            Align(
              alignment: Alignment.centerLeft,
              child: AppMonthPicker(date: month, onChanged: onMonthChanged),
            ),
            _PointCard(point: point),
            const SizedBox(height: TrainerManagePointHistoryPage.cardBottomGap),
            const _Notice(),
          ],
        ),
      ),
    );
  }
}

/// 웹 포인트 카드 — `bg-primary-500 px-6 py-7 gap-y-1`.
class _PointCard extends StatelessWidget {
  const _PointCard({required this.point});

  final StudentPoint? point;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppCard(
      backgroundColor: colors.primary500,
      padding: const EdgeInsets.symmetric(
        horizontal: TrainerManagePointHistoryPage.cardHorizontalPadding,
        vertical: TrainerManagePointHistoryPage.cardVerticalPadding,
      ),
      gap: TrainerManagePointHistoryPage.cardRowGap,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                // BUG-3: 10·11·12월이 `0`·`1`·`2`월이 된다.
                '${point?.webMonthLabel ?? ''}월 활동 포인트',
                // 웹 `HEADING_5` + `text-white`.
                style: AppTypography.heading5.copyWith(color: Colors.white),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/point.png',
                  width: TrainerManagePointHistoryPage.pointIconSize,
                  height: TrainerManagePointHistoryPage.pointIconSize,
                ),
                const SizedBox(width: TrainerManagePointHistoryPage.inlineGap),
                Text(
                  '${point?.monthPoint ?? 0}',
                  // 웹 `HEADING_4` + `text-white`.
                  style: AppTypography.heading4.copyWith(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '누적',
              // 웹 `BODY_4_MEDIUM` + `text-blue-100`.
              //
              // **서베이의 BUG-14는 틀렸다** — `theme.extend`라 Tailwind 기본
              // `blue-100`이 살아 있고, 실측 색이 `rgb(219,234,254)`였다.
              style: AppTypography.body4Medium.copyWith(color: _blue100),
            ),
            Text(
              '${point?.totalPoint ?? 0}',
              // 웹 `BODY_3` + `text-white`.
              style: AppTypography.body3.copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  /// Tailwind 기본 `blue-100`(`#DBEAFE`). 실측 `rgb(219,234,254)`.
  ///
  /// 앱 팔레트(`AppColors`)에 없는 색이다 — 웹도 자기 토큰이 아니라 Tailwind
  /// 기본값을 우연히 쓰고 있어서, 토큰으로 승격하지 않고 이 화면에 둔다.
  static const Color _blue100 = Color(0xFFDBEAFE);
}

/// 웹 안내문 — 아이콘 12 + `활동 포인트는 매월 1일 자정 초기화됩니다.`
class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/notification.svg',
          width: TrainerManagePointHistoryPage.noticeIconSize,
          height: TrainerManagePointHistoryPage.noticeIconSize,
          // 웹 `stroke='black'`. 자산은 `currentColor`로 정규화돼 있다(규율 #13).
          theme: const SvgTheme(currentColor: Colors.black),
        ),
        const SizedBox(width: TrainerManagePointHistoryPage.inlineGap),
        // 웹 `BODY_4` — 색 지정이 없어 기본 `#020817`이다(실측 rgb(2,8,23)).
        const Text('활동 포인트는 매월 1일 자정 초기화됩니다.', style: AppTypography.body4),
      ],
    );
  }
}

/// 웹 `<ul className='bg-gray-100'>`.
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.items,
    required this.isLoadingMore,
    required this.hasNextPage,
  });

  final List<PointHistory> items;
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

/// 빈 상태 — S3와 **완전히 같은 치수**다(문구만 다르다).
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TrainerManagePointHistoryPage.emptyVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: TrainerManagePointHistoryPage.emptyIconBoxWidth,
            child: SvgPicture.asset(
              'assets/images/notification.svg',
              width: TrainerManagePointHistoryPage.emptyIconSize,
              height: TrainerManagePointHistoryPage.emptyIconSize,
              // 웹 `stroke='var(--gray-300)'`.
              theme: SvgTheme(currentColor: colors.gray300),
            ),
          ),
          const SizedBox(
            height: TrainerManagePointHistoryPage.emptyIconBottomGap,
          ),
          Text(
            '포인트 내역이 없습니다.',
            // 웹 `TITLE_1_BOLD` + `text-gray-700`.
            style: AppTypography.title1.copyWith(color: colors.gray700),
          ),
        ],
      ),
    );
  }
}

/// 웹 내역 항목 `<li className='px-7 py-8'>`.
///
/// **S3와 한 군데 다르다** — 날짜가 `BODY_4`(400)다. S3는
/// `BODY_4_MEDIUM`(500)이라 위젯을 공유하지 않았다(실측으로 확인).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final PointHistory item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TrainerManagePointHistoryPage.itemHorizontalPadding,
        vertical: TrainerManagePointHistoryPage.itemVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.createdAt == null
                ? ''
                : KoreanDateFormat.historyDate(item.createdAt!),
            // 웹 `cn(Typography.BODY_4, 'text-gray-500')` — **S3와 굵기가 다르다.**
            style: AppTypography.body4.copyWith(color: colors.gray500),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  item.typeLabel,
                  style: AppTypography.title3.copyWith(color: colors.gray700),
                ),
              ),
              Text(
                item.signedPoint,
                style: AppTypography.title3.copyWith(color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
