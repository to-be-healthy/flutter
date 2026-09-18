import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/router/app_router.dart';
import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/diet/model/diet.dart';
import '../../entity/trainer/api/trainer_api.dart';
import '../../entity/trainer/model/trainer_member_detail.dart';
import '../../feature/course/ui/course_card.dart';
import '../../shared/ui/app_checkbox.dart';
import '../../shared/ui/app_dropdown_menu.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `page/manage/ui/TrainerStudentDetailPage/index.tsx` + `Header.tsx`.
/// `/trainer/manage/[memberId]` — 트레이너가 보는 "회원 정보".
///
/// 치수는 2026-09-16 브라우저 실측이다
/// (`docs/trainer-manage-s2-measurements.md`, 뷰포트 440×900).
///
/// ## 요청 1건
///
/// `GET /api/v1/trainers/members/{memberId}`뿐이다. `<Layout>`에 `type`이
/// 없어 **하단 네비가 없고**, 그래서 네비가 쏘는 요청도 없다.
///
/// ## 응답이 오기 전에는 **화면이 통째로 비어 있다**
///
/// 웹 `{memberInfo && (<><Header/><Layout.Contents/></>)}`가 **헤더까지**
/// 감싼다. 로딩 중에도, 요청이 실패해도 뒤로가기 버튼조차 없다 — 회원
/// 지난 예약(BUG-9)과 같은 부류이고 그대로 옮긴다.
///
/// ## 수강권·포인트 블록은 학생 홈과 같은 컴포넌트다
///
/// 웹이 `CourseCard`/`CourseCardHeader`/`CourseCardContent`를 공유하고,
/// 그 아래 접이식 블록은 두 화면이 각자 인라인으로 쓴다. 두 인라인 블록을
/// 클래스 단위로 대조한 결과 **다른 점은 하나뿐이었다** — 학생 홈 포인트
/// 바에는 `h-[54px]`가 있고 여기에는 없다(내용이 높이를 정해 접힘 54.4 /
/// 펼침 51.5). `CourseCard.pointBarHeight`에 null을 넘겨 그 차이만 맞춘다.
///
/// ## 옮기는 웹 버그
///
/// - **BUG-3** — `{M}월 활동 포인트`의 월이 `searchDate.split('-')[1]
///   .split('')[1]`이라 10·11·12월이 `0월`·`1월`·`2월`이 된다. 학생 홈에서
///   이미 결정·구현된 `StudentPoint.webMonthLabel`을 그대로 쓴다.
/// - **BUG-26** — `<IconArrowDown widht={14} …>` 오타로 prop이 안 먹는다.
///   `CourseCard` 주석 참고.
class TrainerManageMemberPage extends StatefulWidget {
  const TrainerManageMemberPage({
    required this.trainerApi,
    required this.memberId,
    required this.onNavigate,
    required this.onBack,
    super.key,
  });

  /// 웹 `Layout.Contents`의 `p-7 pt-8` — 위만 24, 나머지 20.
  static const double contentTopPadding = 24;
  static const double contentPadding = 20;

  /// 뒤로가기 `<button>`은 패딩이 0이라 히트 영역이 svg와 같다(실측 20×20).
  static const double backButtonSize = 20;

  /// 케밥 버튼은 고스트 `Button` 기본 사이즈(`h-11 px-4`)라 **24×36**이고,
  /// 그 안 svg는 `dots_vertical.svg`의 고유 크기 4×16이다.
  static const double kebabButtonWidth = 24;
  static const double kebabButtonHeight = 36;
  static const double kebabIconWidth = 4;
  static const double kebabIconHeight = 16;

  /// 웹 `w-[130px]`. 패널 우변이 케밥 우변과 **정확히 맞고**(0),
  /// 케밥 아래로 4 내려온다(실측 B6).
  static const double menuWidth = 130;
  static const double menuRightInset = 0;
  static const double menuTopOffset = 4;

  /// 기본 프로필 아이콘은 크기 prop이 없어 **자산 고유 크기 82**로 뜬다.
  /// 사진이 있을 때의 `h-[80px] w-[80px]`와 **2px 다르다** — 웹이 두 분기에
  /// 다른 크기를 쓰는 것이라 맞추지 않는다(회원 마이페이지 아바타와 같은
  /// 종류의 함정이다. 규율 #18).
  static const double defaultProfileSize = 82;
  static const double photoProfileSize = 80;

