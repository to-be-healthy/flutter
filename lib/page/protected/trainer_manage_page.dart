import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/trainer/api/trainer_api.dart';
import '../../entity/trainer/model/trainer_member.dart';
import '../../shared/ui/app_dropdown_menu.dart';
import '../../widget/app_bottom_navigation.dart';
import '../../widget/app_layout.dart';

/// 웹 `page/manage/ui/StudentListPage.tsx` + `feature/manage/ui/StudentList.tsx`
/// 대응. `/trainer/manage` — 트레이너의 "나의 회원".
///
/// 치수는 전부 2026-09-15 브라우저 실측이다
/// (`docs/trainer-manage-s1-measurements.md`, 뷰포트 440×900).
///
/// ## 요청 1건
///
/// `GET /api/v1/trainers/members`뿐이다. 하단 네비(`TrainerNavigation`)는
/// 학생 쪽과 달리 **요청을 쏘지 않고**, 라우트 그룹 레이아웃도 조용하다.
/// 골든 `trainer-manage`가 그 1건을 고정한다.
///
/// ## 웹의 세 가지 상태를 그대로 옮긴다
///
/// 웹 `studentList`는 react-query의 `data`라 값이 **셋**이다.
///
/// | `data` | 언제 | 화면 |
/// |---|---|---|
/// | `undefined` | 로딩 중 · **요청 실패** | 로딩이면 검색바만, 실패면 `검색 결과가 없습니다.` |
/// | `null` | 서버가 `"data": null`(회원 0명) | `등록된 회원이 없습니다.` + `회원 등록하기` |
/// | `[...]` | 회원 있음 | 카드 목록(검색 결과 0건이면 `검색 결과가 없습니다.`) |
///
/// **요청이 실패하면 `null`이 아니라 `undefined`다.** `studentList === null`이
/// 거짓이 되어 빈 상태가 아니라 `검색 결과가 없습니다.`가 뜬다 — 에러 분기가
/// 아예 없는 웹(BUG-13: 19개 화면 전부 `isError` 사용 0건)의 결과다.
/// [_received]가 그 `undefined`와 `null`을 가른다.
///
/// ## 로딩 중에는 검색바만 남는다
///
/// 웹 `{!isLoading && (...)}`가 카운트·정렬·세 분기를 통째로 감싼다. 검색바는
/// 그 바깥이라 **스피너도 스켈레톤도 없이 검색바 하나만** 뜬다. 학생 지난
/// 예약(BUG-9)과 같은 부류라 그대로 옮긴다.
///
/// ## 옮기는 웹 버그
///
/// - **BUG-41** — `가입` 배지가 전원에게 붙는다. 웹은 `item.nonmember`를 읽고
///   서버는 `isNonmember`를 보내므로 조건이 언제나 참이다. 2026-09-15 실측에서
///   `isNonmember`가 `false`인 회원과 `true`인 회원 **둘 다** 배지를 달고
///   있었다. `/student` 홈에서 정한 "버그째 옮기고 기록한다"를 따른다.
/// - **BUG-22** — 검색어만 소문자로 바꾸고 이름은 그대로 둔다. 영문 이름
///   `Kim`은 `kim`으로 찾아지지 않는다.
/// - **BUG-4** — 웹 타입이 `nickName: null`로 못박혀 있지만 서버는 실제
///   별칭을 보낸다. 런타임 쪽이 옳으므로 값이 오면 그린다.
class TrainerManagePage extends StatefulWidget {
  const TrainerManagePage({
    required this.trainerApi,
    required this.onNavigate,
    super.key,
  });

  /// 웹 `Layout.Header`의 `px-7`(20) 안쪽, `h-7 w-7` 고스트 버튼.
  static const double headerActionSize = 20;

  /// 웹 `IconPlus`의 고유 크기. **정사각형이 아니다**(실측 A2).
  static const double plusIconWidth = 17;
  static const double plusIconHeight = 16;

  /// 검색바 바깥 래퍼 `px-7 py-6`.
  static const double searchOuterHorizontalPadding = 20;
  static const double searchOuterVerticalPadding = 16;

  /// 회색 입력 박스 `h-fit rounded-md bg-gray-200 px-6 py-4` — 실측 400×44.
  ///
  /// **높이 44는 고정값이 아니라 계산 결과다**: `py-4`(10+10) + 가장 높은
  /// 자식인 `<input>`의 줄 높이 24(`body1` 16×1.5). 돋보기 버튼(20)이
  /// 아니라 입력이 높이를 정한다.
  static const double searchBoxHeight = 44;
  static const double searchBoxHorizontalPadding = 16;
  static const double searchBoxVerticalPadding = 10;

