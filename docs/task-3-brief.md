## Task 3: 타이포그래피 + Pretendard 폰트

웹 `src/shared/mixin/typography.ts`의 19개 상수는 중복을 제거하면 **16종**이다. Tailwind의 `text-[24px]/[130%]` 표기에서 `130%`는 line-height 비율이며, Flutter `TextStyle.height`는 배수(`1.3`)로 대응한다.

**Files:**
- Create: `flutter/lib/core/theme/app_typography.dart`
- Create: `flutter/lib/core/theme/app_theme.dart`
- Create: `flutter/assets/fonts/` (Pretendard 9웨이트)
- Modify: `flutter/pubspec.yaml` (폰트 선언)
- Test: `flutter/test/core/theme/app_typography_test.dart`

**Interfaces:**
- Consumes: `AppSpacing.standard`, `AppColors.light`, `AppRadius.standard` (Task 2)
- Produces:
  - `AppTypography` — `static const TextStyle heading1..heading5, title1..title3, body1..body4, navText`
  - `AppTheme.light()` → `ThemeData` — 위 extension 3종 + `fontFamily: 'Pretendard'` 주입. 이후 모든 태스크가 `MaterialApp(theme: AppTheme.light())`로 사용

- [ ] **Step 1: Pretendard 폰트 자산 준비**

웹은 `public/fonts/Pretendard-*.subset.woff`(9웨이트)를 쓰지만 **Flutter는 woff를 지원하지 않는다.** otf/ttf를 받아야 한다.

```bash
cd /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
mkdir -p assets/fonts
curl -L -o /tmp/pretendard.zip \
  https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip
unzip -j /tmp/pretendard.zip 'public/static/*.otf' -d assets/fonts/
ls assets/fonts/
```

Expected: `Pretendard-Thin.otf` ~ `Pretendard-Black.otf` 9개 파일.

받아지지 않으면 중단하고 보고한다 — 폰트가 없으면 이후 골든 테스트가 전부 무의미해진다.

- [ ] **Step 2: pubspec.yaml에 폰트 선언**

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/Pretendard-Thin.otf
          weight: 100
        - asset: assets/fonts/Pretendard-ExtraLight.otf
          weight: 200
        - asset: assets/fonts/Pretendard-Light.otf
          weight: 300
        - asset: assets/fonts/Pretendard-Regular.otf
          weight: 400
        - asset: assets/fonts/Pretendard-Medium.otf
          weight: 500
        - asset: assets/fonts/Pretendard-SemiBold.otf
          weight: 600
        - asset: assets/fonts/Pretendard-Bold.otf
          weight: 700
        - asset: assets/fonts/Pretendard-ExtraBold.otf
          weight: 800
        - asset: assets/fonts/Pretendard-Black.otf
          weight: 900
```

- [ ] **Step 3: 실패하는 타이포그래피 테스트 작성**

`test/core/theme/app_typography_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
```

- [ ] **Step 4: 테스트 실패 확인**

```bash
flutter test test/core/theme/app_typography_test.dart
```
Expected: FAIL — URI 없음

- [ ] **Step 5: AppTypography 구현**

`lib/core/theme/app_typography.dart`:

```dart
import 'package:flutter/material.dart';

/// 웹 `src/shared/mixin/typography.ts` 대응.
///
/// 웹 상수 19개 중 아래 3쌍은 값이 동일한 별칭이라 통합했다:
/// HEADING_4 == HEADING_4_BOLD, TITLE_1 == TITLE_1_BOLD,
/// BODY_4 == BODY_4_REGULAR.
///
/// Tailwind `text-[24px]/[130%]`의 130%는 line-height 비율이고
/// Flutter `height`는 배수이므로 1.3으로 옮긴다.
abstract final class AppTypography {
  static const String _family = 'Pretendard';

  static const TextStyle heading1 = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading4SemiBold = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle heading5 = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title1SemiBold = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title3 = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body3 = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body4 = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body4Medium = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  /// 웹 NAV_TEXT. line-height 미지정이라 height를 두지 않는다.
  static const TextStyle navText = TextStyle(
    fontFamily: _family,
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const List<TextStyle> all = [
    heading1,
    heading2,
    heading3,
    heading4,
    heading4SemiBold,
    heading5,
    title1,
    title1SemiBold,
    title2,
    title3,
    body1,
    body2,
    body3,
    body4,
    body4Medium,
    navText,
  ];
}
```

- [ ] **Step 6: AppTheme 조립**

`lib/core/theme/app_theme.dart`:

```dart
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
```

- [ ] **Step 7: 테마 주입 테스트 추가**

`test/core/theme/app_typography_test.dart` 하단에 추가:

```dart
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
```

import 추가:

```dart
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_radius.dart';
import 'package:geonganghaejim/core/theme/app_spacing.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
```

- [ ] **Step 8: 전체 검증 후 커밋**

```bash
./tool/verify.sh
```
Expected: 모든 테스트 PASS

```bash
git add pubspec.yaml assets/fonts lib/core/theme test/core/theme
git commit -m "feat(theme): Pretendard 폰트와 타이포그래피 16종 이식, ThemeData 조립"
```

---