  /// 프로필 사진과 이름 사이 `gap-x-8`.
  static const double profileGap = 24;

  /// 프로필 행 아래 `mb-6`. 바로가기·수강권·식단 카드도 같은 값이다.
  static const double sectionGap = 16;

  /// 이름 아래 줄의 `gap-x-2`. **실측 계정에서는 이 줄이 비어 있었다** —
  /// 두 회원 다 `ranking: 999`·`nickName: null`이라 높이가 0이다.
  static const double subLineGap = 6;

  /// 구분선 `h-[11px] w-[1px] bg-gray-300`. **렌더된 것을 보지 못했다**
  /// (위와 같은 이유) — 클래스에서 읽은 값이다.
  static const double subLineDividerWidth = 1;
  static const double subLineDividerHeight = 11;

  /// 바로가기 카드 `px-8 py-5 shadow-sm` — 실측 400×71.5.
  static const double shortcutHorizontalPadding = 24;
  static const double shortcutVerticalPadding = 12;

  /// 아이콘 래퍼 `flex h-7` — 아이콘 크기가 제각각이라 줄을 맞추는 상자다.
  static const double shortcutIconBoxHeight = 20;

  /// 아이콘과 글자 사이 `gap-y-3`.
  static const double shortcutIconTextGap = 8;

  /// 세로 구분선 `h-11 w-[1px] bg-gray-100`.
  static const double shortcutDividerWidth = 1;
  static const double shortcutDividerHeight = 36;

  /// 카드 그림자 `shadow-sm` — 실측 `0 4 12 rgba(0,0,0,0.08)`.
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x14000000),
    offset: Offset(0, 4),
    blurRadius: 12,
  );

  /// 수강권 없음 카드 `h-[127px]`.
  static const double noCourseCardHeight = 127;

  /// 식단·운동기록 카드 `px-6 py-7` — 실측 400×61.
  static const double listCardHorizontalPadding = 16;
  static const double listCardVerticalPadding = 20;

  /// `icon_arrow_right.svg`의 실측 크기. 자산 고유값(10×17)이다.
  static const double rightArrowWidth = 10;
  static const double rightArrowHeight = 17;

  final TrainerApi trainerApi;
  final Object memberId;
  final ValueChanged<String> onNavigate;

  /// 웹 `router.back()` — 이 화면만은 홈 고정이 아니라 진짜 뒤로가기다.
  final VoidCallback onBack;

  @override
  State<TrainerManageMemberPage> createState() =>
      _TrainerManageMemberPageState();
}