  /// 돋보기 `h-7 w-7` 버튼과 그 안 svg가 **같은 20**이다(실측 B6).
  static const double searchIconSize = 20;

  /// 입력의 `px-5`.
  static const double searchInputHorizontalPadding = 12;

  /// 스크롤 영역 `mt-1 px-7`.
  static const double listTopMargin = 4;
  static const double listHorizontalPadding = 20;

  /// 카운트+정렬 행 `mb-4` — 실측 400×36.
  static const double countRowHeight = 36;
  static const double countRowBottomMargin = 10;

  /// 카드 `h-[72px] rounded-lg px-6 py-7`.
  static const double cardHeight = 72;
  static const double cardHorizontalPadding = 16;
  static const double cardVerticalPadding = 20;

  /// 카드 사이 `gap-y-4`, 목록 아래 `pb-8`.
  static const double cardGap = 10;
  static const double listBottomPadding = 24;

  /// 프로필 `h-10 w-10`(=32) / `IconProfileDefault width=32 height=32`.
  static const double avatarSize = 32;

  /// 아바타와 이름 블록 사이 `gap-x-6`.
  static const double avatarGap = 16;

  /// 1·2·3위만 테두리 색이 다르다(`page/manage/utils.ts`). `border-[2px]`가
  /// 기본 `border`(1px)를 이긴다.
  ///
  /// **기본 프로필 아이콘에는 테두리가 없다** — 웹은 매퍼를 `<Image>`에만
  /// 붙이고 `IconProfileDefault`에는 붙이지 않는다.
  static const double rankBorderWidth = 2;
  static const Color rankFirstBorder = Color(0xFFFFB950);
  static const Color rankSecondBorder = Color(0xFFC4C5CD);
  static const Color rankThirdBorder = Color(0xFFFFB58B);

  /// 이름과 `가입` 배지 사이 `gap-2`.
  static const double nameBadgeGap = 6;

  /// 배지 `rounded-sm bg-blue-50 px-3 py-[1.5px] text-[10px]`.
  ///
  /// **줄 높이는 상속값 `1.5`(단위 없음)라 10×1.5 = 15**다. 그래서 내용
  /// 기준 높이는 18(15+1.5+1.5)인데, 실측 렌더 높이는 **22.41**이다 —
  /// 부모 `flex flex-row`의 `align-items`가 `normal`(stretch)이라 형제인
  /// 이름(22.41)에 맞춰 늘어난다. 그 늘어남까지 옮긴다.
  static const double badgeHorizontalPadding = 8;
  static const double badgeVerticalPadding = 1.5;
  static const double badgeFontSize = 10;
  static const double badgeLineHeight = 1.5;

  /// `잔여`의 `mr-[2px]`.
  static const double remainLabelRightMargin = 2;

  /// 정렬 트리거 — 고스트 `Button`의 기본 사이즈 `h-11 py-[18px] px-4`.
  ///
  /// **`py-[18px]`(36)가 `h-11`(36)과 같아 콘텐츠 박스 높이가 0이다.**
  /// 웹에서는 아이콘·라벨이 그 0짜리 상자를 넘쳐 그려진다. Flutter에서는
  /// 높이 36에 세로 가운데로 두면 같은 그림이 된다 — 넘침을 흉내 낼 이유가
  /// 없다(보이는 결과가 같다).
  static const double sortTriggerHeight = 36;
  static const double sortTriggerHorizontalPadding = 10;
  static const double sortTriggerGap = 4;
  static const double sortIconWidth = 13;
  static const double sortIconHeight = 14;

  /// 드롭다운 패널 `absolute -right-9 top-1 w-[96px]` — 실측 96×100.
  /// 패딩·항목 높이 등 나머지는 공용 `AppDropdownMenu`가 갖는다.
  static const double dropdownWidth = 96;

  /// 트리거 기준 패널 위치(실측 D13). 오른쪽 변끼리 9 어긋나고, 트리거
  /// 아래에서 8 내려온다. **패널 폭에 의존하지 않는 형태로 적는다** —
  /// `left` 차이(−31.03)는 폭이 바뀌면 같이 바뀌는 값이라 근거가 약하다.
  static const double dropdownRightInset = 9;
  static const double dropdownTopOffset = 8;

