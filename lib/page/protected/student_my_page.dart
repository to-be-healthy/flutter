import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/date/korean_date_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/member_info.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_bottom_navigation.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/StudentMyPage.tsx` 대응.
///
/// ## 요청 2건과 그 순서
///
/// 골든 `mypage-student`는 **순서가 있는** 2건이다:
/// `members/trainer-mapping` → `members/me`.
///
/// 1번을 쏘는 것은 화면이 아니라 **하단 네비**다(`home-student`의 1번과 같은
/// 요청·같은 이유). 웹에서는 React의 effect가 자식부터 실행되어 그 순서가
/// 나오는데 Flutter의 `initState`는 부모가 먼저라, 그대로 두면 순서가
/// 뒤집혀 `expectParity`가 떨어진다. 그래서 학생 홈과 똑같이 **자기 요청을
/// 첫 프레임 뒤로 미룬다.**
///
/// **`notification/red-dot`은 없다.** 이 화면 헤더에는 알림 종이 없다 —
/// 홈 두 화면과 다른 점이고, 홈 골든을 복사하면 여기서 틀린다.
///
/// ## 로딩·에러 분기가 없다
///
/// 웹은 `const { data } = useMyInfoQuery();`만 쓰고 `isPending`·`isError`를
/// 보지 않는다. 프로필 카드만 `{data && ...}`로 가려지고 나머지 섹션은
/// 처음부터 그려진다. 스켈레톤도 스피너도 없다 — 발명하면 웹에 없는 화면이
/// 된다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPage extends StatefulWidget {
  const StudentMyPage({
    required this.memberApi,
    required this.onNavigate,
    super.key,
  });

  /// 웹 `<IconAvatar width={80} height={80} />`와 `h-[80px] w-[80px]`.
  static const double avatarSize = 80;

  /// 웹 `IconArrowRightSmall`(`arrow_right_small.svg`)의 고유 크기.
  static const double arrowWidth = 7;
  static const double arrowHeight = 10;

  /// 웹 `w-[320px]`. 바로가기 카드의 고정 폭이다.
  static const double shortcutCardWidth = 320;

  /// 웹 `h-11`(커스텀 스케일 36) — 바로가기 구분선 높이.
  static const double shortcutDividerHeight = 36;

  /// 바로가기 구분선의 **렌더 폭**.
  ///
  /// 웹 클래스는 `w-[1px] border border-gray-200`인데, Tailwind preflight의
  /// `box-sizing: border-box` 안에서 좌우 1px 보더가 1px 폭에 들어가려다
  /// 충돌한다. **실측 결과 2px로 렌더된다**(서베이 BUG-22).
  /// 1px로 옮기면 카드 안 세 칸의 위치가 웹과 어긋난다.
  static const double shortcutDividerWidth = 2;

  /// 웹 `py-[15px]` — 메뉴 행과 앱 버전 행의 상하 패딩.
  ///
  /// 커스텀 스케일에 15가 없어 웹도 임의값을 썼다(규율 #4의 예외).
  /// `BODY_1`의 줄 높이 24와 합쳐 **행 높이 54**가 된다(실측).
  static const double menuRowVerticalPadding = 15;

  final MemberApi memberApi;

  /// 라우터를 화면에 끼우지 않기 위한 이동 콜백(규율 #3).
  final ValueChanged<String> onNavigate;

  @override
  State<StudentMyPage> createState() => _StudentMyPageState();
}

class _StudentMyPageState extends State<StudentMyPage> {
  MemberInfo? _me;

  @override
  void initState() {
    super.initState();
    // **첫 프레임 뒤로 미룬다.** 여기서 바로 부르면 네비보다 먼저 나가
    // 골든 순서(`trainer-mapping` → `me`)가 깨진다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMe());
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.memberApi.me();
      if (mounted) {
        setState(() => _me = me);
      }
    } catch (_) {
      // 웹 `useMyInfoQuery`에 `isError` 분기가 없다. 실패하면 프로필 카드가
      // 안 그려질 뿐, 나머지 섹션은 그대로 보인다.
    }
  }

  @override
  Widget build(BuildContext context) {
    // 웹 `dayjs(new Date()).format('YYYY-MM')` — 식단·지난 예약 링크의
    // 쿼리스트링이다. **빌드마다 다시 계산한다**(웹도 렌더마다 계산한다).
    final month = KoreanDateFormat.month(DateTime.now());

    return AppLayout(
      // 웹 `<Layout.Header className='bg-white' />` — 자식이 없는 빈 흰 바다.
      // 루트는 gray-100이므로 `AppLayout.backgroundColor`로는 안 된다.
      header: const AppLayoutHeader(backgroundColor: Colors.white),
      bottomNavigation: AppBottomNavigation(
        currentLocation: '/student/mypage',
        // 이 호출이 골든의 **첫 번째** 요청이다(네비 `initState`).
        loadTrainerMapping: widget.memberApi.trainerMapping,
        onSelect: widget.onNavigate,
        onScheduleBlocked: () => AppToastScope.read(
          context,
        ).showError(AppBottomNavigation.scheduleBlockedMessage),
      ),
      contents: Column(
        // 흰 섹션들이 화면 폭을 꽉 채워야 한다. 세로가 아니라 **가로**로
        // 늘이는 것이라 규율 #12(무한 높이)와 무관하다.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 웹 `{data && (...)}` — 데이터가 오기 전에는 카드 자체가 없다.
          if (_me != null)
            _ProfileCard(
              me: _me!,
              onTap: () => widget.onNavigate('/student/mypage/info'),
            ),
          _Shortcuts(month: month, onNavigate: widget.onNavigate),
          _MenuList(month: month, onNavigate: widget.onNavigate),
          const _AppVersionRow(),
          const _Footer(),
          // **여기에 `Expanded`를 두면 안 된다**(규율 #12). `AppLayout`의
          // 본문은 `SingleChildScrollView` 안이라 높이 상한이 없고, flex
          // 자식은 그 자리에서 터진다. 필요도 없다 — 남는 자리는 Column이
          // 칠하지 않으므로 Scaffold 배경(gray-100)이 그대로 드러나고,
          // 그것이 웹에서 `Layout.Contents`에 배경이 없어 루트의
          // `bg-gray-100`이 비치는 것과 같은 결과다.
        ],
      ),
    );
  }
}

/// 웹 `StudentMyPage.tsx:29~56`. 카드 전체가 `/student/mypage/info` 링크다.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me, required this.onTap});

  final MemberInfo me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        // 웹 `px-7 pb-7 pt-6` = 좌우 20, 위 16, 아래 20.
        // 아바타 80과 합쳐 **행 높이 116**이 된다(실측).
        padding: EdgeInsets.fromLTRB(
          spacing.s7,
          spacing.s6,
          spacing.s7,
          spacing.s7,
        ),
        child: Row(
          children: [
            _Avatar(fileUrl: me.profileFileUrl),
            // 웹 `ml-5` = 12.
            SizedBox(width: spacing.s5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    me.name,
                    style: AppTypography.heading3,
                    // 웹은 flex 자식이라 저절로 줄지만 Flutter는 넘친다.
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    // 일반 계정은 아이디, 소셜 계정은 이메일이다.
                    me.accountLabel,
                    style: AppTypography.body3.copyWith(color: colors.gray500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const _RightArrow(),
          ],
        ),
      ),
    );
  }
}

/// 웹 `data?.profile ? <Image .../> : <IconAvatar />` (`:32~45`).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.fileUrl});

  final String? fileUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (fileUrl == null) {
      return SvgPicture.asset(
        'assets/images/avatar.svg',
        width: StudentMyPage.avatarSize,
        height: StudentMyPage.avatarSize,
      );
    }

    return ClipOval(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 웹 `border border-gray-300`.
          border: Border.all(color: colors.gray300),
        ),
        child: Image.network(
          // 웹 `?w=300&h=300&q=90` — 표시 크기의 3배를 받아 고해상도 화면에
          // 대비한다. **허브는 정상이고 내 정보 화면만 `&=q=90` 오타다**
          // (서베이 BUG-4).
          '$fileUrl?w=300&h=300&q=90',
          width: StudentMyPage.avatarSize,
          height: StudentMyPage.avatarSize,
          fit: BoxFit.cover,
          // 위젯 테스트에서는 네트워크가 막혀 항상 이 가지로 떨어진다
          // (`deferred-minors.md`에 기록된 한계).
          errorBuilder: (context, error, stackTrace) => SvgPicture.asset(
            'assets/images/avatar.svg',
            width: StudentMyPage.avatarSize,
            height: StudentMyPage.avatarSize,
          ),
        ),
      ),
    );
  }
}

/// 웹 `<IconArrowRightSmall stroke={'var(--gray-400)'} />`.
///
/// 자산이 이미 `stroke="#A7A9AE"`(= `--gray-400`)로 고정돼 있어 색을 덮지
/// 않는다 — 웹이 넘기는 prop 값과 같다.
class _RightArrow extends StatelessWidget {
  const _RightArrow();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/arrow_right_small.svg',
      width: StudentMyPage.arrowWidth,
      height: StudentMyPage.arrowHeight,
    );
  }
}

/// 웹 `StudentMyPage.tsx:59~82`. 흰 래퍼 안에 320px 카드가 가운데 놓인다.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.month, required this.onNavigate});

  /// 웹 `mypage-box-shadow` = `0px 4px 12px 0px rgba(0,0,0,0.06)`.
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  final String month;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      color: Colors.white,
      // 웹 `py-6 pb-9` — `pb-9`(28)가 `py-6`의 아래쪽을 덮는다.
      padding: EdgeInsets.only(top: spacing.s6, bottom: spacing.s9),
      child: Center(
        child: Container(
          width: StudentMyPage.shortcutCardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius.l),
            boxShadow: cardShadow,
          ),
          // 세 칸의 **자연 폭 합이 318.28로 320 안에 들어간다**(실측:
          // 107.31 + 2 + 99.66 + 2 + 107.31). 좌우 패딩이 칸마다 다른 것은
          // 웹 그대로다 — 가운데 칸만 대칭(`px-11`)이고 양옆은 바깥쪽이 좁다.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            // 아이콘 높이가 11·15·16으로 달라 칸 높이도 71·75·76으로
            // 다르다. 웹 `items-center`가 그것을 가운데로 맞춘다
            // (카드 높이는 가장 큰 76).
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ShortcutTile(
                icon: 'class_log',
                iconWidth: 20,
                iconHeight: 11,
                label: '수업일지',
                // 웹 `py-5 pl-8 pr-9` = 상하 12, 좌 24, 우 28.
                padding: EdgeInsets.fromLTRB(
                  spacing.s8,
                  spacing.s5,
                  spacing.s9,
                  spacing.s5,
                ),
                onTap: () => onNavigate('/student/log'),
              ),
              const _ShortcutDivider(),
              _ShortcutTile(
                icon: 'diet',
                iconWidth: 19,
                iconHeight: 15,
                label: '식단',
                // 웹 `px-11 py-5` = 좌우 36, 상하 12.
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.s11,
                  vertical: spacing.s5,
                ),
                onTap: () => onNavigate('/student/diet?month=$month'),
              ),
              const _ShortcutDivider(),
              _ShortcutTile(
                icon: 'exercise_log',
                iconWidth: 18,
                iconHeight: 16,
                label: '운동기록',
                // 웹 `py-5 pl-9 pr-8` = 상하 12, 좌 28, 우 24.
                padding: EdgeInsets.fromLTRB(
                  spacing.s9,
                  spacing.s5,
                  spacing.s8,
                  spacing.s5,
                ),
                onTap: () => onNavigate('/student/workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.iconWidth,
    required this.iconHeight,
    required this.label,
    required this.padding,
    required this.onTap,
  });

  final String icon;
  final double iconWidth;
  final double iconHeight;
  final String label;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/$icon.svg',
              width: iconWidth,
              height: iconHeight,
            ),
            // 웹 `gap-y-5` = 12.
            SizedBox(height: spacing.s5),
            Text(
              label,
              // **웹은 이 라벨에 Typography 클래스를 주지 않는다.** 브라우저
              // 기본값이 그대로 적용되어 실측 16px / 줄 높이 24px / 400이
              // 나오는데, 그것이 곧 `BODY_1`이다. "클래스가 없다"와 "스타일이
              // 없다"는 다르다.
              style: AppTypography.body1,
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `<span className='h-11 w-[1px] border border-gray-200' />`.
class _ShortcutDivider extends StatelessWidget {
  const _ShortcutDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      width: StudentMyPage.shortcutDividerWidth,
      height: StudentMyPage.shortcutDividerHeight,
      color: colors.gray200,
    );
  }
}

/// 웹 `<ul>` 5행 (`StudentMyPage.tsx:84~125`).
class _MenuList extends StatelessWidget {
  const _MenuList({required this.month, required this.onNavigate});

  final String month;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuRow(
          label: '지난 예약',
          onTap: () =>
              onNavigate('/student/mypage/last-reservation?month=$month'),
        ),
        _MenuRow(
          label: '트레이너 정보',
          onTap: () => onNavigate('/student/mypage/trainer-info'),
        ),
        _MenuRow(
          label: '알림 설정',
          onTap: () => onNavigate('/student/mypage/alarm'),
        ),
        // 아래 둘은 마이페이지 밑이 아니라 **공개 라우트**다.
        _MenuRow(label: '약관 및 정책', onTap: () => onNavigate('/policy')),
        _MenuRow(label: '고객센터', onTap: () => onNavigate('/cs')),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        // 웹 `px-7 py-[15px]`. **행 사이에 구분선이 없다** — 흰 행들이 틈
        // 없이 붙어 하나의 흰 블록이 된다(실측).
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s7,
          vertical: StudentMyPage.menuRowVerticalPadding,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.body1)),
            const _RightArrow(),
          ],
        ),
      ),
    );
  }
}

/// 웹 `StudentMyPage.tsx:127~130`.
///
/// **링크가 아니다** — 메뉴 행들과 생김새가 같지만 `<div>`이고 화살표도 없다.
/// 좌우 값 둘 다 하드코딩이라 API에서 오지 않는다(서베이 BUG-11).
class _AppVersionRow extends StatelessWidget {
  const _AppVersionRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s7,
        vertical: StudentMyPage.menuRowVerticalPadding,
      ),
      child: Row(
        // 웹은 이 행에만 `items-center`가 빠져 있다(서베이 BUG-23).
        // 두 값의 글꼴 크기가 같아 눈에 띄지는 않는다.
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('앱 버전', style: AppTypography.body1),
          Text(
            '최신 버전',
            style: AppTypography.body1.copyWith(color: colors.gray500),
          ),
        ],
      ),
    );
  }
}

/// 웹 `<footer>` (`StudentMyPage.tsx:132~139`).
///
/// 배경이 `bg-transparent`라 셸의 gray-100이 그대로 비친다.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      // 웹 `p-7` = 사방 20.
      padding: EdgeInsets.all(spacing.s7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '앱 버전 0.0',
            style: AppTypography.body2.copyWith(color: colors.gray500),
          ),
          // 웹 `gap-4` = 10.
          SizedBox(height: spacing.s4),
          Container(
            decoration: BoxDecoration(
              // 웹 `border-b border-gray-300`.
              border: Border(bottom: BorderSide(color: colors.gray300)),
            ),
            child: Text(
              '오픈 소스 라이선스 보기',
              style: AppTypography.body2.copyWith(color: colors.gray500),
            ),
          ),
        ],
      ),
    );
  }
}