class _TrainerManageMemberPageState extends State<TrainerManageMemberPage> {
  TrainerMemberDetail? _detail;
  bool _isPointOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.trainerApi.member(widget.memberId);
      if (!mounted) {
        return;
      }
      setState(() => _detail = detail);
    } on Object {
      // 웹에는 에러 분기가 없다(BUG-13). `memberInfo`가 undefined로 남아
      // **화면이 통째로 비어 있는 것**이 웹의 동작이다.
      if (!mounted) {
        return;
      }
      setState(() => _detail = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    // 웹 `{memberInfo && (...)}` — 헤더까지 함께 사라진다.
    if (detail == null) {
      return const AppLayout(contents: SizedBox.shrink());
    }

    return AppLayout(
      header: _Header(
        name: detail.name,
        memberId: widget.memberId,
        onBack: widget.onBack,
        onNavigate: widget.onNavigate,
        onDelete: _confirmDelete,
        onRefundDelete: _openRefundSheet,
      ),
      contents: Padding(
        padding: const EdgeInsets.fromLTRB(
          TrainerManageMemberPage.contentPadding,
          TrainerManageMemberPage.contentTopPadding,
          TrainerManageMemberPage.contentPadding,
          TrainerManageMemberPage.contentPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileRow(detail: detail),
            const SizedBox(height: TrainerManageMemberPage.sectionGap),
            _ShortcutCard(
              memberId: widget.memberId,
              name: detail.name,
              onNavigate: widget.onNavigate,
            ),
            const SizedBox(height: TrainerManageMemberPage.sectionGap),
            ..._courseSection(detail),
            ..._dietSection(detail),
            _ListCard(
              title: '개인 운동 기록',
              onTap: () => widget.onNavigate(
                AppRoutes.trainerManageMemberWorkout(widget.memberId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _courseSection(TrainerMemberDetail detail) {
    final course = detail.course;
    if (course == null) {
      // 웹 `{!memberInfo.course && <Card h-[127px] bg-gray-500 …>}`.
      return const [
        _NoCourseCard(),
        SizedBox(height: TrainerManageMemberPage.sectionGap),
      ];
    }
    return [
      CourseCard(
        course: course,
        gymName: detail.gymName,
        point: detail.point,
        rank: detail.rank,
        isPointOpen: _isPointOpen,
        // 웹에 `h-[54px]`가 없다 — 내용이 높이를 정한다.
        pointBarHeight: null,
        onTogglePoint: () => setState(() => _isPointOpen = !_isPointOpen),
        onOpenCourseHistory: () => widget.onNavigate(
          // 웹 `query: {name: memberInfo.name}` — 다음 화면 제목이 쓴다.
          AppRoutes.trainerManageMemberCourseHistory(
            widget.memberId,
            name: detail.name,
          ),
        ),
        onOpenPointHistory: () => widget.onNavigate(
          AppRoutes.trainerManageMemberPointHistory(widget.memberId),
        ),
      ),
      const SizedBox(height: TrainerManageMemberPage.sectionGap),
    ];
  }

  List<Widget> _dietSection(TrainerMemberDetail detail) {
    void openDiet() =>
        widget.onNavigate(AppRoutes.trainerManageMemberDiet(widget.memberId));

    if (detail.hasTodayDiet) {
      return [
        _TodayDietCard(diet: detail.diet!, onOpenAll: openDiet),
        const SizedBox(height: TrainerManageMemberPage.sectionGap),
      ];
    }
    if (detail.hasNoDietYet) {
      return [
        _ListCard(title: '등록 식단', onTap: openDiet),
        const SizedBox(height: TrainerManageMemberPage.sectionGap),
      ];
    }
    // `dietId`가 0이거나 `diet` 자체가 없는 경우 — 웹도 두 카드 모두
    // 그리지 않는다(`&&`와 `=== null` 어디에도 안 걸린다).
    return const [];
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: _DeleteAlert.barrier,
      builder: (context) => _DeleteAlert(name: _detail?.name ?? ''),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    // `await` 앞에서 컨트롤러를 잡는다 — 삭제가 성공하면 이 화면은
    // 사라지므로, 뒤에서 `context`를 조회하면 죽은 컨텍스트가 된다
    // (`app_toast.dart`의 호출 규약).
    final toast = AppToastScope.read(context);
    try {
      await widget.trainerApi.deleteMember(widget.memberId);
      if (!mounted) {
        return;
      }
      // 웹 `router.replace('/trainer/manage')`.
      widget.onNavigate(AppRoutes.trainerManage);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      toast.showError(serverMessage(error));
    }
  }

  Future<void> _openRefundSheet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: _RefundSheet.barrier,
      // 웹 시트는 `fixed bottom-0`이라 높이 상한이 없다. Flutter 기본값
      // (화면의 9/16)에 걸리면 내용이 잘린다 — 월 선택 시트와 같은 이유.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_RefundSheet.topRadius),
        ),
      ),
      constraints: const BoxConstraints(maxWidth: _RefundSheet.maxWidth),
      builder: (context) => const _RefundSheet(),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final toast = AppToastScope.read(context);
    try {
      final message = await widget.trainerApi.deleteMemberWithRefund(
        widget.memberId,
      );
      if (!mounted) {
        return;
      }
      // 웹 `onSuccess: ({message}) => successToast(message)` — 서버 문구를
      // 그대로 띄운다.
      if (message != null && message.isNotEmpty) {
        toast.showSuccess(message);
      }
      widget.onNavigate(AppRoutes.trainerManage);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      toast.showError(serverMessage(error));
    }
  }
}

/// 웹 `Header.tsx`의 `Layout.Header` — 뒤로가기 / 제목 / 케밥.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({
    required this.name,
    required this.memberId,
    required this.onBack,
    required this.onNavigate,
    required this.onDelete,
    required this.onRefundDelete,
  });

  static const Key kebabKey = ValueKey('TrainerManageMemberPage.kebab');

  final String name;
  final Object memberId;
  final VoidCallback onBack;
  final ValueChanged<String> onNavigate;
  final VoidCallback onDelete;
  final VoidCallback onRefundDelete;

  @override
  Size get preferredSize => const Size.fromHeight(AppLayoutHeader.height);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppLayoutHeader(
      title: '회원 정보',
      // 웹 `HEADING_4_SEMIBOLD` + **`text-black`** — 본문 글자색
      // (`rgb(2,8,23)`)이 아니라 순수 검정이다(실측 A3).
      titleStyle: AppTypography.heading4SemiBold.copyWith(color: Colors.black),
      onBack: onBack,
      trailing: AppDropdownMenu(
        width: TrainerManageMemberPage.menuWidth,
        // 패널 우변이 케밥 우변과 정확히 맞고, 아래로 4 내려온다(실측 B6).
        offset: const Offset(
          -TrainerManageMemberPage.menuRightInset,
          TrainerManageMemberPage.menuTopOffset,
        ),
        items: [
          AppDropdownMenuItem(
            label: '별칭 설정',
            onTap: () =>
                onNavigate(AppRoutes.trainerManageMemberEditNickname(memberId)),
          ),
          AppDropdownMenuItem(label: '회원 삭제', onTap: onDelete),
          AppDropdownMenuItem(
            label: '환불 회원 삭제',
            // 웹 `text-point` — 위험한 항목만 빨갛다.
            color: colors.point,
            onTap: onRefundDelete,
          ),
        ],
        trigger: SizedBox(
          key: kebabKey,
          width: TrainerManageMemberPage.kebabButtonWidth,
          height: TrainerManageMemberPage.kebabButtonHeight,
          child: Center(
            child: SvgPicture.asset(
              'assets/images/dots_vertical.svg',
              width: TrainerManageMemberPage.kebabIconWidth,
              height: TrainerManageMemberPage.kebabIconHeight,
            ),
          ),
        ),
      ),
    );
  }
}

