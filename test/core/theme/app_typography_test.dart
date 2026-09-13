import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_radius.dart';
import 'package:geonganghaejim/core/theme/app_spacing.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';

void main() {
  group('AppTypography — 웹 typography.ts 상수 대응', () {
    test('HEADING 계열이 웹 값과 일치한다', () {
      expect(AppTypography.heading1.fontSize, 24.0);
      expect(AppTypography.heading1.height, 1.3);
      expect(AppTypography.heading1.fontWeight, FontWeight.w700);

      expect(AppTypography.heading2.fontSize, 22.0);
      expect(AppTypography.heading3.fontSize, 20.0);

      expect(AppTypography.heading4.fontSize, 18.0);
      expect(AppTypography.heading4.fontWeight, FontWeight.w700);
      expect(AppTypography.heading4SemiBold.fontSize, 18.0);
      expect(AppTypography.heading4SemiBold.fontWeight, FontWeight.w600);

      // HEADING_5만 13px/150%로 다른 계열과 규칙이 다르다 (웹 원본 그대로)
      expect(AppTypography.heading5.fontSize, 13.0);
      expect(AppTypography.heading5.height, 1.5);
      expect(AppTypography.heading5.fontWeight, FontWeight.w600);
    });

    test('TITLE 계열이 웹 값과 일치한다', () {
      expect(AppTypography.title1.fontSize, 16.0);
      expect(AppTypography.title1.height, 1.4);
      expect(AppTypography.title1.fontWeight, FontWeight.w700);

      expect(AppTypography.title1SemiBold.fontWeight, FontWeight.w600);

      expect(AppTypography.title2.fontSize, 15.0);
      expect(AppTypography.title2.height, 1.4);

      // TITLE_3만 150% (TITLE_1/2는 140%)
      expect(AppTypography.title3.fontSize, 14.0);
      expect(AppTypography.title3.height, 1.5);
    });

    test('BODY 계열이 웹 값과 일치한다', () {
      expect(AppTypography.body1.fontSize, 16.0);
      expect(AppTypography.body1.fontWeight, FontWeight.w400);
      expect(AppTypography.body2.fontSize, 14.0);
      expect(AppTypography.body3.fontSize, 13.0);
      expect(AppTypography.body4.fontSize, 12.0);
      expect(AppTypography.body4.fontWeight, FontWeight.w400);
      expect(AppTypography.body4Medium.fontWeight, FontWeight.w500);

      for (final style in [
        AppTypography.body1,
        AppTypography.body2,
        AppTypography.body3,
        AppTypography.body4,
      ]) {
        expect(style.height, 1.5, reason: 'BODY 계열은 전부 150%');
      }
    });

    test('NAV_TEXT는 10px medium이다', () {
      expect(AppTypography.navText.fontSize, 10.0);
      expect(AppTypography.navText.fontWeight, FontWeight.w500);
    });

    test('모든 스타일이 Pretendard를 쓴다', () {
      for (final style in AppTypography.all) {
        expect(style.fontFamily, 'Pretendard');
      }
    });
  });

  group('AppTheme', () {
    testWidgets('ThemeExtension 3종이 주입된다', (tester) async {
      late BuildContext captured;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final theme = Theme.of(captured);
      expect(theme.extension<AppSpacing>()!.s7, 20.0);
      expect(theme.extension<AppColors>()!.primary500, const Color(0xFF1990FF));
      expect(theme.extension<AppRadius>()!.m, 8.0);
    });
  });
}
