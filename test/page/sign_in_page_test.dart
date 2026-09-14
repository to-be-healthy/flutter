import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/page/public/sign_in_page.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';

/// 로그인 골든 픽스처의 계약.
///
/// `test/fixtures/requests/login.json`은 `tool/har_to_golden.py`가
/// `har/login.har`에서 생성한다 — 2026-09-14, geonganghaejim.site 학생 계정의
/// **폼 로그인**(체험하기 버튼이 아니다) 캡처다.
///
/// 아래가 그 골든과 이 파일의 패리티 테스트를 묶는 조건이다. 하나라도 어긋나면
/// 재캡처하거나 요청 쪽을 웹에 맞춰라 — **단언을 지우거나 allowlist를 좁히는
/// 것은 답이 아니다.**
///
/// 1. 골든은 `headers` 키를 담은 현재 형식이어야 한다. `loadGolden`이 옛
///    형식(headers 없음)을 거부하고, 변환기가 그 키를 자동으로 넣는다.
/// 2. **STUDENT 로그인**으로 캡처돼 있어야 한다. `memberType`은
///    `kMaskedKeys`에 없어 **값까지** 대조되는데, 아래 테스트는 `wrap()`
///    기본값(`'STUDENT'`)으로 요청한다. 트레이너 계정으로 캡처했다면
///    골든을 다시 뜨거나 `wrap(memberType: 'TRAINER')`로 맞춰야 한다.
/// 3. `headers.content-type`이 **값까지** 대조된다. 로그인은 본문 있는
///    POST라 dio의 `ImplyContentTypeInterceptor`가 `application/json`을
///    붙인다(`DioClient`는 전역 `contentType`을 지정하지 않는다 — 본문 없는
///    GET에까지 붙어 웹과 어긋나기 때문). 골든(웹 HAR)이
///    `application/json;charset=UTF-8`이면 여기서 차이가 뜬다 — 그건
///    하네스의 오탐이 아니라 실제 차이이므로 **요청 쪽을 웹에 맞춰라.**
/// 4. `Authorization`은 양쪽 모두 없어야 한다. 로그인은 공개 경로이고
///    이 테스트의 `DioClient.create`는 `storage`를 넘기지 않아
///    `AuthInterceptor` 자체가 붙지 않는다. 웹도 토큰을 붙이지 않는 `api`
///    인스턴스로 보낸다(`frontend/src/entity/auth/api/mutations.ts`).
/// 5. 본문의 `userId`·`password`는 `kMaskedKeys`라 더미 값
///    (`'testuser'`/`'password1234'`)을 그대로 둬도 통과한다. 반대로 웹 폼
///    로그인은 `complimentaryLogin`을 **보내지 않는다** — 그 키는 "체험하기"
///    버튼만 붙이므로(`frontend/src/page/public/ui/ComplimentaryButton.tsx`)
///    그 경로로 캡처한 골든을 쓰면 "예상치 못한 추가"로 잡힌다.
/// 6. 로그인 경로(`/api/v1/auth/login`)에는 숫자 세그먼트가 없으므로
///    `--path-template` 유무가 이 골든에는 영향을 주지 않는다.

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
      // 아래 패리티 테스트와 겹치지 않는다: `userId`·`password`가 **둘 다**
      // `kMaskedKeys`에 있어(자격증명이 골든에 평문으로 남지 않도록) 골든 대조는
      // 그 두 키의 **존재만** 확인하고 값은 보지 않는다. 따라서 폼이 아니라 상수를
      // 실어 보내거나 두 값을 서로 바꿔 실어도 패리티는 통과한다 — 폼→본문 결선은
      // 여기서만 잡힌다.
      //
      // 반대로 method·path·memberType은 마스킹 대상이 아니라 골든이 값까지
      // 대조하므로 여기서 다시 단언하지 않는다.
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

    testWidgets('로그인 요청이 웹과 동일한 형태로 나간다 (패리티)', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password1234');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      // 손으로 적은 기대값이 아니라 웹에서 캡처한 골든과 대조한다.
      // 이 한 줄이 검증 루프 3의 실제 적용 지점이며,
      // Phase 1~8의 모든 화면이 같은 방식으로 검증된다.
      expectParity('login', capture.captured);
    });

    testWidgets('잘못된 경로로 요청하면 패리티가 실패한다 (하네스 자체 검증)', (tester) async {
      // 하네스가 실제로 불일치를 잡는지 확인한다.
      // "통과했다"가 아니라 "실패를 잡는다"가 검증의 근거다.
      //
      // **무엇이 실패했는지까지 단언한다.** 헤더 비교가 들어온 뒤로는 경로와
      // 헤더 두 가지가 동시에 어긋나므로, `throwsA(isA<ParityFailure>())`만
      // 보면 경로 비교를 통째로 지워도 이 테스트가 통과한다 — 이름이
      // 약속하는 것(경로 불일치를 잡는다)을 더는 검증하지 못한다.
      final bogus = [
        const CapturedRequest(
          method: 'POST',
          path: '/api/v1/wrong/path',
          query: {},
          body: {'userId': 'x', 'password': 'y', 'memberType': 'STUDENT'},
        ),
      ];

      expect(
        () => expectParity('login', bogus),
        throwsA(
          isA<ParityFailure>().having(
            (e) => e.message,
            'message',
            contains('path:'),
          ),
        ),
      );
    });
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