/// 프로필 사진 + 이름 + (별칭 / 구분선 / 랭킹).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.detail});

  final TrainerMemberDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        _Profile(detail: detail),
        const SizedBox(width: TrainerManageMemberPage.profileGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                detail.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // 웹 `HEADING_2`(22/130/700).
                style: AppTypography.heading2.copyWith(color: colors.gray800),
              ),
              // **실측 계정에서는 이 줄이 통째로 비어 있었다**(높이 0) —
              // 두 회원 다 `ranking: 999`·`nickName: null`이다. 세 조각의
              // 조건은 웹 소스에서 읽었고 모델 테스트가 고정한다.
              _SubLine(detail: detail),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubLine extends StatelessWidget {
  const _SubLine({required this.detail});

  final TrainerMemberDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final style = AppTypography.body3.copyWith(color: colors.gray500);

    final nickName = detail.nickName;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nickName != null && nickName.isNotEmpty)
          Text(nickName, style: style),
        // **`||`가 아니라 `&&`다** — 랭킹과 별칭이 둘 다 있을 때만 나온다.
        if (detail.showsDivider) ...[
          const SizedBox(width: TrainerManageMemberPage.subLineGap),
          Container(
            width: TrainerManageMemberPage.subLineDividerWidth,
            height: TrainerManageMemberPage.subLineDividerHeight,
            color: colors.gray300,
          ),
        ],
        if (detail.showsRanking) ...[
          if (nickName != null && nickName.isNotEmpty)
            const SizedBox(width: TrainerManageMemberPage.subLineGap),
          Text.rich(
            TextSpan(
              style: style,
              children: [
                const TextSpan(text: '랭킹 '),
                TextSpan(
                  text: '${detail.ranking}',
                  style: style.copyWith(color: colors.primary500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 웹 `{fileUrl ? <Image 80×80 …/> : <IconDefaultProfile/>}`.
class _Profile extends StatelessWidget {
  const _Profile({required this.detail});

  final TrainerMemberDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final url = detail.fileUrl;

    if (url == null || url.isEmpty) {
      // **크기 prop이 없어 자산 고유 크기 82로 뜬다**(실측 E22).
      // 사진 분기의 80과 2px 다르다 — 맞추면 웹과 달라진다.
      return SvgPicture.asset(
        'assets/images/icon_default_profile.svg',
        width: TrainerManageMemberPage.defaultProfileSize,
        height: TrainerManageMemberPage.defaultProfileSize,
      );
    }

    final rankColor = _rankBorderColor(detail.ranking);
    return Container(
      width: TrainerManageMemberPage.photoProfileSize,
      height: TrainerManageMemberPage.photoProfileSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: rankColor ?? colors.gray300,
          width: rankColor == null ? 1 : 2,
        ),
      ),
      child: Image.network(
        '$url?w=300&h=300&q=90',
        // 웹 `object-cover`. S1 카드(`object-contain`)와 **다르다.**
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SvgPicture.asset(
          'assets/images/icon_default_profile.svg',
          width: TrainerManageMemberPage.photoProfileSize,
          height: TrainerManageMemberPage.photoProfileSize,
        ),
      ),
    );
  }

  /// 웹 `profileBorderStyleMapper` — S1 카드와 같은 매퍼다.
  static Color? _rankBorderColor(int ranking) => switch (ranking) {
    1 => const Color(0xFFFFB950),
    2 => const Color(0xFFC4C5CD),
    3 => const Color(0xFFFFB58B),
    _ => null,
  };
}

/// 3열 바로가기 카드 — 실측 400×71.5.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.memberId,
    required this.name,
    required this.onNavigate,
  });

  final Object memberId;
  final String name;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TrainerManageMemberPage.shortcutHorizontalPadding,
        vertical: TrainerManageMemberPage.shortcutVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius.l),
        boxShadow: const [TrainerManageMemberPage.cardShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ShortcutColumn(
            asset: 'assets/images/icon_calendar_blue.svg',
            width: 19,
            height: 18,
            label: '예약 내역',
            // 웹 `?name=${memberInfo?.name}` — 없으면 다음 화면의 제목이
            // 통째로 사라진다.
            onTap: () => onNavigate(
              AppRoutes.trainerManageMemberReservation(memberId, name: name),
            ),
          ),
          _ShortcutDivider(color: colors.gray100),
          _ShortcutColumn(
            asset: 'assets/images/icon_edit.svg',
            width: 21,
            height: 20,
            label: '회원 메모',
            onTap: () =>
                onNavigate(AppRoutes.trainerManageMemberEditMemo(memberId)),
          ),
          _ShortcutDivider(color: colors.gray100),
          _ShortcutColumn(
            asset: 'assets/images/icon_dumbel.svg',
            width: 20,
            height: 11,
            label: '수업 일지',
            onTap: () => onNavigate(AppRoutes.trainerManageMemberLog(memberId)),
          ),
        ],
      ),
    );
  }
}

