import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const colors = AppColors.light;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary500,
        primary: colors.primary500,
        error: colors.point,
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTypography.heading1,
        headlineMedium: AppTypography.heading2,
        headlineSmall: AppTypography.heading3,
        titleLarge: AppTypography.title1,
        titleMedium: AppTypography.title2,
        titleSmall: AppTypography.title3,
        bodyLarge: AppTypography.body1,
        bodyMedium: AppTypography.body2,
        bodySmall: AppTypography.body3,
        labelSmall: AppTypography.navText,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppSpacing.standard,
        AppColors.light,
        AppRadius.standard,
      ],
    );
  }
}
