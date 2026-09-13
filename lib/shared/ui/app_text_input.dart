import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 웹 `src/shared/ui/input` 대응.
///
/// `AppButton`과 동일한 테마 경유 규율을 따른다: 색·간격·라운드는
/// `Theme.of(context).extension<...>()`를 거치고, 타이포는
/// `AppTypography` 정적 상수(=`AppTheme.light()`가 쓰는 값 그 자체)를 쓴다.
/// `BorderSide.none`은 대응 토큰이 없는 프레임워크 상수라 리터럴로 남긴다.
class AppTextInput extends StatelessWidget {
  const AppTextInput({
    required this.label,
    this.errorText,
    this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.title3.copyWith(color: colors.gray700),
        ),
        SizedBox(height: spacing.s3),
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTypography.body1.copyWith(color: colors.gray800),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: spacing.s6,
              vertical: spacing.s6,
            ),
            filled: true,
            fillColor: colors.gray100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.m),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.m),
              borderSide: BorderSide(color: colors.primary500),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.m),
              borderSide: BorderSide(color: colors.point),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: spacing.s2),
          Text(
            errorText!,
            style: AppTypography.body4.copyWith(color: colors.point),
          ),
        ],
      ],
    );
  }
}
