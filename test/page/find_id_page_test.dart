import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/entity/auth/ui/social_icon.dart';
import 'package:geonganghaejim/page/public/find_id_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

/// 아이디 찾기 골든 픽스처의 계약.
///
/// `test/fixtures/requests/find-id.json`은 `tool/har_to_golden.py`가
/// `har/find-id.har`에서 생성한다 — 2026-09-14, geonganghaejim.site의
/// `/find/id` 화면을 **로그인 없이** 열어 캡처했다.
///
/// 1. `name`은 `kMaskedKeys`에 **없어 값까지 대조된다.** 캡처에 쓴 값이
///    `'홍길동'`이라 아래 테스트도 같은 이름을 입력한다. 재캡처할 때 다른
///    이름을 쓰면 이 테스트가 먼저 깨진다 — 그때 테스트를 고치지 말고
///    같은 이름으로 다시 뜨거나 양쪽을 함께 바꿔라.
/// 2. `email`은 마스킹되므로 값이 달라도 통과한다. 다만 폼이
///    `EMAIL_REGEXP`를 통과해야 제출 버튼이 활성화되므로 형식은 맞아야 한다.
/// 3. `Authorization`은 양쪽 모두 없다. 웹은 토큰 없는 `api` 인스턴스를 쓰고
///    (`mutations.ts`), 실제 캡처에도 그 헤더가 없다. 앱 쪽은
///    `AuthInterceptor._publicPaths`의 `/auth/find/`가 같은 일을 한다.
/// 4. 캡처 계정은 없다 — 예약 도메인(`example.com`)으로 보내 서버가 404를
///    돌려준 요청이다. **요청의 모양만** 쓰는 골든이라 응답 실패는 무관하다.
void main() {
  group('FindIdPage', () {
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

    // 로그인 화면과 같은 패리티 경계다 — 라우터를 끼우지 않는다.
    // 닫기(X) 동작은 `context.canPop()`을 타므로 라우터가 있는
    // `app_test.dart`에서 확인한다.
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(child: FindIdPage(authApi: AuthApi(dio))),
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

    Color backgroundOf(WidgetTester tester, String label) {
      final container = tester.widget<Container>(
        find.byKey(AppButton.backgroundKeyFor(label)),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    group('폼', () {
      testWidgets('제목·두 라벨·플레이스홀더를 보여준다', (tester) async {
        await tester.pumpWidget(wrap());

        expect(find.text('아이디 찾기'), findsOneWidget);
        expect(find.text('이름을 입력해주세요.'), findsOneWidget);
        expect(find.text('가입한 이메일 주소를 입력해주세요.'), findsOneWidget);
        expect(find.text('이름 입력'), findsOneWidget);
        expect(find.text('이메일 주소 입력'), findsOneWidget);
      });

      testWidgets('헤더에 닫기만 있고 뒤로가기는 없다', (tester) async {
        // 웹 헤더는 `justify-end` + `IconClose` 하나뿐이다.
        //
        // 뮤테이션: `AppLayoutHeader`의 `automaticallyImplyLeading: false`를
        // 지우면 스택이 있는 화면에서 Material 기본 뒤로가기가 끼어든다.
        await tester.pumpWidget(wrap());

        expect(find.byType(IconButton), findsOneWidget);
        // `BackButton`은 AppBar가 `automaticallyImplyLeading`으로 **스스로**
        // 끼워 넣는 위젯이다. 우리가 만드는 뒤로가기는 SVG를 담은 평범한
        // `IconButton`이라 이 타입에 걸리지 않는다 — 침입만 정확히 잡는다.
        expect(find.byType(BackButton), findsNothing);
      });

      testWidgets('첫 화면에서 제출 버튼이 비활성이다', (tester) async {
        // 웹 `disabled={!isValid}` + `mode: 'onChange'` — 아무것도 입력하지
        // 않은 상태에서 `isValid`는 false다.
        //
        // 뮤테이션: `onPressed`를 무조건 `_submit`으로 바꾸면 배경이
        // primary500이 되어 깨진다.
        await tester.pumpWidget(wrap());

        expect(backgroundOf(tester, '이메일 전송하기'), AppColors.light.gray300);
      });

      testWidgets('비활성 상태에서 눌러도 요청이 나가지 않는다', (tester) async {
        await tester.pumpWidget(wrap());

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(capture.captured, isEmpty);
      });

      testWidgets('두 필드가 모두 유효해지는 순간 활성으로 바뀐다', (tester) async {
        await tester.pumpWidget(wrap());

        await tester.enterText(find.byType(TextField).first, '홍길동');
        await tester.pump();
        expect(
          backgroundOf(tester, '이메일 전송하기'),
          AppColors.light.gray300,
          reason: '이메일이 아직 비어 있으면 여전히 비활성이다',
        );

        await tester.enterText(
          find.byType(TextField).last,
          'parity-harness@example.com',
        );
        await tester.pump();

        expect(backgroundOf(tester, '이메일 전송하기'), AppColors.light.primary500);
      });

      testWidgets('이름을 치는 동안 이메일 에러는 뜨지 않는다', (tester) async {
        // 웹 RHF는 `errors`를 **변경된 필드에만** 채운다. 폼 전체 검증은
        // `isValid`(버튼 활성 여부)에만 쓰인다.
        await tester.pumpWidget(wrap());

        await tester.enterText(find.byType(TextField).first, '홍길동');
        await tester.pump();

        expect(find.text('이메일을 입력해주세요.'), findsNothing);
      });

      testWidgets('이름에 숫자를 넣으면 웹과 같은 문구가 뜬다', (tester) async {
        // 웹 `NAME_REGEXP = /^[가-힣a-zA-Z]+$/`.
        // 마침표가 없는 것도 웹 문구 그대로다.
        await tester.pumpWidget(wrap());

        await tester.enterText(find.byType(TextField).first, '홍길동1');
        await tester.pump();

        expect(find.text('한글 또는 영문만 입력해주세요'), findsOneWidget);
        expect(backgroundOf(tester, '이메일 전송하기'), AppColors.light.gray300);
      });

      testWidgets('이름을 지우면 필수 문구로 바뀐다', (tester) async {
        await tester.pumpWidget(wrap());

        await tester.enterText(find.byType(TextField).first, '홍길동');
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pump();

        expect(find.text('이름을 입력해주세요.'), findsNWidgets(2));
      });

      testWidgets('이메일 형식이 틀리면 웹과 같은 문구가 뜬다', (tester) async {
        await tester.pumpWidget(wrap());

        await tester.enterText(find.byType(TextField).last, 'not-an-email');
        await tester.pump();

        expect(find.text('이메일 형식이 아닙니다.'), findsOneWidget);
      });
    });

    group('키보드', () {
      // **이 두 화면이 `AppLayout.bottomArea`에 상호작용 컨트롤을 넣은 첫
      // 화면이다.** 로그인 화면의 제출 버튼은 `contents` 안에 있어서
      // 기존 키보드 테스트(`sign_in_page_test.dart`)가 재는 것은 Scaffold의
      // **body** 경로다. `bottomNavigationBar`는 규칙이 완전히 다르다 —
      // `_ScaffoldLayout`이 그 자리를 `size.height` 기준으로 잡아 키보드를
      // 피해 저절로 떠오르지 않는다. `AppLayout`이 `viewInsets.bottom`을
      // 패딩으로 직접 더해 보정하는데, 그 보정이 실제로 일하는지(또는
      // 이중 계산인지) 확인하는 테스트가 없었다.
      const double keyboardInset = 300;

      /// 실기기와 같은 논리 크기(iPhone 17 Pro, 402x874). 기본 테스트 표면
      /// (800x600)은 키보드를 띄우면 본문이 434pt가 아니라 160pt만 남아,
      /// "필드가 보이는가"가 화면 크기 탓인지 버그 탓인지 구분되지 않는다.
      void useDeviceSizedSurface(WidgetTester tester) {
        tester.view.physicalSize = const Size(1206, 2622);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
      }

      Widget wrapWithKeyboard() => MaterialApp(
        theme: AppTheme.light(),
        // `MaterialApp`이 뷰로부터 자기 `MediaQuery`를 만들어 바깥 것을
        // 덮으므로, 주입은 반드시 **안쪽**에서 해야 한다.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: keyboardInset),
            ),
            child: AppToastScope(
              notifier: toast,
              child: AppToastHost(child: FindIdPage(authApi: AuthApi(dio))),
            ),
          ),
        ),
      );

      testWidgets('키보드가 올라와도 제출 버튼이 가려지지 않는다', (tester) async {
        // 뮤테이션: `AppLayout`의
        // `+ EdgeInsets.only(bottom: keyboardInset)`를 지우면 버튼이
        // 키보드 아래로 내려간다.
        useDeviceSizedSurface(tester);
        await tester.pumpWidget(wrapWithKeyboard());

        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final button = tester.getRect(
          find.byKey(AppButton.backgroundKeyFor('이메일 전송하기')),
        );

        expect(
          button.bottom,
          lessThanOrEqualTo(screenHeight - keyboardInset),
          reason:
              '버튼 아래끝 ${button.bottom} vs 가시 하한 '
              '${screenHeight - keyboardInset}',
        );
      });

      testWidgets('키보드가 올라와도 이메일 입력이 보인다', (tester) async {
        // 하단 영역이 키보드 높이만큼 두꺼워지면 본문 슬롯이 그만큼 줄어든다.
        // 사용자가 마지막으로 치는 필드가 두 번째 입력이라, 버튼만 떠 있고
        // 입력이 가려지면 화면이 쓸모없어진다.
        useDeviceSizedSurface(tester);
        await tester.pumpWidget(wrapWithKeyboard());

        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final emailField = tester.getRect(find.byType(TextField).last);

        expect(
          emailField.bottom,
          lessThanOrEqualTo(screenHeight - keyboardInset),
          reason:
              '이메일 입력 아래끝 ${emailField.bottom} vs 가시 하한 '
              '${screenHeight - keyboardInset}',
        );
      });
    });

    group('제출', () {
      testWidgets('요청이 웹과 동일한 형태로 나간다 (패리티)', (tester) async {
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expectParity('find-id', capture.captured);
      });

      testWidgets('공개 경로라 Authorization을 붙이지 않는다', (tester) async {
        // `AuthInterceptor._publicPaths`의 `/auth/find/`가 실제로 이 경로에
        // 걸리는지 확인한다 — 실측 HAR에도 이 헤더가 없다.
        final tokenBackedDio = DioClient.create(
          baseUrl: 'https://example.test',
          // 붙일 토큰이 "있는" 상태여야 헤더가 안 붙는 것이 의미를 가진다.
          storage: FakeTokenStorage(access: 'a', refresh: 'r'),
          extra: [capture],
        );
        tokenBackedDio.httpClientAdapter = adapter;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: AppToastScope(
              notifier: toast,
              child: AppToastHost(
                child: FindIdPage(authApi: AuthApi(tokenBackedDio)),
              ),
            ),
          ),
        );
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(
          capture.captured.single.headers.containsKey('authorization'),
          isFalse,
        );
      });

      testWidgets('실패하면 서버 메시지를 토스트로 띄운다', (tester) async {
        // 웹 `onError: errorToast(error?.response?.data.message)`.
        // 이 화면은 에러를 인라인 텍스트로 그리지 않는다.
        adapter.statusCode = 404;
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.text('회원이 존재하지 않습니다.'), findsOneWidget);
        expect(find.text('아이디 찾기'), findsOneWidget, reason: '폼에 그대로 머문다');

        toast.dismiss();
      });
    });

    group('결과 · 일반 가입', () {
      testWidgets('마스킹된 아이디와 가입일자를 보여준다', (tester) async {
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.text('hea***ent0'), findsOneWidget);
        // 웹 `dayjs(createdAt).format('YYYY.MM.DD')`.
        expect(find.text('가입일자: 2024.03.15'), findsOneWidget);
        expect(find.text('개인정보보호를 위해 아이디 중 일부는 *로 표기됩니다.'), findsOneWidget);
      });

      testWidgets('버튼 문구가 로그인 하기로 바뀐다', (tester) async {
        // 아이디 찾기의 일반 분기만 '로그인 하기'다(나머지 셋은 '완료').
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.text('로그인 하기'), findsOneWidget);
        expect(find.text('이메일 전송하기'), findsNothing);
        expect(
          backgroundOf(tester, '로그인 하기'),
          AppColors.light.primary500,
          reason: '결과 화면의 버튼에는 disabled가 없다',
        );
      });

      testWidgets('가입일자를 못 읽으면 그 줄만 비운다', (tester) async {
        // 웹은 `dayjs(undefined)`가 "Invalid Date"를 그린다. 아이디를
        // 보여주는 것이 이 화면의 목적이라 날짜 때문에 죽거나 쓰레기 문구를
        // 띄우지 않는다.
        adapter.createdAt = null;
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.text('hea***ent0'), findsOneWidget);
        expect(find.textContaining('가입일자'), findsNothing);
      });
    });

    group('결과 · 소셜 가입', () {
      testWidgets('소셜 아이콘과 안내 문구를 보여준다', (tester) async {
        adapter.socialType = 'KAKAO';
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.byType(AppSocialIcon), findsOneWidget);
        // 웹도 응답이 아니라 폼의 현재 값(`watch('email')`)을 쓴다.
        expect(
          find.textContaining('parity-harness@example.com'),
          findsOneWidget,
        );
        expect(find.textContaining('카카오 계정으로 가입되어 있습니다.'), findsOneWidget);
        expect(find.text('완료'), findsOneWidget);
      });

      testWidgets('아이디 카드는 그리지 않는다', (tester) async {
        adapter.socialType = 'NAVER';
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(find.text('개인정보보호를 위해 아이디 중 일부는 *로 표기됩니다.'), findsNothing);
        expect(find.text('로그인 하기'), findsNothing);
      });
    });

    group('AppSocialIcon', () {
      testWidgets('모르는 소셜 타입이 와도 화면이 죽지 않는다', (tester) async {
        // 웹은 `socialProviders[socialType]`을 무조건 찾아 써서 런타임에
        // 터진다. 백엔드에 제공자가 추가되면 앱 업데이트 전까지 그 값이
        // 내려올 수 있다.
        adapter.socialType = 'LINE';
        await tester.pumpWidget(wrap());
        await fillValidForm(tester);

        await tester.tap(find.text('이메일 전송하기'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AppSocialIcon), findsOneWidget);
        // 헤더의 닫기(X)도 SvgPicture라 범위를 아이콘 안으로 좁힌다.
        expect(
          find.descendant(
            of: find.byType(AppSocialIcon),
            matching: find.byType(SvgPicture),
          ),
          findsNothing,
        );
        expect(find.text('완료'), findsOneWidget);
      });
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  int statusCode = 200;
  String socialType = 'NONE';
  String? createdAt = '2024-03-15T10:20:30';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final createdAtJson = createdAt == null ? 'null' : '"$createdAt"';
    final body = statusCode == 200
        ? '{"status":"success","message":"조회 성공","data":'
              '{"userId":"hea***ent0","createdAt":$createdAtJson,'
              '"socialType":"$socialType"}}'
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
