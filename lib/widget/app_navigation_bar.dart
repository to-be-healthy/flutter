import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 웹 `src/widget/navigation.tsx`의 **표현 부분**.
///
/// 웹은 `StudentNavigation`(L106-204)과 `TrainerNavigation`(L22-104)이
/// 별개 컴포넌트인데 껍데기 마크업이 **문자열까지 동일**하다
/// (`rounded-tl-md rounded-tr-md bg-white shadow-nav` +
/// `<ul className='flex items-center justify-between px-11 py-[18px]'>`).
/// 여기서는 그 공통부만 빼서 둘이 공유한다 — 다른 것은 탭 목록과 동작이다.
///
/// **이 위젯은 요청을 쏘지 않는다.** 학생 네비는 마운트 시
/// `members/trainer-mapping`을 쏘고 트레이너 네비는 아무것도 쏘지 않는데,
/// 그 차이가 두 홈 골든의 모양을 가른다 — 그 책임은 각 네비 위젯이 진다.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({required this.items, super.key});

  /// 웹 `px-11 py-[18px]`. 세로 18은 스케일(4/6/8/10/12/16/20/…)에 없는
  /// 임의값이라 상수로 옮긴다(규율 #4).
  static const double verticalPadding = 18;

  final List<AppNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        // 웹 `rounded-tl-md rounded-tr-md`.
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.m)),
        boxShadow: const <BoxShadow>[
          // 웹 `.shadow-nav` = `0px -2px 8px 0px rgba(0,0,0,0.06)`
          // (`global.css:219`).
          //
          // `tailwind.config.js:149`의 `nav: 'shadow-nav'`는 **무효 CSS 값**을
          // 만든다(`box-shadow: shadow-nav`). 무효 선언은 파서가 버리므로
          // 순서와 무관하게 global.css의 값이 적용된다.
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s11,
          vertical: verticalPadding,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final item in items)
              _NavigationItemView(
                item: item,
                activeColor: Colors.black,
                inactiveColor: colors.gray700,
                gap: spacing.s2,
              ),
          ],
        ),
      ),
    );
  }
}

/// 탭 하나의 정의. 아이콘은 `<icon>_filled.svg` / `<icon>_outlined.svg` 쌍이다.
@immutable
class AppNavigationTab {
  const AppNavigationTab({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final String icon;

  String get filledAsset => 'assets/images/${icon}_filled.svg';
  String get outlinedAsset => 'assets/images/${icon}_outlined.svg';
}

/// 탭 하나 + 그 탭의 현재 상태·동작.
///
/// 아이콘과 라벨의 활성 여부를 **따로** 받는다. 웹 `TrainerNavigation`의
/// 홈 탭이 아이콘은 `/trainer || /trainer/manage`, 라벨은 `/trainer`만
/// 보기 때문이다(L33 vs L41) — `/trainer/manage`에서 아이콘은 켜지고 라벨은
/// 꺼진다. 실측이고 그대로 옮긴다.
@immutable
class AppNavigationItem {
  const AppNavigationItem({
    required this.tab,
    required this.isIconActive,
    required this.isLabelActive,
    required this.onTap,
  });

  /// 아이콘·라벨 활성 조건이 같은 흔한 경우.
  factory AppNavigationItem.uniform({
    required AppNavigationTab tab,
    required bool isActive,
    required VoidCallback onTap,
  }) => AppNavigationItem(
    tab: tab,
    isIconActive: isActive,
    isLabelActive: isActive,
    onTap: onTap,
  );

  final AppNavigationTab tab;
  final bool isIconActive;
  final bool isLabelActive;
  final VoidCallback onTap;
}

class _NavigationItemView extends StatelessWidget {
  const _NavigationItemView({
    required this.item,
    required this.activeColor,
    required this.inactiveColor,
    required this.gap,
  });

  /// 웹 자산의 고유 크기. `community_*`만 22×21이고 나머지는 24×24다.
  /// 웹은 크기를 넘기지 않아 자산 고유 크기로 렌더된다.
  static const double iconSize = 24;
  static const double communityIconWidth = 22;
  static const double communityIconHeight = 21;

  final AppNavigationItem item;
  final Color activeColor;
  final Color inactiveColor;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tab = item.tab;
    final isCommunity = tab.icon == 'community';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: gap,
        children: [
          SvgPicture.asset(
            // 아이콘에는 색을 주입하지 않는다 — 자산 자체가 활성/비활성
            // 색을 품고 있고(filled는 검정, outlined는 검정 또는 gray700),
            // 웹도 `fill` prop 없이 둘을 갈아끼우기만 한다.
            item.isIconActive ? tab.filledAsset : tab.outlinedAsset,
            width: isCommunity ? communityIconWidth : iconSize,
            height: isCommunity ? communityIconHeight : iconSize,
          ),
          Text(
            tab.label,
            // 웹 `NAV_TEXT`(10px medium) + 활성 `text-black` / 비활성
            // `text-gray-700`. NAV_TEXT 자체가 gray-700을 품고 있어 비활성이
            // 기본값이다.
            style: AppTypography.navText.copyWith(
              color: item.isLabelActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