class _ShortcutDivider extends StatelessWidget {
  const _ShortcutDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: TrainerManageMemberPage.shortcutDividerWidth,
    height: TrainerManageMemberPage.shortcutDividerHeight,
    color: color,
  );
}

class _ShortcutColumn extends StatelessWidget {
  const _ShortcutColumn({
    required this.asset,
    required this.width,
    required this.height,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final double width;
  final double height;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 웹 `flex h-7 items-center justify-center` — **세 아이콘의 고유
          // 크기가 제각각이라**(19×18 / 21×20 / 20×11) 높이 20짜리 상자로
          // 줄을 맞춘다. 상자를 없애면 열마다 글자 높이가 어긋난다.
          SizedBox(
            height: TrainerManageMemberPage.shortcutIconBoxHeight,
            child: Center(
              child: SvgPicture.asset(asset, width: width, height: height),
            ),
          ),
          const SizedBox(height: TrainerManageMemberPage.shortcutIconTextGap),
          Text(
            label,
            // 웹 `HEADING_5`(13/150/600).
            style: AppTypography.heading5.copyWith(color: colors.gray800),
          ),
        ],
      ),
    );
  }
}

/// 웹 `{!memberInfo.course && <Card h-[127px] bg-gray-500 …>}`.
class _NoCourseCard extends StatelessWidget {
  const _NoCourseCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      height: TrainerManageMemberPage.noCourseCardHeight,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.gray500,
        borderRadius: BorderRadius.circular(radius.l),
      ),
      child: Text(
        '현재 등록된 수강권이 없습니다.',
        // 웹 `TITLE_3`(14/150/600) + `text-white`.
        style: AppTypography.title3.copyWith(color: Colors.white),
      ),
    );
  }
}

