import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/course/api/course_api.dart';
import 'package:geonganghaejim/page/protected/trainer_manage_course_history_page.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

/// 골든 `trainer-manage-course-history`가 경로에 `/6`을 담고 있다
/// (`trainer-manage-member`와 같은 처리 — 캡처한 회원의 실측 응답을 그대로
/// 픽스처로 쓰므로 둘이 어긋나면 테스트가 먼저 깨져야 한다).
const int _memberId = 6;

/// 골든의 `searchDate=2026-09`를 고정한다. 넘기지 않으면 10월이 되는 순간
/// 패리티가 깨진다(`/student/mypage/last-reservation`과 같은 처리).
const String _month = '2026-09';

/// 2026-09-18 실측 응답 — 만료 수강권 + 내역 0건
/// (`docs/trainer-manage-s3-measurements.md` 산출물 ②).
///
/// **`content`가 `[]`다. `null`이 아니다** — 실서버가 준 모양 그대로다.
Map<String, dynamic> _expiredEmpty() => <String, dynamic>{
  'content': <dynamic>[],
  'pageNumber': 0,
  'pageSize': 20,
  'totalPages': 0,
  'totalElements': 0,
  'isLast': true,
  'mainData': <String, dynamic>{
    'course': <String, dynamic>{
      'courseId': 3,
      'totalLessonCnt': 10,
      'remainLessonCnt': 3,
      'completedLessonCnt': 10,
      'createdAt': '2026-03-13T14:44:48',
    },
    'gymName': '건강해짐 홍대점',
  },
};

/// 2026-09-18 실측 응답 — 내역 4건(`searchDate=2026-03`).
Map<String, dynamic> _expiredWithHistory() => <String, dynamic>{
  ..._expiredEmpty(),
  'content': <dynamic>[
    <String, dynamic>{
      'courseHistoryId': 7,
      'cnt': 1,
      'calculation': 'MINUS',
      'type': 'RESERVATION',
      'createdAt': '2026-03-29T14:44:48',
    },
    <String, dynamic>{
      'courseHistoryId': 4,
      'cnt': 10,
      'calculation': 'PLUS',
      'type': 'COURSE_CREATE',
      'createdAt': '2026-03-13T14:44:48',
    },
  ],
  'totalPages': 1,
  'totalElements': 2,
};

/// 활성(비만료) 수강권 — memberId 15 실측값(`courseId 2`, 3회 중 0회 소진).
Map<String, dynamic> _active() => <String, dynamic>{
  ..._expiredEmpty(),
  'mainData': <String, dynamic>{
    'course': <String, dynamic>{
      'courseId': 2,
      'totalLessonCnt': 3,
      'remainLessonCnt': 3,
      'completedLessonCnt': 0,
      'createdAt': '2026-03-13T14:44:48',
    },
    'gymName': '건강해짐 홍대점',
  },
};