  /// shadcn `border` 기본색(`--border`)과 `shadow-md`. 팔레트 토큰이 아니라
  /// 라이브러리 기본값이라 여기 리터럴로 둔다.
  static const Color popoverBorder = Color(0xFFE2E8F0);

  /// 빈 상태 `mb-[30%]` — **퍼센트 세로 마진은 부모의 폭 기준**이다.
  /// 400 × 30% = 120(실측 F27). 높이(683)의 30%가 아니다.
  static const double emptyBottomMargin = 120;

  /// `alert_circle.svg`의 고유 크기. 정사각형이 아니다.
  static const double emptyIconWidth = 35;
  static const double emptyIconHeight = 36;

  /// 아이콘과 문구 사이 `gap-y-5`, 문구 묶음과 버튼 사이 `gap-y-11`.
  static const double emptyIconTextGap = 12;
  static const double emptyGroupGap = 36;

  /// `회원 등록하기` — `h-12 w-[146px] px-8 py-3` + `gap-x-1`.
  static const double registerButtonHeight = 48;
  static const double registerButtonWidth = 146;
  static const double registerButtonGap = 4;

  final TrainerApi trainerApi;

  /// 라우터를 화면에 끼우지 않는다(규율 #3). 테스트는 이 콜백으로 이동을
  /// 확인한다.
  final ValueChanged<String> onNavigate;

  @override
  State<TrainerManagePage> createState() => _TrainerManagePageState();
}

/// 웹 `sortConditionMapper`(`StudentList.tsx:33~43`).
enum _SortCondition {
  /// `memberId` 오름차순.
  byMemberId('기본 순'),

  /// `ranking` 오름차순. 순위가 없는 회원은 서버가 **999**로 보내므로
  /// 자연히 뒤로 밀린다.
  byRanking('랭킹 순');

  const _SortCondition(this.label);

  final String label;

  int compare(TrainerMember a, TrainerMember b) => switch (this) {
    _SortCondition.byMemberId => a.memberId - b.memberId,
    _SortCondition.byRanking => a.ranking - b.ranking,
  };
}

class _TrainerManagePageState extends State<TrainerManagePage> {
  /// 웹 `isLoading`.
  bool _loading = true;

  /// 웹 `data !== undefined`. 응답을 **받았는가**를 기록한다.
  ///
  /// [_members]가 null인 이유가 "서버가 회원 0명이라 null을 줬다"인지
  /// "요청이 실패했다"인지를 이것만이 구분한다 — 두 경우의 화면이 다르다.
  bool _received = false;

  List<TrainerMember>? _members;

