import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/page/public/sign_in_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';

import 'package:geonganghaejim/entity/auth/model/auth_state.dart';
import 'package:geonganghaejim/entity/auth/ui/auth_scope.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

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

/// 같은 문구를 쓰는 placeholder와 구분해 **에러 텍스트만** 고른다.
/// 에러는 point 색, placeholder는 gray-500이다.
Finder _errorText(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data == text && w.style?.color == AppColors.light.point,
  description: 'point 색 에러 텍스트 "$text"',
);

void main() {
  group('SignInPage', () {
    late RequestCapture capture;
    late Dio dio;
    late _StubAdapter adapter;
    late FakeTokenStorage tokenStorage;
    late FakeAuthProfileStorage profileStorage;
    late AuthState authState;

    setUp(() {
      capture = RequestCapture();
      dio = DioClient.create(baseUrl: 'https://example.test', extra: [capture]);

      // 네트워크로 나가지 않도록 응답을 가로챈다.
      adapter = _StubAdapter();
      dio.httpClientAdapter = adapter;

      tokenStorage = FakeTokenStorage();
      profileStorage = FakeAuthProfileStorage();
      authState = AuthState(tokenStorage, profileStorage);
    });

    // **패리티 경계:** 여기서는 라우터를 끼우지 않는다.
    //
    // 로그인에 성공하면 `AuthState`가 바뀌고, 실제 앱에서는 라우터가 그걸
    // 보고 `/${memberType}`로 이동한다. 그 홈 화면이 붙는 Phase 3부터는
    // 홈이 GET 3건(`members/trainer-mapping`·`home/student`·
    // `notification/red-dot`)을 쏘는데, 라우터를 여기 끼우면 그 요청들이
    // **이 화면의 캡처에 섞여** `login` 골든에 "예상치 못한 추가"로 잡힌다.
    // 올바른 구현이 실패하는 것이다.
    //
    // 그래서 이 테스트가 보는 범위는 **로그인 요청까지**이고, 홈이 쏘는
    // 3건은 홈 화면이 생길 때 `har/home-student.har`로 별도 골든
    // (`expectParity('home-student', ...)`)을 만들어 검증한다.
    // `login.json`이 1건인 것은 버그가 아니라 이 경계의 결과다.
    Widget wrap({String memberType = 'STUDENT'}) => MaterialApp(
      theme: AppTheme.light(),
      home: AuthScope(
        notifier: authState,
        child: SignInPage(authApi: AuthApi(dio), memberType: memberType),
      ),
    );

    testWidgets('아이디·비밀번호 입력과 로그인 버튼을 표시한다', (tester) async {
      await tester.pumpWidget(wrap());

      // 웹은 이메일이 아니라 아이디로 로그인한다 (CommandLoginMember.userId)
      expect(find.text('회원 로그인'), findsOneWidget); // student 기본값
      expect(find.text('아이디'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(find.text('로그인'), findsOneWidget);
    });

    testWidgets('키보드가 올라와도 로그인 버튼에 닿을 수 있다', (tester) async {
      // 실기기 확인 항목 "키보드가 올라올 때 하단 버튼이 가려지지 않는가"를
      // 사람 눈 대신 맡는다.
      //
      // **스크롤로 확인하지 않는다.** `ensureVisible`을 부르면 스크롤 뒤의
      // 가시성만 보게 되고, 그건 `SingleChildScrollView`를 통째로 들어내도
      // 통과한다(실제로 뮤테이션에서 확인했다). 이 화면의 버튼을 지키는 것은
      // 스크롤이 아니라 **레이아웃이 키보드 위에서 끝난다는 사실**이므로,
      // 스크롤하지 않은 상태의 위치를 그대로 잰다.
      //
      // 실측 여백(iPhone 17 Pro, 한글 키보드 336pt 가정): 버튼 아래끝 362pt,
      // 가시 하한 538pt → **176pt 여유**. Phase 2가 웹처럼 로고 블록
      // (40 + 64 + 55 = 159pt)을 되살려도 17pt가 남아 통과한다. 즉 이 단언이
      // 깨지는 것은 로고보다 더 키울 때이고, 그때 bottomArea로 옮길지
      // 스크롤에 기댈지를 의식적으로 결정하게 만든다.
      // (뮤테이션 확인: 상단 여백 +200 → 562pt로 실패.)
      tester.view.physicalSize = const Size(1206, 2622); // iPhone 17 Pro
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap());

      // iOS 한글 키보드가 대략 가리는 높이.
      tester.view.viewInsets = const FakeViewPadding(bottom: 1008); // 논리 336
      await tester.pumpAndSettle();

      // `AppButton`은 이제 둘이다(로그인·회원가입). 제출 버튼만 잰다.
      final buttonRect = tester.getRect(
        find.byKey(AppButton.backgroundKeyFor('로그인')),
      );
      final visibleBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
          tester.view.viewInsets.bottom / tester.view.devicePixelRatio;

      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(visibleBottom),
        reason: '로그인 버튼이 키보드 영역($visibleBottom pt 아래)에 갇혔다',
      );
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
      //
      // **문구만으로는 못 고른다.** 웹은 같은 문장을 placeholder로도 쓰고
      // (`SignInForm.tsx:57,83`) 이 구현도 그대로 따랐으므로, 빈 입력일 때
      // 화면에는 같은 글자가 둘(placeholder + 에러) 있다. 이전 버전은
      // `findsOneWidget`이라 placeholder가 붙는 순간 깨졌다 — 느슨하게
      // `findsNWidgets(2)`로 바꾸면 유효성 검사가 통째로 빠져도 통과하므로,
      // **에러 색(point)으로 에러 텍스트만 집어** 단언한다.
      expect(_errorText('아이디를 입력해주세요.'), findsOneWidget);
      expect(_errorText('비밀번호를 입력해주세요.'), findsOneWidget);
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

    testWidgets('로그인에 성공하면 토큰과 프로필을 저장한다', (tester) async {
      // **Phase 0에 없던 조각이다.** 그때는 응답을 받고도 버려서
      // `TokenStorage.writeTokens`의 프로덕션 호출부가 0개였고, 그래서
      // "인증 요청이 헤더 없이 나가도 패리티가 통과한다"는 상태였다.
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password1234');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      expect(tokenStorage.writeCount, 1);
      expect(tokenStorage.access, _StubAdapter.accessToken);
      expect(tokenStorage.refresh, _StubAdapter.refreshToken);

      expect(profileStorage.writeCount, 1);
      expect(profileStorage.user?.userId, _StubAdapter.userId);
      expect(authState.isSignedIn, isTrue);
    });

    testWidgets('memberType은 요청한 값이 아니라 응답 값을 따른다', (tester) async {
      // 웹도 `router.replace(`/${data.memberType?.toLowerCase()}`)`로 응답을
      // 쓴다. STUDENT로 요청했는데 계정이 TRAINER면 서버 쪽이 옳다 —
      // 요청 값을 믿으면 반대 역할의 홈으로 보내게 된다.
      adapter.memberType = 'TRAINER';
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password1234');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      expect(authState.user!.memberType, 'TRAINER');
      expect(authState.user!.homeLocation, '/trainer');
    });

    testWidgets('요청이 실패하면 토큰을 저장하지 않는다', (tester) async {
      adapter.statusCode = 401;
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'wrongpassword');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      expect(tokenStorage.writeCount, 0);
      expect(profileStorage.writeCount, 0);
      expect(authState.isSignedIn, isFalse);
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
  /// 성공 응답이 담는 값. 테스트가 "이 값이 저장소까지 갔는가"를 단언할 때
  /// 문자열을 다시 적지 않도록 상수로 둔다.
  static const String accessToken = 'at';
  static const String refreshToken = 'rt';
  static const String userId = 'testuser';

  /// 테스트가 `pumpWidget` 전에 바꿔 실패 경로를 재현한다.
  int statusCode = 200;

  /// 서버가 돌려주는 역할. 요청한 값과 **다르게** 둘 수 있어야 한다 —
  /// 웹이 요청 값이 아니라 응답 값을 따르는 것을 검증하는 자리다.
  String memberType = 'STUDENT';

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
              '{"memberId":1,"name":"홍길동",'
              '"accessToken":"$accessToken","refreshToken":"$refreshToken",'
              '"userId":"$userId","memberType":"$memberType","gymId":7}}'
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
