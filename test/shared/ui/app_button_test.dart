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
        find.byKey(AppButton.backgroundKeyFor('로그인')),
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, AppColors.light.primary500);
    });

    testWidgets('비활성 배경은 variant와 무관하게 gray300이다 (웹 disabled:bg-gray-300)', (
      tester,
    ) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          _wrap(AppButton(label: '확인', onPressed: null, variant: variant)),
        );

        final container = tester.widget<Container>(
          find.byKey(AppButton.backgroundKeyFor('확인')),
        );
        final decoration = container.decoration! as BoxDecoration;

        expect(
          decoration.color,
          AppColors.light.gray300,
          reason: '$variant 비활성 배경은 gray300이어야 한다',
        );
      }
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

    testWidgets('AppButton이 둘 이상이어도 label로 각각의 배경을 찾을 수 있다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              AppButton(label: '확인', onPressed: () {}),
              const AppButton(
                label: '취소',
                onPressed: null,
                variant: AppButtonVariant.ghost,
              ),
            ],
          ),
        ),
      );

      // static const 단일 Key였다면 find.byKey가 둘을 동시에 잡아
      // tester.widget()이 "too many elements"로 깨졌을 것이다.
      final confirm = tester.widget<Container>(
        find.byKey(AppButton.backgroundKeyFor('확인')),
      );
      final cancel = tester.widget<Container>(
        find.byKey(AppButton.backgroundKeyFor('취소')),
      );

      // 서로 다른 색이어야 각 키가 "동일한 하나"가 아니라 자기 위젯을
      // 정확히 가리키고 있음을 검증한 것이 된다.
      expect(
        (confirm.decoration! as BoxDecoration).color,
        AppColors.light.primary500,
      );
      expect(
        (cancel.decoration! as BoxDecoration).color,
        AppColors.light.gray300, // 비활성이라 ghost 기본(transparent) 대신 gray300
      );
    });
  });
}
