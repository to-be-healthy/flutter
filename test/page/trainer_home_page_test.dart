import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/home/api/home_api.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/entity/notification/api/notification_api.dart';
import 'package:geonganghaejim/page/protected/trainer_home_page.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_bottom_navigation.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> home = _defaultHome();
  Map<String, dynamic> me = _defaultMe();
  bool redDot = false;

  /// 응답을 붙잡아 둔다. 로딩 중 화면을 관찰하려면 응답이 와 있으면 안 된다.
  Completer<void>? gate;

  final Set<String> failingPaths = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (gate != null) {
      await gate!.future;
    }
    final path = options.path;
    if (failingPaths.contains(path)) {
      return ResponseBody.fromString('{"message":"서버 오류"}', 500);
    }
    final Object? data = switch (path) {
      HomeApi.trainerHomePath => home,
      MemberApi.mePath => me,
      NotificationApi.redDotPath => redDot,
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

Map<String, dynamic> _defaultMe() => <String, dynamic>{
  'id': 5,
  'name': '박트레이너',
  'memberType': 'TRAINER',
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
};

Map<String, dynamic> _defaultHome() => <String, dynamic>{
  'studentCount': 12,
  'bestStudents': <dynamic>[
    <String, dynamic>{'memberId': 3, 'name': '김회원', 'courseId': 9},
  ],
  'todaySchedule': <String, dynamic>{
    'trainerName': '박트레이너',
    'scheduleTotalCount': 2,
    'schedule': <dynamic>[
      <String, dynamic>{
        'scheduleId': 1,
        'lessonStartTime': '23:00:00',
        'applicantId': 7,
        'applicantName': '늦은회원',
      },
      <String, dynamic>{
        'scheduleId': 2,
        'lessonStartTime': '08:00:00',
        'applicantId': 8,
        'applicantName': '이른회원',
      },
    ],
  },
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'redDotStatus': true,
};

void main() {
  group('TrainerHomePage', () {
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

    // 라우터를 끼우지 않는다(`next-steps.md` §7-3).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(
          child: TrainerHomePage(
            homeApi: HomeApi(dio),
            memberApi: MemberApi(dio),
            notificationApi: NotificationApi(dio),
            onNavigate: navigated.add,
          ),
        ),
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// 토스트는 2초 뒤 스스로 사라진다 — `pumpAndSettle`은 그 타이머를
    /// 지나쳐 버린다(`student_home_page_test.dart`와 같은 이유).
    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    group('요청 3건 — 골든 `home-trainer`', () {
      // 골든은 `har/home-trainer.har`에서 생성했다(2026-09-15, 트레이너 체험
      // 계정). 학생 홈과 **모양이 다르다** — 1번이 `members/me`다.
      testWidgets('들어오면 웹과 같은 요청 3건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('home-trainer', capture.captured);
      });

      // 학생 홈은 1번을 하단 네비가 쐈지만 트레이너 네비에는 요청이 없다 —
      // 세 건 전부 페이지가 쏜다. 그래서 `addPostFrameCallback`이 필요 없다.
      testWidgets('세 요청 전부 페이지가 선언 순서대로 쏜다', (tester) async {
        await pump(tester);

        expect(capture.captured.map((r) => r.path).toList(), <String>[
          MemberApi.mePath,
          HomeApi.trainerHomePath,
          NotificationApi.redDotPath,
        ]);
      });

      // `AppTrainerBottomNavigation`에는 react-query 훅이 없다. 네비가
      // 요청을 쏘기 시작하면 골든이 4건이 되어 깨진다.
      testWidgets('하단 네비는 요청을 쏘지 않는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.where((r) => r.path == MemberApi.trainerMappingPath),
          isEmpty,
        );
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

      testWidgets('세 요청 전부 content-type이 없다', (tester) async {
        await pump(tester);

        for (final request in capture.captured) {
          expect(request.headers.containsKey('content-type'), isFalse);
        }
      });
    });

    group('헤더', () {
      // 트레이너 홈이 `members/me`를 부르는 이유가 이 문자열 하나다.
      testWidgets('헬스장 이름을 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('건강해짐 홍대점'), findsOneWidget);
      });

      testWidgets('members/me 가 실패하면 이름 자리가 빈다', (tester) async {
        adapter.failingPaths.add(MemberApi.mePath);
        await pump(tester);

        expect(find.text('건강해짐 홍대점'), findsNothing);
        // 나머지 화면은 그대로다.
        expect(find.text('오늘의 수업'), findsOneWidget);
      });

      testWidgets('red-dot이 true면 빨간 점을 보여준다', (tester) async {
        adapter.redDot = true;
        await pump(tester);

        expect(_redDotFinder(), findsOneWidget);
      });

      testWidgets('red-dot이 false면 점이 없다', (tester) async {
        adapter.redDot = false;
        await pump(tester);

        expect(_redDotFinder(), findsNothing);
      });

      // 웹 배너는 `absolute top-0 h-[170px]`이고 그 기준이 **헤더를 포함한**
      // 컨테이너다 — 화면 맨 위에서 170px가 파랗고 그중 56px가 헤더다.
      // 헤더(AppBar)는 본문과 별개 레이어라 본문이 그 뒤를 칠할 수 없으므로,
      // 헤더를 직접 칠하고 본문에는 나머지만 그린다. 본문에 170을 그대로
      // 그리면 226px가 되어 웹보다 56px 더 파래진다.
      testWidgets('헤더와 배너를 합친 파란 영역이 웹과 같은 170이다', (tester) async {
        await pump(tester);

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, AppColors.light.primary500);
        expect(appBar.toolbarHeight, AppLayoutHeader.height);

        final banner = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.color == AppColors.light.primary500 &&
                w.constraints?.maxHeight == TrainerHomePage.bannerBodyHeight,
          ),
        );
        expect(banner.constraints!.maxHeight, 114);
        expect(
          appBar.toolbarHeight! + banner.constraints!.maxHeight,
          TrainerHomePage.bannerHeight,
        );
      });

      testWidgets('알림을 누르면 알림 화면으로 간다', (tester) async {
        await pump(tester);

        await tester.tap(find.byKey(TrainerHomePage.alarmButtonKey));
        await tester.pumpAndSettle();

        expect(navigated, contains('/trainer/alarm'));
      });
    });

    group('오늘의 수업', () {
      testWidgets('수업 카드를 시각과 이름으로 그린다', (tester) async {
        await pump(tester);

        expect(find.text('오늘의 수업'), findsOneWidget);
        // 서버 문자열 그대로다 — 포맷하지 않는다.
        expect(find.text('23:00:00'), findsOneWidget);
        expect(find.text('08:00:00'), findsOneWidget);
        expect(find.text('늦은회원'), findsOneWidget);
      });

      // **웹 버그 BUG-1을 그대로 옮겼다.** `findClosestSchedule`이
      // `dayjs("23:00:00")` → Invalid Date라 비교가 전부 false가 되어
      // 언제나 첫 원소를 고른다. 08:00짜리가 더 가깝지만 23:00이 칠해진다.
      testWidgets('하이라이트는 가장 가까운 수업이 아니라 첫 번째다 (웹 버그)', (tester) async {
        await pump(tester);

        // **어느 카드인지까지 본다.** "하이라이트가 하나뿐"만 단언하면
        // 정렬을 고쳐 08:00을 칠해도 그대로 통과한다 — 뮤테이션으로 확인한
        // 실제 구멍이었다. 픽스처는 23:00이 첫 번째, 08:00이 두 번째다.
        expect(_isLessonHighlighted(tester, '23:00:00'), isTrue);
        expect(_isLessonHighlighted(tester, '08:00:00'), isFalse);
      });

      testWidgets('수업 카드를 누르면 그 회원 상세로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('늦은회원'));

        expect(navigated, contains('/trainer/manage/7'));
      });

      testWidgets('수업이 없으면 안내 문구를 보여준다', (tester) async {
        adapter.home = _defaultHome()
          ..['todaySchedule'] = <String, dynamic>{'schedule': <dynamic>[]};
        await pump(tester);

        expect(find.text('예약된 수업이 없습니다.'), findsOneWidget);
      });

      // **BUG-4를 그대로 옮겼다.** 웹 트레이너 홈에는 `isPending` 분기가
      // 아예 없어서, 데이터가 오기 전에는 `homeInfo?.todaySchedule.schedule
      // .length === 0`이 `undefined === 0` → 거짓이라 **자식이 하나도 없는
      // 빈 카드**가 그려진다. 학생 홈은 스피너로 이 순간을 가린다.
      testWidgets('로딩 중에는 안내 문구도 없는 빈 카드다 (웹 동작)', (tester) async {
        adapter.gate = Completer<void>();
        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('예약된 수업이 없습니다.'), findsNothing);
        // 스피너도 없다 — 넣으면 웹에 없는 화면이 된다.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // 껍데기는 이미 그려져 있다.
        expect(find.text('오늘의 수업'), findsOneWidget);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });
    });

    group('숏컷 카드', () {
      testWidgets('회원 수와 두 카드를 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('회원'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('피드백 작성'), findsOneWidget);
        expect(find.text('간편한 회원 관리와\n운동 일지 공유'), findsOneWidget);
        expect(find.text('수업 내역 관리와\n피드백 작성'), findsOneWidget);
      });

      testWidgets('회원 카드를 누르면 회원 관리로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('간편한 회원 관리와\n운동 일지 공유'));

        expect(navigated, contains('/trainer/manage'));
      });

      testWidgets('피드백 카드를 누르면 피드백 작성으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('수업 내역 관리와\n피드백 작성'));

        expect(navigated, contains('/trainer/manage/feedback'));
      });

      // Phase A 경계: 회원 추가 모달은 Phase B다. 웹은 부모 링크를
      // `preventDefault`로 막는데, Flutter는 안쪽 제스처가 먼저 잡는다 —
      // **이동하지 않는 것**이 단언의 핵심이다.
      testWidgets('회원 추가 버튼은 준비 중을 알리고 이동하지 않는다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(TrainerHomePage), warnIfMissed: false);
        await tapVisible(tester, find.text('회원'));
        navigated.clear();

        await tester.tap(_plusButtonFinder());
        await settleWithoutDismissingToast(tester);

        expect(navigated, isEmpty);
        expect(
          find.text(TrainerHomePage.dialogUnimplementedMessage),
          findsOneWidget,
        );
        toast.dismiss();
      });
    });

    group('우수 회원', () {
      testWidgets('이름과 수강권 지급 버튼을 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('김회원'), findsOneWidget);
        expect(find.text('수강권 지급'), findsOneWidget);
      });

      testWidgets('우수 회원이 없으면 섹션 자체가 없다', (tester) async {
        adapter.home = _defaultHome()..['bestStudents'] = <dynamic>[];
        await pump(tester);

        expect(find.text('수강권 지급'), findsNothing);
        expect(find.textContaining('월의 우수 회원'), findsNothing);
      });

      // **웹 버그 BUG-2를 그대로 옮겼다.** 섹션 헤더와 메달 숫자가
      // `map()` 안쪽에 있어서 회원이 N명이면 N번 반복된다. 메달 숫자도
      // `item.ranking`이 아니라 하드코딩 `'1'`이다.
      //
      // 이 단언이 결정을 고정한다 — 헤더를 리스트 밖으로 빼면 여기가 먼저
      // 깨져서 웹과 달라졌음을 알게 된다.
      testWidgets('회원이 둘이면 헤더와 메달이 두 번 나온다 (웹 버그)', (tester) async {
        adapter.home = _defaultHome()
          ..['bestStudents'] = <dynamic>[
            <String, dynamic>{'memberId': 3, 'name': '김회원', 'courseId': 9},
            <String, dynamic>{'memberId': 4, 'name': '이회원', 'courseId': 10},
          ];
        await pump(tester);

        expect(find.textContaining('월의 우수 회원'), findsNWidgets(2));
        // 2등인데도 메달 숫자가 '1'이다.
        expect(find.text('1'), findsNWidgets(2));
      });

      testWidgets('이름을 누르면 회원 상세로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('김회원'));

        expect(navigated, contains('/trainer/manage/3'));
      });

      // Phase A 경계: 확인 모달과 `PATCH /api/v1/course/{courseId}`는
      // Phase B다(공유 계정의 실제 수강권을 늘리는 뮤테이션).
      testWidgets('수강권 지급은 준비 중을 알리고 요청을 보내지 않는다', (tester) async {
        await pump(tester);
        final before = capture.captured.length;

        await tester.ensureVisible(find.text('수강권 지급'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('수강권 지급'));
        await settleWithoutDismissingToast(tester);

        expect(capture.captured, hasLength(before));
        expect(
          find.text(TrainerHomePage.dialogUnimplementedMessage),
          findsOneWidget,
        );
        toast.dismiss();
      });
    });

    group('하단 네비', () {
      testWidgets('트레이너 탭 넷을 보여준다', (tester) async {
        await pump(tester);

        for (final tab in AppTrainerBottomNavigation.tabs) {
          expect(find.text(tab.label), findsOneWidget);
        }
        // 학생 네비의 라벨이 아니다.
        expect(find.text('수업예약'), findsNothing);
        expect(find.text('스케줄'), findsOneWidget);
      });

      testWidgets('스케줄 탭은 가드 없이 바로 이동한다', (tester) async {
        await pump(tester);
        final before = capture.captured.length;

        await tester.tap(find.text('스케줄'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/trainer/schedule']);
        // 학생 네비와 달리 확인 요청을 보내지 않는다.
        expect(capture.captured, hasLength(before));
      });

      testWidgets('마이 탭도 바로 이동한다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('마이'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/trainer/mypage']);
      });
    });

    // 위젯 테스트 기본 뷰포트는 800×600인데 실기기는 논리 폭 ~390이다.
    // 회원 홈에서 이 검사가 35px 오버플로를 잡았다(규율 #14).
    group('폰 너비', () {
      Future<void> usePhoneViewport(WidgetTester tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      testWidgets('390pt에서 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);

        await pump(tester);

        expect(find.text('오늘의 수업'), findsOneWidget);
      });

      // 헬스장 이름과 회원 이름이 길면 헤더·우수 회원 행이 가장 빡빡하다.
      testWidgets('390pt에서 긴 이름들이 줄어든다', (tester) async {
        await usePhoneViewport(tester);
        adapter.me = _defaultMe()
          ..['gym'] = <String, dynamic>{
            'id': 1,
            'name': '건강해짐 홍대입구역 중앙점 프리미엄 피트니스 센터',
          };
        adapter.home = _defaultHome()
          ..['bestStudents'] = <dynamic>[
            <String, dynamic>{
              'memberId': 3,
              'name': '아주아주긴이름을가진회원님입니다',
              'courseId': 9,
            },
          ];

        await pump(tester);

        expect(find.text('수강권 지급'), findsOneWidget);
      });

      testWidgets('390pt에서 수업이 없는 상태도 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);
        adapter.home = _defaultHome()
          ..['todaySchedule'] = <String, dynamic>{'schedule': <dynamic>[]};

        await pump(tester);

        expect(find.text('예약된 수업이 없습니다.'), findsOneWidget);
      });
    });
  });
}

/// 헤더 우상단 빨간 점.
Finder _redDotFinder() => find.byWidgetPredicate((widget) {
  if (widget is! Container) {
    return false;
  }
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.shape == BoxShape.circle &&
      decoration.color == AppColors.light.point;
});

/// 그 시각의 수업 카드가 하이라이트 테두리를 갖고 있는가.
///
/// 수업 카드는 `Container`이고 시각 `Text`를 자손으로 갖는다 — 그 조상
/// `Container`의 테두리 색을 본다.
bool _isLessonHighlighted(WidgetTester tester, String time) {
  final card = tester.widgetList<Container>(
    find.ancestor(of: find.text(time), matching: find.byType(Container)),
  );
  return card.any((c) {
    final decoration = c.decoration;
    return decoration is BoxDecoration &&
        decoration.border?.top.color == TrainerHomePage.closestLessonBorder;
  });
}

/// 회원 카드 우상단의 `+` 버튼.
Finder _plusButtonFinder() => find.byWidgetPredicate(
  (widget) =>
      widget.runtimeType.toString().contains('SvgPicture') &&
      widget.toString().contains('plus.svg'),
);
