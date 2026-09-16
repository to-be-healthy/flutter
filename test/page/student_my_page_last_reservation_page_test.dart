import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/date/korean_date_format.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/schedule/api/schedule_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_last_reservation_page.dart';
import 'package:geonganghaejim/widget/app_month_picker.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  /// `null`이면 서버가 `reservations: null`을 준 것으로 친다.
  List<Map<String, dynamic>>? reservations = _defaultReservations();

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
        'data': <String, dynamic>{
          // **실측에서 언제나 null이다**(서베이 BUG-20).
          'course': null,
          'reservations': reservations,
        },
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

/// 2026-09-15 실측 응답(2026-04, `healthy-student0`)에서 가져온 모양.
List<Map<String, dynamic>> _defaultReservations() => <Map<String, dynamic>>[
  <String, dynamic>{
    'scheduleId': 984,
    'lessonDt': '2026-04-13',
    'lessonStartTime': '04:00:00',
    'lessonEndTime': '05:00:00',
    'trainerName': '김트레이너 트레이너',
    'reservationStatus': 'COMPLETED',
  },
  <String, dynamic>{
    'scheduleId': 985,
    'lessonDt': '2026-04-14',
    'lessonStartTime': '13:30:00',
    'lessonEndTime': '14:30:00',
    'trainerName': '김트레이너 트레이너',
    'reservationStatus': 'NO_SHOW',
  },
];

