import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/date/korean_date_format.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/home/api/home_api.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/entity/notification/api/notification_api.dart';
import 'package:geonganghaejim/feature/course/ui/course_card.dart';
import 'package:geonganghaejim/feature/diet/ui/today_diet_tile.dart';
import 'package:geonganghaejim/page/protected/student_home_page.dart';
import 'package:geonganghaejim/shared/ui/app_progress.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_bottom_navigation.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

/// 경로별로 다른 응답을 돌려주는 어댑터.
///
/// 홈은 요청이 셋이고 테스트마다 응답 내용을 갈아끼워야 한다.
class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> home = _defaultHome();
  bool redDot = false;
  bool mapped = true;

  /// 실패시킬 경로. 웹의 "에러 처리 없음"을 재현하는 테스트가 쓴다.
  final Set<String> failingPaths = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (failingPaths.contains(path)) {
      return ResponseBody.fromString('{"message":"서버 오류"}', 500);
    }
    final Object? data = switch (path) {
      HomeApi.studentHomePath => home,
      NotificationApi.redDotPath => redDot,
      MemberApi.trainerMappingPath => <String, dynamic>{'mapped': mapped},
      _ => null,
    };
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

/// 모든 카드가 나오는 응답.
Map<String, dynamic> _defaultHome() => <String, dynamic>{
  'course': <String, dynamic>{
    'courseId': 3,
    'totalLessonCnt': 10,
    'remainLessonCnt': 4,
    'completedLessonCnt': 6,
  },
  'point': <String, dynamic>{
    'searchDate': '2026-09',
    'monthPoint': 120,
    'totalPoint': 980,
  },
  'rank': <String, dynamic>{
    'ranking': 3,
    'lastMonthRanking': 5,
    'totalMemberCnt': 42,
  },
  'myReservation': <String, dynamic>{
    'scheduleId': 77,
    'lessonDt': '2026-09-15',
    'lessonStartTime': '14:30:00',
    'trainerName': '김트레이너 트레이너',
  },
  'lessonHistory': <String, dynamic>{
    'id': 12,
    'content': '오늘은 하체 위주로 진행했습니다.',
    'feedbackChecked': 'UNREAD',
    'trainerProfile': null,
  },
  'diet': <String, dynamic>{
    'breakfast': <String, dynamic>{'fast': true, 'dietFile': null},
    'lunch': <String, dynamic>{'fast': false, 'dietFile': null},
    'dinner': <String, dynamic>{'fast': false, 'dietFile': null},
  },
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 강남점'},
  'redDotStatus': true,
};

