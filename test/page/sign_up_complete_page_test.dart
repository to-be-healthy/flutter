import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/page/public/sign_up_complete_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';

/// 요청이 0건인 화면이라 패리티 골든이 없다 — 대조할 요청 자체가 없다.
///
/// 파라미터가 비었을 때의 처리는 여기 없다. 웹은 화면 안에서
/// `throw new Error()`를 던지지만 앱은 **라우터에서** 온보딩으로 돌려보내므로
/// (`/sign-in`의 `?type=` 게이트와 같은 패턴) `app_test.dart`가 본다.
void main() {
  group('SignUpCompletePage', () {
    Widget wrap({
      String name = '홍길동',
      String memberType = 'student',
      ValueChanged<String>? onConfirm,
    }) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: SignUpCompletePage(
          name: name,
          memberType: memberType,
          onConfirm: onConfirm ?? (_) {},
        ),
      );
    }

    testWidgets('가입완료 문구와 이름을 보여준다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('가입완료'), findsOneWidget);
      expect(find.text('홍길동님, 환영합니다!'), findsOneWidget);
    });

    testWidgets('이름이 다르면 인사말도 따라 바뀐다', (tester) async {
      await tester.pumpWidget(wrap(name: '정선우'));

      expect(find.text('정선우님, 환영합니다!'), findsOneWidget);
    });

    testWidgets('"가입완료"는 웹 HEADING_4_BOLD + primary500이다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(
        tester.widget<Text>(find.text('가입완료')).style,
        AppTypography.heading4.copyWith(color: AppColors.light.primary500),
      );
    });

    testWidgets('인사말은 웹 HEADING_1 + gray800이다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(
        tester.widget<Text>(find.text('홍길동님, 환영합니다!')).style,
        AppTypography.heading1.copyWith(color: AppColors.light.gray800),
      );
    });

    testWidgets('완료 이미지를 보여준다', (tester) async {
      await tester.pumpWidget(wrap());

      final image = tester.widget<Image>(find.byType(Image));

      expect(
        (image.image as AssetImage).assetName,
        'assets/images/sign_up_complete.png',
      );
      // 웹 `<Image width={100} height={100} />`.
      expect(image.width, SignUpCompletePage.imageSize);
      expect(image.height, SignUpCompletePage.imageSize);
    });

    // 웹은 이 화면에 `Layout.Header`를 두지 않는다. 가입을 막 끝낸 사용자를
    // 되돌려 보낼 곳이 없기 때문이다.
    testWidgets('헤더가 없다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('확인을 누르면 가입한 역할을 들고 로그인으로 간다', (tester) async {
      final confirmed = <String>[];
      await tester.pumpWidget(
        wrap(memberType: 'trainer', onConfirm: confirmed.add),
      );

      await tester.tap(find.text('확인'));
      await tester.pump();

      // 웹 `href={`/sign-in?type=${type}`}` — 역할이 빠지면 로그인 화면이
      // `?type=`을 필수로 요구해 라우터가 온보딩으로 되돌린다.
      expect(confirmed, <String>['trainer']);
    });

    testWidgets('확인 버튼은 웹 h-[57px] + TITLE_1_BOLD다', (tester) async {
      await tester.pumpWidget(wrap());

      final button = tester.widget<AppButton>(find.byType(AppButton));

      expect(button.height, SignUpCompletePage.confirmButtonHeight);
      expect(button.labelStyle, AppTypography.title1);
    });

    // 웹은 확인 버튼을 `Layout.BottomArea`가 아니라 Contents 안에 두고
    // `h-full` + `justify-between`으로 아래에 붙인다. 구조가 달라지면
    // 스크롤·키보드 동작이 웹과 어긋난다.
    testWidgets('확인 버튼이 하단 슬롯이 아니라 본문 안에 있다', (tester) async {
      await tester.pumpWidget(wrap());

      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(AppButton),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
        isNull,
      );
    });
  });
}
