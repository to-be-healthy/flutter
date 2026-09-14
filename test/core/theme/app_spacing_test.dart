import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_spacing.dart';

void main() {
  group('AppSpacing — 웹 tailwind.config.js 비선형 스케일 고정', () {
    const s = AppSpacing.standard;

    test('Tailwind 기본값이 아닌 웹 정의값과 일치한다', () {
      expect(s.s1, 4.0);
      expect(s.s2, 6.0);
      expect(s.s3, 8.0);
      expect(s.s4, 10.0);
      expect(s.s5, 12.0);
      expect(s.s6, 16.0);
      expect(s.s7, 20.0);
      expect(s.s8, 24.0);
      expect(s.s9, 28.0);
      expect(s.s10, 32.0);
      expect(s.s11, 36.0);
      expect(s.s12, 48.0);
    });

    test('Tailwind 기본 스케일과 다르다 (회귀 방지)', () {
      // Tailwind 기본은 4 = 1rem = 16px. 웹은 10px.
      expect(s.s4, isNot(16.0));
      // Tailwind 기본은 6 = 1.5rem = 24px. 웹은 16px.
      expect(s.s6, isNot(24.0));
    });

    test('lerp는 두 스케일 사이를 보간한다', () {
      const other = AppSpacing(
        s1: 8,
        s2: 12,
        s3: 16,
        s4: 20,
        s5: 24,
        s6: 32,
        s7: 40,
        s8: 48,
        s9: 56,
        s10: 64,
        s11: 72,
        s12: 96,
      );
      final mid = s.lerp(other, 0.5);
      expect(mid.s1, 6.0);
      expect(mid.s12, 72.0);
    });
  });
}
