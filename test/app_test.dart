import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/app.dart';

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
}
