import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_edit_password_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  /// 확인 요청의 `data` 값. 웹이 `if (data)`로 가드하는 자리다.
  bool verified = true;

  /// 실패시킬 메서드(`POST` = 확인, `PATCH` = 변경).
  final Set<String> failingMethods = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    if (failingMethods.contains(method)) {
      return ResponseBody.fromString(
        '{"message":"비밀번호가 일치하지 않습니다.","code":"400"}',
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
        'data': method == 'POST' ? verified : true,
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

void main() {
  group('StudentMyPageEditPasswordPage', () {
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
          child: StudentMyPageEditPasswordPage(
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
      await tester.enterText(find.byType(TextField), 'current-pass');
      await tester.pumpAndSettle();
      await tester.tap(find.text('비밀번호 확인'));
      await tester.pumpAndSettle();
    }

    bool isSubmitEnabled(WidgetTester tester, String label) =>
        tester.widget<AppButton>(find.byType(AppButton)).onPressed != null &&
        find.text(label).evaluate().isNotEmpty;

    group('진입 — 요청이 없다', () {
      testWidgets('마운트 시 아무 요청도 보내지 않는다', (tester) async {
        await pump(tester);

        expect(capture.captured, isEmpty);
      });

      testWidgets('1단계 문구와 입력 하나를 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('현재 비밀번호를 입력해주세요.'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('비밀번호'), findsOneWidget);
        // 2단계 문구는 아직 없다.
        expect(find.text('새로운 비밀번호를 입력해주세요.'), findsNothing);
      });

      testWidgets('뒤로가기가 동작한다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);
      });

      testWidgets('비밀번호 찾기로 갈 수 있다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('비밀번호 찾기'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/find/pw']);
        expect(capture.captured, isEmpty);
      });
    });

    group('1단계 — 현재 비밀번호 확인', () {
      // 웹 `disabled={!password}`.
      testWidgets('입력 전에는 버튼이 비활성이다', (tester) async {
        await pump(tester);

        expect(isSubmitEnabled(tester, '비밀번호 확인'), isFalse);

        await tester.tap(find.text('비밀번호 확인'));
        await tester.pumpAndSettle();

        expect(capture.captured, isEmpty);
      });

      testWidgets('입력하면 버튼이 활성된다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), 'a');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester, '비밀번호 확인'), isTrue);
      });

      // **골든이 없는 요청이라 여기가 유일한 계약이다.**
      testWidgets('POST 로 비밀번호를 보낸다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        expect(capture.captured.length, 1);
        final request = capture.captured.single;
        expect(request.method, 'POST');
        expect(request.path, MemberApi.passwordPath);
        expect(request.body, <String, dynamic>{'password': 'current-pass'});
        expect(request.headers.containsKey('authorization'), isTrue);
      });

      testWidgets('성공하면 2단계로 간다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        expect(find.text('새로운 비밀번호를 입력해주세요.'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('비밀번호 변경하기'), findsOneWidget);
        // 1단계의 힌트는 2단계에 없다.
        expect(find.text('비밀번호 찾기'), findsNothing);
      });

      // 웹 `if (data) setStep(2)` — false면 **아무 일도 일어나지 않는다.**
      testWidgets('data 가 false면 아무 안내 없이 1단계에 남는다', (tester) async {
        adapter.verified = false;

        await pump(tester);
        await goToStep2(tester);

        expect(find.text('현재 비밀번호를 입력해주세요.'), findsOneWidget);
        expect(find.text('새로운 비밀번호를 입력해주세요.'), findsNothing);
        // 토스트도 없다 — 웹에 그 분기가 없다.
        expect(find.text('비밀번호가 일치하지 않습니다.'), findsNothing);
      });

      testWidgets('실패하면 서버 메시지를 띄운다', (tester) async {
        adapter.failingMethods.add('POST');

        await pump(tester);
        await tester.enterText(find.byType(TextField), 'wrong-pass');
        await tester.pumpAndSettle();
        await tester.tap(find.text('비밀번호 확인'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
        expect(find.text('새로운 비밀번호를 입력해주세요.'), findsNothing);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      // **웹 버그를 그대로 옮겼다.** `setPassword('')`는 상태만 비우고
      // 비제어 입력창의 글자는 그대로 남긴다 — 글자가 보이는데 버튼이 꺼진다.
      testWidgets('실패하면 글자는 남고 버튼만 비활성이 된다', (tester) async {
        adapter.failingMethods.add('POST');

        await pump(tester);
        await tester.enterText(find.byType(TextField), 'wrong-pass');
        await tester.pumpAndSettle();
        await tester.tap(find.text('비밀번호 확인'));
        await settleWithoutDismissingToast(tester);

        expect(
          find.text('wrong-pass'),
          findsOneWidget,
          reason: '입력창의 글자는 지워지지 않는다',
        );
        expect(
          isSubmitEnabled(tester, '비밀번호 확인'),
          isFalse,
          reason: '상태는 비워져 버튼이 꺼진다',
        );

        toast.dismiss();
        await tester.pumpAndSettle();
      });
    });

    group('2단계 — 새 비밀번호', () {
      Future<void> enterNew(
        WidgetTester tester,
        String newPassword,
        String confirm,
      ) async {
        await tester.enterText(find.byType(TextField).at(0), newPassword);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), confirm);
        await tester.pumpAndSettle();
      }

      testWidgets('둘 다 비어 있으면 버튼이 비활성이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        expect(isSubmitEnabled(tester, '비밀번호 변경하기'), isFalse);
      });

      testWidgets('하나만 채우면 여전히 비활성이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);

        await tester.enterText(find.byType(TextField).at(0), 'newpass123');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester, '비밀번호 변경하기'), isFalse);
      });

      testWidgets('두 값이 다르면 비활성이다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        await enterNew(tester, 'newpass123', 'newpass124');

        expect(isSubmitEnabled(tester, '비밀번호 변경하기'), isFalse);
      });

      testWidgets('두 값이 같으면 활성된다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        await enterNew(tester, 'newpass123', 'newpass123');

        expect(isSubmitEnabled(tester, '비밀번호 변경하기'), isTrue);
      });

      // **길이·형식 검증은 화면에 없다.** 플레이스홀더가 "8자리 이상"이라
      // 말하지만 확인하지 않는다 — 웹 그대로다.
      testWidgets('8자 미만이어도 버튼이 활성된다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        await enterNew(tester, 'ab', 'ab');

        expect(isSubmitEnabled(tester, '비밀번호 변경하기'), isTrue);
      });

      testWidgets('PATCH 로 두 값을 보낸다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        await enterNew(tester, 'newpass123', 'newpass123');

        await tester.tap(find.text('비밀번호 변경하기'));
        await tester.pumpAndSettle();

        expect(capture.captured.length, 2);
        final request = capture.captured.last;
        expect(request.method, 'PATCH');
        expect(request.path, MemberApi.passwordPath);
        // **키 이름이 계약이다** — 서버 `CommandChangeMemberPassword`.
        expect(request.body, <String, dynamic>{
          'changePassword1': 'newpass123',
          'changePassword2': 'newpass123',
        });
      });

      // 웹 `router.replace('../info')` + `//TODO: SUCCESS TOAST`.
      testWidgets('성공하면 내 정보로 가고 토스트는 없다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        await enterNew(tester, 'newpass123', 'newpass123');

        await tester.tap(find.text('비밀번호 변경하기'));
        await settleWithoutDismissingToast(tester);

        expect(navigated, <String>['/student/mypage/info']);
        // 토스트 컨트롤러가 아무 메시지도 들고 있지 않아야 한다.
        expect(toast.current, isNull, reason: '웹은 성공 토스트를 //TODO 로 남겨 뒀다');
      });

      testWidgets('실패하면 서버 메시지를 띄우고 2단계에 남는다', (tester) async {
        await pump(tester);
        await goToStep2(tester);
        adapter.failingMethods.add('PATCH');
        await enterNew(tester, 'newpass123', 'newpass123');

        await tester.tap(find.text('비밀번호 변경하기'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
        expect(find.text('새로운 비밀번호를 입력해주세요.'), findsOneWidget);
        expect(navigated, isEmpty);

        toast.dismiss();
        await tester.pumpAndSettle();
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값(규율 #15).
    // 기댓값은 리터럴로 쓴다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      Finder fieldBox() => find.ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );

      testWidgets('입력 상자 높이가 52다', (tester) async {
        await pump(tester);

        // py-[13px] 둘 + 줄 높이 24 + 테두리 2.
        expect(tester.getSize(fieldBox().first).height, 52);
      });

      testWidgets('제출 버튼 높이가 56이다', (tester) async {
        await pump(tester);

        // py-[18px] 둘 + 줄 높이 20. `AppButton.defaultHeight`(44)가 아니다.
        final button = tester.widget<AppButton>(find.byType(AppButton));
        expect(button.height, 56);
        expect(tester.getSize(find.byType(AppButton)).height, 56);
      });

      // **`mt-7`(20)이 아니라 `space-y-3`(8)이다.** Tailwind의 `space-y-*`가
      // 특정도에서 이겨 `mt-7`을 덮는다 — 실측으로 확인했다.
      testWidgets('힌트 문단 위 간격이 20이 아니라 8이다', (tester) async {
        await pump(tester);

        final box = tester.getRect(fieldBox().first);
        final hint = tester.getRect(find.text('비밀번호가 기억나지 않으세요?'));

        expect(hint.top - box.bottom, 8);
      });

      testWidgets('제목과 입력 상자 사이가 8이다', (tester) async {
        await pump(tester);

        final title = tester.getRect(find.text('현재 비밀번호를 입력해주세요.'));
        final box = tester.getRect(fieldBox().first);

        expect(box.top - title.bottom, 8);
      });

      testWidgets('힌트 링크는 primary 색이다', (tester) async {
        await pump(tester);

        final link = tester.widget<Text>(find.text('비밀번호 찾기'));
        expect(link.style?.color, AppColors.light.primary500);
        expect(link.style?.fontSize, 12);
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