/// `등록 식단` · `개인 운동 기록` — 제목 + 오른쪽 화살표만 있는 카드.
/// 실측 400×61로 둘이 완전히 같은 모양이다.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.onTap});

  final String title;
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: TrainerManageMemberPage.listCardHorizontalPadding,
          vertical: TrainerManageMemberPage.listCardVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius.l),
          boxShadow: const [TrainerManageMemberPage.cardShadow],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              // 웹 `TITLE_2`(15/140/600) + `text-gray-800`.
              style: AppTypography.title2.copyWith(color: colors.gray800),
            ),
            SvgPicture.asset(
              'assets/images/icon_arrow_right.svg',
              width: TrainerManageMemberPage.rightArrowWidth,
              height: TrainerManageMemberPage.rightArrowHeight,
              // 자산의 `stroke="current"`를 정규화해 두었다(규율 #13).
              // 실측 stroke는 `#5F6165` = gray600이다.
              theme: SvgTheme(currentColor: colors.gray600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `{memberInfo.diet.dietId && <Card>오늘 식단 …</Card>}`.
///
/// **이 분기를 브라우저에서 보지 못했다.** 실측 계정 두 회원 모두
/// `dietId: null`이라 `등록 식단`으로 떨어졌고, 3칸 블록은 DOM에 아예
/// 없었다(측정 실패 H40). 아래 치수는 웹 소스의 클래스에서 옮긴 것이다 —
/// `deferred-minors.md`에 디자인 검수 항목으로 남겼다.
///
/// 학생 홈의 `TodayDietTile`을 쓰지 않는다. **빈 칸 분기가 다르다** —
/// 그쪽은 `+` 아이콘을 그려 등록을 유도하지만, 트레이너 화면의 빈 칸은
/// 아무것도 없는 회색 상자다(`<div className='h-[88px] w-full rounded-md
/// bg-gray-100 p-0' />`).
class _TodayDietCard extends StatelessWidget {
  const _TodayDietCard({required this.diet, required this.onOpenAll});

  /// 웹 `h-[88px]`.
  static const double tileHeight = 88;

  /// 웹 `<IconCheck width={17} height={17} />`.
  static const double checkIconSize = 17;

  /// 칸 사이 `gap-2`.
  static const double tileGap = 6;

  /// 헤더 아래 `mb-7`.
  static const double headerGap = 20;

  final HomeDiet diet;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TrainerManageMemberPage.listCardHorizontalPadding,
        vertical: TrainerManageMemberPage.listCardVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius.l),
        boxShadow: const [TrainerManageMemberPage.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '오늘 식단',
                style: AppTypography.title2.copyWith(color: colors.gray800),
              ),
              GestureDetector(
                onTap: onOpenAll,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  // **`등록 식단` 카드와 달리 화살표가 아니라 글자다.**
                  '식단전체',
                  style: AppTypography.body3.copyWith(color: colors.gray500),
                ),
              ),
            ],
          ),
          const SizedBox(height: headerGap),
          Row(
            children: [
              // **인덱스로 센다.** `meal != diet.breakfast`로 첫 칸을
              // 가려내면 `DietMeal`에 값 동등성이 생기는 순간 조용히
              // 깨진다 — 빈 끼니 셋은 필드가 모두 같아서 전부 "첫 칸"이
              // 되거나 전부 아니게 된다.
              for (final (index, meal) in diet.meals.indexed) ...[
                if (index > 0) const SizedBox(width: tileGap),
                Expanded(child: _DietTile(meal: meal)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DietTile extends StatelessWidget {
  const _DietTile({required this.meal});

  final DietMeal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return switch (meal.tile) {
      // 웹 `{meal.fast && <div … bg-gray-100 text-gray-400>단식</div>}` —
      // **단식이 사진을 이긴다**(`DietMeal.tile`이 그 순서를 담는다).
      DietTile.fasting => Container(
        height: _TodayDietCard.tileHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.gray100,
          borderRadius: BorderRadius.circular(radius.m),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/check.svg',
              width: _TodayDietCard.checkIconSize,
              height: _TodayDietCard.checkIconSize,
              // 웹 `<IconCheck fill={'var(--primary-500)'} />`.
              theme: SvgTheme(currentColor: colors.primary500),
            ),
            // 웹 `<span className='mb-1'>` = 4.
            const SizedBox(height: 4),
            Text(
              '단식',
              style: AppTypography.title2.copyWith(color: colors.gray400),
            ),
          ],
        ),
      ),
      DietTile.photo => ClipRRect(
        borderRadius: BorderRadius.circular(radius.m),
        child: SizedBox(
          height: _TodayDietCard.tileHeight,
          width: double.infinity,
          child: Image.network(
            meal.fileUrl!,
            // 웹 `.custom-image { width:100%; height:100%; object-fit:cover }`.
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: colors.gray100),
          ),
        ),
      ),
      // 웹 빈 칸은 **아무것도 없는 회색 상자**다(학생 홈과 다르다).
      DietTile.empty => Container(
        height: _TodayDietCard.tileHeight,
        decoration: BoxDecoration(
          color: colors.gray100,
          borderRadius: BorderRadius.circular(radius.m),
        ),
      ),
    };
  }
}

