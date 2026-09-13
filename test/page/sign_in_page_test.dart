import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/page/public/sign_in_page.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';

/// 패리티 테스트 보류 사유.
///
/// `flutter_test`의 `testWidgets`는 `package:test`의 `test`와 달리
/// `skip`이 `bool?`이라 사유 문자열을 받지 못한다. 그래서 사유를 테스트
/// 이름에 붙여 `flutter test` 출력에 드러낸다.
///
/// `test/fixtures/requests/login.json`이 생기면 아래 두 테스트의
/// `skip: true`와 이름 접미사만 떼면 된다 — **본문은 그대로 둔다.**
const String kGoldenPending = '골든 픽스처 없음 — Task 4 Step 7(HAR 캡처) 대기';

void main() {
  group('SignInPage', () {
    late RequestCapture capture;
    late Dio dio;
    late _StubAdapter adapter;

    setUp(() {
      capture = RequestCapture();
      dio = DioClient.create(baseUrl: 'https://example.test', extra: [capture]);

      // 네트워크로 나가지 않도록 응답을 가로챈다.
      adapter = _StubAdapter();
      dio.httpClientAdapter = adapter;
    });

    Widget wrap({String memberType = 'STUDENT'}) => MaterialApp(
      theme: AppTheme.light(),
      home: SignInPage(authApi: AuthApi(dio), memberType: memberType),
    );

    testWidgets('아이디·비밀번호 입력과 로그인 버튼을 표시한다', (tester) async {
      await tester.pumpWidget(wrap());

      // 웹은 이메일이 아니라 아이디로 로그인한다 (CommandLoginMember.userId)
      expect(find.text('회원 로그인'), findsOneWidget); // student 기본값
      expect(find.text('아이디'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(find.text('로그인'), findsOneWidget);
    });

    testWidgets('트레이너 타입이면 제목이 트레이너 로그인이다', (tester) async {
      await tester.pumpWidget(wrap(memberType: 'TRAINER'));

      expect(find.text('트레이너 로그인'), findsOneWidget);
      expect(find.text('회원 로그인'), findsNothing);
    });

    testWidgets('빈 입력으로 제출하면 오류를 표시하고 요청을 보내지 않는다', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      // 웹 SignInForm의 react-hook-form `required.message`와 같은 문구다.
      // `textContaining('입력')`으로 느슨하게 잡으면 나중에 누가
      // AppTextInput에 placeholder(웹 문구가 동일하다)를 붙이는 순간
      // 유효성 검사가 깨져도 통과한다.
      expect(find.text('아이디를 입력해주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해주세요.'), findsOneWidget);
      expect(capture.captured, isEmpty);
    });

    testWidgets('입력한 아이디·비밀번호가 요청 본문에 그대로 실린다', (tester) async {
      // 아래 패리티 테스트와 겹치지 않는다: `password`는 `kMaskedKeys`에 있어
      // 골든 대조가 **키 존재만** 확인한다. 즉 userId와 password를 서로 바꿔
      // 실어도 패리티는 통과한다. 그 결선(폼 → 요청 본문)은 여기서만 잡힌다.
      // 반대로 method·path·memberType은 골든의 몫이라 여기서 다시 단언하지 않는다.
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password1234');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      expect(capture.captured, hasLength(1));
      final body = capture.captured.single.body;
      expect(body, isA<Map<String, dynamic>>());
      expect((body! as Map<String, dynamic>)['userId'], 'testuser');
      expect((body as Map<String, dynamic>)['password'], 'password1234');
    });

    testWidgets('요청이 실패하면 서버 메시지를 화면에 표시한다', (tester) async {
      adapter.statusCode = 401;
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'wrongpassword');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      // 웹 SignInForm은 `error.response?.data?.message`를 errorToast로 띄운다.
      expect(find.text('아이디 또는 비밀번호가 일치하지 않습니다.'), findsOneWidget);
    });

    testWidgets('로그인 요청이 웹과 동일한 형태로 나간다 (패리티) — 보류: $kGoldenPending', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password1234');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      // 손으로 적은 기대값이 아니라 웹에서 캡처한 골든과 대조한다.
      // 이 한 줄이 검증 루프 3의 실제 적용 지점이며,
      // Phase 1~8의 모든 화면이 같은 방식으로 검증된다.
      expectParity('login', capture.captured);
    }, skip: true);

    testWidgets('잘못된 경로로 요청하면 패리티가 실패한다 (하네스 자체 검증) '
        '— 보류: $kGoldenPending', (tester) async {
      // 하네스가 실제로 불일치를 잡는지 확인한다.
      // "통과했다"가 아니라 "실패를 잡는다"가 검증의 근거다.
      final bogus = [
        const CapturedRequest(
          method: 'POST',
          path: '/api/v1/wrong/path',
          query: {},
          body: {'userId': 'x', 'password': 'y', 'memberType': 'STUDENT'},
        ),
      ];

      expect(() => expectParity('login', bogus), throwsA(isA<ParityFailure>()));
    }, skip: true);
  });
}

/// 네트워크 없이 고정 응답을 주는 어댑터.
///
/// [statusCode]를 바꾸면 실패 경로를 재현한다 — dio 기본 `validateStatus`가
/// 2xx 외를 거부해 `DioException`을 던지고, 그때도 `response.data`는 아래
/// 실패 envelope로 채워진다(웹이 `error.response.data.message`를 읽는 구조와 동일).
class _StubAdapter implements HttpClientAdapter {
  /// 테스트가 `pumpWidget` 전에 바꿔 실패 경로를 재현한다.
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 백엔드 ApiResultTokens envelope 형태를 그대로 흉내낸다.
    final body = statusCode == 200
        ? '{"status":"success","message":"로그인 성공","data":'
              '{"memberId":1,"name":"홍길동","accessToken":"at","refreshToken":"rt",'
              '"userId":"testuser","memberType":"STUDENT","gymId":7}}'
        : '{"status":"fail",'
              '"message":"아이디 또는 비밀번호가 일치하지 않습니다.","data":null}';

    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
