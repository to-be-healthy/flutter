import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/app.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_text_input.dart';

void main() {
  // 기본 카운터 스모크 테스트(`test/widget_test.dart`)를 대체한다.
  // `main.dart`가 `MyApp`을 버렸으므로 그 테스트는 더 이상 컴파일되지 않는다.
  testWidgets('앱 진입점이 로그인 화면을 띄운다', (tester) async {
    await tester.pumpWidget(
      const GeonganghaejimApp(baseUrl: 'https://example.test'),
    );
    await tester.pump();

    expect(find.text('회원 로그인'), findsOneWidget);
    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('OS 글꼴 배율을 상한까지만 따른다', (tester) async {
    // 디자인이 고정 높이를 가진 웹에서 픽셀 단위로 옮겨졌고
    // `AppButton.height`(44)·`AppTextInput.height`(50)가 그 값을 고정한다.
    // "고정 높이"와 "무제한 OS 배율"은 동시에 참일 수 없다.
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const GeonganghaejimApp(baseUrl: 'https://example.test'),
    );
    await tester.pump();

    final context = tester.element(find.text('아이디'));
    final scaler = MediaQuery.textScalerOf(context);

    expect(scaler.scale(16), 16 * kMaxTextScaleFactor);
  });

  testWidgets('상한 아래의 배율은 그대로 따른다 (클램프지 무시가 아니다)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const GeonganghaejimApp(baseUrl: 'https://example.test'),
    );
    await tester.pump();

    final context = tester.element(find.text('아이디'));

    expect(MediaQuery.textScalerOf(context).scale(16), closeTo(16 * 1.1, 0.01));
  });

  testWidgets('상한 배율에서도 버튼·입력 고정 높이가 넘치지 않는다', (tester) async {
    // 상한값을 고른 근거를 테스트로 고정한다. 가장 빡빡한 제약은 44px
    // 버튼 안의 title1SemiBold(16px × 1.4)다.
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const GeonganghaejimApp(baseUrl: 'https://example.test'),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(AppButton.backgroundKeyFor('로그인'))).height,
      AppButton.height,
    );
    expect(
      16 * 1.4 * kMaxTextScaleFactor,
      lessThan(AppButton.height),
      reason: '버튼 라인박스가 44px 안에 들어와야 한다',
    );
    expect(
      16 * 1.5 * kMaxTextScaleFactor,
      lessThan(AppTextInput.height),
      reason: '입력 라인박스가 50px 안에 들어와야 한다',
    );
  });
}