void main() {
  setUpAll(KoreanDateFormat.ensureInitialized);

  group('StudentHomePage', () {
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
      toast = AppToastController();
      navigated = <String>[];
    });

    tearDown(() => toast.dispose());

    // 라우터를 끼우지 않는다(`next-steps.md` §7-3). 이동은 `onNavigate`가
    // 받은 경로로 확인하고, 실제 라우팅은 `app_test.dart`에서 본다.
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(
          child: StudentHomePage(
            homeApi: HomeApi(dio),
            notificationApi: NotificationApi(dio),
            memberApi: MemberApi(dio),
            onNavigate: navigated.add,
          ),
        ),
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    /// 화면이 800×600 뷰포트보다 길다. 카드 다섯 장이 세로로 쌓이므로
    /// 아래쪽 카드는 스크롤해야 탭할 수 있다 — 그러지 않으면 `tap()`이
    /// "outside the bounds of the root of the render tree"로 빗나간다.
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// 토스트를 단언할 때 쓴다.
    ///
    /// **`pumpAndSettle`을 쓰면 안 된다.** 토스트는 2초 뒤 스스로 사라지는
    /// 타이머를 걸고(`AppToastController.visibleDuration`), `pumpAndSettle`은
    /// 스케줄된 프레임이 없어질 때까지 시간을 진행시켜 그 타이머를 지나쳐
    /// 버린다 — 토스트가 떴다가 사라진 뒤에 단언하게 된다.
    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    group('요청 3건 — 골든 `home-student`', () {
      // 골든은 `har/home-student.har`에서 생성됐다. 로그인 직후 홈이 쏘는
      // GET 3건이고, 이 테스트가 그 골든을 **처음으로 소비한다**
      // (`next-steps.md` §6의 이월 부채가 여기서 닫힌다).
      testWidgets('들어오면 웹과 같은 요청 3건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('home-student', capture.captured);
      });

      // 골든은 **순서가 있는** 목록이고 `expectParity`가 인덱스로 대조한다.
      // 웹에서 `trainer-mapping`이 먼저인 것은 React effect가 자식(하단
      // 네비)부터 실행되기 때문인데, Flutter의 `initState`는 부모가 먼저라
      // 그대로 두면 순서가 뒤집힌다. 화면이 자기 요청을 첫 프레임 뒤로
      // 미뤄 맞춘 것이고, 이 단언이 그 배선을 고정한다.
      testWidgets('네비의 매핑 조회가 화면의 두 요청보다 먼저다', (tester) async {
        await pump(tester);

        expect(capture.captured.map((r) => r.path).toList(), <String>[
          MemberApi.trainerMappingPath,
          HomeApi.studentHomePath,
          NotificationApi.redDotPath,
        ]);
      });

      testWidgets('세 요청 전부에 Authorization이 붙는다', (tester) async {
        await pump(tester);

        for (final request in capture.captured) {
          expect(
            request.headers.containsKey('authorization'),
            isTrue,
            reason: '${request.path} 에 토큰이 붙지 않았다',
          );
        }
      });

      // 본문 없는 GET이라 브라우저가 `content-type`을 붙이지 않는다(실측).
      // `DioClient.create`가 전역 `contentType`을 지정하지 않는 것이 전제다.
      testWidgets('세 요청 전부 content-type이 없다', (tester) async {
        await pump(tester);

        for (final request in capture.captured) {
          expect(request.headers.containsKey('content-type'), isFalse);
        }
      });
    });

    group('헤더', () {
      testWidgets('red-dot이 true면 빨간 점을 보여준다', (tester) async {
        adapter.redDot = true;
        await pump(tester);

        expect(_redDotFinder(tester), findsOneWidget);
      });

      testWidgets('red-dot이 false면 점이 없다', (tester) async {
        adapter.redDot = false;
        await pump(tester);

        expect(_redDotFinder(tester), findsNothing);
      });

      // 웹 `useHomeAlarmQuery`에는 에러 처리가 전혀 없다 — 실패하면 점이
      // 안 찍힐 뿐 화면은 정상이다.
      testWidgets('red-dot 요청이 실패해도 화면은 그대로다', (tester) async {
        adapter.failingPaths.add(NotificationApi.redDotPath);
        await pump(tester);

        expect(_redDotFinder(tester), findsNothing);
        expect(find.text('오늘 식단'), findsOneWidget);
      });

      testWidgets('알림 아이콘을 누르면 알림 화면으로 간다', (tester) async {
        await pump(tester);

        await tester.tap(find.byKey(StudentHomePage.alarmButtonKey));
        await tester.pumpAndSettle();

        expect(navigated, contains('/student/alarm'));
      });
    });

    group('수강권 카드', () {
      testWidgets('남은 횟수와 헬스장 이름을 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('4회 예약할 수 있어요!'), findsOneWidget);
        expect(find.text('건강해짐 강남점'), findsOneWidget);
        expect(find.text('PT 10회 수강권'), findsOneWidget);
      });

      testWidgets('진행률이 completed/total 이다', (tester) async {
        await pump(tester);

        expect(tester.widget<AppProgress>(find.byType(AppProgress)).value, 60);
      });

      testWidgets('만료되면 문구와 진행바 색이 바뀐다', (tester) async {
        adapter.home = _defaultHome()
          ..['course'] = <String, dynamic>{
            'totalLessonCnt': 10,
            'remainLessonCnt': 0,
            'completedLessonCnt': 10,
          };
        await pump(tester);

        expect(find.text('10회 PT수강 만료'), findsOneWidget);
        final progress = tester.widget<AppProgress>(find.byType(AppProgress));
        expect(progress.value, 100);
        expect(progress.barColor, AppColors.light.gray400);
      });

      // 웹은 만료된 수강권의 하단을 **접히지 않는 고정 바**로 둔다.
      testWidgets('만료되면 눌러도 포인트가 펼쳐지지 않는다', (tester) async {
        adapter.home = _defaultHome()
          ..['course'] = <String, dynamic>{
            'totalLessonCnt': 10,
            'remainLessonCnt': 0,
            'completedLessonCnt': 10,
          };
        await pump(tester);

        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();

        expect(find.text('이번달 포인트'), findsNothing);
      });

      testWidgets('수강권이 없으면 안내 박스만 보여준다', (tester) async {
        adapter.home = _defaultHome()..['course'] = null;
        await pump(tester);

        expect(find.text('현재 등록된 수강권이 없습니다.'), findsOneWidget);
        expect(find.byType(CourseCard), findsNothing);
      });

      // **웹 버그를 그대로 옮긴 것이다**(사용자 결정 2026-09-15).
      // 포인트/랭킹 UI가 `{data?.course && (...)}` 안쪽에 중첩돼 있어서,
      // 응답에 `point`·`rank`가 있어도 수강권이 없으면 통째로 사라진다.
      // 이 단언이 그 결정을 고정한다 — 고칠 때는 웹도 함께 고친다.
      testWidgets('수강권이 없으면 포인트·랭킹이 통째로 사라진다 (웹 버그)', (tester) async {
        adapter.home = _defaultHome()..['course'] = null;
        await pump(tester);

        expect(find.textContaining('활동 포인트'), findsNothing);
        expect(find.text('랭킹'), findsNothing);
      });
    });

    group('포인트 펼침', () {
      testWidgets('처음에는 접혀 있고 이번 달 점수만 보인다', (tester) async {
        await pump(tester);

        expect(find.text('9월 활동 포인트'), findsOneWidget);
        expect(find.text('이번달 포인트'), findsNothing);
      });

      testWidgets('누르면 포인트·랭킹 카드가 펼쳐진다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();

        expect(find.text('이번달 포인트'), findsOneWidget);
        expect(find.text('랭킹'), findsOneWidget);
        expect(find.text('누적 980'), findsOneWidget);
        expect(find.text('총 42명'), findsOneWidget);
      });

      testWidgets('펼친 뒤 포인트 카드를 누르면 포인트 내역으로 간다', (tester) async {
        await pump(tester);
        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('이번달 포인트'));

        expect(navigated, contains('/student/point-history'));
      });

      testWidgets('랭킹이 999면 "-"로 적는다', (tester) async {
        adapter.home = _defaultHome()
          ..['rank'] = <String, dynamic>{
            'ranking': 999,
            'lastMonthRanking': 999,
            'totalMemberCnt': 42,
          };
        await pump(tester);
        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });
    });

    // 사용자 결정(2026-09-15): 버그째 이관하고 기록한다.
    // 웹 `searchDate.split('-')[1].split('')[1]`이 01~09월에만 우연히 맞는다.
    group('월 표시 — 웹 버그를 그대로 옮겼다', () {
      Future<void> pumpWithMonth(WidgetTester tester, String searchDate) async {
        adapter.home = _defaultHome()
          ..['point'] = <String, dynamic>{
            'searchDate': searchDate,
            'monthPoint': 120,
            'totalPoint': 980,
          };
        await pump(tester);
      }

      testWidgets('9월은 "9월 활동 포인트"', (tester) async {
        await pumpWithMonth(tester, '2026-09');
        expect(find.text('9월 활동 포인트'), findsOneWidget);
      });

      testWidgets('10월은 "0월 활동 포인트"가 된다 (웹 버그)', (tester) async {
        await pumpWithMonth(tester, '2026-10');
        expect(find.text('0월 활동 포인트'), findsOneWidget);
      });

      testWidgets('12월은 "2월 활동 포인트"가 된다 (웹 버그)', (tester) async {
        await pumpWithMonth(tester, '2026-12');
        expect(find.text('2월 활동 포인트'), findsOneWidget);
      });
    });

    group('다음 PT예정일 카드', () {
      // 서버가 원시 `LocalDate`/`LocalTime`을 주고 화면이 ko 로케일로
      // 포맷한다. 2026-09-15는 화요일.
      testWidgets('날짜와 시각을 ko 로케일로 포맷한다', (tester) async {
        await pump(tester);

        expect(find.text('다음 PT예정일'), findsOneWidget);
        expect(find.text('09.15 (화) 오후 02:30'), findsOneWidget);
      });

      testWidgets('예약이 없으면 카드가 없다', (tester) async {
        adapter.home = _defaultHome()..['myReservation'] = null;
        await pump(tester);

        expect(find.text('다음 PT예정일'), findsNothing);
      });

      testWidgets('누르면 예약 탭으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('다음 PT예정일'));

        expect(navigated, contains('/student/schedule?tab=myReservation'));
      });
    });

    group('수업 일지 카드', () {
      testWidgets('내용과 미확인 배지를 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('수업 일지'), findsOneWidget);
        expect(find.text('오늘은 하체 위주로 진행했습니다.'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('READ면 배지가 없다', (tester) async {
        adapter.home = _defaultHome()
          ..['lessonHistory'] = <String, dynamic>{
            'id': 12,
            'content': '오늘은 하체 위주로 진행했습니다.',
            'feedbackChecked': 'READ',
          };
        await pump(tester);

        expect(find.text('1'), findsNothing);
      });

      testWidgets('일지가 없으면 카드가 없다', (tester) async {
        adapter.home = _defaultHome()..['lessonHistory'] = null;
        await pump(tester);

        expect(find.text('수업 일지'), findsNothing);
      });

      testWidgets('본문을 누르면 그 일지로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('오늘은 하체 위주로 진행했습니다.'));

        expect(navigated, contains('/student/log/12'));
      });

      testWidgets('"수업전체"를 누르면 목록으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('수업전체'));

        expect(navigated, contains('/student/log'));
      });
    });

    group('오늘 식단 카드', () {
      testWidgets('타일 셋을 그린다', (tester) async {
        await pump(tester);

        expect(find.byType(TodayDietTile), findsNWidgets(3));
        expect(find.text('단식'), findsOneWidget);
      });

      testWidgets('식단이 없으면 카드는 남고 타일만 없다', (tester) async {
        adapter.home = _defaultHome()..['diet'] = null;
        await pump(tester);

        expect(find.text('오늘 식단'), findsOneWidget);
        expect(find.byType(TodayDietTile), findsNothing);
      });

      // Phase A는 타일 렌더까지다(사용자 결정). 탭했을 때 아무 일도 없으면
      // 죽은 UI로 보이므로, 미구현임이 드러나야 한다.
      testWidgets('타일을 누르면 준비 중임을 알린다 (Phase B 경계)', (tester) async {
        await pump(tester);

        await tester.ensureVisible(find.byType(TodayDietTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TodayDietTile).first);
        await settleWithoutDismissingToast(tester);

        expect(find.text('식단 사진 등록은 준비 중입니다.'), findsOneWidget);
        toast.dismiss();
      });

      testWidgets('"식단전체"는 이번 달 쿼리를 달고 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('식단전체'));

        final month = KoreanDateFormat.month(DateTime.now());
        expect(navigated, contains('/student/diet?month=$month'));
      });
    });

    group('개인 운동 기록 카드', () {
      // 웹은 이 카드를 조건 없이 그린다.
      testWidgets('데이터가 전혀 없어도 보인다', (tester) async {
        adapter.home = <String, dynamic>{};
        await pump(tester);

        expect(find.text('개인 운동 기록'), findsOneWidget);
      });

      testWidgets('누르면 운동 기록으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('개인 운동 기록'));

        expect(navigated, contains('/student/workout'));
      });
    });

    group('하단 네비', () {
      testWidgets('탭 넷을 보여준다', (tester) async {
        await pump(tester);

        for (final tab in AppBottomNavigation.tabs) {
          expect(find.text(tab.label), findsOneWidget);
        }
      });

      testWidgets('커뮤니티 탭은 바로 이동한다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('커뮤니티'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/student/community']);
      });

      // 수업예약 탭만 가드가 있다. 누르면 매핑을 **다시** 조회한다
      // (웹 `refetch()`, `staleTime: 0`).
      testWidgets('수업예약 탭은 매핑을 다시 조회한다', (tester) async {
        await pump(tester);
        final before = capture.captured.length;

        await tester.tap(find.text('수업예약'));
        await tester.pumpAndSettle();

        expect(capture.captured.length, before + 1);
        expect(capture.captured.last.path, MemberApi.trainerMappingPath);
      });

      testWidgets('매핑이 있으면 예약 화면으로 간다', (tester) async {
        adapter.mapped = true;
        await pump(tester);

        await tester.tap(find.text('수업예약'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/student/schedule']);
      });

      testWidgets('매핑이 없으면 토스트를 띄우고 이동하지 않는다', (tester) async {
        adapter.mapped = false;
        await pump(tester);

        await tester.tap(find.text('수업예약'));
        await settleWithoutDismissingToast(tester);

        expect(navigated, isEmpty);
        expect(
          find.text(AppBottomNavigation.scheduleBlockedMessage),
          findsOneWidget,
        );
        toast.dismiss();
      });

      // 웹은 `mapped: false`와 요청 실패를 구별하지 않는다 — 같은 토스트다.
      testWidgets('매핑 조회가 실패해도 같은 토스트를 띄운다', (tester) async {
        await pump(tester);
        adapter.failingPaths.add(MemberApi.trainerMappingPath);

        await tester.tap(find.text('수업예약'));
        await settleWithoutDismissingToast(tester);

        expect(navigated, isEmpty);
        expect(
          find.text(AppBottomNavigation.scheduleBlockedMessage),
          findsOneWidget,
        );
        toast.dismiss();
      });
    });

    // 위젯 테스트 기본 뷰포트는 800×600인데 **실기기는 논리 폭 ~390이다.**
    // 오버플로는 좁은 쪽에서 살고, 실제로 이 작업에서 터진 오버플로
    // (`_PointTitle`, 16px)도 800px에서 나왔다 — 거기를 안 보면 넘치는 채로
    // 통과한다. `/student`는 로그인 게이트 뒤라 `INITIAL_LOCATION`만으로
    // 실기기에서 열 수 없으므로(규율 #9), **이 테스트가 그 자리를 대신한다.**
    //
    // 디버그 빌드에서 `RenderFlex overflowed`는 예외로 올라오고
    // `testWidgets`가 그것을 실패로 잡는다. 펌프만 해도 검증이 된다.
    group('폰 너비', () {
      Future<void> usePhoneViewport(WidgetTester tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      testWidgets('390pt에서 카드 다섯 장이 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);

        await pump(tester);

        expect(find.text('오늘 식단'), findsOneWidget);
      });

      // 포인트 상세가 가장 빡빡하다: 130px 카드 둘 + `ml-3`(8) +
      // 각 카드 `p-6`(16×2) + 본문 `p-7`(20×2).
      testWidgets('390pt에서 포인트 상세를 펼쳐도 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);
        await pump(tester);

        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();

        expect(find.text('이번달 포인트'), findsOneWidget);
      });

      // 헬스장 이름이 길면 `_Header`의 `Flexible`이 실제로 줄이는지 본다 —
      // 웹은 flex 자식이라 저절로 줄어들지만 Flutter Row는 넘친다.
      testWidgets('390pt에서 긴 헬스장 이름이 줄어든다', (tester) async {
        await usePhoneViewport(tester);
        adapter.home = _defaultHome()
          ..['gym'] = <String, dynamic>{
            'id': 1,
            'name': '건강해짐 강남대로 중앙점 프리미엄 피트니스 센터 2호점',
          };

        await pump(tester);

        expect(find.text('PT 10회 수강권'), findsOneWidget);
      });

      // 만료 분기는 하단이 고정 바로 바뀐다 — 펼침형과 레이아웃이 다르다.
      testWidgets('390pt에서 만료 수강권도 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);
        adapter.home = _defaultHome()
          ..['course'] = <String, dynamic>{
            'totalLessonCnt': 100,
            'remainLessonCnt': 0,
            'completedLessonCnt': 100,
          };

        await pump(tester);

        expect(find.text('100회 PT수강 만료'), findsOneWidget);
      });
    });

    group('로딩·실패', () {
      testWidgets('홈 응답이 오기 전에는 로딩만 보인다', (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('오늘 식단'), findsNothing);

        await tester.pumpAndSettle();
      });

      // 웹 `useStudentHomeDataQuery`에 `isError` 분기가 없어서, 네트워크
      // 에러가 "수강권 없음" 화면과 **시각적으로 동일**해진다. 명시적
      // 이탈 없이 그 동작을 옮겼고 `deferred-minors.md`에 기록했다.
      testWidgets('홈 요청이 실패하면 수강권 없음 화면과 같아진다 (웹 동작)', (tester) async {
        adapter.failingPaths.add(HomeApi.studentHomePath);
        await pump(tester);

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('현재 등록된 수강권이 없습니다.'), findsOneWidget);
        expect(find.text('개인 운동 기록'), findsOneWidget);
      });
    });
  });
}

/// 헤더 우상단 빨간 점.
Finder _redDotFinder(WidgetTester tester) => find.byWidgetPredicate((widget) {
  if (widget is! Container) {
    return false;
  }
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.shape == BoxShape.circle &&
      decoration.color == AppColors.light.point;
});