  _SortCondition _sort = _SortCondition.byMemberId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.trainerApi.members();
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
        _received = true;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      // 웹은 에러 분기가 없어 `data`가 `undefined`로 남는다 — 여기서도
      // `_received`를 세우지 않아 같은 상태를 만든다.
      setState(() {
        _members = null;
        _received = false;
        _loading = false;
      });
    }
  }

  /// 웹 `StudentListController(studentList ?? []).sort(...).search(...).get()`.
  ///
  /// **정렬이 먼저, 검색이 나중이다.** 웹은 `students.sort()`로 원본 배열을
  /// 제자리에서 뒤집지만 여기서는 복사본을 정렬한다 — 결과가 같고, 캐시를
  /// 건드리지 않는다(`deferred-minors.md`에 근거를 적어 뒀다).
  List<TrainerMember> get _processed {
    final sorted = [...?_members]..sort(_sort.compare);
    // BUG-22: 검색어만 소문자로 바꾼다. 이름은 그대로다.
    final keyword = _query.toLowerCase();
    return sorted.where((member) => member.name.contains(keyword)).toList();
  }

  void _openAddStudent() {
    _AddStudentDialog.show(context, onNavigate: widget.onNavigate);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppLayout(
      // 웹 `<Layout.Contents className='overflow-y-hidden'>` — 검색바는
      // 고정하고 목록만 스크롤한다.
      scrollable: false,
      header: AppLayoutHeader(
        title: '나의 회원',
        // **웹 S1만 `HEADING_4`(bold)다.** 지금까지 옮긴 아홉 화면은 전부
        // `HEADING_4_SEMIBOLD`라 기본값을 쓴다(웹 소스 grep으로 확인).
        titleStyle: AppTypography.heading4.copyWith(color: colors.gray800),
        // 웹은 `<Link href='/trainer'>`라 히스토리와 무관하게 늘 홈으로
        // 간다. 뒤로가기 pop이 아니다.
        onBack: () => widget.onNavigate(AppRoutes.trainerHome),
        trailing: _AddStudentTrigger(onPressed: _openAddStudent),
      ),
      bottomNavigation: AppTrainerBottomNavigation(
        currentLocation: AppTrainerBottomNavigation.manageRoute,
        onSelect: widget.onNavigate,
      ),
      contents: Column(
        children: [
          _SearchField(onChanged: (value) => setState(() => _query = value)),
          // 로딩 중에는 여기가 통째로 없다(웹 `{!isLoading && ...}`).
          if (!_loading)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: TrainerManagePage.listTopMargin,
                  left: TrainerManagePage.listHorizontalPadding,
                  right: TrainerManagePage.listHorizontalPadding,
                ),
                child: Column(
                  children: [
                    // **카운트+정렬은 세 분기 전부에서 보인다.** 웹에서
                    // 이 행은 분기들의 형제라, 회원이 0명이어도 `총 0명`과
                    // 살아 있는 정렬 드롭다운이 함께 뜬다.
                    _CountAndSortRow(
                      count: _processed.length,
                      sort: _sort,
                      onSortChanged: (sort) => setState(() => _sort = sort),
                    ),
                    const SizedBox(
                      height: TrainerManagePage.countRowBottomMargin,
                    ),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    // 웹 `studentList === null` — 서버가 회원 0명이라 null을 준 경우만이다.
    // 요청 실패(`undefined`)는 여기 걸리지 않는다.
    if (_received && _members == null) {
      return _EmptyState(
        message: '등록된 회원이 없습니다.',
        isRegisteredEmpty: true,
        onRegister: _openAddStudent,
      );
    }

    final processed = _processed;
    if (processed.isEmpty) {
      return const _EmptyState(
        message: '검색 결과가 없습니다.',
        isRegisteredEmpty: false,
      );
    }

    return ListView.separated(
      // 웹 `pb-8`. 목록 위에는 패딩이 없다.
      padding: const EdgeInsets.only(
        bottom: TrainerManagePage.listBottomPadding,
      ),
      itemCount: processed.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: TrainerManagePage.cardGap),
      itemBuilder: (context, index) {
        final member = processed[index];
        return _MemberCard(
          member: member,
          onTap: () =>
              widget.onNavigate(AppRoutes.trainerManageMember(member.memberId)),
        );
      },
    );
  }
}

/// 헤더 오른쪽 `+`. 웹 `AddStudentDialog`의 기본 트리거
/// (`Button variant='ghost' size='icon' className='h-7 w-7'`).
class _AddStudentTrigger extends StatelessWidget {
  const _AddStudentTrigger({required this.onPressed});

  static const Key buttonKey = ValueKey('TrainerManagePage.addStudent');

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: TrainerManagePage.headerActionSize,
        height: TrainerManagePage.headerActionSize,
        child: Center(
          child: SvgPicture.asset(
            'assets/images/plus.svg',
            width: TrainerManagePage.plusIconWidth,
            height: TrainerManagePage.plusIconHeight,
            // 웹 `<IconPlus fill='black' />`. 자산이 `fill="currentColor"`로
            // 정규화돼 있어 `currentColor`를 주지 않으면 검정으로 그려지지만,
            // 웹이 명시하는 값을 그대로 적는다.
            theme: const SvgTheme(currentColor: Colors.black),
          ),
        ),
      ),
    );
  }
}

