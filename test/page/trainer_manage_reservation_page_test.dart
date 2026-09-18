import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geonganghaejim/core/date/korean_date_format.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/entity/schedule/api/schedule_api.dart';
import 'package:geonganghaejim/feature/schedule/ui/reservation_card.dart';
import 'package:geonganghaejim/page/protected/trainer_manage_reservation_page.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_month_picker.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

const int _memberId = 6;
const String _month = '2026-09';

/// 2026-09-18 실측 항목(`docs/trainer-manage-s5-measurements.md` 산출물 ②).
Map<String, dynamic> _reservation({
  int scheduleId = 984,
  String status = 'COMPLETED',
  String start = '04:00:00',
  String end = '05:00:00',
}) => <String, dynamic>{
  'scheduleId': scheduleId,
  'lessonDt': '2026-04-13',
  'lessonStartTime': start,
  'lessonEndTime': end,
  // 서버가 `" 트레이너"`를 덧붙여 준다. 이 화면은 쓰지 않는다.
  'trainerName': '김트레이너 트레이너',
  'reservationStatus': status,
};

class _StubAdapter implements HttpClientAdapter {
  /// **빈 목록은 `null`이다**(실측) — `[]`가 아니다.
  List<dynamic>? upcoming;
  List<dynamic>? past;

