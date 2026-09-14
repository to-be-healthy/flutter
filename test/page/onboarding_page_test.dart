import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/entity/auth/model/auth_state.dart';
import 'package:geonganghaejim/entity/auth/ui/auth_scope.dart';
import 'package:geonganghaejim/page/public/onboarding_page.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

void main() {
  group('OnboardingPage', () {
    late RequestCapture capture;
    late Dio dio;
    late _StubAdapter adapter;
    late FakeTokenStorage tokenStorage;
    late FakeAuthProfileStorage profileStorage;
    late AuthState authState;

    setUp(() {
      capture = RequestCapture();
      dio = DioClient.create(baseUrl: 'https://example.test', extra: [capture]);
      adapter = _StubAdapter();
      dio.httpClientAdapter = adapter;

      tokenStorage = FakeTokenStorage();
      profileStorage = FakeAuthProfileStorage();
      authState = AuthState(tokenStorage, profileStorage);
    });

    // 로그인 화면과 같은 패리티 경계다 — 라우터를 끼우지 않는다.
    // 여기서 검증하는 것은 "체험하기가 웹과 같은 요청을 보내는가"까지이고,
    // 성공 후 홈으로 가는 이동과 홈이 쏘는 요청은 홈 화면의 몫이다.
    Widget wrap({String? memberType}) => MaterialApp(
      theme: AppTheme.light(),
      home: AuthScope(
        notifier: authState,
        child: OnboardingPage(authApi: AuthApi(dio), memberType: memberType),
      ),
    );

    group('역할 선택 (웹 `/`, 쿼리 없음)', () {
      testWidgets('로고·인사말·역할 버튼 두 개를 보여준다', (tester) async {
        await tester.pumpWidget(wrap());

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('안녕하세요!\n건강해짐입니다!'), findsOneWidget);
        expect(find.text('트레이너로 시작'), findsOneWidget);
        expect(find.text('회원으로 시작'), findsOneWidget);
      });

      testWidgets('헤더에 뒤로가기가 없다', (tester) async {
        // 웹 `<Layout.Header />`는 자식이 없어 56px 자리만 잡는다.
        // 첫 화면이라 돌아갈 곳도 없다.
        await tester.pumpWidget(wrap());

        expect(find.byType(IconButton), findsNothing);
      });

      testWidgets('요청을 보내지 않는다', (tester) async {
        await tester.pumpWidget(wrap());

        expect(capture.captured, isEmpty);
      });
    });

    group('로그인 수단 선택 (웹 `/?type=`)', () {
      testWidgets('제목과 두 링크, 고객센터를 보여준다', (tester) async {
        await tester.pumpWidget(wrap(memberType: 'student'));

        expect(find.text('차별화된 PT 서비스를\n경험해보세요!'), findsOneWidget);
        expect(find.text('아이디 로그인'), findsOneWidget);
        expect(find.text('체험하기'), findsOneWidget);
        expect(find.text('건강해짐 고객센터'), findsOneWidget);
      });

      testWidgets('헤더에 뒤로가기가 있다', (tester) async {
        await tester.pumpWidget(wrap(memberType: 'student'));

        expect(find.byType(IconButton), findsOneWidget);
      });

      testWidgets('체험하기 요청이 웹과 동일한 형태로 나간다 (패리티)', (tester) async {
        // 웹 "체험하기"를 실제로 눌러 캡처한 HAR에서 생성한 골든과 대조한다.
        // 폼 로그인 골든(`login`)과 **딱 한 키가 다르다**:
        // `complimentaryLogin: true`. 두 골든을 나란히 두는 이유가 그것이다.
        await tester.pumpWidget(wrap(memberType: 'student'));

        await tester.tap(find.text('체험하기'));
        await tester.pumpAndSettle();

        expectParity('login-complimentary', capture.captured);
      });

      testWidgets('트레이너면 트레이너 데모 계정으로 보낸다', (tester) async {
        // `userId`는 `kMaskedKeys`라 골든이 값을 대조하지 않는다 —
        // 역할별로 다른 계정을 쓰는지는 여기서만 잡힌다.
        await tester.pumpWidget(wrap(memberType: 'trainer'));

        await tester.tap(find.text('체험하기'));
        await tester.pumpAndSettle();

        final body = capture.captured.single.body! as Map<String, dynamic>;
        expect(body['userId'], 'healthy-trainer0');
        expect(body['memberType'], 'TRAINER');
        expect(body['complimentaryLogin'], isTrue);
      });

      testWidgets('체험하기에 성공하면 토큰과 프로필을 저장한다', (tester) async {
        await tester.pumpWidget(wrap(memberType: 'student'));

        await tester.tap(find.text('체험하기'));
        await tester.pumpAndSettle();

        expect(tokenStorage.writeCount, 1);
        expect(profileStorage.writeCount, 1);
        expect(authState.isSignedIn, isTrue);
      });

      testWidgets('체험하기가 실패하면 서버 메시지를 보여주고 저장하지 않는다', (tester) async {
        adapter.statusCode = 401;
        await tester.pumpWidget(wrap(memberType: 'student'));

        await tester.tap(find.text('체험하기'));
        await tester.pumpAndSettle();

        expect(find.text('체험 계정을 사용할 수 없습니다.'), findsOneWidget);
        expect(tokenStorage.writeCount, 0);
        expect(authState.isSignedIn, isFalse);
      });
    });
  });
}

/// 네트워크 없이 고정 응답을 주는 어댑터.
class _StubAdapter implements HttpClientAdapter {
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = statusCode == 200
        ? '{"status":"success","message":"로그인 성공","data":'
              '{"memberId":6,"name":"체험","accessToken":"at","refreshToken":"rt",'
              '"userId":"healthy-student0","memberType":"STUDENT","gymId":1}}'
        : '{"status":"fail","message":"체험 계정을 사용할 수 없습니다.","data":null}';

    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
