## Task 2: 디자인 토큰 — spacing + 색상

**웹 원본과의 대응이 이 태스크의 전부다.** 값 하나가 틀리면 이후 모든 화면이 어긋나므로, 구현보다 테스트를 먼저 확정한다.

**Files:**
- Create: `flutter/lib/core/theme/app_spacing.dart`
- Create: `flutter/lib/core/theme/app_colors.dart`
- Create: `flutter/lib/core/theme/app_radius.dart`
- Test: `flutter/test/core/theme/app_spacing_test.dart`, `flutter/test/core/theme/app_colors_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `AppSpacing extends ThemeExtension<AppSpacing>` — `double s1..s12` getter
  - `AppColors extends ThemeExtension<AppColors>` — `Color primary50..primary900, gray100..gray800, point, blue10, blue50`
  - `AppRadius extends ThemeExtension<AppRadius>` — `double s, m, l`
  - 접근: `Theme.of(context).extension<AppSpacing>()!.s7`

- [ ] **Step 1: 실패하는 spacing 테스트 작성**

웹 `tailwind.config.js`의 값을 그대로 못박는다. **이 숫자가 계획 전체의 안전장치다.**

`test/core/theme/app_spacing_test.dart`:

```dart
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
        s1: 8, s2: 12, s3: 16, s4: 20, s5: 24, s6: 32,
        s7: 40, s8: 48, s9: 56, s10: 64, s11: 72, s12: 96,
      );
      final mid = s.lerp(other, 0.5);
      expect(mid.s1, 6.0);
      expect(mid.s12, 72.0);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
flutter test test/core/theme/app_spacing_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:geonganghaejim/core/theme/app_spacing.dart'`

- [ ] **Step 3: AppSpacing 구현**

`lib/core/theme/app_spacing.dart`:

```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/core/theme/app_spacing_test.dart
```

Expected: PASS (3 tests)

- [ ] **Step 5: 색상 테스트 작성**

`test/core/theme/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';

void main() {
  group('AppColors — 웹 global.css :root 변수 고정', () {
    const c = AppColors.light;

    test('primary 팔레트 10단이 웹 값과 일치한다', () {
      expect(c.primary50, const Color(0xFFE2F1FF));
      expect(c.primary100, const Color(0xFFBADCFF));
      expect(c.primary200, const Color(0xFF8EC7FF));
      expect(c.primary300, const Color(0xFF5FB1FF));
      expect(c.primary400, const Color(0xFF3BA0FF));
      expect(c.primary500, const Color(0xFF1990FF));
      expect(c.primary600, const Color(0xFF1F82F0));
      expect(c.primary700, const Color(0xFF206FDC));
      expect(c.primary800, const Color(0xFF205ECA));
      expect(c.primary900, const Color(0xFF1F3EAA));
    });

    test('gray 팔레트는 100~800 8단이다 (900은 웹 global.css에 없음)', () {
      expect(c.gray100, const Color(0xFFF2F3F5));
      expect(c.gray200, const Color(0xFFDEE1E6));
      expect(c.gray300, const Color(0xFFCBCFD3));
      expect(c.gray400, const Color(0xFFA7A9AE));
      expect(c.gray500, const Color(0xFF86888D));
      expect(c.gray600, const Color(0xFF5F6165));
      expect(c.gray700, const Color(0xFF4C4E52));
      expect(c.gray800, const Color(0xFF2E3134));
    });

    test('포인트·blue 색상이 웹 값과 일치한다', () {
      expect(c.point, const Color(0xFFFF4668));
      expect(c.blue10, const Color(0xFFF4FAFF));
      expect(c.blue50, const Color(0xFFE2F1FF));
    });
  });
}
```

- [ ] **Step 6: 테스트 실패 확인 후 AppColors 구현**

```bash
flutter test test/core/theme/app_colors_test.dart
```
Expected: FAIL — URI 없음

`lib/core/theme/app_colors.dart`:

```dart
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
```

`lib/core/theme/app_radius.dart`:

```dart
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
```

- [ ] **Step 7: 전체 검증 후 커밋**

```bash
./tool/verify.sh
```
Expected: 모든 테스트 PASS

```bash
git add lib/core/theme test/core/theme
git commit -m "feat(theme): 웹 디자인 토큰(spacing·색상·radius)을 ThemeExtension으로 이식"
```

---
