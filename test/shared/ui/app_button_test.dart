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
      await tester.pumpWidget(
        _wrap(const AppButton(label: '로그인', onPressed: null)),
      );

      expect(find.text('로그인'), findsOneWidget);
    });

    testWidgets('탭하면 콜백이 호출된다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(AppButton(label: '로그인', onPressed: () => tapped++)),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('primary 변형은 테마의 primary500을 배경으로 쓴다', (tester) async {
      await tester.pumpWidget(_wrap(AppButton(label: '로그인', onPressed: () {})));

      // find.descendant(of: AppButton, matching: Container) 대신 Key로 잡는다.
      // 내부 위젯 트리 모양(예: Container를 감싸는 래퍼 추가)이 바뀌어도
      // "배경을 그리는 위젯이 테마의 primary500을 쓴다"는 의도만 검증하기 위함.
      final container = tester.widget<Container>(
        find.byKey(AppButton.backgroundKey),
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, AppColors.light.primary500);
    });

    testWidgets('비활성 상태에서는 콜백이 호출되지 않는다', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: '로그인', onPressed: null)),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      // 예외 없이 통과하면 성공
    });

    testWidgets('isLoading이면 라벨 대신 인디케이터를 보여준다', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: '로그인', onPressed: () {}, isLoading: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('로그인'), findsNothing);
    });

    testWidgets('isLoading이면 onPressed가 있어도 탭이 막힌다 (중복 제출 방지)', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          AppButton(label: '로그인', onPressed: () => tapped++, isLoading: true),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, 0);
    });
  });
}
