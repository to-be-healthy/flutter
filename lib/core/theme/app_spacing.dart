import 'package:flutter/material.dart';

/// 웹 `tailwind.config.js`의 spacing 스케일.
///
/// 주의: Tailwind 기본 스케일이 아니다. 웹이 비선형으로 재정의했다.
/// `p-7` = 20px, `gap-6` = 16px. 기본값(4 = 16px)을 가정하면 전부 어긋난다.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.s1,
    required this.s2,
    required this.s3,
    required this.s4,
    required this.s5,
    required this.s6,
    required this.s7,
    required this.s8,
    required this.s9,
    required this.s10,
    required this.s11,
    required this.s12,
  });

  /// 웹 원본과 1:1 대응하는 표준 스케일.
  static const AppSpacing standard = AppSpacing(
    s1: 4,
    s2: 6,
    s3: 8,
    s4: 10,
    s5: 12,
    s6: 16,
    s7: 20,
    s8: 24,
    s9: 28,
    s10: 32,
    s11: 36,
    s12: 48,
  );

  final double s1;
  final double s2;
  final double s3;
  final double s4;
  final double s5;
  final double s6;
  final double s7;
  final double s8;
  final double s9;
  final double s10;
  final double s11;
  final double s12;

  @override
  AppSpacing copyWith({
    double? s1,
    double? s2,
    double? s3,
    double? s4,
    double? s5,
    double? s6,
    double? s7,
    double? s8,
    double? s9,
    double? s10,
    double? s11,
    double? s12,
  }) {
    return AppSpacing(
      s1: s1 ?? this.s1,
      s2: s2 ?? this.s2,
      s3: s3 ?? this.s3,
      s4: s4 ?? this.s4,
      s5: s5 ?? this.s5,
      s6: s6 ?? this.s6,
      s7: s7 ?? this.s7,
      s8: s8 ?? this.s8,
      s9: s9 ?? this.s9,
      s10: s10 ?? this.s10,
      s11: s11 ?? this.s11,
      s12: s12 ?? this.s12,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) {
      return this;
    }
    return AppSpacing(
      s1: lerpDouble(s1, other.s1, t),
      s2: lerpDouble(s2, other.s2, t),
      s3: lerpDouble(s3, other.s3, t),
      s4: lerpDouble(s4, other.s4, t),
      s5: lerpDouble(s5, other.s5, t),
      s6: lerpDouble(s6, other.s6, t),
      s7: lerpDouble(s7, other.s7, t),
      s8: lerpDouble(s8, other.s8, t),
      s9: lerpDouble(s9, other.s9, t),
      s10: lerpDouble(s10, other.s10, t),
      s11: lerpDouble(s11, other.s11, t),
      s12: lerpDouble(s12, other.s12, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
