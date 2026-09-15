import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/page/public/policy_page.dart';

/// 요청이 0건인 화면이라 패리티 골든이 없다 — 하네스를 빠뜨린 것이 아니라
/// 대조할 요청 자체가 없다. 웹 `PolicyPage.tsx`도 `api`/`authApi`를 쓰지 않는다.
void main() {
  group('PolicyPage', () {
    Widget wrap({VoidCallback? onBack, ValueChanged<String>? onOpen}) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: PolicyPage(onBack: onBack ?? () {}, onOpen: onOpen ?? (_) {}),
      );
    }

    testWidgets('제목과 두 항목을 보여준다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('약관 및 정책'), findsOneWidget);
      expect(find.text('서비스 이용약관'), findsOneWidget);
      expect(find.text('개인정보 처리방침'), findsOneWidget);
    });

    testWidgets('제목은 웹 HEADING_3이다', (tester) async {
      await tester.pumpWidget(wrap());

      // 웹 `cn(Typography.HEADING_3, 'bg-white px-7 pb-7 pt-8')`
      // → 20px/130% bold. HEADING_1(24px)이 아니다.
      expect(
        tester.widget<Text>(find.text('약관 및 정책')).style,
        AppTypography.heading3,
      );
    });

    testWidgets('항목 문구는 웹 BODY_1이다', (tester) async {
      await tester.pumpWidget(wrap());

      // 웹 `cn(Typography.BODY_1)` — 색 클래스가 없다.
      expect(
        tester.widget<Text>(find.text('서비스 이용약관')).style,
        AppTypography.body1,
      );
    });

    testWidgets('항목마다 오른쪽 화살표가 있다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byType(SvgPicture), findsNWidgets(3));
    });

    testWidgets('이용약관을 누르면 그 경로를 연다', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(wrap(onOpen: opened.add));

      await tester.tap(find.text('서비스 이용약관'));
      await tester.pump();

      expect(opened, <String>['/policy/terms']);
    });

    testWidgets('개인정보 처리방침을 누르면 그 경로를 연다', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(wrap(onOpen: opened.add));

      await tester.tap(find.text('개인정보 처리방침'));
      await tester.pump();

      expect(opened, <String>['/policy/privacy']);
    });

    testWidgets('헤더 뒤로가기를 누르면 onBack이 불린다', (tester) async {
      var backs = 0;
      await tester.pumpWidget(wrap(onBack: () => backs++));

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(backs, 1);
    });

    // 웹 헤더에는 `<Button variant='ghost'><IconBack /></Button>` 하나뿐이고
    // 제목이 없다. 제목을 넣으면 웹에 없는 것이 생긴다.
    testWidgets('헤더에 제목이 없다', (tester) async {
      await tester.pumpWidget(wrap());

      // 본문 h1은 Contents 안에 있다 — 헤더(AppBar) 안에는 없어야 한다.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('약관 및 정책'),
        ),
        findsNothing,
      );
    });
  });
}
