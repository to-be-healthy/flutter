import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/shared/ui/app_text_input.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppTextInput', () {
    testWidgets('라벨 타이포·색은 웹 TITLE_3 + text-gray-800과 같다', (tester) async {
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      final label = tester.widget<Text>(find.text('아이디'));

      // 웹 `SignInForm.tsx:50,74` = `cn(Typography.TITLE_3, 'text-gray-800')`
      // → 14px/150% semibold, gray-800. gray-700이 아니다.
      expect(
        label.style,
        AppTypography.title3.copyWith(color: AppColors.light.gray800),
      );
    });

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

    testWidgets('도달 불가한 그림자 border를 두지 않는다', (tester) async {
      // `enabledBorder`가 항상 이기므로 `border:`는 절대 렌더되지 않는다.
      // 값이 같아 지금은 버그가 아니지만, 이 위젯은 62개 화면이 복사할
      // 템플릿이라 죽은 분기가 복사된 뒤 갈라진다 — 직전 라운드가 제거한
      // `errorBorder`와 같은 종류의 재도입이었다.
      //
      // 부작용 하나를 여기 기록한다: `border:`가 없으므로 나중에 누가
      // `enabled: false`를 붙이면 `disabledBorder`가 Material 기본값
      // (`UnderlineInputBorder`)로 떨어진다. 비활성 입력을 추가할 때는
      // `disabledBorder`를 명시할 것.
      for (final errorText in <String?>[null, '이미 사용 중인 아이디입니다']) {
        await tester.pumpWidget(
          _wrap(AppTextInput(label: '아이디', errorText: errorText)),
        );

        final field = tester.widget<TextField>(find.byType(TextField));

        expect(
          field.decoration!.border,
          isNull,
          reason: 'errorText=$errorText 에서 도달 불가한 border가 남아 있다',
        );
      }
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
