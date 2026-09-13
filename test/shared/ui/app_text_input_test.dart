import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/shared/ui/app_text_input.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppTextInput', () {
    testWidgets('에러가 없으면 테두리에 색을 넣지 않는다', (tester) async {
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      final field = tester.widget<TextField>(find.byType(TextField));
      final border = field.decoration!.enabledBorder! as OutlineInputBorder;

      expect(border.borderSide, BorderSide.none);
    });

    testWidgets('에러가 있으면 테두리가 point 색이 된다 (errorBorder는 도달 불가라 쓰지 않는다)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppTextInput(label: '아이디', errorText: '이미 사용 중인 아이디입니다')),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      final border = field.decoration!.enabledBorder! as OutlineInputBorder;

      expect(border.borderSide.color, AppColors.light.point);
      // Flutter의 errorBorder는 decoration.errorText가 설정될 때만
      // 적용된다. 이 위젯은 errorText를 InputDecoration에 넘기지 않으므로
      // errorBorder를 정의해도 절대 쓰이지 않는다 — 그래서 enabledBorder를
      // 직접 바꾸는 방식으로 구현했고, 그 사실을 여기서 함께 남긴다.
      expect(field.decoration!.errorText, isNull);
    });

    testWidgets('에러 메시지를 별도 텍스트로 보여준다', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppTextInput(label: '아이디', errorText: '이미 사용 중인 아이디입니다')),
      );

      expect(find.text('이미 사용 중인 아이디입니다'), findsOneWidget);
    });

    testWidgets('라벨을 표시한다', (tester) async {
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      expect(find.text('아이디'), findsOneWidget);
    });
  });
}