/// 웹 검색바 — 바깥 `px-7 py-6` + 안쪽 `rounded-md bg-gray-200 px-6 py-4`.
///
/// **로딩 중에도 이것만은 남는다**(웹 `{!isLoading}` 바깥에 있다).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  static const Key fieldKey = ValueKey('TrainerManagePage.search');

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TrainerManagePage.searchOuterHorizontalPadding,
        vertical: TrainerManagePage.searchOuterVerticalPadding,
      ),
      child: Container(
        height: TrainerManagePage.searchBoxHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: TrainerManagePage.searchBoxHorizontalPadding,
        ),
        decoration: BoxDecoration(
          color: colors.gray200,
          // 웹 `rounded-md`.
          borderRadius: BorderRadius.circular(radius.m),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/search.svg',
              width: TrainerManagePage.searchIconSize,
              height: TrainerManagePage.searchIconSize,
            ),
            Expanded(
              child: TextField(
                key: fieldKey,
                onChanged: onChanged,
                style: AppTypography.body1.copyWith(color: colors.gray800),
                cursorColor: colors.primary500,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  // 웹 `px-5`. 세로 패딩은 없다 — 입력의 줄 높이 24가
                  // 그대로 회색 박스의 높이를 만든다.
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: TrainerManagePage.searchInputHorizontalPadding,
                  ),
                  hintText: '이름 검색',
                  // 웹 `placeholder:text-[16px]/[150%] placeholder:text-gray-500`.
                  hintStyle: AppTypography.body1.copyWith(
                    color: colors.gray500,
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

/// `총 n명` + 정렬 드롭다운 트리거.
class _CountAndSortRow extends StatelessWidget {
  const _CountAndSortRow({
    required this.count,
    required this.sort,
    required this.onSortChanged,
  });

  final int count;
  final _SortCondition sort;
  final ValueChanged<_SortCondition> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: TrainerManagePage.countRowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 웹 `총 <span>{n}</span>명` — **숫자만** TITLE_3 + primary-500이고
          // 앞뒤 글자는 BODY_2다. 한 줄 안에서 글꼴이 갈린다.
          Text.rich(
            TextSpan(
              style: AppTypography.body2.copyWith(color: colors.gray800),
              children: [
                const TextSpan(text: '총 '),
                TextSpan(
                  text: '$count',
                  style: AppTypography.title3.copyWith(
                    color: colors.primary500,
                  ),
                ),
                const TextSpan(text: '명'),
              ],
            ),
          ),
          _SortDropdown(sort: sort, onChanged: onSortChanged),
        ],
      ),
    );
  }
}

/// 정렬 드롭다운. 패널은 공용 [AppDropdownMenu]가 그린다.
class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.sort, required this.onChanged});

  static const Key triggerKey = ValueKey('TrainerManagePage.sortTrigger');

  final _SortCondition sort;
  final ValueChanged<_SortCondition> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppDropdownMenu(
      width: TrainerManagePage.dropdownWidth,
      // 트리거 오른쪽 변에서 9 안쪽, 아래로 8(실측 D13).
      offset: const Offset(
        -TrainerManagePage.dropdownRightInset,
        TrainerManagePage.dropdownTopOffset,
      ),
      items: [
        for (final condition in _SortCondition.values)
          AppDropdownMenuItem(
            label: condition.label,
            // 웹 `item.label === sort.label ? 'text-black' : 'text-gray-500'`.
            // **선택된 쪽이 gray800이 아니라 순수 검정이다.**
            color: condition == sort ? Colors.black : colors.gray500,
            onTap: () => onChanged(condition),
          ),
      ],
      trigger: SizedBox(
        key: triggerKey,
        height: TrainerManagePage.sortTriggerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TrainerManagePage.sortTriggerHorizontalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/icon_arrow_down_up.svg',
                width: TrainerManagePage.sortIconWidth,
                height: TrainerManagePage.sortIconHeight,
              ),
              const SizedBox(width: TrainerManagePage.sortTriggerGap),
              Text(
                sort.label,
                style: AppTypography.body3.copyWith(color: colors.gray800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 회원 카드 — 실측 400×72.
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final TrainerMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: TrainerManagePage.cardHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: TrainerManagePage.cardHorizontalPadding,
          vertical: TrainerManagePage.cardVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          // 웹 `rounded-lg`.
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  _Avatar(fileUrl: member.fileUrl, ranking: member.ranking),
                  const SizedBox(width: TrainerManagePage.avatarGap),
                  // 이름+별칭 묶음은 `py-7`이 남긴 32보다 높아질 수 있다
                  // (이름 22.4 + 별칭 18 = 40.4). 웹에는 `overflow-hidden`이
                  // 없어 카드 위아래로 넘쳐 그려질 뿐 카드 높이는 72
                  // 그대로다. `OverflowBox`가 그 "넘쳐 그리기"를 만든다 —
                  // 이게 없으면 Flutter는 RenderFlex 오버플로로 터진다.
                  Flexible(
                    child: OverflowBox(
                      minHeight: 0,
                      maxHeight: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: _MemberIdentity(member: member),
                    ),
                  ),
                ],
              ),
            ),
            _RemainingLessons(member: member, colors: colors),
          ],
        ),
      ),
    );
  }
}

