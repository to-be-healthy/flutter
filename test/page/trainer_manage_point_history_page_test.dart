import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/router/app_router.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/entity/point/api/point_api.dart';
import 'package:geonganghaejim/entity/trainer/api/trainer_api.dart';
import 'package:geonganghaejim/page/protected/trainer_manage_point_history_page.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_month_picker.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

const int _memberId = 6;
const String _month = '2026-09';

/// 2026-09-18 실측 응답 — 내역 0건 (2026-09)
/// (`docs/trainer-manage-s4-measurements.md` 산출물 ②).
Map<String, dynamic> _emptyPoint() => <String, dynamic>{
  'content': <dynamic>[],
  'pageNumber': 0,
  'pageSize': 20,
  'totalPages': 0,
  'totalElements': 0,
  'isLast': true,
  'mainData': <String, dynamic>{
    'searchDate': '2026-09',
    'monthPoint': 0,
    'totalPoint': 85,
  },
};

/// 2026-09-18 실측 응답 — 2026-04의 항목 모양.
Map<String, dynamic> _withHistory() => <String, dynamic>{
  ..._emptyPoint(),
  'content': <dynamic>[
    <String, dynamic>{
      'pointId': 12,
      'type': 'DIET',
      'calculation': 'PLUS',
      'point': 5,
      'createdAt': '2026-04-11T14:47:52',
    },
    <String, dynamic>{
      'pointId': 11,
      'type': 'WORKOUT',
      'calculation': 'PLUS',
      'point': 10,
      'createdAt': '2026-04-10T14:47:52',
    },
    <String, dynamic>{
      'pointId': 10,
      'type': 'NO_SHOW',
      'calculation': 'MINUS',
      'point': 5,
      'createdAt': '2026-04-09T14:47:52',
    },
  ],
  'mainData': <String, dynamic>{
    'searchDate': '2026-04',
    'monthPoint': 85,
    'totalPoint': 85,
  },
  'totalPages': 1,
  'totalElements': 3,
};

