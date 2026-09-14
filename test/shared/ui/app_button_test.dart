import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
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

    testWidgets('라벨 타이포는 웹 TITLE_1_SEMIBOLD와 같다', (tester) async {
      await tester.pumpWidget(_wrap(AppButton(label: '로그인', onPressed: () {})));

      final label = tester.widget<Text>(find.text('로그인'));

      // 웹 `SignInForm.tsx:100` = `cn(Typography.TITLE_1_SEMIBOLD, 'h-[44px]')`
      // → 16px/140% **semibold**. bold(`title1`)가 아니다.
      //
      // `leadingDistribution: even`은 고정 높이(44px) 박스 안에서 웹과 같은
      // 세로 위치를 얻기 위한 것이다 — CSS는 여분 행간을 위아래 절반씩
      // 나누는데(half-leading) Flutter 기본값은 폰트의 ascent/descent 비율로
      // 나눠서, Pretendard 한글 메트릭에서 글자가 1~2px 어긋난다.
      expect(
        label.style,
        AppTypography.title1SemiBold.copyWith(
          color: Colors.white,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
    });

    testWidgets('버튼 높이는 웹 h-[44px]와 같다', (tester) async {
      // 웹 `SignInForm.tsx:100`이 `h-[44px]`로 고정한다. 패딩 기반이던
      // 이전 구현은 ~10px 높았다.
      await tester.pumpWidget(_wrap(AppButton(label: '로그인', onPressed: () {})));

      expect(
        tester.getSize(find.byKey(AppButton.backgroundKeyFor('로그인'))).height,
        AppButton.height,
      );
      expect(AppButton.height, 44.0);
    });

    testWidgets('로딩 인디케이터가 떠도 높이는 44px로 같다', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: '로그인', onPressed: () {}, isLoading: true)),
      );

      expect(
        tester.getSize(find.byKey(AppButton.backgroundKeyFor('로그인'))).height,
        AppButton.height,
      );
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

    testWidgets('스크린리더에 버튼·활성 상태·라벨을 노출한다', (tester) async {
      // GestureDetector + Container + Text만으로는 TalkBack/VoiceOver가
      // "버튼"임을 알리지 못하고 비활성 상태도 드러나지 않는다.
      // 62개 화면이 이 위젯을 복사한다.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrap(AppButton(label: '로그인', onPressed: () {})));

      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: '로그인',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          // 스크린리더가 두 번 탭해 활성화할 수 있어야 한다. excludeSemantics로
          // 자식을 접었으므로 Semantics가 직접 onTap을 노출한다.
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('비활성 버튼은 스크린리더에 비활성으로 노출된다', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(const AppButton(label: '로그인', onPressed: null)),
      );

      final node = tester.getSemantics(find.byType(AppButton));

      expect(
        node,
        matchesSemantics(
          label: '로그인',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('isLoading이면 비활성으로 노출된다 (중복 제출 방지와 같은 상태)', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(AppButton(label: '로그인', onPressed: () {}, isLoading: true)),
      );

      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: '로그인',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
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