/// 웹 `AlertDialog` — `{name}님을 삭제하시겠습니까?`.
///
/// **`true`를 돌려주면 삭제를 진행한다.** 취소·바깥 탭·Escape는 null이다.
///
/// 회원 탈퇴 화면의 확인 다이얼로그와 **합치지 않았다.** 웹에서 아예 다른
/// 컴포넌트다 — 그쪽은 shadcn `Dialog`(폭 320, `p-7`, 제목+본문, 버튼 높이가
/// 내용으로 정해짐)이고 이쪽은 `AlertDialog`(폭 400, `px-7 py-11`, 제목만,
/// 버튼 `h-12` 고정)다. 공통 상수가 라운드(8)와 테두리색뿐이라 합치면
/// 옵션만 늘어난다.
class _DeleteAlert extends StatelessWidget {
  const _DeleteAlert({required this.name});

  static const Key cancelKey = ValueKey('TrainerManageMemberPage.deleteCancel');
  static const Key confirmKey = ValueKey(
    'TrainerManageMemberPage.deleteConfirm',
  );

  /// 웹 `w-[calc(100%-20px*2)] max-w-[calc(var(--max-width)-20px*2)]`
  /// → 440 − 40 = 400.
  static const double maxWidth = 400;

  /// 웹 `px-7 py-11` — 세로가 36이다(커스텀 스케일 11 = 36).
  static const double horizontalPadding = 20;
  static const double verticalPadding = 36;

  /// 제목 래퍼 `mb-8`(24) + 다이얼로그 `gap-4`(10) = **34**.
  /// 둘 중 하나만 옮기면 절반이 된다(회원 탈퇴 다이얼로그와 같은 함정).
  static const double titleToButtonsGap = 34;

  /// 버튼 `h-12`, 사이 `gap-3`.
  static const double buttonHeight = 48;
  static const double buttonGap = 8;

  /// 웹 `bg-black/80`.
  static const Color barrier = Color(0xCC000000);

