import 'package:flutter/material.dart';

/// 웹 global.css 의 --radius-s/m/l.
@immutable
class AppRadius extends ThemeExtension<AppRadius> {
  const AppRadius({required this.s, required this.m, required this.l});

  static const AppRadius standard = AppRadius(s: 4, m: 8, l: 12);

  final double s;
  final double m;
  final double l;

  @override
  AppRadius copyWith({double? s, double? m, double? l}) {
    return AppRadius(s: s ?? this.s, m: m ?? this.m, l: l ?? this.l);
  }

  @override
  AppRadius lerp(ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) {
      return this;
    }
    return AppRadius(
      s: s + (other.s - s) * t,
      m: m + (other.m - m) * t,
      l: l + (other.l - l) * t,
    );
  }
}
