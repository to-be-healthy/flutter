## Task 7: 공통 위젯 — Button, TextInput

이후 62개 화면이 이 두 위젯을 재사용한다. **AI에게 화면 이식을 맡기기 전에 사람이 확정해야 하는 "정답 패턴"이다.** 색·간격·타이포를 리터럴로 쓰지 않고 테마를 경유하는 방식을 여기서 못박는다.

**Files:**
- Create: `flutter/lib/shared/ui/app_button.dart`
- Create: `flutter/lib/shared/ui/app_text_input.dart`
- Test: `flutter/test/shared/ui/app_button_test.dart`

**Interfaces:**
- Consumes: `AppTheme.light()`, `AppSpacing`, `AppColors`, `AppRadius`, `AppTypography` (Task 2·3)
- Produces:
  - `AppButton({required String label, VoidCallback? onPressed, AppButtonVariant variant = AppButtonVariant.primary, bool isLoading = false})`
  - `AppButtonVariant { primary, secondary, ghost }`
  - `AppTextInput({required String label, String? errorText, ValueChanged<String>? onChanged, bool obscureText = false})`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/shared/ui/app_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('라벨을 표시한다', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppButton(label: '로그인', onPressed: null),
      ));

      expect(find.text('로그인'), findsOneWidget);
    });

    testWidgets('탭하면 콜백이 호출된다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppButton(label: '로그인', onPressed: () => tapped++),
      ));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('primary 변형은 테마의 primary500을 배경으로 쓴다', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(label: '로그인', onPressed: () {}),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, AppColors.light.primary500);
    });

    testWidgets('비활성 상태에서는 콜백이 호출되지 않는다', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppButton(label: '로그인', onPressed: null),
      ));

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      // 예외 없이 통과하면 성공
    });

    testWidgets('isLoading이면 라벨 대신 인디케이터를 보여준다', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(label: '로그인', onPressed: () {}, isLoading: true),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('로그인'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
flutter test test/shared/ui/app_button_test.dart
```
Expected: FAIL — URI 없음

- [ ] **Step 3: AppButton 구현**

`lib/shared/ui/app_button.dart`:

```dart
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
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    super.key,
  });

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

    final background = switch (variant) {
      AppButtonVariant.primary =>
        isEnabled ? colors.primary500 : colors.gray200,
      AppButtonVariant.secondary => colors.blue50,
      AppButtonVariant.ghost => Colors.transparent,
    };

    final foreground = switch (variant) {
      AppButtonVariant.primary => isEnabled ? Colors.white : colors.gray400,
      AppButtonVariant.secondary => colors.primary500,
      AppButtonVariant.ghost => colors.gray600,
    };

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/shared/ui/app_button_test.dart
```
Expected: PASS (8 tests)

- [ ] **Step 5: AppTextInput 구현**

`lib/shared/ui/app_text_input.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 웹 `src/shared/ui/input` 대응.
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
```

- [ ] **Step 6: 커밋**

```bash
./tool/verify.sh
git add lib/shared test/shared
git commit -m "feat(ui): 공통 위젯 AppButton·AppTextInput 추가"
```

---
