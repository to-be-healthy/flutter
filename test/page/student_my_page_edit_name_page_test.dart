import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_edit_name_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_plain_input.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> me = _defaultMe();

  /// 응답을 붙잡아 둔다. 데이터가 오기 전 화면을 관찰하려면 필요하다.
  Completer<void>? gate;

  final Set<String> failingMethods = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (gate != null) {
      await gate!.future;
    }
    final method = options.method.toUpperCase();
    if (failingMethods.contains(method)) {
      return ResponseBody.fromString(
        '{"message":"이미 사용 중인 이름입니다.","code":"400"}',
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
        'data': method == 'GET'
            ? me
            : <String, dynamic>{'memberId': 6, 'name': '새이름'},
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
  'profile': null,
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'memberType': 'STUDENT',
  'socialType': 'NONE',
};

void main() {
  group('StudentMyPageEditNamePage', () {
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
          child: StudentMyPageEditNamePage(
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

    bool isSubmitEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton)).onPressed != null;

    group('요청 1건 — 골든 `mypage-student-edit-name`', () {
      // 골든은 `har/mypage-student-edit-name.har`에서 생성했다(2026-09-15).
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student-edit-name', capture.captured);
      });

      testWidgets('Authorization이 붙는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.single.headers.containsKey('authorization'),
          isTrue,
        );
      });

      testWidgets('뒤로가기가 동작한다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);
      });
    });

    group('입력창은 현재 이름을 보여주고 버튼은 꺼져 있다', () {
      // 웹 `defaultValue={data?.name}` + `useState('')`의 조합이다.
      testWidgets('이름이 채워져 있는데도 버튼이 비활성이다', (tester) async {
        await pump(tester);

        expect(find.text('차은우'), findsOneWidget);
        expect(isSubmitEnabled(tester), isFalse, reason: 'name 상태는 아직 비어 있다');
      });

      testWidgets('데이터가 오기 전에는 입력창이 비어 있다', (tester) async {
        adapter.gate = Completer<void>();

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('차은우'), findsNothing);
        expect(find.text('변경하실 이름을 입력해주세요.'), findsOneWidget);
        expect(isSubmitEnabled(tester), isFalse);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('다른 이름을 입력하면 활성된다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), '김철수');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester), isTrue);
      });

      // 웹 `name === data?.name`.
      testWidgets('현재 이름과 같게 되돌리면 다시 비활성이다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), '김철수');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '차은우');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester), isFalse);
      });

      // 웹 `name === ''`.
      testWidgets('전부 지우면 비활성이다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), '김철수');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester), isFalse);
      });

      // 웹에 `isError` 분기가 없다. `data?.name`이 없으면 버튼 조건의
      // 앞쪽이 참이 되지 않아 **입력만 하면 바꿀 수 있다.**
      testWidgets('조회에 실패해도 입력하면 바꿀 수 있다', (tester) async {
        adapter.failingMethods.add('GET');

        await pump(tester);

        expect(find.text('차은우'), findsNothing);
        await tester.enterText(find.byType(TextField), '김철수');
        await tester.pumpAndSettle();

        expect(isSubmitEnabled(tester), isTrue);
      });
    });

    group('이름 변경', () {
      Future<void> submit(WidgetTester tester, String name) async {
        await tester.enterText(find.byType(TextField), name);
        await tester.pumpAndSettle();
        await tester.tap(find.text('변경 완료'));
        await tester.pumpAndSettle();
      }

      testWidgets('PATCH 로 이름을 보낸다', (tester) async {
        await pump(tester);
        await submit(tester, '김철수');

        expect(capture.captured.length, 2);
        final request = capture.captured.last;
        expect(request.method, 'PATCH');
        expect(request.path, MemberApi.namePath);
        expect(request.body, <String, dynamic>{'name': '김철수'});
        expect(request.headers.containsKey('authorization'), isTrue);
      });

      testWidgets('성공하면 내 정보로 간다', (tester) async {
        await pump(tester);
        await submit(tester, '김철수');

        expect(navigated, <String>['/student/mypage/info']);
      });

      // 웹은 이동 전에 `refetchQueries(['myinfo'])`를 부른다. 앱에는 공유
      // 캐시가 없어 **이 화면에서는 재조회하지 않는다** — 돌아간 화면이
      // 자기 `initState`에서 같은 GET을 한다.
      testWidgets('이동 전에 재조회하지 않는다', (tester) async {
        await pump(tester);
        await submit(tester, '김철수');

        expect(
          capture.captured.map((r) => '${r.method} ${r.path}').toList(),
          <String>['GET ${MemberApi.mePath}', 'PATCH ${MemberApi.namePath}'],
        );
      });

      testWidgets('실패하면 서버 메시지를 띄우고 화면에 남는다', (tester) async {
        await pump(tester);
        adapter.failingMethods.add('PATCH');

        await tester.enterText(find.byType(TextField), '김철수');
        await tester.pumpAndSettle();
        await tester.tap(find.text('변경 완료'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('이미 사용 중인 이름입니다.'), findsOneWidget);
        expect(navigated, isEmpty);
        expect(find.text('변경하실 이름을 입력해주세요.'), findsOneWidget);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      testWidgets('실패 뒤에 다시 시도할 수 있다', (tester) async {
        await pump(tester);
        adapter.failingMethods.add('PATCH');

        await tester.enterText(find.byType(TextField), '김철수');
        await tester.pumpAndSettle();
        await tester.tap(find.text('변경 완료'));
        await settleWithoutDismissingToast(tester);
        toast.dismiss();
        await tester.pumpAndSettle();

        adapter.failingMethods.clear();
        await tester.tap(find.text('변경 완료'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/student/mypage/info']);
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값(규율 #15).
    // 기댓값은 리터럴로 쓴다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      testWidgets('입력 상자 높이가 52다', (tester) async {
        await pump(tester);

        expect(tester.getSize(find.byType(AppPlainInput)).height, 52);
      });

      testWidgets('제출 버튼 높이가 56이다', (tester) async {
        await pump(tester);

        expect(tester.getSize(find.byType(AppButton)).height, 56);
      });

      testWidgets('제목과 입력 상자 사이가 8이다', (tester) async {
        await pump(tester);

        final title = tester.getRect(find.text('변경하실 이름을 입력해주세요.'));
        final box = tester.getRect(find.byType(AppPlainInput));

        expect(box.top - title.bottom, 8);
      });
    });

    group('폰 너비(390pt)', () {
      testWidgets('긴 이름이 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        adapter.me = _defaultMe()..['name'] = '아주아주기다란회원이름입니다정말로';

        await pump(tester);

        expect(tester.takeException(), isNull);
      });
    });
  });
}
