import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_trainer_info_page.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  /// `null`이면 매핑 없음(서버가 `data: null`을 준다).
  Map<String, dynamic>? data = _defaultTrainer();

  Completer<void>? gate;

  bool fails = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (gate != null) {
      await gate!.future;
    }
    if (fails) {
      return ResponseBody.fromString('{"message":"서버 오류"}', 500);
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 200,
        'message': '성공',
        'data': data,
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

/// 2026-09-15 실측 응답 모양.
Map<String, dynamic> _defaultTrainer() => <String, dynamic>{
  'mappingId': 3,
  'trainer': <String, dynamic>{
    'id': 5,
    'email': 'healthy-trainer0@geonganghaejim.site',
    'name': '김트레이너',
    'profile': null,
    // **`GymDto`라 id 필드명이 `id`다**(`gymId`가 아니다).
    'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  },
};

void main() {
  group('StudentMyPageTrainerInfoPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
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
      backCount = 0;
    });

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: StudentMyPageTrainerInfoPage(
        memberApi: MemberApi(dio),
        onBack: () => backCount++,
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    group('요청 1건 — 골든 `mypage-student-trainer-info`', () {
      // **캡처 때 401 → refresh-token → 재시도가 찍혔지만 담지 않았다.**
      // 토큰 만료로 인터셉터가 한 일이지 화면이 보내는 요청이 아니다.
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student-trainer-info', capture.captured);
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

    group('트레이너가 있을 때', () {
      testWidgets('이름·직함·이메일·헬스장을 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('김트레이너'), findsOneWidget);
        expect(find.text('트레이너'), findsOneWidget);
        expect(find.text('이메일'), findsOneWidget);
        expect(
          find.text('healthy-trainer0@geonganghaejim.site'),
          findsOneWidget,
        );
        expect(find.text('헬스장'), findsOneWidget);
        expect(find.text('건강해짐 홍대점'), findsOneWidget);
        expect(find.text('등록된 트레이너가 없습니다.'), findsNothing);
      });

      // **`gym`은 `GymDto`라 id 필드명이 `id`다.** `gymId`로 읽으려 하면
      // 이름이 비어 버린다 — 홈 두 화면을 죽였던 그 함정이다.
      testWidgets('gym.name 을 읽는다', (tester) async {
        adapter.data = _defaultTrainer();
        (adapter.data!['trainer'] as Map<String, dynamic>)['gym'] =
            <String, dynamic>{'id': 9, 'name': '건강해짐 강남점'};

        await pump(tester);

        expect(find.text('건강해짐 강남점'), findsOneWidget);
      });

      testWidgets('프로필 사진이 없으면 아바타 자산을 그린다', (tester) async {
        await pump(tester);

        // **헤더의 뒤로가기도 `SvgPicture`다** — 타입만으로 찾으면 둘이
        // 잡힌다(규율 #19). 원형 컨테이너 안쪽으로 좁힌다.
        expect(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.circle,
            ),
            matching: find.byType(SvgPicture),
          ),
          findsOneWidget,
        );
        // 빈 상태 아이콘(35)은 없다.
        expect(
          find.byWidgetPredicate((w) => w is SvgPicture && w.width == 35),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('트레이너가 없을 때', () {
      testWidgets('매핑이 없으면 빈 상태를 보여준다', (tester) async {
        adapter.data = null;

        await pump(tester);

        expect(find.text('등록된 트레이너가 없습니다.'), findsOneWidget);
        expect(find.text('이메일'), findsNothing);
      });

      // 웹 `{!data && <NoTrainer />}` — `isLoading` 분기가 없다(BUG-10).
      testWidgets('조회 중에도 빈 상태가 먼저 보인다', (tester) async {
        adapter.gate = Completer<void>();

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(
          find.text('등록된 트레이너가 없습니다.'),
          findsOneWidget,
          reason: '로딩 분기가 없어 빈 상태가 깜빡인다',
        );

        adapter.gate!.complete();
        await tester.pumpAndSettle();

        expect(find.text('등록된 트레이너가 없습니다.'), findsNothing);
        expect(find.text('김트레이너'), findsOneWidget);
      });

      // 웹에 `isError` 분기가 없어 **실패와 매핑 없음이 구분되지 않는다.**
      testWidgets('조회에 실패해도 빈 상태가 남는다', (tester) async {
        adapter.fails = true;

        await pump(tester);

        expect(find.text('등록된 트레이너가 없습니다.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      // 서버가 `trainer`만 빠뜨리면 웹은 TypeError다. 앱은 빈 상태로 흡수한다.
      testWidgets('trainer 가 없으면 빈 상태로 흡수한다', (tester) async {
        adapter.data = <String, dynamic>{'mappingId': 3};

        await pump(tester);

        expect(find.text('등록된 트레이너가 없습니다.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값(규율 #15).
    // 기댓값은 리터럴로 쓴다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      testWidgets('프로필 원이 80 × 80이고 테두리가 gray300이다', (tester) async {
        await pump(tester);

        final avatar = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        );
        expect(tester.getSize(avatar.first), const Size(80, 80));

        final decoration =
            tester.widget<Container>(avatar.first).decoration! as BoxDecoration;
        expect(decoration.border?.top.color, AppColors.light.gray300);
      });

      testWidgets('정보 카드 높이가 98이다', (tester) async {
        await pump(tester);

        final card = find.ancestor(
          of: find.text('이메일'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == Colors.white,
          ),
        );
        // py-7(20+20) + 두 행 21 + 행 사이 16.
        expect(tester.getSize(card.first).height, 98);
      });

      testWidgets('이름과 직함 사이가 2다', (tester) async {
        await pump(tester);

        final name = tester.getRect(find.text('김트레이너'));
        final role = tester.getRect(find.text('트레이너'));

        expect(role.top - name.bottom, 2);
      });

      // 웹 `py-28`은 **커스텀 스케일이 아니라 Tailwind 기본 7rem = 112**다.
      testWidgets('빈 상태 위아래 여백이 112다', (tester) async {
        adapter.data = null;

        await pump(tester);

        final icon = find.byWidgetPredicate(
          (w) => w is SvgPicture && w.width == 35,
        );
        expect(tester.getRect(icon).top, greaterThanOrEqualTo(112));
        expect(StudentMyPageTrainerInfoPage.emptyVerticalPadding, 112);
      });

      testWidgets('이름은 순검정이다', (tester) async {
        await pump(tester);

        // 웹 `text-black` — gray800(#2E3134)이 아니다.
        final name = tester.widget<Text>(find.text('김트레이너'));
        expect(name.style?.color, Colors.black);
        expect(name.style?.color, isNot(AppColors.light.gray800));
      });
    });

    group('폰 너비(390pt)', () {
      testWidgets('긴 이메일이 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        adapter.data = _defaultTrainer();
        (adapter.data!['trainer'] as Map<String, dynamic>)['email'] =
            'very.long.trainer.email.address@geonganghaejim.site';

        await pump(tester);

        expect(tester.takeException(), isNull);
      });

      testWidgets('빈 상태도 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        adapter.data = null;

        await pump(tester);

        expect(tester.takeException(), isNull);
      });
    });
  });
}