/// 수강권 없음 — `mainData.course`가 null.
///
/// **미실측 분기다**(이 트레이너의 회원 둘 다 수강권이 있었다). 백엔드
/// `CourseGetResult.course`가 nullable이라는 계약에서 만든 모양이다.
Map<String, dynamic> _noCourse() => <String, dynamic>{
  ..._expiredEmpty(),
  'mainData': <String, dynamic>{'course': null, 'gymName': '건강해짐 홍대점'},
};

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> Function(int page) pageBuilder = (_) => _expiredEmpty();

  Completer<void>? gate;
  bool fails = false;

  /// 뮤테이션 응답을 실패로 돌린다.
  bool mutationFails = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    if (method != 'GET') {
      if (mutationFails) {
        return ResponseBody.fromString(
          '{"message":"처리할 수 없습니다."}',
          500,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'message': '처리되었습니다.', 'data': null}),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }

    if (gate != null) {
      await gate!.future;
    }
    if (fails) {
      return ResponseBody.fromString('{"message":"서버 오류"}', 500);
    }
    final page = int.tryParse('${options.queryParameters['page'] ?? 0}') ?? 0;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'message': '수강권이 조회되었습니다.',
        'data': pageBuilder(page),
        'status': 'OK',
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
  group('TrainerManageCourseHistoryPage', () {
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
      navigated = <String>[];
      backCount = 0;
      toast = AppToastController();
      addTearDown(toast.dispose);
    });

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap({String name = '차은우'}) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => AppToastScope(
        notifier: toast,
        child: AppToastHost(child: child!),
      ),
      home: TrainerManageCourseHistoryPage(
        courseApi: CourseApi(dio),
        memberId: _memberId,
        name: name,
        initialMonth: _month,
        onBack: () => backCount++,
        onNavigate: navigated.add,
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

    /// 토스트는 2초 뒤 스스로 사라진다 — `pumpAndSettle`은 그 타이머를
    /// 지나치지 않고 **남긴 채** 끝나서 테스트가 "Timer is still pending"으로
    /// 깨진다(`/student/mypage/info` 테스트와 같은 처리).
    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> dismissToast(WidgetTester tester) async {
      toast.dismiss();
      await tester.pumpAndSettle();
    }

    group('요청 — 골든 `trainer-manage-course-history`', () {
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('trainer-manage-course-history', capture.captured);
      });

      testWidgets('쿼리 셋(page·size·searchDate)을 전부 보낸다', (tester) async {
        await pump(tester);

        final query = capture.captured.single.query;
        // dio가 int를 그대로 싣는다(골든 비교기는 문자열로 정규화한다).
        expect('${query['page']}', '0');
        expect('${query['size']}', '20');
        expect(query['searchDate'], _month);
      });

      testWidgets('월을 바꾸면 그 달로 `page=0`부터 다시 받는다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.text('2026년 9월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026년 3월 선택'));
        await tester.pumpAndSettle();

        expect(capture.captured, hasLength(1));
        expect(capture.captured.single.query['searchDate'], '2026-03');
        // 새 무한쿼리라 페이지가 0으로 되돌아간다.
        expect('${capture.captured.single.query['page']}', '0');
      });
    });

    group('헤더', () {
      testWidgets('제목이 `{name}님 수강권`이다', (tester) async {
        await pump(tester);

        expect(find.text('차은우님 수강권'), findsOneWidget);
      });

      testWidgets('뒤로가기가 웹 `router.back()`이다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);
      });

      testWidgets('만료면 `+`가 뜬다', (tester) async {
        await pump(tester);

        expect(find.byKey(_plusKey), findsOneWidget);
      });

      testWidgets('활성이면 `+`가 없다', (tester) async {
        adapter.pageBuilder = (_) => _active();

        await pump(tester);

        expect(find.byKey(_plusKey), findsNothing);
      });

      // 웹 조건이 `course?.a === course?.b`라 course가 없으면
      // `undefined === undefined` → true다. 아래 둘이 그 동작을 고정한다.
      testWidgets('수강권이 없어도 `+`가 뜬다', (tester) async {
        adapter.pageBuilder = (_) => _noCourse();

        await pump(tester);

        expect(find.byKey(_plusKey), findsOneWidget);
      });

      testWidgets('응답이 오기 전(로딩 중)에도 `+`가 뜬다', (tester) async {
        adapter.pageBuilder = (_) => _active();
        adapter.gate = Completer<void>();

        useWebViewport(tester);
        await tester.pumpWidget(wrap());
        await tester.pump();

        // 활성 응답이 오면 사라질 `+`가, 아직 오지 않아 떠 있다.
        expect(find.byKey(_plusKey), findsOneWidget);

        adapter.gate!.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(_plusKey), findsNothing);
      });
    });

    group('액션 바', () {
      testWidgets('만료면 `수업 횟수 추가`가 눌리지 않는다', (tester) async {
        await pump(tester);

        await tester.tap(find.byKey(_addKey));
        await tester.pumpAndSettle();

        // 시트가 열리지 않는다.
        expect(find.text('추가할 수업횟수'), findsNothing);
      });

      testWidgets('활성이면 `수업 횟수 추가`가 시트를 연다', (tester) async {
        adapter.pageBuilder = (_) => _active();

        await pump(tester);
        await tester.tap(find.byKey(_addKey));
        await tester.pumpAndSettle();

        expect(find.text('추가할 수업횟수'), findsOneWidget);
      });

      testWidgets('만료 시 `수업 횟수 추가` 글자색이 gray400이다', (tester) async {
        await pump(tester);

        final colors = AppTheme.light().extension<AppColors>()!;
        final text = tester.widget<Text>(find.text('수업 횟수 추가'));
        expect(text.style?.color, colors.gray400);
      });

      testWidgets('치수 — 바 46, 버튼 160, 구분선 1×30', (tester) async {
        await pump(tester);

        // 리터럴로 박는다(규율 #18). 2026-09-18 실측 B11·B12·B15.
        expect(tester.getSize(find.byKey(_addKey)), const Size(160, 46));
        expect(tester.getSize(find.byKey(_deleteKey)), const Size(160, 46));

        // 바 자체의 높이 — 버튼만 재면 바가 늘어나도 통과한다(규율 #15).
        final colors = AppTheme.light().extension<AppColors>()!;
        final bar = find.ancestor(
          of: find.byKey(_addKey),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == colors.gray100,
          ),
        );
        expect(tester.getSize(bar.first).height, 46);

        // 구분선 — 조상 탐색이 아니라 **자기 색**으로 지목한다(규율 #19).
        final divider = find.byWidgetPredicate(
          (w) => w is Container && w.color == colors.gray200,
        );
        expect(divider, findsOneWidget);
        expect(tester.getSize(divider), const Size(1, 30));
      });
    });

    group('하단 네비', () {
      testWidgets('어느 탭도 활성이 아니다', (tester) async {
        await pump(tester);

        // 2026-09-18 실측: 웹의 네 라벨이 전부 같은 색(gray700)이었다 —
        // 활성 판정이 완전 일치라 이 경로는 어느 탭에도 걸리지 않는다.
        final colors = AppTheme.light().extension<AppColors>()!;
        for (final label in <String>['홈', '스케줄', '커뮤니티', '마이']) {
          final text = tester.widget<Text>(find.text(label));
          expect(
            text.style?.color,
            isNot(colors.primary500),
            reason: '$label 이 활성으로 그려졌다',
          );
        }
      });
    });

    group('내역 목록', () {
      testWidgets('빈 내역이면 문구가 뜬다', (tester) async {
        await pump(tester);

        expect(find.text('수강권 내역이 없습니다.'), findsOneWidget);
      });

      testWidgets('항목이 날짜·라벨·증감으로 렌더된다', (tester) async {
        adapter.pageBuilder = (_) => _expiredWithHistory();

        await pump(tester);

        // 웹 `dayjs(createdAt).format('YY.MM.DD')`.
        expect(find.text('26.03.29'), findsOneWidget);
        expect(find.text('수업 예약'), findsOneWidget);
        expect(find.text('-1'), findsOneWidget);

        expect(find.text('26.03.13'), findsOneWidget);
        expect(find.text('수강권 생성'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);

        // 항목이 있으면 빈 문구는 없다.
        expect(find.text('수강권 내역이 없습니다.'), findsNothing);
      });

      testWidgets('항목 높이가 87이다', (tester) async {
        adapter.pageBuilder = (_) => _expiredWithHistory();

        await pump(tester);

        // 실측 C2·C8: 24 + 18(날짜) + 21(행) + 24 = 87.
        // 글자 높이가 섞인 치수라 실제 글꼴이 실려야 나온다(규율 #17).
        final tile = find.ancestor(
          of: find.text('26.03.29'),
          matching: find.byType(Padding),
        );
        expect(tester.getSize(tile.first).height, 87);
      });
    });

    group('수강권 없음 분기', () {
      testWidgets('문구와 등록 버튼이 뜬다', (tester) async {
        adapter.pageBuilder = (_) => _noCourse();

        await pump(tester);

        expect(find.text('등록된 수강권이 없습니다.'), findsOneWidget);
        expect(find.text('수강권 등록'), findsOneWidget);
        // 액션 바는 웹에서 `course &&` 안에 있어 아예 없다.
        expect(find.byKey(_addKey), findsNothing);
        expect(find.byKey(_deleteKey), findsNothing);
      });

      testWidgets('등록 버튼 치수가 112 × 37이다', (tester) async {
        adapter.pageBuilder = (_) => _noCourse();

        await pump(tester);

        expect(
          tester.getSize(find.byKey(_registerEmptyKey)),
          const Size(112, 37),
        );
      });
    });

    group('수강권 등록 — `POST /api/v1/course`', () {
      testWidgets('입력한 횟수를 body에 실어 보낸다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_plusKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '10');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_submitKey));
        await tester.pumpAndSettle();

        final posted = capture.captured.firstWhere((r) => r.method == 'POST');
        expect(posted.path, '/api/v1/course');
        expect(posted.body, <String, dynamic>{
          'memberId': _memberId,
          'lessonCnt': 10,
        });

        // 성공 토스트의 2초 타이머를 남기지 않는다.
        await dismissToast(tester);
      });

      testWidgets('빈 입력으로는 보내지 않는다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_plusKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_submitKey));
        await tester.pumpAndSettle();

        expect(capture.captured.where((r) => r.method == 'POST'), isEmpty);
      });

      testWidgets('500을 넘으면 에러 문구가 뜨고 보내지 않는다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_plusKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '501');
        await tester.pumpAndSettle();

        expect(find.text('500회 이하로 입력해주세요.'), findsOneWidget);

        await tester.tap(find.byKey(_submitKey));
        await tester.pumpAndSettle();

        expect(capture.captured.where((r) => r.method == 'POST'), isEmpty);
      });

      testWidgets('닫기 X를 누르면 아무것도 보내지 않고 닫힌다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_plusKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '10');
        await tester.pumpAndSettle();

        // 웹 `absolute right-7 top-7` — 실측 14 × 14.
        expect(tester.getSize(find.byKey(_closeKey)), const Size(14, 14));

        await tester.tap(find.byKey(_closeKey));
        await tester.pumpAndSettle();

        expect(find.text('등록할 수업횟수'), findsNothing);
        expect(capture.captured.where((r) => r.method == 'POST'), isEmpty);
      });

      testWidgets('3자를 넘겨 입력하면 잘라낸다', (tester) async {
        await pump(tester);

        await tester.tap(find.byKey(_plusKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '12345');
        await tester.pumpAndSettle();

        expect(find.text('123'), findsOneWidget);
      });
    });

    group('수업 횟수 추가 — `PATCH /api/v1/course/{courseId}`', () {
      testWidgets('body가 계약대로 나가고 `updateCnt`가 int다', (tester) async {
        adapter.pageBuilder = (_) => _active();

        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_addKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '5');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_submitKey));
        await tester.pumpAndSettle();

        final patched = capture.captured.firstWhere((r) => r.method == 'PATCH');
        // courseId는 활성 픽스처의 2다.
        expect(patched.path, '/api/v1/course/2');
        expect(patched.body, <String, dynamic>{
          'memberId': _memberId,
          'calculation': 'PLUS',
          'type': 'PLUS_CNT',
          // 웹은 `"5"`(문자열)를 보내고 Jackson이 강제변환한다.
          // 앱은 계약대로 int를 보낸다 — 이 단언이 그 결정을 고정한다.
          'updateCnt': 5,
        });
        expect(
          (patched.body! as Map<String, dynamic>)['updateCnt'],
          isA<int>(),
        );

        await dismissToast(tester);
      });

      testWidgets('성공하면 입력값으로 만든 문구를 띄운다', (tester) async {
        adapter.pageBuilder = (_) => _active();

        await pump(tester);
        await tester.tap(find.byKey(_addKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '7');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_submitKey));
        await settleWithoutDismissingToast(tester);

        // 웹 `successToast(`${addInput}회가 연장되었습니다.`)` — 서버 문구가 아니다.
        expect(find.text('7회가 연장되었습니다.'), findsOneWidget);

        await dismissToast(tester);
      });
    });

    group('수강권 삭제 — `DELETE /api/v1/course/{courseId}`', () {
      testWidgets('알럿에서 `예`를 눌러야 나간다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();

        expect(find.text('수강권을 삭제하시겠습니까?'), findsOneWidget);

        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();

        final deleted = capture.captured.firstWhere(
          (r) => r.method == 'DELETE',
        );
        expect(deleted.path, '/api/v1/course/3');

        await dismissToast(tester);
      });

      testWidgets('`아니요`면 아무것도 보내지 않는다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_cancelKey));
        await tester.pumpAndSettle();

        expect(capture.captured.where((r) => r.method == 'DELETE'), isEmpty);
      });

      testWidgets('실패하면 서버 문구를 토스트로 띄운다', (tester) async {
        adapter.mutationFails = true;

        await pump(tester);
        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_confirmKey));
        await settleWithoutDismissingToast(tester);

        expect(find.text('처리할 수 없습니다.'), findsOneWidget);

        await dismissToast(tester);
      });
    });

    group('무한스크롤', () {
      testWidgets('마지막 페이지가 아니면 다음 page를 부른다', (tester) async {
        adapter.pageBuilder = (page) => <String, dynamic>{
          ..._expiredWithHistory(),
          // 20건을 채워 스크롤이 생기게 한다.
          'content': List<dynamic>.generate(
            20,
            (i) => <String, dynamic>{
              'courseHistoryId': page * 100 + i,
              'cnt': 1,
              'calculation': 'MINUS',
              'type': 'RESERVATION',
              'createdAt': '2026-03-${(i % 28) + 1}T14:44:48',
            },
          ),
          'isLast': page >= 1,
        };

        await pump(tester);
        capture.clear();

        await tester.drag(
          find.text('수강권 삭제'),
          const Offset(0, -4000),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(capture.captured, isNotEmpty);
        // 웹 `getNextPageParam: (lastPage, allPages) => allPages.length`.
        expect('${capture.captured.first.query['page']}', '1');
        expect(capture.captured.first.query['searchDate'], _month);
      });

      testWidgets('마지막 페이지면 더 부르지 않는다', (tester) async {
        await pump(tester);
        capture.clear();

        await tester.drag(
          find.text('수강권 삭제'),
          const Offset(0, -4000),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(capture.captured, isEmpty);
      });
    });

    group('실패', () {
      testWidgets('조회가 실패하면 웹처럼 수강권 없음 화면이 된다', (tester) async {
        adapter.fails = true;

        await pump(tester);

        expect(find.text('등록된 수강권이 없습니다.'), findsOneWidget);
      });
    });

    // 규율 #14 — 실기기 논리 폭에서만 드러나는 오버플로.
    testWidgets('390pt에서 넘치지 않는다 (만료 + 긴 이름 + 내역)', (tester) async {
      adapter.pageBuilder = (_) => _expiredWithHistory();

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 가장 넓어지는 데이터: 만료 분기(헤더 `+`가 함께 뜬다) + 긴 이름.
      await tester.pumpWidget(wrap(name: '김수한무거북이와두루미'));
      await tester.pumpAndSettle();

      expect(find.text('김수한무거북이와두루미님 수강권'), findsOneWidget);
    });
  });
}

const Key _plusKey = ValueKey('TrainerManageCourseHistoryPage.register');
const Key _registerEmptyKey = ValueKey(
  'TrainerManageCourseHistoryPage.registerEmpty',
);
const Key _addKey = ValueKey('TrainerManageCourseHistoryPage.add');
const Key _deleteKey = ValueKey('TrainerManageCourseHistoryPage.delete');
const Key _inputKey = ValueKey('TrainerManageCourseHistoryPage.input');
const Key _submitKey = ValueKey('TrainerManageCourseHistoryPage.submit');
const Key _closeKey = ValueKey('TrainerManageCourseHistoryPage.close');
const Key _cancelKey = ValueKey('TrainerManageCourseHistoryPage.deleteCancel');
const Key _confirmKey = ValueKey(
  'TrainerManageCourseHistoryPage.deleteConfirm',
);
