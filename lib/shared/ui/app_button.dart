import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// 웹 `src/shared/ui/button` 대응.
///
/// 색·간격·라운드는 전부 ThemeExtension을 경유한다.
/// 화면 코드에서 리터럴 값을 쓰지 않기 위한 기준 구현이다.
///
/// 예외(토큰화하지 않는 리터럴): `Colors.white`·`Colors.transparent`는
/// `AppColors`에 대응 토큰이 없는 프레임워크 상수이고, 로딩 인디케이터의
/// `strokeWidth: 2`는 디자인 토큰이 아니라 Material 위젯 자체의 기본 굵기다.
/// `AppTypography`는 `ThemeExtension`이 아니라 정적 상수 모음이라 —
/// `AppTheme.light()`가 동일 상수로 `TextTheme`을 구성한다 — 여기서
/// `Theme.of(context).extension<...>()` 경유 대상이 아니다.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    super.key,
  });

  /// 배경을 그리는 [Container]에 붙는 키. 위젯 트리 모양이 아니라
  /// "배경이 어떤 색을 쓰는가"만 테스트가 검증할 수 있게 한다.
  static const Key backgroundKey = Key('app_button_background');

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    final isEnabled = onPressed != null && !isLoading;

    final background = switch (variant) {
      AppButtonVariant.primary =>
        isEnabled ? colors.primary500 : colors.gray200,
      AppButtonVariant.secondary => colors.blue50,
      AppButtonVariant.ghost => Colors.transparent,
    };

    final foreground = switch (variant) {
      AppButtonVariant.primary => isEnabled ? Colors.white : colors.gray400,
      AppButtonVariant.secondary => colors.primary500,
      AppButtonVariant.ghost => colors.gray600,
    };

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: backgroundKey,
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: spacing.s6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius.m),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: spacing.s7,
                height: spacing.s7,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              )
            : Text(
                label,
                style: AppTypography.title1.copyWith(color: foreground),
              ),
      ),
    );
  }
}
