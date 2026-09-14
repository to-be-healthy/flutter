import 'package:flutter/material.dart';

/// 웹 `src/app/_styles/global.css` :root 의 디자인 토큰.
///
/// 주의: 웹은 `tailwind.config.js`가 `var(--*)`를 참조만 하고
/// 실제 값은 global.css에 있다. 값의 출처는 항상 global.css다.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary50,
    required this.primary100,
    required this.primary200,
    required this.primary300,
    required this.primary400,
    required this.primary500,
    required this.primary600,
    required this.primary700,
    required this.primary800,
    required this.primary900,
    required this.gray100,
    required this.gray200,
    required this.gray300,
    required this.gray400,
    required this.gray500,
    required this.gray600,
    required this.gray700,
    required this.gray800,
    required this.point,
    required this.blue10,
    required this.blue50,
  });

  static const AppColors light = AppColors(
    primary50: Color(0xFFE2F1FF),
    primary100: Color(0xFFBADCFF),
    primary200: Color(0xFF8EC7FF),
    primary300: Color(0xFF5FB1FF),
    primary400: Color(0xFF3BA0FF),
    primary500: Color(0xFF1990FF),
    primary600: Color(0xFF1F82F0),
    primary700: Color(0xFF206FDC),
    primary800: Color(0xFF205ECA),
    primary900: Color(0xFF1F3EAA),
    gray100: Color(0xFFF2F3F5),
    gray200: Color(0xFFDEE1E6),
    gray300: Color(0xFFCBCFD3),
    gray400: Color(0xFFA7A9AE),
    gray500: Color(0xFF86888D),
    gray600: Color(0xFF5F6165),
    gray700: Color(0xFF4C4E52),
    gray800: Color(0xFF2E3134),
    point: Color(0xFFFF4668),
    blue10: Color(0xFFF4FAFF),
    blue50: Color(0xFFE2F1FF),
  );

  final Color primary50;
  final Color primary100;
  final Color primary200;
  final Color primary300;
  final Color primary400;
  final Color primary500;
  final Color primary600;
  final Color primary700;
  final Color primary800;
  final Color primary900;
  final Color gray100;
  final Color gray200;
  final Color gray300;
  final Color gray400;
  final Color gray500;
  final Color gray600;
  final Color gray700;
  final Color gray800;
  final Color point;
  final Color blue10;
  final Color blue50;

  @override
  AppColors copyWith({
    Color? primary50,
    Color? primary100,
    Color? primary200,
    Color? primary300,
    Color? primary400,
    Color? primary500,
    Color? primary600,
    Color? primary700,
    Color? primary800,
    Color? primary900,
    Color? gray100,
    Color? gray200,
    Color? gray300,
    Color? gray400,
    Color? gray500,
    Color? gray600,
    Color? gray700,
    Color? gray800,
    Color? point,
    Color? blue10,
    Color? blue50,
  }) {
    return AppColors(
      primary50: primary50 ?? this.primary50,
      primary100: primary100 ?? this.primary100,
      primary200: primary200 ?? this.primary200,
      primary300: primary300 ?? this.primary300,
      primary400: primary400 ?? this.primary400,
      primary500: primary500 ?? this.primary500,
      primary600: primary600 ?? this.primary600,
      primary700: primary700 ?? this.primary700,
      primary800: primary800 ?? this.primary800,
      primary900: primary900 ?? this.primary900,
      gray100: gray100 ?? this.gray100,
      gray200: gray200 ?? this.gray200,
      gray300: gray300 ?? this.gray300,
      gray400: gray400 ?? this.gray400,
      gray500: gray500 ?? this.gray500,
      gray600: gray600 ?? this.gray600,
      gray700: gray700 ?? this.gray700,
      gray800: gray800 ?? this.gray800,
      point: point ?? this.point,
      blue10: blue10 ?? this.blue10,
      blue50: blue50 ?? this.blue50,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      primary50: Color.lerp(primary50, other.primary50, t)!,
      primary100: Color.lerp(primary100, other.primary100, t)!,
      primary200: Color.lerp(primary200, other.primary200, t)!,
      primary300: Color.lerp(primary300, other.primary300, t)!,
      primary400: Color.lerp(primary400, other.primary400, t)!,
      primary500: Color.lerp(primary500, other.primary500, t)!,
      primary600: Color.lerp(primary600, other.primary600, t)!,
      primary700: Color.lerp(primary700, other.primary700, t)!,
      primary800: Color.lerp(primary800, other.primary800, t)!,
      primary900: Color.lerp(primary900, other.primary900, t)!,
      gray100: Color.lerp(gray100, other.gray100, t)!,
      gray200: Color.lerp(gray200, other.gray200, t)!,
      gray300: Color.lerp(gray300, other.gray300, t)!,
      gray400: Color.lerp(gray400, other.gray400, t)!,
      gray500: Color.lerp(gray500, other.gray500, t)!,
      gray600: Color.lerp(gray600, other.gray600, t)!,
      gray700: Color.lerp(gray700, other.gray700, t)!,
      gray800: Color.lerp(gray800, other.gray800, t)!,
      point: Color.lerp(point, other.point, t)!,
      blue10: Color.lerp(blue10, other.blue10, t)!,
      blue50: Color.lerp(blue50, other.blue50, t)!,
    );
  }
}