/// 이름 + `가입` 배지 + 별칭.
class _MemberIdentity extends StatelessWidget {
  const _MemberIdentity({required this.member});

  final TrainerMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 웹 부모의 `align-items: normal`(stretch) 때문에 배지가 이름 높이에
        // 맞춰 늘어난다.
        //
        // **늘리는 주체는 배지의 `alignment`다.** `alignment`가 붙은
        // `Container`는 허용된 최대 크기까지 커지므로, 위에서 최대 높이만
        // 정해 주면 알아서 이름 높이에 맞춰진다 — 그리고 같은 속성이 웹
        // `flex-center`처럼 안쪽 글자를 가운데로 둔다. 한 속성이 두 일을
        // 하므로 `Row`에 `CrossAxisAlignment.stretch`를 겹쳐 두지 않는다
        // (겹치면 서로를 가려 어느 쪽을 지워도 테스트가 안 깨진다 —
        // 뮤테이션 M11·M26으로 확인했다).
        //
        // 그 "최대 높이"를 주는 것이 `IntrinsicHeight`다. 빼면 높이가
        // 무한이 되어 화면이 터진다(M23에서 46건 전부 실패).
        IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title1.copyWith(color: colors.gray800),
                ),
              ),
              // **BUG-41 — 배지가 전원에게 붙는다.**
              //
              // 웹 `{!item.nonmember && ...}`의 `nonmember`는 서버에 없는
              // 키(실제 키는 `isNonmember`)라 언제나 `undefined`이고,
              // `!undefined`는 참이다. 즉 조건이 사실상 없다.
              // `member.isNonmember`를 **일부러 보지 않는다** — 그 값을
              // 보는 순간 웹과 다른 화면이 된다.
              const SizedBox(width: TrainerManagePage.nameBadgeGap),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: TrainerManagePage.badgeHorizontalPadding,
                  vertical: TrainerManagePage.badgeVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: colors.blue50,
                  // 웹 `rounded-sm`.
                  borderRadius: BorderRadius.circular(radius.s),
                ),
                child: Text(
                  '가입',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: TrainerManagePage.badgeFontSize,
                    height: TrainerManagePage.badgeLineHeight,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: colors.primary500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // BUG-4: 웹 타입은 `null`로 못박혀 있지만 서버는 실제 별칭을 보낸다.
        if (member.nickName != null && member.nickName!.isNotEmpty)
          Text(
            member.nickName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body4.copyWith(color: colors.gray500),
          ),
      ],
    );
  }
}

/// 우측 `잔여 3/10`.
class _RemainingLessons extends StatelessWidget {
  const _RemainingLessons({required this.member, required this.colors});

  final TrainerMember member;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          // 웹 `mr-[2px]`.
          padding: const EdgeInsets.only(
            right: TrainerManagePage.remainLabelRightMargin,
          ),
          child: Text(
            '잔여',
            style: AppTypography.body3.copyWith(color: colors.primary500),
          ),
        ),
        Text(
          '${member.remainLessonCnt}',
          style: AppTypography.title3.copyWith(color: colors.primary500),
        ),
        Text(
          '/${member.lessonCnt}',
          style: AppTypography.body2.copyWith(color: colors.gray400),
        ),
      ],
    );
  }
}

/// 프로필. 웹은 `fileUrl`이 있을 때만 테두리를 그린다.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.fileUrl, required this.ranking});

  final String? fileUrl;
  final int ranking;

  /// 웹 `profileBorderStyleMapper`. 4위 이하는 색 지정이 없어 기본
  /// `border-gray-300`(1px)이 남는다.
  static Color? rankBorderColor(int ranking) => switch (ranking) {
    1 => TrainerManagePage.rankFirstBorder,
    2 => TrainerManagePage.rankSecondBorder,
    3 => TrainerManagePage.rankThirdBorder,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final url = fileUrl;

    if (url == null) {
      // 웹 `<IconProfileDefault width={32} height={32} />` — **테두리 없다.**
      return SvgPicture.asset(
        'assets/images/profile_default.svg',
        width: TrainerManagePage.avatarSize,
        height: TrainerManagePage.avatarSize,
      );
    }

    final rankColor = rankBorderColor(ranking);

    return Container(
      width: TrainerManagePage.avatarSize,
      height: TrainerManagePage.avatarSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          // 1·2·3위는 `border-[2px]`가 기본 `border`(1px)를 이긴다.
          color: rankColor ?? colors.gray300,
          width: rankColor == null ? 1 : TrainerManagePage.rankBorderWidth,
        ),
      ),
      child: Image.network(
        // 웹 `?w=300&h=300&q=90`.
        '$url?w=300&h=300&q=90',
        // 웹 `object-contain`. 다른 화면들의 `object-cover`와 다르다.
        fit: BoxFit.contain,
        // 위젯 테스트에서는 네트워크가 막혀 늘 이 가지로 떨어진다.
        errorBuilder: (context, error, stackTrace) => SvgPicture.asset(
          'assets/images/profile_default.svg',
          width: TrainerManagePage.avatarSize,
          height: TrainerManagePage.avatarSize,
        ),
      ),
    );
  }
}

