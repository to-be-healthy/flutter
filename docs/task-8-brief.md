## Task 8: Layout 셸

웹 `src/widget/layout.tsx`(76줄)는 `Layout.Header` / `Layout.Contents` / `Layout.BottomArea` 슬롯 패턴이고, `global.css`의 `body { position: fixed; height: 100dvh }`로 모바일 브라우저 바운스를 차단한 뒤 Contents만 `overflow-y-auto`로 스크롤시킨다. **Flutter에서는 그 해킹이 불필요하다** — Scaffold가 같은 구조를 기본 제공한다.

**Files:**
- Create: `flutter/lib/widget/app_layout.dart`
- Test: `flutter/test/widget/app_layout_test.dart`

**Interfaces:**
- Consumes: `AppTheme.light()`, `AppSpacing`, `AppColors` (Task 2·3)
- Produces: `AppLayout({PreferredSizeWidget? header, required Widget contents, Widget? bottomArea})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/widget/app_layout_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  group('AppLayout', () {
    testWidgets('세 슬롯을 모두 렌더한다', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppLayout(
          header: AppLayoutHeader(title: '로그인'),
          contents: Text('본문'),
          bottomArea: Text('하단'),
        ),
      ));

      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('본문'), findsOneWidget);
      expect(find.text('하단'), findsOneWidget);
    });

    testWidgets('header·bottomArea 없이도 동작한다', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppLayout(contents: Text('본문만')),
      ));

      expect(find.text('본문만'), findsOneWidget);
    });

    testWidgets('본문이 길면 스크롤된다', (tester) async {
      await tester.pumpWidget(_wrap(
        AppLayout(
          contents: Column(
            children: List.generate(50, (i) => SizedBox(
              height: 100,
              child: Text('항목 $i'),
            )),
          ),
        ),
      ));

      expect(find.text('항목 0'), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
      await tester.pump();
      expect(find.text('항목 0'), findsNothing);
    });

    testWidgets('SafeArea로 노치·홈인디케이터를 회피한다', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppLayout(contents: Text('본문')),
      ));

      expect(find.byType(SafeArea), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
flutter test test/widget/app_layout_test.dart
```
Expected: FAIL — URI 없음

- [ ] **Step 3: 구현**

`lib/widget/app_layout.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 웹 `src/widget/layout.tsx` 슬롯 패턴 대응.
///
/// 웹은 body를 position:fixed로 고정하고 Contents만 스크롤시켜
/// 모바일 브라우저 바운스를 막았다. 네이티브에는 그 문제가 없으므로
/// Scaffold 기본 구조를 그대로 쓴다.
class AppLayout extends StatelessWidget {
  const AppLayout({
    required this.contents,
    this.header,
    this.bottomArea,
    super.key,
  });

  final Widget contents;
  final PreferredSizeWidget? header;
  final Widget? bottomArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      appBar: header,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: spacing.s6),
          child: contents,
        ),
      ),
      bottomNavigationBar: bottomArea == null
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.s6,
                  spacing.s5,
                  spacing.s6,
                  spacing.s6,
                ),
                child: bottomArea,
              ),
            ),
    );
  }
}

/// 웹 `Layout.Header` 대응.
class AppLayoutHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppLayoutHeader({required this.title, this.onBack, super.key});

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: colors.gray800),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(
        title,
        style: AppTypography.title1.copyWith(color: colors.gray800),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/widget/app_layout_test.dart
```
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
./tool/verify.sh
git add lib/widget test/widget
git commit -m "feat(widget): AppLayout 슬롯 셸 추가"
```

---

