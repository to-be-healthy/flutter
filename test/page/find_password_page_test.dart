import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/entity/auth/ui/social_icon.dart';
import 'package:geonganghaejim/page/public/find_password_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';

/// 비밀번호 찾기 골든 픽스처의 계약.
///
/// `test/fixtures/requests/find-password.json`은 `har/find-password.har`에서
/// 생성한다. 조건은 아이디 찾기 골든과 같다(`find_id_page_test.dart`의 주석
/// 참고) — `name`은 값까지 대조되고 `email`은 마스킹되며 `Authorization`은
/// 양쪽 모두 없다.
///
/// **두 골든을 바꿔 쓰면 경로 불일치로 떨어진다.** 본문은 완전히 같고
/// (`{name, email}`) 경로만 `find/user-id` vs `find/password`다 — 이 한
/// 글자가 두 골든을 구별하는 전부다.
///
/// **재캡처 주의:** 실존 계정으로 이 요청을 보내면 그 계정의 비밀번호가
/// 실제로 초기화된다. 캡처는 예약 도메인(`example.com`)으로만 해야 한다.
void main() {
  group('FindPasswordPage', () {
    late RequestCapture capture;
    late Dio dio;
    late _StubAdapter adapter;
    late AppToastController toast;

    setUp(() {
      capture = RequestCapture();
      dio = DioClient.create(baseUrl: 'https://example.test', extra: [capture]);
      adapter = _StubAdapter();
      dio.httpClientAdapter = adapter;
      toast = AppToastController();
    });

    tearDown(() => toast.dispose());

    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(child: FindPasswordPage(authApi: AuthApi(dio))),
      ),
    );

    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, '홍길동');
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).last,
        'parity-harness@example.com',
      );
      await tester.pump();
    }

    testWidgets('제목과 아이디 찾기에 없는 안내문을 보여준다', (tester) async {
      // 웹 `<p className='pt-12 text-gray-500'>` — `FindIdPage`에는 없는
      // 한 줄이고, 두 화면의 폼을 가르는 유일한 차이다.
      await tester.pumpWidget(wrap());

      expect(find.text('비밀번호 찾기'), findsOneWidget);
      expect(find.text('가입하신 이메일 주소로 초기화된 비밀번호를 보내드립니다.'), findsOneWidget);
    });

    testWidgets('첫 화면에서 제출 버튼이 비활성이다', (tester) async {
      await tester.pumpWidget(wrap());

      final container = tester.widget<Container>(
        find.byKey(AppButton.backgroundKeyFor('이메일 전송하기')),
      );

      expect(
        (container.decoration! as BoxDecoration).color,
        AppColors.light.gray300,
      );
    });

    testWidgets('요청이 웹과 동일한 형태로 나간다 (패리티)', (tester) async {
      await tester.pumpWidget(wrap());
      await fillValidForm(tester);

      await tester.tap(find.text('이메일 전송하기'));
      await tester.pumpAndSettle();

      expectParity('find-password', capture.captured);
    });

    testWidgets('아이디 찾기 골든과 바꿔 쓰면 경로에서 걸린다', (tester) async {
      // 골든이 공허하게 통과하지 않는다는 증거다. 두 요청의 본문이 완전히
      // 같아서, 경로를 대조하지 않으면 이 테스트가 통과해 버린다.
      await tester.pumpWidget(wrap());
      await fillValidForm(tester);

      await tester.tap(find.text('이메일 전송하기'));
      await tester.pumpAndSettle();

      expect(
        () => expectParity('find-id', capture.captured),
        throwsA(isA<ParityFailure>()),
      );
    });

    testWidgets('실패하면 서버 메시지를 토스트로 띄운다', (tester) async {
      adapter.statusCode = 404;
      await tester.pumpWidget(wrap());
      await fillValidForm(tester);

      await tester.tap(find.text('이메일 전송하기'));
      await tester.pumpAndSettle();

      expect(find.text('회원이 존재하지 않습니다.'), findsOneWidget);

      toast.dismiss();
    });

    group('결과 · 일반 가입', () {
      testWidgets('발송 안내와 완료 버튼을 보여준다', (tester) async {
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        // 웹도 응답이 아니라 폼의 현재 값(`watch('email')`)을 쓴다 —
        // 이 응답에는 이메일이 아예 없다(`Pick<..., 'socialType'>`).
        expect(
          find.textContaining('parity-harness@example.com'),
          findsOneWidget,
        );
        expect(find.textContaining('으로 초기화된 비밀번호가 발송되었습니다.'), findsOneWidget);
        // 아이디 찾기와 달리 이쪽은 '완료'다.
        expect(find.text('완료'), findsOneWidget);
        expect(find.text('로그인 하기'), findsNothing);
      });

      testWidgets('소셜 아이콘이 아니라 편지 아이콘을 쓴다', (tester) async {
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSocialIcon), findsNothing);
      });
    });

    group('결과 · 소셜 가입', () {
      testWidgets('소셜 안내로 갈린다', (tester) async {
        adapter.socialType = 'NAVER';
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSocialIcon), findsOneWidget);
        expect(find.textContaining('네이버 계정으로 가입되어 있습니다.'), findsOneWidget);
        expect(
          find.textContaining('초기화된 비밀번호가 발송되었습니다.'),
          findsNothing,
          reason: '소셜 계정에는 비밀번호를 보내지 않는다',
        );
        expect(find.text('완료'), findsOneWidget);
      });
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  int statusCode = 200;
  String socialType = 'NONE';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = statusCode == 200
        ? '{"status":"success","message":"발송 성공","data":'
              '{"socialType":"$socialType"}}'
        : '{"message":"회원이 존재하지 않습니다.","code":"400"}';

    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
