import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 웹 `src/shared/ui/card.tsx` 대응.
///
/// 웹 루트는 `h-35 relative flex w-40 flex-col gap-y-2 rounded-lg bg-white p-6`
/// 인데, `h-35`·`w-40`은 **실질적으로 죽은 값이다** — `h-35`는 Tailwind 기본
/// 스케일에도 이 프로젝트의 커스텀 스케일(1~12)에도 없어 클래스가 생성되지
/// 않고, `w-40`은 쓰는 쪽이 전부 `w-full`로 덮는다. 그래서 크기를 강제하지
/// 않고 부모가 정하게 둔다.
///
/// 남는 기본값은 넷이다: `bg-white` · `rounded-lg`(12) · `p-6`(16) ·
/// `gap-y-2`(6). 홈의 카드들은 이 중 패딩만 화면마다 덮는다
/// (`px-6 py-7`, `p-0`, `gap-y-8` 등).
class AppCard extends StatelessWidget {
  const AppCard({
    required this.children,
    this.padding,
    this.gap,
    this.backgroundColor,
    super.key,
  });

  final List<Widget> children;

  /// 웹 `p-6`(사방 16px)이 기본. 화면이 `px-6 py-7`처럼 덮는다.
  final EdgeInsetsGeometry? padding;

  /// 웹 `gap-y-2`(6px)가 기본. 홈의 카드들은 대부분 `gap-y-8`(24)로 덮는다.
  final double? gap;

  /// 웹 `bg-white`가 기본. 수강권 카드가 `bg-primary-500`/`bg-gray-500`으로 덮는다.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(radius.l),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(spacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: gap ?? spacing.s2,
          children: children,
        ),
      ),
    );
  }

  /// 색을 참조만 하는 곳(수강권 카드의 만료 분기 등)을 위해 노출한다.
  static Color defaultBackground(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!.gray100;
}

/// 웹 `CardHeader` — 자식에 `Typography.TITLE_1_BOLD`를 씌우는 것이 전부다.
class AppCardHeader extends StatelessWidget {
  const AppCardHeader({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(style: AppTypography.title1, child: child);
  }
}

/// 웹 `CardContent` — `Typography.BODY_4_REGULAR` + `text-gray-500` +
/// `whitespace-pre-wrap`.
///
/// `whitespace-pre-wrap`(개행 보존 + 줄바꿈)은 Flutter `Text`의 기본 동작이라
/// 따로 옮길 것이 없다.
class AppCardContent extends StatelessWidget {
  const AppCardContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return DefaultTextStyle.merge(
      style: AppTypography.body4.copyWith(color: colors.gray500),
      child: child,
    );
  }
}