  bool upcomingFails = false;
  final List<String> mutations = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    if (method != 'GET') {
      mutations.add('$method ${options.path}');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'message': '처리되었습니다.', 'data': null}),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }

    final isUpcoming = options.path.endsWith('/new');
    if (isUpcoming && upcomingFails) {
      return ResponseBody.fromString('{"message":"서버 오류"}', 500);
    }

    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'message': '조회되었습니다.',
        'data': <String, dynamic>{
          // `/old`는 course가 항상 null이다(실측).
          'course': isUpcoming ? <String, dynamic>{'courseId': 3} : null,
          'reservations': isUpcoming ? upcoming : past,
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

void main() {
  // `04월 13일 월요일` 같은 한국어 날짜를 만들려면 로케일 데이터가 필요하다
  // (`/student/mypage/last-reservation` 테스트와 같은 처리).
  setUpAll(KoreanDateFormat.ensureInitialized);

  group('TrainerManageReservationPage', () {
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
      backCount = 0;
      toast = AppToastController();
      addTearDown(toast.dispose);
    });

    Widget wrap({String name = '차은우'}) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => AppToastScope(
        notifier: toast,
        child: AppToastHost(child: child!),
      ),
      home: TrainerManageReservationPage(
        scheduleApi: ScheduleApi(dio),
        memberId: _memberId,
        name: name,
        initialMonth: _month,
        onBack: () => backCount++,
      ),
    );

    void useWebViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(440 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> pump(WidgetTester tester, {String name = '차은우'}) async {
      useWebViewport(tester);
      await tester.pumpWidget(wrap(name: name));
      await tester.pumpAndSettle();
    }

    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> openPastTab(WidgetTester tester) async {
      await tester.tap(find.text('지난 예약'));
      await tester.pumpAndSettle();
    }

    group('요청 2건 — 골든 `trainer-manage-reservation`', () {
      testWidgets('들어오면 웹과 같은 요청 2건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('trainer-manage-reservation', capture.captured);
      });

      // 웹은 훅이 페이지 컴포넌트에 있어 **비활성 탭의 요청도 나간다**.
      testWidgets('지난 예약 탭을 안 열어도 `old`가 나간다', (tester) async {
        await pump(tester);

        expect(capture.captured.map((r) => r.path).toList(), <String>[
          '/api/v1/trainers/reservation/new',
          '/api/v1/trainers/reservation/old',
        ]);
      });

      testWidgets('탭을 바꿔도 요청이 더 나가지 않는다', (tester) async {
        await pump(tester);
        capture.clear();

        await openPastTab(tester);

        expect(capture.captured, isEmpty);
      });

      testWidgets('월을 바꾸면 `old`만 다시 받는다', (tester) async {
        await pump(tester);
        await openPastTab(tester);
        capture.clear();

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('4월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026년 4월 선택'));
        await tester.pumpAndSettle();

        expect(capture.captured, hasLength(1));
        expect(
          capture.captured.single.path,
          '/api/v1/trainers/reservation/old',
        );
        expect(capture.captured.single.query['searchDate'], '2026-04');
        expect('${capture.captured.single.query['memberId']}', '6');
      });
    });

    group('헤더', () {
      testWidgets('제목이 `{name}님 예약 내역`이다', (tester) async {
        await pump(tester);

        expect(find.text('차은우님 예약 내역'), findsOneWidget);
      });

      // 웹 `{name && `${name}님 예약 내역`}` — 실측에서 h2가 0×0이었다.
      testWidgets('이름이 없으면 제목이 통째로 사라진다', (tester) async {
        await pump(tester, name: '');

        expect(find.textContaining('예약 내역'), findsNothing);
        expect(find.textContaining('님'), findsNothing);
      });

      testWidgets('뒤로가기가 웹 `router.back()`이다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);
      });
    });

    group('탭', () {
      testWidgets('기본이 다가오는 예약이다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);

        expect(find.text('예약된 수업이 없습니다.'), findsOneWidget);
        // 지난 예약 탭의 내용은 아직 그리지 않는다.
        expect(find.byType(AppMonthPicker), findsNothing);
      });

      // **이 분기는 실측하지 못했다**(웹에서 다가오는 예약이 0건이었다).
      // 소스에서 옮긴 값이라 테스트가 없으면 한 번도 실행되지 않는다.
      testWidgets('다가오는 예약이 있으면 체크 아이콘 카드로 그린다', (tester) async {
        adapter.upcoming = <dynamic>[_reservation(status: 'AVAILABLE')];

        await pump(tester);

        expect(find.text('04월 13일 월요일'), findsOneWidget);
        expect(find.text('오전 4:00 - 5:00'), findsOneWidget);
        // 다가오는 예약에는 상태 배지가 없다 — 체크 아이콘이다.
        expect(find.byType(ReservationStatusBadge), findsNothing);

        final check = tester.widget<SvgPicture>(
          find.byWidgetPredicate(
            (w) =>
                w is SvgPicture &&
                (w.bytesLoader as SvgAssetLoader).assetName ==
                    'assets/images/check.svg',
          ),
        );
        // 웹 `width={17} height={17}`. 규율 #20 — `getSize`가 아니라
        // **위젯의 선언값**을 읽는다(viewBox 크기가 잡히지 않도록).
        expect(Size(check.width!, check.height!), const Size(17, 17));
      });

      testWidgets('지난 예약 탭으로 바꾸면 월 선택이 뜬다', (tester) async {
        await pump(tester);
        await openPastTab(tester);

        expect(find.byType(AppMonthPicker), findsOneWidget);
        expect(find.text('완료한 수업이 없습니다.'), findsOneWidget);
      });

      // **웹 버그 그대로.** `twSelector`가 만든 `font-semibold`가 생성되지
      // 않아 활성 탭도 400이다(실측). 누가 "고치면" 이 단언이 먼저 깨진다.
      testWidgets('활성 탭도 글꼴이 400이다 (twSelector 버그)', (tester) async {
        await pump(tester);

        final active = tester.widget<Text>(find.text('다가오는 예약'));
        expect(active.style?.fontWeight, FontWeight.w400);
        expect(
          active.style?.fontWeight,
          isNot(AppTypography.heading5.fontWeight),
        );
      });

      testWidgets('활성 탭만 배경이 primary500이고 글자가 희다', (tester) async {
        await pump(tester);

        final colors = AppTheme.light().extension<AppColors>()!;
        final active = tester.widget<Text>(find.text('다가오는 예약'));
        final inactive = tester.widget<Text>(find.text('지난 예약'));
        expect(active.style?.color, Colors.white);
        expect(inactive.style?.color, colors.gray500);
      });
    });

    group('지난 예약 목록', () {
      testWidgets('카드가 날짜·시간·배지를 그린다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);
        await openPastTab(tester);

        expect(find.text('04월 13일 월요일'), findsOneWidget);
        expect(find.text('오전 4:00 - 5:00'), findsOneWidget);
        expect(find.text('출석'), findsOneWidget);
      });

      testWidgets('COMPLETED가 아니면 미출석 배지다', (tester) async {
        adapter.past = <dynamic>[_reservation(status: 'NO_SHOW')];

        await pump(tester);
        await openPastTab(tester);

        expect(find.text('미출석'), findsOneWidget);
        expect(find.text('출석'), findsNothing);
      });

      testWidgets('배지 치수가 52 × 22다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);
        await openPastTab(tester);

        // 실측 B18. 높이는 18(글자) + 2 + 2.
        expect(
          tester.getSize(find.byType(ReservationStatusBadge)),
          const Size(52, 22),
        );
      });

      testWidgets('월 선택이 좌측 정렬이다', (tester) async {
        await pump(tester);
        await openPastTab(tester);

        // 본문 패딩 20 안쪽 = x 20.
        expect(tester.getTopLeft(find.byType(AppMonthPicker)).dx, 20);
      });
    });

    group('수업 정보 시트 — 노쇼 토글', () {
      testWidgets('카드를 누르면 시트가 열린다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);
        await openPastTab(tester);
        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();

        expect(find.text('수업 정보'), findsOneWidget);
        // 본문은 날짜 + 시간 + 상태가 한 문장이다(실측: span 앞에 공백).
        expect(
          find.textContaining('04.13 (월) 오전 4:00 - 5:00 출석'),
          findsOneWidget,
        );
      });

      // **동사가 반대다.** 출석(COMPLETED) 상태에서 `미출석`을 누르면
      // **DELETE**가 나간다 — 서베이 §4.3⑱.
      testWidgets('출석 상태에서 `미출석`을 누르면 DELETE다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);
        await openPastTab(tester);
        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('미출석'));
        await settleWithoutDismissingToast(tester);

        expect(adapter.mutations, <String>[
          'DELETE /api/v1/schedule/no-show/984',
        ]);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      testWidgets('미출석 상태에서 `출석`을 누르면 POST다', (tester) async {
        adapter.past = <dynamic>[_reservation(status: 'NO_SHOW')];

        await pump(tester);
        await openPastTab(tester);
        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();
        // 시트의 좌측 버튼 라벨이 뒤집힌다.
        await tester.tap(find.byKey(_toggleKey));
        await settleWithoutDismissingToast(tester);

        expect(adapter.mutations, <String>[
          'POST /api/v1/schedule/no-show/984',
        ]);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      // **미실측 분기다**(실측 데이터가 전부 COMPLETED였다). 라벨과 색이
      // 뒤집히는 것을 여기서 고정한다 — M19가 기대는 분기이기도 하다.
      testWidgets('미출석 상태면 시트 좌측 버튼이 `출석`이고 색이 뒤집힌다', (tester) async {
        adapter.past = <dynamic>[_reservation(status: 'NO_SHOW')];

        await pump(tester);
        await openPastTab(tester);
        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();

        final colors = AppTheme.light().extension<AppColors>()!;
        final label = tester.widget<Text>(
          find.descendant(
            of: find.byKey(_toggleKey),
            matching: find.byType(Text),
          ),
        );
        expect(label.data, '출석');
        expect(label.style?.color, colors.primary500);

        final box = tester.widget<Container>(
          find.descendant(
            of: find.byKey(_toggleKey),
            matching: find.byType(Container),
          ),
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          ReservationStatusBadge.attendedBackground,
        );

        // 본문 상태 문구도 뒤집힌다.
        expect(find.textContaining('미출석'), findsWidgets);
      });

      testWidgets('`확인`은 아무것도 보내지 않고 닫는다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);
        await openPastTab(tester);
        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();

        expect(adapter.mutations, isEmpty);
        expect(find.text('수업 정보'), findsNothing);
      });

      testWidgets('토글 성공 후 `old`를 다시 받는다', (tester) async {
        adapter.past = <dynamic>[_reservation()];

        await pump(tester);
        await openPastTab(tester);
        await tester.tap(find.text('04월 13일 월요일'));
        await tester.pumpAndSettle();
        capture.clear();
        await tester.tap(find.text('미출석'));
        await settleWithoutDismissingToast(tester);

        // 웹 `refetchQueries(['TrainerStudentLastReservationList'])`.
        expect(
          capture.captured.where(
            (r) => r.path == '/api/v1/trainers/reservation/old',
          ),
          hasLength(1),
        );

        toast.dismiss();
        await tester.pumpAndSettle();
      });
    });

    group('실패', () {
      testWidgets('다가오는 예약 조회가 실패해도 빈 상태로 뜬다', (tester) async {
        adapter.upcomingFails = true;

        await pump(tester);

        expect(find.text('예약된 수업이 없습니다.'), findsOneWidget);
      });
    });

    // 규율 #14.
    testWidgets('390pt에서 넘치지 않는다 (지난 예약 + 긴 이름)', (tester) async {
      adapter.past = <dynamic>[
        _reservation(),
        _reservation(scheduleId: 985, status: 'NO_SHOW'),
      ];

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(name: '김수한무거북이와두루미'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지난 예약'));
      await tester.pumpAndSettle();

      expect(find.text('미출석'), findsOneWidget);
    });
  });
}

const Key _toggleKey = ValueKey('TrainerManageReservationPage.toggleNoShow');
const Key _confirmKey = ValueKey('TrainerManageReservationPage.sheetConfirm');
