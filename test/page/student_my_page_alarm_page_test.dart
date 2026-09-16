import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_alarm_page.dart';
import 'package:geonganghaejim/shared/ui/app_switch.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> me = _defaultMe();

  /// 응답을 붙잡아 둔다. 재조회가 끝나기 전 화면을 관찰하려면 필요하다.
  Completer<void>? gate;

  final Set<String> failingMethods = <String>{};

  /// PATCH 가 성공하면 서버 상태가 바뀐 것으로 친다 — 뒤따르는 재조회가
  /// 새 값을 돌려줘야 스위치가 움직인다.
  bool applyToggle = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    if (method == 'PATCH') {
      if (failingMethods.contains('PATCH')) {
        return ResponseBody.fromString(
          '{"message":"알림 설정에 실패했습니다.","code":"400"}',
          400,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }
      if (applyToggle) {
        // 경로 `/api/v1/members/alarm/{type}/{status}`를 읽어 반영한다.
        final parts = options.path.split('/');
        final type = parts[parts.length - 2];
        final status = parts.last;
        const field = <String, String>{
          'PUSH': 'pushAlarmStatus',
          'COMMUNITY': 'communityAlarmStatus',
          'FEEDBACK': 'feedbackAlarmStatus',
          'SCHEDULENOTICE': 'scheduleNoticeStatus',
        };
        me = Map<String, dynamic>.from(me)..[field[type]!] = status;
      }
    }
    if (gate != null) {
      await gate!.future;
    }
    if (method == 'GET' && failingMethods.contains('GET')) {
      return ResponseBody.fromString('{"message":"서버 오류"}', 500);
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 200,
        'message': '성공',
        'data': method == 'GET' ? me : true,
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

/// 2026-09-15 실측 응답(`healthy-student0`) — 알림 4종이 전부 `DISABLE`이다.
Map<String, dynamic> _defaultMe() => <String, dynamic>{
  'id': 6,
  'userId': 'healthy-student0',
  'name': '차은우',
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'memberType': 'STUDENT',
  'socialType': 'NONE',
  'pushAlarmStatus': 'DISABLE',
  'communityAlarmStatus': 'DISABLE',
  'feedbackAlarmStatus': 'DISABLE',
  'scheduleNoticeStatus': 'DISABLE',
};

void main() {
  group('StudentMyPageAlarmPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
    late AppToastController toast;
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
      backCount = 0;
    });

    tearDown(() => toast.dispose());

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(
          child: StudentMyPageAlarmPage(
            memberApi: MemberApi(dio),
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

    /// [label] 행의 스위치.
    Finder switchIn(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.color == Colors.white,
        ),
      ),
      matching: find.byType(AppSwitch),
    );

    group('요청 1건 — 골든 `mypage-student-alarm`', () {
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student-alarm', capture.captured);
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

    group('구성 — 세 행과 제목', () {
      testWidgets('제목이 헤더가 아니라 본문에 있다', (tester) async {
        await pump(tester);

        expect(find.text('알림 설정'), findsOneWidget);
        // 헤더에는 뒤로가기만 있다 — `AppBar`의 title 슬롯은 비어 있다.
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.title, isNull);
        expect(appBar.backgroundColor, Colors.white);
      });

      testWidgets('세 행의 라벨과 부제를 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('앱 푸쉬 알림'), findsOneWidget);
        expect(find.text('커뮤니티'), findsOneWidget);
        expect(find.text('내 글에 댓글, 좋아요'), findsOneWidget);
        expect(find.text('피드백'), findsOneWidget);
        expect(find.text('수업 일지, 식단 피드백 작성 알림'), findsOneWidget);
      });

      // 웹 타입 유니온에도 백엔드에도 있는데 **화면에 자리가 없다**(BUG-2).
      testWidgets('일정 알림 토글은 없다', (tester) async {
        await pump(tester);

        expect(find.byType(AppSwitch), findsNWidgets(3));
        expect(find.textContaining('일정'), findsNothing);
      });

      // 웹에 `isPending`·`isError` 분기가 없다(BUG-3).
      testWidgets('조회 전에는 라벨만 보이고 스위치가 하나도 없다', (tester) async {
        adapter.gate = Completer<void>();

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('앱 푸쉬 알림'), findsOneWidget);
        expect(find.byType(AppSwitch), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('조회에 실패해도 라벨만 남는다', (tester) async {
        adapter.failingMethods.add('GET');

        await pump(tester);

        expect(find.text('커뮤니티'), findsOneWidget);
        expect(find.byType(AppSwitch), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('BUG-1 — 커뮤니티 스위치가 엉뚱한 필드로 게이팅된다', () {
      // 웹 `{data?.scheduleNoticeStatus && <Switch id='COMMUNITY' .../>}`.
      testWidgets('scheduleNoticeStatus 가 비면 커뮤니티 스위치만 사라진다', (tester) async {
        adapter.me = _defaultMe()..['scheduleNoticeStatus'] = '';

        await pump(tester);

        expect(switchIn('커뮤니티'), findsNothing);
        // 나머지 둘은 그대로다.
        expect(switchIn('앱 푸쉬 알림'), findsOneWidget);
        expect(switchIn('피드백'), findsOneWidget);
        // 라벨과 부제는 남는다.
        expect(find.text('커뮤니티'), findsOneWidget);
        expect(find.text('내 글에 댓글, 좋아요'), findsOneWidget);
      });

      // 반대로 communityAlarmStatus 가 비어도 스위치는 그대로 그려진다 —
      // 게이트가 그 값을 보지 않기 때문이다.
      testWidgets('communityAlarmStatus 가 비어도 스위치는 남는다', (tester) async {
        adapter.me = _defaultMe()..['communityAlarmStatus'] = '';

        await pump(tester);

        expect(switchIn('커뮤니티'), findsOneWidget);
        // 값이 `ENABLED`가 아니므로 꺼진 상태다.
        expect(tester.widget<AppSwitch>(switchIn('커뮤니티')).value, isFalse);
      });

      // 켜짐 판정은 제대로 `communityAlarmStatus`를 본다.
      testWidgets('켜짐 판정은 communityAlarmStatus 를 본다', (tester) async {
        adapter.me = _defaultMe()
          ..['communityAlarmStatus'] = 'ENABLED'
          ..['scheduleNoticeStatus'] = 'DISABLE';

        await pump(tester);

        expect(tester.widget<AppSwitch>(switchIn('커뮤니티')).value, isTrue);
      });
    });

    group('토글', () {
      testWidgets('PATCH 뒤에 재조회한다', (tester) async {
        await pump(tester);

        await tester.tap(switchIn('앱 푸쉬 알림'));
        await tester.pumpAndSettle();

        expect(
          capture.captured.map((r) => '${r.method} ${r.path}').toList(),
          <String>[
            'GET ${MemberApi.mePath}',
            'PATCH ${MemberApi.alarmPath}/PUSH/ENABLED',
            'GET ${MemberApi.mePath}',
          ],
        );
      });

      // 상태 철자가 계약이다 — `DISABLED`가 아니라 **`DISABLE`**.
      testWidgets('끌 때는 DISABLE 을 보낸다', (tester) async {
        adapter.me = _defaultMe()..['pushAlarmStatus'] = 'ENABLED';

        await pump(tester);
        await tester.tap(switchIn('앱 푸쉬 알림'));
        await tester.pumpAndSettle();

        expect(capture.captured[1].path, '${MemberApi.alarmPath}/PUSH/DISABLE');
      });

      testWidgets('행마다 자기 타입을 보낸다', (tester) async {
        const expected = <String, String>{
          '커뮤니티': 'COMMUNITY',
          '피드백': 'FEEDBACK',
        };

        for (final entry in expected.entries) {
          await pump(tester);
          final before = capture.captured.length;

          await tester.tap(switchIn(entry.key));
          await tester.pumpAndSettle();

          expect(
            capture.captured[before].path,
            '${MemberApi.alarmPath}/${entry.value}/ENABLED',
            reason: '${entry.key} 가 엉뚱한 타입을 보낸다',
          );
        }
      });

      testWidgets('재조회 결과가 스위치를 움직인다', (tester) async {
        await pump(tester);
        expect(tester.widget<AppSwitch>(switchIn('앱 푸쉬 알림')).value, isFalse);

        await tester.tap(switchIn('앱 푸쉬 알림'));
        await tester.pumpAndSettle();

        expect(tester.widget<AppSwitch>(switchIn('앱 푸쉬 알림')).value, isTrue);
      });

      // **낙관적 갱신이 없다.** 서버가 응답하기 전에는 스위치가 그대로다.
      testWidgets('응답 전에는 스위치가 움직이지 않는다', (tester) async {
        await pump(tester);
        adapter.gate = Completer<void>();

        await tester.tap(switchIn('앱 푸쉬 알림'));
        await tester.pump();

        expect(
          tester.widget<AppSwitch>(switchIn('앱 푸쉬 알림')).value,
          isFalse,
          reason: '웹도 refetch 가 끝나야 움직인다',
        );

        adapter.gate!.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<AppSwitch>(switchIn('앱 푸쉬 알림')).value, isTrue);
      });

      testWidgets('실패하면 토스트를 띄우고 스위치가 그대로다', (tester) async {
        adapter.failingMethods.add('PATCH');

        await pump(tester);
        await tester.tap(switchIn('앱 푸쉬 알림'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('알림 설정에 실패했습니다.'), findsOneWidget);
        expect(tester.widget<AppSwitch>(switchIn('앱 푸쉬 알림')).value, isFalse);
        // 재조회도 하지 않는다.
        expect(capture.captured.length, 2);

        toast.dismiss();
        await tester.pumpAndSettle();
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값(규율 #15).
    // 기댓값은 리터럴로 쓴다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      Size rowSize(WidgetTester tester, String label) => tester.getSize(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.color == Colors.white,
              ),
            )
            .first,
      );

      testWidgets('제목 블록 높이가 70이다', (tester) async {
        await pump(tester);

        // pt-8(24) + HEADING_3 줄 높이 26 + pb-7(20).
        expect(rowSize(tester, '알림 설정').height, 70);
      });

      // **스위치(28)가 행 높이를 정한다** — 글자(24)가 아니다.
      testWidgets('첫 행은 64, 나머지 둘은 77이다', (tester) async {
        await pump(tester);

        expect(rowSize(tester, '앱 푸쉬 알림').height, 64);
        expect(rowSize(tester, '커뮤니티').height, 77);
        expect(rowSize(tester, '피드백').height, 77);
      });

      // 웹 `mt-3` = 8. **이 회색 틈이 구분선 역할을 한다.**
      testWidgets('첫 행과 둘째 행 사이만 8이고 나머지는 붙어 있다', (tester) async {
        await pump(tester);

        final first = tester.getRect(
          find
              .ancestor(
                of: find.text('앱 푸쉬 알림'),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.color == Colors.white,
                ),
              )
              .first,
        );
        final second = tester.getRect(
          find
              .ancestor(
                of: find.text('커뮤니티'),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.color == Colors.white,
                ),
              )
              .first,
        );
        final third = tester.getRect(
          find
              .ancestor(
                of: find.text('피드백'),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.color == Colors.white,
                ),
              )
              .first,
        );

        expect(second.top - first.bottom, 8);
        expect(third.top - second.bottom, 0);
      });

      testWidgets('스위치는 48 × 28이고 손잡이는 24다', (tester) async {
        await pump(tester);

        expect(
          tester.getSize(find.byType(AppSwitch).first),
          const Size(48, 28),
        );
        // 이동 거리 20 = 48 − 보더 4 − 손잡이 24.
        expect(AppSwitch.thumbTravel, 20);
      });

      testWidgets('꺼짐은 gray300, 켜짐은 primary500이다', (tester) async {
        final colors = AppColors.light;

        await pump(tester);
        final off = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(AppSwitch).first,
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect((off.decoration! as BoxDecoration).color, colors.gray300);

        await tester.tap(switchIn('앱 푸쉬 알림'));
        await tester.pumpAndSettle();

        final on = tester.widget<AnimatedContainer>(
          find.descendant(
            of: switchIn('앱 푸쉬 알림'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect((on.decoration! as BoxDecoration).color, colors.primary500);
      });
    });

    group('폰 너비(390pt)', () {
      testWidgets('긴 부제가 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pump(tester);

        expect(tester.takeException(), isNull);
      });
    });
  });
}
