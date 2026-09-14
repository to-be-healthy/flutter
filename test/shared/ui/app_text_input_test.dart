import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_radius.dart';
import 'package:geonganghaejim/core/theme/app_spacing.dart';
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

    testWidgets('입력 높이는 웹 h-[50px]와 같다 — 칠해지는 상자 자체가 50이다', (tester) async {
      // 웹 `SignInForm.tsx:58,81`의 `containerClassName='h-[50px]'`.
      //
      // **이 단언이 무엇을 재는지가 핵심이다.** 이전 구현은 `TextField`를
      // `SizedBox(height: 50)`로 감쌌고, 이 테스트는 그 SizedBox를 재서
      // 통과했다. 실제로 칠해지는 채움·테두리 상자는 24pt(= body1 행 높이)
      // 였고 50pt 슬롯 가운데 떠 있었다 — 시뮬레이터 실측에서야 드러났다.
      // SizedBox를 없앤 지금은 `TextField`의 크기가 곧 `InputDecorator`가
      // 콘텐츠에서 계산한 상자 높이라, 이 한 줄이 화면에 보이는 높이를 잡는다.
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      expect(
        tester.getSize(find.byType(TextField)).height,
        AppTextInput.height,
      );
      expect(AppTextInput.height, 50.0);
    });

    testWidgets('에러가 붙어도 입력 자체의 높이는 50px로 같다', (tester) async {
      // 에러 메시지는 입력 박스 **바깥**의 별도 Text다 — 박스를 밀어내면
      // 폼 전체가 웹과 어긋난다.
      await tester.pumpWidget(
        _wrap(const AppTextInput(label: '아이디', errorText: '아이디를 입력해주세요.')),
      );

      expect(
        tester.getSize(find.byType(TextField)).height,
        AppTextInput.height,
      );
    });

    testWidgets('입력 타이포에 leadingDistribution even을 준다', (tester) async {
      // 고정 높이 박스 안에서 웹과 같은 세로 위치를 얻기 위한 것이다 —
      // CSS half-leading과 Flutter 기본 분배 규칙이 다르다.
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(
        field.style,
        AppTypography.body1.copyWith(
          color: AppColors.light.gray800,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
    });

    testWidgets('에러가 없어도 웹과 같은 gray-200 테두리를 그린다', (tester) async {
      // 웹 `TextInput.tsx`는 평상시에도 `border border-solid border-gray-200`
      // 이다. 이전 구현은 `BorderSide.none`이라 테두리가 아예 없었다.
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      final field = tester.widget<TextField>(find.byType(TextField));
      final border = field.decoration!.enabledBorder! as OutlineInputBorder;

      expect(border.borderSide.color, AppColors.light.gray200);
      expect(border.borderSide.style, BorderStyle.solid);
    });

    testWidgets('모서리 반경은 웹 rounded-md(8px)다', (tester) async {
      // 웹 입력의 `rounded-md` → `var(--radius-m)` → 8px. 버튼(`rounded-lg`,
      // 12px)과 다르다 — 둘을 같은 토큰으로 쓰면 한쪽이 조용히 틀어진다.
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      final field = tester.widget<TextField>(find.byType(TextField));
      final border = field.decoration!.enabledBorder! as OutlineInputBorder;

      expect(border.borderRadius, BorderRadius.circular(AppRadius.standard.m));
      expect(AppRadius.standard.m, 8.0);
    });

    testWidgets('입력을 채우지 않는다 — gray-100은 웹의 비활성 색이다', (tester) async {
      // 웹 `TextInput.tsx`의 클래스에는 `bg-*`가 없어 페이지 배경이 비친다.
      // gray-100이 등장하는 곳은 `disabled:bg-gray-100` 하나뿐이다. 이전
      // 구현은 그 비활성 색을 평상시 채움으로 써서, 62개 화면이 복사했다면
      // 모든 입력이 비활성처럼 보였을 것이다.
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.decoration!.filled, isFalse);
      expect(field.decoration!.fillColor, isNull);
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

    testWidgets('플레이스홀더를 웹처럼 BODY_1 + gray-500으로 보여준다', (tester) async {
      // 웹 `TextInput.tsx`의 `twSelector('placeholder', Typography.BODY_1)` +
      // `placeholder:text-gray-500`. 이 위젯에는 placeholder가 아예 없어서
      // 로그인 화면에 안내 문구가 비어 있었다 — 시뮬레이터 대조에서 드러났다.
      await tester.pumpWidget(
        _wrap(const AppTextInput(label: '아이디', hint: '아이디를 입력해주세요.')),
      );

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.decoration!.hintText, '아이디를 입력해주세요.');
      expect(field.decoration!.hintStyle!.color, AppColors.light.gray500);
      expect(
        field.decoration!.hintStyle!.fontSize,
        AppTypography.body1.fontSize,
      );
      expect(find.text('아이디를 입력해주세요.'), findsOneWidget);
    });

    testWidgets('hint를 주지 않으면 플레이스홀더가 없다', (tester) async {
      await tester.pumpWidget(_wrap(const AppTextInput(label: '아이디')));

      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        isNull,
      );
    });

    testWidgets('라벨·입력·에러 사이 간격이 모두 8px로 같다', (tester) async {
      // 웹은 셋을 **한 컨테이너의 `gap-y-3`**으로 묶는다 —
      // `SignInForm.tsx`의 `flex w-full flex-col gap-y-3`,
      // `FindIdPage.tsx`의 `flex flex-col gap-3`. 둘 다 8px이다.
      //
      // 이전 구현은 에러 쪽만 `s2`(6px)였다. 근거 없는 2px 어긋남이었고,
      // 62개 화면이 복사하기 전에 잡는다. 라벨 쪽과 **같은 값**임을 함께
      // 단언해야 한쪽만 바뀌는 회귀가 잡힌다.
      await tester.pumpWidget(
        _wrap(const AppTextInput(label: '아이디', errorText: '아이디를 입력해주세요.')),
      );

      final labelBottom = tester.getRect(find.text('아이디')).bottom;
      final field = tester.getRect(find.byType(TextField));
      final errorTop = tester.getRect(find.text('아이디를 입력해주세요.')).top;

      expect(field.top - labelBottom, AppSpacing.standard.s3);
      expect(errorTop - field.bottom, AppSpacing.standard.s3);
      expect(AppSpacing.standard.s3, 8.0);
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