/// 두 빈 상태. 아이콘과 문구는 같고 **글자색과 버튼 유무가 다르다.**
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.isRegisteredEmpty,
    this.onRegister,
  });

  final String message;

  /// true면 `등록된 회원이 없습니다.`(gray-700 + 등록 버튼),
  /// false면 `검색 결과가 없습니다.`(gray-500, 버튼 없음).
  final bool isRegisteredEmpty;

  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      // 웹 `mb-[30%]` — 퍼센트 세로 마진이라 **부모의 폭** 기준이다(실측 120).
      padding: const EdgeInsets.only(
        bottom: TrainerManagePage.emptyBottomMargin,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/alert_circle.svg',
              width: TrainerManagePage.emptyIconWidth,
              height: TrainerManagePage.emptyIconHeight,
            ),
            // 웹 `gap-y-5`.
            const SizedBox(height: TrainerManagePage.emptyIconTextGap),
            Text(
              message,
              style: AppTypography.title1.copyWith(
                color: isRegisteredEmpty ? colors.gray700 : colors.gray500,
              ),
            ),
            if (isRegisteredEmpty) ...[
              // 웹 `gap-y-11`. 자식이 둘일 때만 실효가 있다 — 검색 결과
              // 없음 쪽은 자식이 하나라 이 간격이 아예 생기지 않는다(실측).
              const SizedBox(height: TrainerManagePage.emptyGroupGap),
              _RegisterButton(onPressed: onRegister!),
            ],
          ],
        ),
      ),
    );
  }
}

/// `회원 등록하기` — `variant='default'` + `h-12 w-[146px] px-8 py-3`.
class _RegisterButton extends StatelessWidget {
  const _RegisterButton({required this.onPressed});