/// S2와 같은 엔드포인트의 응답. **이 화면은 `name` 하나만 쓴다.**
Map<String, dynamic> _memberDetail() => <String, dynamic>{
  'memberId': _memberId,
  'name': '차은우',
  'nickName': null,
  'fileUrl': null,
  'memo': null,
  'ranking': 999,
  'lessonDt': null,
  'lessonStartTime': null,
  'diet': null,
  'course': null,
  'point': null,
  'rank': <String, dynamic>{
    'ranking': 999,
    'lastMonthRanking': 999,
    'totalMemberCnt': 2,
  },
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'isNonmember': false,
};

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> Function(int page) pageBuilder = (_) => _emptyPoint();

  Completer<void>? gate;
  bool pointFails = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic> body;

    if (options.path.contains('trainer-mapping')) {
      body = <String, dynamic>{
        'message': '매핑 여부가 조회되었습니다.',
        'data': <String, dynamic>{'mapped': false},
      };
    } else if (options.path.contains('/trainers/members/')) {
      body = <String, dynamic>{'message': '조회되었습니다.', 'data': _memberDetail()};
    } else {
      if (gate != null) {
        await gate!.future;
      }
      if (pointFails) {
        return ResponseBody.fromString('{"message":"서버 오류"}', 500);
      }
      final page = int.tryParse('${options.queryParameters['page'] ?? 0}') ?? 0;
      body = <String, dynamic>{
        'message': '포인트가 조회되었습니다.',
        'data': pageBuilder(page),
      };
    }

    return ResponseBody.fromString(
      jsonEncode(body),
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
  group('TrainerManagePointHistoryPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
    late AppToastController toast;
    late List<String> navigated;

    setUp(() {
      capture = RequestCapture();
      adapter = _StubAdapter();
      dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: FakeTokenStorage(access: 'a', refresh: 'r'),
        extra: <Interceptor>[capture],
      );
      dio.httpClientAdapter = adapter;
      navigated = <String>[];
      toast = AppToastController();
      addTearDown(toast.dispose);
    });

    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => AppToastScope(
        notifier: toast,
        child: AppToastHost(child: child!),
      ),
      home: TrainerManagePointHistoryPage(
        trainerApi: TrainerApi(dio),
        pointApi: PointApi(dio),
        memberApi: MemberApi(dio),
        memberId: _memberId,
        initialMonth: _month,
        onNavigate: navigated.add,
      ),
    );

    void useWebViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(440 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> pump(WidgetTester tester) async {
      useWebViewport(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    group('요청 3건 — 골든 `trainer-manage-point-history`', () {
      testWidgets('들어오면 웹과 같은 요청 3건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('trainer-manage-point-history', capture.captured);
      });

      // **이 테스트가 `addPostFrameCallback`을 지킨다.** 없애면 화면 요청이
      // 네비보다 먼저 나가 순서가 뒤집힌다(실측: 웹은 네비가 1번).
      testWidgets('하단바의 `trainer-mapping`이 **첫 번째**다 (BUG-1)', (tester) async {
        await pump(tester);

        expect(capture.captured.map((r) => r.path).toList(), <String>[
          '/api/v1/members/trainer-mapping',
          '/api/v1/trainers/members/$_memberId',
          '/api/v1/members/$_memberId/point',
        ]);
      });

      testWidgets('포인트 요청이 쿼리 셋을 전부 보낸다', (tester) async {
        await pump(tester);

        final point = capture.captured.last.query;
        expect('${point['page']}', '0');
        expect('${point['size']}', '20');
        expect(point['searchDate'], _month);
      });

      testWidgets('월을 바꾸면 포인트만 다시 받는다 (이름은 아니다)', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('4월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026년 4월 선택'));
        await tester.pumpAndSettle();

        // 실측: 월을 바꾸면 3번만 새 `searchDate`로 나간다.
        expect(capture.captured, hasLength(1));
        expect(
          capture.captured.single.path,
          '/api/v1/members/$_memberId/point',
        );
        expect(capture.captured.single.query['searchDate'], '2026-04');
        expect('${capture.captured.single.query['page']}', '0');
      });
    });

    group('헤더', () {
      testWidgets('제목이 `{name}님 포인트`다 — 이름은 2번 요청에서 온다', (tester) async {
        await pump(tester);

        expect(find.text('차은우님 포인트'), findsOneWidget);
      });

      // 웹 `<Link href='./'>`는 **뒤로가기가 아니다.** 어디서 들어왔든
      // `/trainer/manage/{memberId}`로 간다(실측으로 확인).
      testWidgets('X를 누르면 회원 정보(S2)로 간다', (tester) async {
        await pump(tester);

        await tester.tapAt(const Offset(27, 23));
        await tester.pumpAndSettle();

        expect(navigated, <String>[AppRoutes.trainerManageMember(_memberId)]);
      });

      // 실측: 링크 가운데 클릭이 제목에 막혔다(`intercepts pointer events`).
      testWidgets('제목 자리는 눌리지 않는다 (웹에서 제목이 링크를 덮는다)', (tester) async {
        await pump(tester);

        await tester.tap(find.text('차은우님 포인트'));
        await tester.pumpAndSettle();

        expect(navigated, isEmpty);
      });
    });

    group('포인트 카드', () {
      testWidgets('월 라벨·이번달·누적을 그린다', (tester) async {
        await pump(tester);

        // BUG-3: `'2026-09'.split('-')[1][1]` = `'9'`.
        expect(find.text('9월 활동 포인트'), findsOneWidget);
        expect(find.text('누적'), findsOneWidget);
        expect(find.text('85'), findsOneWidget);
      });

      testWidgets('이번 달 포인트를 그린다', (tester) async {
        // **0으로 확인하지 않는다** — 트리에 다른 `0`이 있으면 단언이
        // 통과하면서 아무것도 지키지 않는다. 고유한 값으로 잡는다.
        adapter.pageBuilder = (_) => <String, dynamic>{
          ..._emptyPoint(),
          'mainData': <String, dynamic>{
            'searchDate': '2026-09',
            'monthPoint': 7,
            'totalPoint': 85,
          },
        };

        await pump(tester);

        expect(find.text('7'), findsOneWidget);
      });

      // **BUG-3을 뮤테이션으로 지킨다.** 10~12월이 0·1·2월이 되는 것은 웹 버그를
      // 그대로 옮긴 결과이고, 누가 "고치면" 이 단언이 먼저 깨져야 한다.
      testWidgets('12월이 `2월 활동 포인트`가 된다 (웹 버그 그대로)', (tester) async {
        adapter.pageBuilder = (_) => <String, dynamic>{
          ..._emptyPoint(),
          'mainData': <String, dynamic>{
            'searchDate': '2026-12',
            'monthPoint': 3,
            'totalPoint': 88,
          },
        };

        await pump(tester);

        expect(find.text('2월 활동 포인트'), findsOneWidget);
        expect(find.text('12월 활동 포인트'), findsNothing);
      });

      testWidgets('`누적`이 Tailwind 기본 blue-100이다 (BUG-14는 버그가 아니었다)', (
        tester,
      ) async {
        await pump(tester);

        // 실측 `rgb(219,234,254)` = #DBEAFE. 서베이는 이 클래스가 생성되지
        // 않는다고 적었지만 `theme.extend`라 기본 팔레트가 살아 있다.
        final text = tester.widget<Text>(find.text('누적'));
        expect(text.style?.color, const Color(0xFFDBEAFE));
      });

      // **실측 B2 — S3 수강권 화면과 반대다.** 거기는 `justify-end`라 x=338,
      // 여기는 그 클래스가 없어 x=20이다. 이 단언이 없으면 정렬을 뒤집어도
      // 테스트가 전부 통과한다.
      testWidgets('월 선택이 좌측 정렬이다 (S3는 우측)', (tester) async {
        await pump(tester);

        expect(tester.getTopLeft(find.byType(AppMonthPicker)).dx, 20);
      });

      testWidgets('안내문을 그린다', (tester) async {
        await pump(tester);

        expect(find.text('활동 포인트는 매월 1일 자정 초기화됩니다.'), findsOneWidget);
      });
    });

    group('내역 목록', () {
      testWidgets('빈 내역이면 문구가 뜬다', (tester) async {
        await pump(tester);

        expect(find.text('포인트 내역이 없습니다.'), findsOneWidget);
      });

      testWidgets('항목을 날짜·라벨·증감으로 그린다', (tester) async {
        adapter.pageBuilder = (_) => _withHistory();

        await pump(tester);

        expect(find.text('26.04.11'), findsOneWidget);
        expect(find.text('식단등록'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);

        expect(find.text('개인운동'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);

        // `MINUS`는 부호가 -다.
        expect(find.text('노쇼'), findsOneWidget);
        expect(find.text('-5'), findsOneWidget);
      });

      // **서베이가 "S3와 동일 형태"라고 적었지만 날짜 굵기가 다르다.**
      // 실측: S3는 `BODY_4_MEDIUM`(500), S4는 `BODY_4`(400).
      testWidgets('날짜가 BODY_4(400)다 — S3의 500이 아니다', (tester) async {
        adapter.pageBuilder = (_) => _withHistory();

        await pump(tester);

        final date = tester.widget<Text>(find.text('26.04.11'));
        expect(date.style?.fontWeight, FontWeight.w400);
        expect(
          date.style?.fontWeight,
          isNot(AppTypography.body4Medium.fontWeight),
        );
      });

      testWidgets('항목 높이가 87이다', (tester) async {
        adapter.pageBuilder = (_) => _withHistory();

        await pump(tester);

        // 실측 C1: 24 + 18(날짜) + 21(행) + 24 = 87.
        final tile = find.ancestor(
          of: find.text('26.04.11'),
          matching: find.byType(Padding),
        );
        expect(tester.getSize(tile.first).height, 87);
      });
    });

    group('하단바 — BUG-1', () {
      testWidgets('학생 네비가 붙는다 (트레이너 네비가 아니다)', (tester) async {
        await pump(tester);

        // 웹 실측: 링크가 `/student`·`/student/community`·`/student/mypage`.
        expect(find.text('수업예약'), findsOneWidget);
        expect(find.text('스케줄'), findsNothing);
      });

      testWidgets('어느 탭도 활성이 아니다', (tester) async {
        await pump(tester);

        final colors = AppTheme.light().extension<AppColors>()!;
        for (final label in <String>['홈', '수업예약', '커뮤니티', '마이']) {
          final text = tester.widget<Text>(find.text(label));
          expect(
            text.style?.color,
            isNot(colors.primary500),
            reason: '$label 이 활성으로 그려졌다',
          );
        }
      });
    });

    group('로딩·실패', () {
      testWidgets('응답 전에는 웹처럼 raw `Loading..`을 그린다 (BUG-13)', (tester) async {
        adapter.gate = Completer<void>();

        useWebViewport(tester);
        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.pump();

        expect(find.text('Loading..'), findsOneWidget);

        adapter.gate!.complete();
        await tester.pumpAndSettle();

        expect(find.text('Loading..'), findsNothing);
      });

      testWidgets('포인트 조회가 실패해도 화면이 뜬다 (웹에 에러 분기가 없다)', (tester) async {
        adapter.pointFails = true;

        await pump(tester);

        // 이름은 따로 오므로 제목은 살아 있고, 카드는 0으로 그려진다.
        expect(find.text('차은우님 포인트'), findsOneWidget);
        expect(find.text('포인트 내역이 없습니다.'), findsOneWidget);
      });
    });

    group('무한스크롤', () {
      testWidgets('마지막 페이지가 아니면 다음 page를 부른다', (tester) async {
        adapter.pageBuilder = (page) => <String, dynamic>{
          ..._emptyPoint(),
          'content': List<dynamic>.generate(
            20,
            (i) => <String, dynamic>{
              'pointId': page * 100 + i,
              'type': 'DIET',
              'calculation': 'PLUS',
              'point': 5,
              'createdAt': '2026-04-${(i % 28) + 1}T14:47:52',
            },
          ),
          'isLast': page >= 1,
        };

        await pump(tester);
        capture.clear();

        await tester.drag(
          find.text('누적'),
          const Offset(0, -4000),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(capture.captured, isNotEmpty);
        expect('${capture.captured.first.query['page']}', '1');
      });

      testWidgets('마지막 페이지면 더 부르지 않는다', (tester) async {
        adapter.pageBuilder = (_) => _withHistory();

        await pump(tester);
        capture.clear();

        await tester.drag(
          find.text('누적'),
          const Offset(0, -4000),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(capture.captured, isEmpty);
      });
    });

    // 규율 #14.
    testWidgets('390pt에서 넘치지 않는다 (긴 이름 + 내역)', (tester) async {
      adapter.pageBuilder = (_) => _withHistory();

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('차은우님 포인트'), findsOneWidget);
    });
  });
}
