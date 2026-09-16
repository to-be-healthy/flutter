import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// 웹 shadcn `DropdownMenu`(Radix) 대응.
///
/// ## 왜 이제 공용인가
///
/// `/trainer/manage`의 정렬 드롭다운이 첫 사용처였고, `/trainer/manage/
/// [memberId]`의 케밥 메뉴가 두 번째다. **두 화면의 실측값이 폭과 위치만
/// 빼고 전부 같았다** — 패널 패딩 4, 라운드 8, 테두리 `#E2E8F0` 1px,
/// 그림자 `0 4 12 rgba(0,0,0,0.16)`, 항목 높이 45, 항목 좌우 패딩 16,
/// 항목 글꼴 `TITLE_3`(14/21/600), **항목 사이 간격 0**.
/// shadcn 기본값을 공유하니 당연하지만, 그걸 실측으로 확인한 뒤 올렸다.
///
/// 서베이는 이 위젯을 화면보다 먼저 만들라고 권했다(Phase 0). 그때
/// 만들었다면 사용처가 하나뿐인 채로 모양을 짐작했을 것이다 — 두 번째
/// 사용처가 생긴 지금 **무엇이 같고 무엇이 다른지 실측으로 알고** 만든다.
///
/// ## 위치는 트리거의 **오른쪽 아래**를 기준으로 잡는다
///
/// 웹은 Radix popper가 계산한 자리를 화면별 `absolute -right-N top-N`이
/// 덮어쓴다. 그래서 왼쪽 기준 좌표는 패널 폭에 딸려 흔들리고, **오른쪽
/// 변끼리의 차이가 안정적인 값**이다(정렬 −9 / 케밥 0).
class AppDropdownMenu extends StatefulWidget {
  const AppDropdownMenu({
    required this.trigger,
    required this.items,
    required this.width,
    this.offset = Offset.zero,
    super.key,
  });

  /// shadcn `p-1`.
  static const double panelPadding = 4;

  /// 항목 높이(실측 45) — 좌우 패딩 `px-6`, 상하 `py-5`가 만든 값이다.
  static const double itemHeight = 45;

  /// 웹 항목의 `px-6`.
  static const double itemHorizontalPadding = 16;

  /// shadcn `border` 기본색(`--border`). 팔레트 토큰이 아니라 라이브러리
  /// 기본값이라 리터럴로 둔다.
  static const Color border = Color(0xFFE2E8F0);

  /// shadcn `shadow-md`의 유효 레이어. 앞 두 레이어는 완전 투명이다.
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x29000000),
    offset: Offset(0, 4),
    blurRadius: 12,
  );

  final Widget trigger;
  final List<AppDropdownMenuItem> items;

  /// 웹 `w-[96px]`·`w-[130px]` 같은 화면별 고정 폭.
  final double width;

  /// 트리거의 오른쪽 아래 → 패널의 오른쪽 위. `dx`는 오른쪽 변끼리의 차이,
  /// `dy`는 트리거 아래에서 내려오는 거리다.
  final Offset offset;

  @override
  State<AppDropdownMenu> createState() => AppDropdownMenuState();
}

class AppDropdownMenuState extends State<AppDropdownMenu> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _controller = OverlayPortalController();

  void open() => _controller.show();
  void close() => _controller.hide();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) => Stack(
          children: [
            // 바깥을 누르면 닫힌다. **막에 색이 없다** — 드롭다운은
            // 다이얼로그와 달리 뒤를 어둡게 하지 않는다(실측).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: close,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: widget.offset,
              child: _Panel(
                width: widget.width,
                items: widget.items,
                onSelected: close,
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: open,
          behavior: HitTestBehavior.opaque,
          child: widget.trigger,
        ),
      ),
    );
  }
}

/// 항목 하나. 색을 화면이 정한다 — 선택 상태(정렬)든 위험 표시(환불
/// 삭제의 `text-point`)든 웹이 항목마다 클래스로 직접 지정한다.
@immutable
class AppDropdownMenuItem {
  const AppDropdownMenuItem({
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;

  /// null이면 `gray800`.
  final Color? color;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.width,
    required this.items,
    required this.onSelected,
  });

  final double width;
  final List<AppDropdownMenuItem> items;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppDropdownMenu.panelPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          // shadcn `rounded-md`.
          borderRadius: BorderRadius.circular(radius.m),
          border: Border.all(color: AppDropdownMenu.border),
          boxShadow: const [AppDropdownMenu.shadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // 실측: 항목 사이 간격이 **0**이다. 구분선도 없다.
          children: [
            for (final item in items)
              _Item(
                item: item,
                colors: colors,
                radius: radius,
                onSelected: onSelected,
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.colors,
    required this.radius,
    required this.onSelected,
  });

  final AppDropdownMenuItem item;
  final AppColors colors;
  final AppRadius radius;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onSelected();
        item.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: AppDropdownMenu.itemHeight,
        width: double.infinity,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDropdownMenu.itemHorizontalPadding,
        ),
        decoration: BoxDecoration(
          // shadcn `rounded-sm`. 배경이 없어 보이지 않지만 값은 그대로 둔다.
          borderRadius: BorderRadius.circular(radius.s),
        ),
        child: Text(
          item.label,
          // 웹 `Typography.TITLE_3` — 두 화면 모두 같다(실측 14/21/600).
          style: AppTypography.title3.copyWith(
            color: item.color ?? colors.gray800,
          ),
        ),
      ),
    );
  }
}