  static const Key buttonKey = ValueKey('TrainerManagePage.register');

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      key: buttonKey,
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: TrainerManagePage.registerButtonWidth,
        height: TrainerManagePage.registerButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary500,
          // shadcn Button 기본 `rounded-lg`.
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/plus.svg',
              width: TrainerManagePage.plusIconWidth,
              height: TrainerManagePage.plusIconHeight,
              // 웹 `<IconPlus fill='white' />`.
              theme: const SvgTheme(currentColor: Colors.white),
            ),
            // 웹 `gap-x-1`.
            const SizedBox(width: TrainerManagePage.registerButtonGap),
            Text(
              '회원 등록하기',
              style: AppTypography.title3.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `feature/manage/ui/AddStudentDialog.tsx` — 전체 폭 상단 다이얼로그.
///
/// 이 화면에서 **두 군데**가 연다: 헤더의 `+`와 빈 상태의 `회원 등록하기`.
/// 웹도 같은 컴포넌트를 두 번 쓴다(후자는 `children`으로 트리거를 갈아끼운다).
///
/// 치수는 실측 G29~G33이다. 눈에 띄는 것 둘:
/// - **모서리가 둥글지 않다**(`borderRadius: 0`). `p-0`이 패딩만 지우는데
///   shadcn 기본에 라운드가 없어서다.
/// - **테두리 1px이 있어 안쪽 폭이 440이 아니라 438**이다.
class _AddStudentDialog extends StatelessWidget {
  const _AddStudentDialog({required this.onNavigate});

  /// 웹 `max-w-[var(--max-width)]`.
  static const double maxWidth = 440;

  /// shadcn `border` 1px. 이것 때문에 안쪽이 438이 된다.
  static const double borderWidth = 1;

  /// 헤더 높이는 공용 `Layout.Header`와 같은 56이다.
  static const double headerHeight = 56;
  static const double headerHorizontalPadding = 20;

  /// shadcn `DialogContent`의 `grid gap-4` — 헤더와 본문 사이.
  static const double sectionGap = 10;

  /// 본문 `py-6`.
  static const double bodyVerticalPadding = 16;

  /// 닫기 버튼은 **세로로만 크다**(실측 20×36). 고스트가 아니라
  /// `variant='outline'`에 `p-0`이라 폭은 svg 그대로고 높이만 `h-11`이다.
  static const double closeButtonWidth = 20;
  static const double closeButtonHeight = 36;
  static const double closeIconSize = 20;

  /// 헤더 왼쪽의 빈 자리(`w-[40px]`). **높이가 0이다** — 제목을 가운데로
  /// 밀기 위한 자리차지일 뿐이다.
  static const double dummyWidth = 40;

  /// `people_plus.svg`는 25×24, `peoples.svg`는 24×24다(실측 G32).
  static const double peoplePlusWidth = 25;
  static const double peoplePlusHeight = 24;
  static const double peoplesSize = 24;

  /// 아이콘과 글자 사이 `gap-y-2`.
  static const double linkGap = 6;

  /// 웹 `bg-black/80`.
  static const Color barrier = Color(0xCC000000);

  static const Key closeKey = ValueKey('AddStudentDialog.close');
  static const Key inviteKey = ValueKey('AddStudentDialog.invite');
  static const Key appendKey = ValueKey('AddStudentDialog.append');

  final ValueChanged<String> onNavigate;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onNavigate,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '회원 추가',
      barrierColor: barrier,
      // 웹은 `data-[state=open]:animate-in`으로 페이드+줌이 붙지만, 시간은
      // shadcn 기본 `duration-200`이다.
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _AddStudentDialog(onNavigate: onNavigate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Align(
      // 웹 `top-0` + `translate-y-0` — 화면 맨 위에 붙는다.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: TrainerManagePage.popoverBorder,
                width: borderWidth,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29000000),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(context, colors),
                const SizedBox(height: sectionGap),
                _body(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors colors) {
    return SizedBox(
      height: headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: headerHorizontalPadding,
        ),
        child: Row(
          // 웹 `flex-row-reverse` + 공용 헤더의 `justify-between`.
          // 자식 순서를 뒤집으면 닫기가 오른쪽, 빈 자리가 왼쪽에 놓인다 —
          // 실측 좌표(닫기 left 399, 빈 자리 left 21)와 같다.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: dummyWidth, height: 0),
            Text(
              '회원 추가',
              // 웹 `Typography.HEADING_4` — bold다.
              style: AppTypography.heading4.copyWith(color: colors.gray800),
            ),
            GestureDetector(
              key: closeKey,
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: closeButtonWidth,
                height: closeButtonHeight,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/icon_close.svg',
                    width: closeIconSize,
                    height: closeIconSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: bodyVerticalPadding),
      child: Row(
        children: [
          // 웹 `justify-evenly`는 **실효가 없다** — 두 링크가 `w-full`이라
          // 남는 공간이 0이다. 각자 정확히 절반을 차지한다(실측 219 + 219).
          Expanded(
            child: _link(
              key: inviteKey,
              asset: 'assets/images/people_plus.svg',
              width: peoplePlusWidth,
              height: peoplePlusHeight,
              label: '회원 직접 추가',
              route: AppRoutes.trainerManageInvite,
              colors: colors,
            ),
          ),
          Expanded(
            child: _link(
              key: appendKey,
              asset: 'assets/images/peoples.svg',
              width: peoplesSize,
              height: peoplesSize,
              label: '가입된 회원 추가',
              route: AppRoutes.trainerManageAppend,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _link({
    required Key key,
    required String asset,
    required double width,
    required double height,
    required String label,
    required String route,
    required AppColors colors,
  }) {
    return Builder(
      builder: (context) => GestureDetector(
        key: key,
        onTap: () {
          // 웹은 `<Link>`라 라우트가 바뀌면서 다이얼로그가 언마운트된다.
          Navigator.of(context).pop();
          onNavigate(route);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(asset, width: width, height: height),
            const SizedBox(height: linkGap),
            Text(
              label,
              // 웹 `Typography.HEADING_5` — 13/150%/600.
              style: AppTypography.heading5.copyWith(color: colors.gray800),
            ),
          ],
        ),
      ),
    );
  }
}
