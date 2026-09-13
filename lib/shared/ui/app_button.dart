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
///
/// 비활성 배경은 웹 `button.tsx`의 base 클래스(`disabled:bg-gray-300`)를
/// 그대로 따라 variant와 무관하게 `gray300`이다. 웹에 `disabled:text-*`는
/// 없으므로 전경색은 비활성 여부와 상관없이 variant 기본값을 유지한다.
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
  ///
  /// `label`로 구분한다 — 화면 하나에 `AppButton`이 둘 이상(확인/취소 등)
  /// 있어도 각 인스턴스를 유일하게 찾을 수 있어야 하기 때문이다.
  static Key backgroundKeyFor(String label) =>
      ValueKey('AppButton.background.$label');

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

    // 웹 button.tsx의 base가 `disabled:bg-gray-300` — variant 무관.
    final background = !isEnabled
        ? colors.gray300
        : switch (variant) {
            AppButtonVariant.primary => colors.primary500,
            AppButtonVariant.secondary => colors.blue50,
            AppButtonVariant.ghost => Colors.transparent,
          };

    // 웹은 비활성에서 전경색을 바꾸지 않는다(disabled:text-* 없음).
    final foreground = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => colors.primary500,
      AppButtonVariant.ghost => colors.gray600,
    };

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: backgroundKeyFor(label),
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
