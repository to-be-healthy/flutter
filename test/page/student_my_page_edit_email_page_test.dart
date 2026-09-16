import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_edit_email_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_plain_input.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> me = _defaultMe();

  /// 실패시킬 경로(부분 일치).
  final Set<String> failingPaths = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (failingPaths.any(path.contains)) {
      return ResponseBody.fromString(
        '{"message":"인증번호가 올바르지 않습니다.","code":"400"}',
        400,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 200,
        'message': '성공',
        'data': options.method.toUpperCase() == 'GET' ? me : true,
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 2026-09-15 실측 응답(`healthy-student0`).
Map<String, dynamic> _defaultMe() => <String, dynamic>{
  'id': 6,
  'userId': 'healthy-student0',
  'email': 'healthy-student0@geonganghaejim.site',
  'name': '차은우',
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'memberType': 'STUDENT',
  'socialType': 'NONE',
};

void main() {
  group('StudentMyPageEditEmailPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
    late AppToastController toast;
    late List<String> navigated;
    late int backCount;

    setUp(() {
      capture = RequestCapture();
      adapter = _StubAdapter();
      dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: FakeTokenStorage(access: 'a', refresh: 'r'),
        extra: <Interceptor>[capture],
      );
      dio.httpClientAdapter = adapter;
      toast = AppToastController();
      navigated = <String>[];
      backCount = 0;
    });

    tearDown(() => toast.dispose());

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(
          child: StudentMyPageEditEmailPage(
            authApi: AuthApi(dio),
            memberApi: MemberApi(dio),
            onNavigate: navigated.add,
            onBack: () => backCount++,
          ),
        ),
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// 1단계를 통과해 2단계까지.
    Future<void> goToStep2(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'new@example.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text('인증 요청'));
      await tester.pumpAndSettle();
    }

    bool isSubmitEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton)).onPressed != null;

    group('요청 1건 — 골든 `mypage-student-edit-email`', () {
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student-edit-email', capture.captured);
      });

      testWidgets('뒤로가기가 동작한다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);
      });
    });

    group('1단계 — 인증 요청', () {
      testWidgets('현재 이메일이 채워져 있고 버튼은 비활성이다', (tester) async {
        await pump(tester);

        expect(
          find.text('healthy-student0@geonganghaejim.site'),
          findsOneWidget,
        );
        expect(find.text('변경하실 이메일을 입력해주세요.'), findsOneWidget);
        // 2단계 문구는 아직 없다.
        expect(find.text('이메일로 발송된 인증번호를 입력해주세요.'), findsNothing);
        expect(isSubmitEnabled(tester), isFalse);
      });

      testWidgets('현재 이메일과 같게 두면 비활성이다', (tester) async {
        await pump(tester);

        await tester.enterText(
          find.byType(TextField),
          'healthy-student0@geonganghaejim.site',
        );
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester), isFalse);
      });

      testWidgets('다른 이메일을 넣으면 활성된다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), 'new@example.com');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester), isTrue);
      });

      // **이 프로젝트에서 토큰 없이 나가는 요청은 여기가 유일하다.**
      // 웹이 `api`(토큰 미주입) 인스턴스를 쓰고, 앱은
      // `AuthInterceptor._publicPaths`의 `/auth/validation/`이 같은 일을 한다.
      testWidgets('인증 메일 요청에는 Authorization이 붙지 않는다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        final send = capture.captured.firstWhere(
          (r) => r.path == AuthApi.sendVerificationCodePath,
        );
        expect(send.method, 'POST');
        expect(send.body, <String, dynamic>{'email': 'new@example.com'});
        expect(
          send.headers.containsKey('authorization'),
          isFalse,
          reason: '웹은 토큰 없는 인스턴스로 보낸다',
        );
        // 반면 첫 조회에는 붙는다.
        expect(
          capture.captured.first.headers.containsKey('authorization'),
          isTrue,
        );
      });

      testWidgets('성공하면 2단계로 간다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        expect(find.text('이메일로 발송된 인증번호를 입력해주세요.'), findsOneWidget);
        expect(find.text('재전송'), findsOneWidget);
        expect(find.text('인증 완료'), findsOneWidget);
        expect(find.text('인증 요청'), findsNothing);
      });

      testWidgets('실패하면 토스트를 띄우고 1단계에 남는다', (tester) async {
        adapter.failingPaths.add(AuthApi.sendVerificationCodePath);

        await pump(tester);
        await tester.enterText(find.byType(TextField), 'new@example.com');
        await tester.pumpAndSettle();
        await tester.tap(find.text('인증 요청'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('인증번호가 올바르지 않습니다.'), findsOneWidget);
        expect(find.text('이메일로 발송된 인증번호를 입력해주세요.'), findsNothing);

        toast.dismiss();
        await tester.pumpAndSettle();
      });
    });

    group('2단계 — 인증 완료', () {
      // **인증번호 칸이 이메일 칸보다 위다**(서베이 BUG-15).
      testWidgets('인증번호 칸이 이메일 칸보다 위에 있다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        final code = tester.getRect(find.text('이메일로 발송된 인증번호를 입력해주세요.'));
        final email = tester.getRect(find.text('변경하실 이메일을 입력해주세요.'));

        expect(
          code.top,
          lessThan(email.top),
          reason: '웹 DOM 순서가 그렇다 — 나중에 생긴 입력이 위로 간다',
        );
      });

      // `disabled`가 아니라 `readOnly`다 — 흐려지지 않는다.
      testWidgets('이메일 칸이 readOnly 로 잠긴다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        final inputs = tester.widgetList<AppPlainInput>(
          find.byType(AppPlainInput),
        );
        expect(inputs.length, 2);
        // 첫 번째가 인증번호(위), 두 번째가 이메일이다.
        expect(inputs.first.readOnly, isFalse);
        expect(inputs.last.readOnly, isTrue);
      });

      testWidgets('인증번호를 넣기 전에는 버튼이 비활성이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        expect(isSubmitEnabled(tester), isFalse);
      });

      testWidgets('PATCH 로 email 과 emailKey 를 보낸다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        await tester.enterText(find.byType(TextField).first, '123456');
        await tester.pumpAndSettle();
        await tester.tap(find.text('인증 완료'));
        await tester.pumpAndSettle();

        final change = capture.captured.last;
        expect(change.method, 'PATCH');
        expect(change.path, MemberApi.emailPath);
        // **키 이름이 계약이다** — `code`가 아니라 `emailKey`.
        expect(change.body, <String, dynamic>{
          'email': 'new@example.com',
          'emailKey': '123456',
        });
        expect(change.headers.containsKey('authorization'), isTrue);
      });

      testWidgets('성공하면 내 정보로 간다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        await tester.enterText(find.byType(TextField).first, '123456');
        await tester.pumpAndSettle();
        await tester.tap(find.text('인증 완료'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/student/mypage/info']);
      });

      testWidgets('실패하면 토스트를 띄우고 남는다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        adapter.failingPaths.add(MemberApi.emailPath);

        await tester.enterText(find.byType(TextField).first, '000000');
        await tester.pumpAndSettle();
        await tester.tap(find.text('인증 완료'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('인증번호가 올바르지 않습니다.'), findsOneWidget);
        expect(navigated, isEmpty);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      testWidgets('재전송은 같은 요청을 한 번 더 보낸다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        final before = capture.captured.length;

        await tester.tap(find.text('재전송'));
        await tester.pumpAndSettle();

        expect(capture.captured.length, before + 1);
        expect(capture.captured.last.path, AuthApi.sendVerificationCodePath);
      });

      // 웹이 콜백을 하나도 넘기지 않는다(서베이 BUG-14) —
      // **성공도 실패도 알리지 않는다.**
      testWidgets('재전송이 실패해도 토스트가 없다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        adapter.failingPaths.add(AuthApi.sendVerificationCodePath);

        await tester.tap(find.text('재전송'));
        await settleWithoutDismissingToast(tester);

        expect(toast.current, isNull, reason: '웹 재전송에는 onError 가 없다');
        expect(tester.takeException(), isNull);
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값(규율 #15).
    // 기댓값은 리터럴로 쓴다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      testWidgets('1단계 입력 상자는 52다', (tester) async {
        await pump(tester);

        expect(tester.getSize(find.byType(AppPlainInput)).height, 52);
      });

      // **옆의 재전송 버튼(56)이 행 높이를 끌어올린다.** 상자 클래스만
      // 읽으면 52로 틀린다.
      testWidgets('2단계 인증번호 상자는 56이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        final code = find.byType(AppPlainInput).first;
        expect(tester.getSize(code).height, 56);
        // 아래 이메일 칸은 여전히 52다.
        expect(tester.getSize(find.byType(AppPlainInput).last).height, 52);
      });

      testWidgets('재전송 버튼은 56이고 gray700이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        final button = find.ancestor(
          of: find.text('재전송'),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        expect(tester.getSize(button.first).height, 56);

        final decoration =
            tester.widget<Container>(button.first).decoration! as BoxDecoration;
        expect(decoration.color, AppColors.light.gray700);
      });

      // 웹 `gap-2`는 커스텀 스케일이라 **6**이다(Tailwind 기본 8이 아니다).
      testWidgets('인증번호 칸과 재전송 사이가 6이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        final code = tester.getRect(find.byType(AppPlainInput).first);
        final button = tester.getRect(
          find
              .ancestor(
                of: find.text('재전송'),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.decoration is BoxDecoration,
                ),
              )
              .first,
        );

        expect(button.left - code.right, 6);
      });

      testWidgets('제출 버튼 높이가 56이다', (tester) async {
        await pump(tester);

        expect(tester.getSize(find.byType(AppButton)).height, 56);
      });
    });

    group('폰 너비(390pt)', () {
      testWidgets('두 단계 다 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pump(tester);
        expect(tester.takeException(), isNull);

        await goToStep2(tester);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