  final String name;

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
                '$name님을 삭제하시겠습니까?',
                // 웹 `TITLE_1`(16/140/700) + `text-center`.
                textAlign: TextAlign.center,
                style: AppTypography.title1.copyWith(color: colors.gray800),
              ),
              const SizedBox(height: titleToButtonsGap),
              Row(
                children: [
                  Expanded(
                    child: _AlertButton(
                      key: cancelKey,
                      label: '아니요',
                      background: colors.gray100,
                      foreground: colors.gray600,
                      // 웹 `AlertDialogCancel`은 `buttonVariants({variant:
                      // 'outline'})`라 **테두리가 남는다**(실측 확인).
                      border: AppDropdownMenu.border,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: buttonGap),
                  Expanded(
                    child: _AlertButton(
                      key: confirmKey,
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
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = Theme.of(context).extension<AppRadius>()!;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _DeleteAlert.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          // 웹 `rounded-md`.
          borderRadius: BorderRadius.circular(radius.m),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(
          label,
          // 웹 `TITLE_1_SEMIBOLD`(16/140/600).
          style: AppTypography.title1SemiBold.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// 웹 `Sheet` — 환불 회원 삭제. **`true`를 돌려주면 삭제를 진행한다.**
///
/// 체크박스를 켜야 `회원 삭제`가 활성화된다. 웹 `disabled:bg-gray-300`은
/// **흐려지는 게 아니라 배경색만 회색**이 된다(실측 opacity 1).
class _RefundSheet extends StatefulWidget {
  const _RefundSheet();

  static const Key checkboxKey = ValueKey(
    'TrainerManageMemberPage.refundCheck',
  );
  static const Key cancelKey = ValueKey('TrainerManageMemberPage.refundCancel');
  static const Key confirmKey = ValueKey(
    'TrainerManageMemberPage.refundConfirm',
  );

  /// 웹 `max-w-[var(--max-width)]`.
  static const double maxWidth = 440;

  /// 웹 `rounded-t-lg`.
  static const double topRadius = 12;

  /// 웹 `p-7 pb-9` — 아래만 28이다.
  static const double horizontalPadding = 20;
  static const double topPadding = 20;
  static const double bottomPadding = 28;

  /// 제목 아래 `mb-7`.
  static const double titleGap = 20;

  /// 설명 아래 · 체크박스 아래 `mb-10`.
  ///
  /// **시트의 `gap-4`(10)는 더해지지 않는다**(실측 D19: 20 / 32 / 32가
  /// `mb-*` 값 그대로다). 같은 shadcn 껍데기인데도 알럿에서는 더해졌다 —
  /// 그쪽은 `grid`라 `gap`이 살아 있고 시트는 그렇지 않다.
  static const double blockGap = 32;

  /// 체크박스와 문구 사이 `ml-3`.
  static const double checkLabelGap = 8;

  /// 버튼 `h-12`, 사이 `gap-x-3`.
  static const double buttonHeight = 48;
  static const double buttonGap = 8;

  /// 시트 우상단 닫기 X(shadcn `SheetContent` 기본). 실측 14×14.
  static const double closeIconSize = 14;

  /// 웹 `bg-black/80`.
  static const Color barrier = Color(0xCC000000);

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _RefundSheet.horizontalPadding,
          _RefundSheet.topPadding,
          _RefundSheet.horizontalPadding,
          _RefundSheet.bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '환불 회원 삭제하기',
                    // 웹 `HEADING_4_BOLD`(18/130/700) + `text-black`.
                    style: AppTypography.heading4.copyWith(color: Colors.black),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(
                    'assets/images/close.svg',
                    width: _RefundSheet.closeIconSize,
                    height: _RefundSheet.closeIconSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _RefundSheet.titleGap),
            Text(
              '회원 삭제시 회원 정보, 운동 기록, 예약 내역, 수강권 등은 '
              '복구되지 않습니다.',
              // 웹 `BODY_1`(16/150/400) + `text-gray-600`.
              style: AppTypography.body1.copyWith(color: colors.gray600),
            ),
            const SizedBox(height: _RefundSheet.blockGap),
            GestureDetector(
              key: _RefundSheet.checkboxKey,
              onTap: () => setState(() => _checked = !_checked),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  AppCheckbox(checked: _checked),
                  const SizedBox(width: _RefundSheet.checkLabelGap),
                  Expanded(
                    child: Text(
                      '위 내용을 확인하였으며, 회원을 삭제합니다.',
                      // 웹 `BODY_2`(14/150/400) + `text-black`.
                      style: AppTypography.body2.copyWith(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _RefundSheet.blockGap),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    key: _RefundSheet.cancelKey,
                    label: '취소',
                    background: colors.gray100,
                    foreground: colors.gray600,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: _RefundSheet.buttonGap),
                Expanded(
                  child: _SheetButton(
                    key: _RefundSheet.confirmKey,
                    label: '회원 삭제',
                    // 웹 `checked ? 'bg-point' : 'bg-gray-300'`.
                    background: _checked ? colors.point : colors.gray300,
                    foreground: Colors.white,
                    // 웹 `disabled` + `disabled:pointer-events-none`.
                    onPressed: _checked
                        ? () => Navigator.of(context).pop(true)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = Theme.of(context).extension<AppRadius>()!;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _RefundSheet.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius.m),
        ),
        child: Text(
          label,
          // 웹 `TITLE_1_SEMIBOLD`(16/140/600).
          style: AppTypography.title1SemiBold.copyWith(color: foreground),
        ),
      ),
    );
  }
}