void main() {
  setUpAll(KoreanDateFormat.ensureInitialized);

  group('StudentMyPageLastReservationPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
    late List<String> months;
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
      months = <String>[];
      backCount = 0;
    });

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap({String? initialMonth = '2026-09'}) => MaterialApp(
      theme: AppTheme.light(),
      home: StudentMyPageLastReservationPage(
        scheduleApi: ScheduleApi(dio),
        initialMonth: initialMonth,
        onMonthChanged: months.add,
        onBack: () => backCount++,
      ),
    );

    Future<void> pump(
      WidgetTester tester, {
      String? initialMonth = '2026-09',
    }) async {
      await tester.pumpWidget(wrap(initialMonth: initialMonth));
      await tester.pumpAndSettle();
    }

    group('요청 1건 — 골든 `mypage-student-last-reservation`', () {
      // 골든은 쿼리스트링(`searchDate=2026-09`)까지 고정한다.
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student-last-reservation', capture.captured);
      });

      testWidgets('Authorization이 붙는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.single.headers.containsKey('authorization'),
          isTrue,
        );
      });

      // **웹 헤더는 `router.back()`이 아니라 `<Link href='/student/mypage'>`다.**
      testWidgets('뒤로가기가 동작한다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);
      });
    });

    // 서베이 BUG-8. `?month=`가 없으면 웹은 `dayjs(null)`로 Invalid Date를
    // 만들고 그 문자열을 그대로 서버에 보낸다.
    group('BUG-8 — month 쿼리가 없으면 Invalid Date 를 보낸다', () {
      testWidgets('searchDate 가 Invalid Date 다', (tester) async {
        await pump(tester, initialMonth: null);

        expect(capture.captured.single.query, <String, dynamic>{
          'searchDate': 'Invalid Date',
        });
      });

      // 웹 `{selectedMonth && <MonthPicker />}` — 달을 못 읽으면 선택기가 없다.
      testWidgets('월 선택기 자체가 없다', (tester) async {
        await pump(tester, initialMonth: null);

        expect(find.byType(AppMonthPicker), findsNothing);
      });

      testWidgets('읽을 수 없는 month 도 같은 결과다', (tester) async {
        await pump(tester, initialMonth: '이상한값');

        expect(capture.captured.single.query['searchDate'], 'Invalid Date');
      });
    });

    group('목록', () {
      testWidgets('카드를 날짜·시간·상태와 함께 보여준다', (tester) async {
        await pump(tester);

        // `MM월 DD일 dddd`.
        expect(find.text('04월 13일 월요일'), findsOneWidget);
        // `convertTo12HourFormat` — **한 자리 시**다(`04:00`이 아니라 `4:00`).
        expect(find.text('오전 4:00 - 5:00'), findsOneWidget);
        expect(find.text('출석'), findsOneWidget);

        expect(find.text('04월 14일 화요일'), findsOneWidget);
        expect(find.text('오후 1:30 - 2:30'), findsOneWidget);
        expect(find.text('미출석'), findsOneWidget);
      });

      testWidgets('COMPLETED 가 아니면 전부 미출석이다', (tester) async {
        adapter.reservations = <Map<String, dynamic>>[
          ..._defaultReservations().take(1),
        ];
        adapter.reservations!.first['reservationStatus'] = 'CANCELED';

        await pump(tester);

        expect(find.text('미출석'), findsOneWidget);
        expect(find.text('출석'), findsNothing);
      });
    });

    group('빈 상태', () {
      // 서버가 빈 배열이 아니라 **null**을 준다.
      testWidgets('reservations 가 null이면 빈 상태다', (tester) async {
        adapter.reservations = null;

        await pump(tester);

        expect(find.text('지난 예약이 없습니다.'), findsOneWidget);
      });

      // **빈 배열은 빈 상태가 아니다.** 웹이 `=== null`로만 판단한다.
      testWidgets('빈 배열이면 빈 상태도 카드도 없다', (tester) async {
        adapter.reservations = <Map<String, dynamic>>[];

        await pump(tester);

        expect(find.text('지난 예약이 없습니다.'), findsNothing);
        expect(find.text('04월 13일 월요일'), findsNothing);
      });

      // 서베이 BUG-9: 로딩 중에는 `data`가 undefined라 `=== null`이 거짓이다.
      testWidgets('조회 중에는 빈 상태조차 뜨지 않는다', (tester) async {
        adapter.gate = Completer<void>();
        adapter.reservations = null;

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(
          find.text('지난 예약이 없습니다.'),
          findsNothing,
          reason: '웹은 로딩 분기가 없어 완전 공백이다',
        );
        // 월 선택기는 보인다.
        expect(find.byType(AppMonthPicker), findsOneWidget);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('지난 예약이 없습니다.'), findsOneWidget);
      });

      testWidgets('조회에 실패해도 공백이다', (tester) async {
        adapter.fails = true;

        await pump(tester);

        expect(find.text('지난 예약이 없습니다.'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('월 선택기', () {
      testWidgets('선택된 달을 보여준다', (tester) async {
        await pump(tester);

        // 웹 `YYYY년 M월` — **월에 0을 붙이지 않는다.**
        expect(find.text('2026년 9월'), findsOneWidget);
      });

      testWidgets('누르면 시트가 열리고 12칸이 나온다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();

        expect(find.text('월 선택하기'), findsOneWidget);
        expect(find.text('2026년'), findsOneWidget);
        for (var month = 1; month <= 12; month++) {
          expect(find.text('$month월'), findsOneWidget);
        }
        expect(find.text('2026년 9월 선택'), findsOneWidget);
      });

      testWidgets('달을 고르면 다시 조회하고 쿼리를 알린다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('4월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026년 4월 선택'));
        await tester.pumpAndSettle();

        expect(months, <String>['2026-04']);
        expect(capture.captured.length, 2);
        expect(capture.captured.last.query, <String, dynamic>{
          'searchDate': '2026-04',
        });
        expect(find.text('2026년 4월'), findsOneWidget);
      });

      // 웹 `isFuture` — 올해의 다음 달부터는 눌러도 안 먹는다.
      testWidgets('올해의 미래 달은 눌러도 선택되지 않는다', (tester) async {
        final now = DateTime.now();
        if (now.month == 12) {
          return; // 12월에는 미래 달이 없다.
        }
        await pump(tester, initialMonth: '${now.year}-01');

        await tester.tap(find.text('${now.year}년 1월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${now.month + 1}월'));
        await tester.pumpAndSettle();

        expect(
          find.text('${now.year}년 1월 선택'),
          findsOneWidget,
          reason: '미래 달을 눌러도 선택이 바뀌지 않는다',
        );
      });

      // 웹 `unselectabled = year >= currentYear`.
      testWidgets('올해보다 뒤 연도로는 못 간다', (tester) async {
        final now = DateTime.now();
        await pump(tester, initialMonth: '${now.year}-01');

        await tester.tap(find.text('${now.year}년 1월'));
        await tester.pumpAndSettle();

        final right = find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == AppMonthPicker.yearArrowGap,
        );
        expect(right, findsOneWidget);
        // 오른쪽 화살표를 눌러도 연도가 그대로다.
        await tester.tap(find.text('${now.year}년'));
        await tester.pumpAndSettle();
        expect(find.text('${now.year}년'), findsOneWidget);
      });
    });

    group('상세 시트', () {
      testWidgets('카드를 누르면 열린다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();

        expect(find.text('수업 정보'), findsOneWidget);
        // `MM.DD (dd)` + 12시간 시각 + 상태.
        expect(find.textContaining('04.13 (월) 오전 4:00 - 5:00'), findsOneWidget);
        expect(find.text('확인'), findsOneWidget);
      });

      testWidgets('확인을 누르면 닫힌다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();

        expect(find.text('수업 정보'), findsNothing);
      });

      // 웹은 **미출석일 때만** point 색을 준다.
      testWidgets('미출석이면 상태 글자가 point 색이다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('04월 14일 화요일'));
        await tester.pumpAndSettle();

        final rich = tester.widget<Text>(find.textContaining('04.14 (화)'));
        final status = (rich.textSpan! as TextSpan).children!.first as TextSpan;
        expect(status.text, ' 미출석');
        expect(status.style?.color, AppColors.light.point);
      });

      testWidgets('출석이면 상태 글자에 별도 색이 없다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();

        final rich = tester.widget<Text>(find.textContaining('04.13 (월)'));
        final status = (rich.textSpan! as TextSpan).children!.first as TextSpan;
        expect(status.text, ' 출석');
        expect(status.style, isNull);
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값(규율 #15).
    // 기댓값은 리터럴로 쓴다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      testWidgets('카드 높이가 89.4다', (tester) async {
        await pump(tester);

        final card = find.ancestor(
          of: find.text('04월 13일 월요일'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == Colors.white,
          ),
        );
        // py-7(20+20) + 머리글 21 + gap-y-2(6) + 본문 22.4.
        expect(tester.getSize(card.first).height, closeTo(89.41, 0.5));
      });

      testWidgets('상태 배지가 52 × 22다', (tester) async {
        await pump(tester);

        final badge = find.ancestor(
          of: find.text('출석'),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        expect(tester.getSize(badge.first), const Size(52, 22));
      });

      testWidgets('빈 상태 위아래 여백이 112다', (tester) async {
        adapter.reservations = null;

        await pump(tester);

        expect(StudentMyPageLastReservationPage.emptyVerticalPadding, 112);
        // py-28(112+112) + 아이콘 28 + mb-5(12) + 22.4.
        final empty = find.ancestor(
          of: find.text('지난 예약이 없습니다.'),
          matching: find.byType(Padding),
        );
        expect(tester.getSize(empty.first).height, closeTo(286.4, 0.6));
      });

      testWidgets('월 선택 트리거 높이가 51.5다', (tester) async {
        await pump(tester);

        // py-6(16+16) + HEADING_5 줄 높이 19.5.
        expect(
          tester.getSize(find.byType(AppMonthPicker)).height,
          closeTo(51.5, 0.5),
        );
      });

      testWidgets('월 격자 칸이 72이고 원이 56이다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();

        final circle = find.ancestor(
          of: find.text('9월'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        );
        expect(tester.getSize(circle.first), const Size(56, 56));
        expect(AppMonthPicker.cellHeight, 72);
      });
    });

    group('폰 너비(390pt)', () {
      testWidgets('목록과 두 시트가 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pump(tester);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  });
}
