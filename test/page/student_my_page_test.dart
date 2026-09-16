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
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_bottom_navigation.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> me = _defaultMe();
  bool mapped = true;

  /// 응답을 붙잡아 둔다. 데이터가 오기 전 화면을 관찰하려면 필요하다.
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
      MemberApi.mePath => me,
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

/// 2026-09-15 실측 응답(`healthy-student0`)을 그대로 옮긴 것이다.
///
/// **`gym`의 id 필드명이 `gymId`가 아니라 `id`다** — `GymDto`이기 때문이고,
/// 이것을 `gymId`로 써 두었다가 홈 두 화면이 실서버에서 빈 화면이 된 적이
/// 있다(`test/entity/gym/gym_test.dart`).
Map<String, dynamic> _defaultMe() => <String, dynamic>{
  'id': 6,
  'userId': 'healthy-student0',
  'email': 'healthy-student0@geonganghaejim.site',
  'name': '차은우',
  'profile': null,
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'memberType': 'STUDENT',
  'pushAlarmStatus': 'DISABLE',
  'communityAlarmStatus': 'DISABLE',
  'feedbackAlarmStatus': 'DISABLE',
  'scheduleNoticeStatus': 'DISABLE',
  'socialType': 'NONE',
};

void main() {
  group('StudentMyPage', () {
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

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AppToastScope(
        notifier: toast,
        child: AppToastHost(
          child: StudentMyPage(
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

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> usePhoneViewport(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// `_ProfileCard`처럼 흰 배경을 가진 Container의 렌더 크기.
    Size sizeOfTextRow(WidgetTester tester, String text) {
      final row = find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.color == Colors.white,
        ),
      );
      return tester.getSize(row.first);
    }

    group('요청 2건 — 골든 `mypage-student`', () {
      // 골든은 `har/mypage-student.har`에서 생성했다(2026-09-15, 회원 체험
      // 계정으로 `/student/mypage`를 직접 열어 캡처).
      testWidgets('들어오면 웹과 같은 요청 2건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student', capture.captured);
      });

      // **1번을 쏘는 것은 화면이 아니라 하단 네비다.** 화면이 자기 요청을
      // `addPostFrameCallback`으로 미루지 않으면 여기가 뒤집힌다.
      testWidgets('하단 네비가 먼저, 화면이 나중에 쏜다', (tester) async {
        await pump(tester);

        expect(capture.captured.map((r) => r.path).toList(), <String>[
          MemberApi.trainerMappingPath,
          MemberApi.mePath,
        ]);
      });

      // 홈 두 화면과 다른 점이다. 헤더에 알림 종이 없어 이 요청이 없다 —
      // 홈 골든을 복사해 왔다면 여기서 3건이 되어 패리티가 깨진다.
      testWidgets('빨간 점을 조회하지 않는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.where((r) => r.path.contains('notification')),
          isEmpty,
        );
      });

      testWidgets('두 요청 다 Authorization이 붙는다', (tester) async {
        await pump(tester);

        for (final request in capture.captured) {
          expect(
            request.headers.containsKey('authorization'),
            isTrue,
            reason: '${request.path} 에 토큰이 붙지 않았다',
          );
        }
      });
    });

    group('프로필 카드 — 웹 `{data && ...}`', () {
      testWidgets('이름과 아이디를 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('차은우'), findsOneWidget);
        expect(find.text('healthy-student0'), findsOneWidget);
      });

      // 웹 `data?.socialType === 'NONE' ? data.userId : data?.email`.
      testWidgets('소셜 계정이면 아이디 대신 이메일을 보여준다', (tester) async {
        adapter.me = _defaultMe()..['socialType'] = 'KAKAO';

        await pump(tester);

        expect(
          find.text('healthy-student0@geonganghaejim.site'),
          findsOneWidget,
        );
        expect(find.text('healthy-student0'), findsNothing);
      });

      // **로딩 스피너도 스켈레톤도 없다.** 웹은 카드 자체를 안 그린다.
      testWidgets('데이터가 오기 전에는 카드가 아예 없다', (tester) async {
        adapter.gate = Completer<void>();

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.text('차은우'), findsNothing);
        // 나머지 섹션은 처음부터 보인다 — 화면 전체가 가려지는 게 아니다.
        expect(find.text('지난 예약'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });

      // 웹 `useMyInfoQuery`에 `isError` 분기가 없다.
      testWidgets('요청이 실패해도 나머지 섹션은 그대로다', (tester) async {
        adapter.failingPaths.add(MemberApi.mePath);

        await pump(tester);

        expect(find.text('차은우'), findsNothing);
        expect(find.text('고객센터'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('프로필 사진이 없으면 아바타 자산을 그린다', (tester) async {
        await pump(tester);

        // `profile: null`이 기본값이다(실측 응답도 그랬다).
        expect(find.bySemanticsLabel('차은우'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('누르면 내 정보로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('차은우'));

        expect(navigated, <String>['/student/mypage/info']);
      });
    });

    group('3분할 바로가기', () {
      testWidgets('세 칸을 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('수업일지'), findsOneWidget);
        expect(find.text('식단'), findsOneWidget);
        expect(find.text('운동기록'), findsOneWidget);
      });

      testWidgets('수업일지를 누르면 수업일지로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('수업일지'));

        expect(navigated, <String>['/student/log']);
      });

      // 웹 `/student/diet?month=${dayjs(new Date()).format('YYYY-MM')}`.
      testWidgets('식단 링크에 이번 달이 쿼리로 붙는다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('식단'));

        final month = KoreanDateFormat.month(DateTime.now());
        expect(navigated, <String>['/student/diet?month=$month']);
        // 포맷이 어긋나면 서버가 못 알아듣는다 — 모양까지 본다.
        expect(month, matches(RegExp(r'^\d{4}-\d{2}$')));
      });

      testWidgets('운동기록을 누르면 운동기록으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('운동기록'));

        expect(navigated, <String>['/student/workout']);
      });
    });

    group('메뉴 5행', () {
      testWidgets('웹과 같은 순서로 다섯 행을 보여준다', (tester) async {
        await pump(tester);

        for (final label in <String>[
          '지난 예약',
          '트레이너 정보',
          '알림 설정',
          '약관 및 정책',
          '고객센터',
        ]) {
          expect(find.text(label), findsOneWidget, reason: '$label 행이 없다');
        }
      });

      testWidgets('지난 예약 링크에 이번 달이 쿼리로 붙는다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('지난 예약'));

        final month = KoreanDateFormat.month(DateTime.now());
        expect(navigated, <String>[
          '/student/mypage/last-reservation?month=$month',
        ]);
      });

      testWidgets('트레이너 정보는 매핑 여부와 무관하게 늘 보인다', (tester) async {
        // 웹 허브에는 매핑 여부 분기가 없다 — 빈 상태는 이동한 화면이 낸다.
        adapter.mapped = false;

        await pump(tester);

        expect(find.text('트레이너 정보'), findsOneWidget);
      });

      testWidgets('각 행이 웹과 같은 경로로 간다', (tester) async {
        const expected = <String, String>{
          '트레이너 정보': '/student/mypage/trainer-info',
          '알림 설정': '/student/mypage/alarm',
          // 아래 둘은 마이페이지 밑이 아니라 공개 라우트다.
          '약관 및 정책': '/policy',
          '고객센터': '/cs',
        };

        for (final entry in expected.entries) {
          navigated.clear();
          await pump(tester);

          await tapVisible(tester, find.text(entry.key));

          expect(navigated, <String>[
            entry.value,
          ], reason: '${entry.key} 가 엉뚱한 곳으로 간다');
        }
      });
    });

    group('앱 버전 행과 푸터 — 전부 하드코딩이다', () {
      testWidgets('앱 버전 행은 링크가 아니다', (tester) async {
        await pump(tester);

        expect(find.text('앱 버전'), findsOneWidget);
        expect(find.text('최신 버전'), findsOneWidget);

        await tapVisible(tester, find.text('앱 버전'));

        expect(navigated, isEmpty, reason: '웹에서 이 행은 <div>다');
      });

      // 웹 `href={'#'}` — 아무 데도 가지 않는다(서베이 BUG-11).
      testWidgets('오픈 소스 라이선스는 눌러도 아무 일도 없다', (tester) async {
        await pump(tester);

        expect(find.text('앱 버전 0.0'), findsOneWidget);

        await tapVisible(tester, find.text('오픈 소스 라이선스 보기'));

        expect(navigated, isEmpty);
      });
    });

    group('하단 네비', () {
      testWidgets('마이 탭이 활성이다', (tester) async {
        await pump(tester);

        expect(find.byType(AppBottomNavigation), findsOneWidget);
        expect(find.text('마이'), findsOneWidget);
      });

      testWidgets('홈 탭을 누르면 홈으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('홈'));

        expect(navigated, <String>['/student']);
      });

      // 학생 홈과 같은 가드다 — 네비가 갖고 있으므로 여기서도 그대로 산다.
      testWidgets('매핑이 없으면 수업예약이 막히고 토스트가 뜬다', (tester) async {
        adapter.mapped = false;

        await pump(tester);
        await tester.tap(find.text('수업예약'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(navigated, isEmpty);
        expect(
          find.text(AppBottomNavigation.scheduleBlockedMessage),
          findsOneWidget,
        );

        toast.dismiss();
        await tester.pumpAndSettle();
      });
    });

    group('치수 — 웹 실측값을 고정한다', () {
      // 2026-09-15 브라우저 실측(`getBoundingClientRect`)으로 받은 값이다.
      // 색·존재만 보는 단언은 "얼마나"를 못 잡는다(규율 #15).
      testWidgets('헤더는 흰색이고 56이다', (tester) async {
        await pump(tester);

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.white);
        expect(appBar.toolbarHeight, AppLayoutHeader.height);
      });

      testWidgets('프로필 카드 높이가 116이다', (tester) async {
        await pump(tester);

        // 아바타 80 + 위 16 + 아래 20.
        expect(sizeOfTextRow(tester, '차은우').height, 116);
      });

      testWidgets('메뉴 행 높이가 54다', (tester) async {
        await pump(tester);

        // py-[15px] 둘 + BODY_1 줄 높이 24.
        expect(sizeOfTextRow(tester, '지난 예약').height, 54);
      });

      testWidgets('바로가기 카드 폭이 320이다', (tester) async {
        await pump(tester);

        final card = find.ancestor(
          of: find.text('식단'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.maxWidth == StudentMyPage.shortcutCardWidth,
          ),
        );
        expect(tester.getSize(card.first).width, 320);
      });

      // 웹 클래스는 `w-[1px]`인데 보더가 더해져 **2px로 렌더된다**(실측).
      testWidgets('바로가기 구분선은 2 × 36이다', (tester) async {
        await pump(tester);

        final colors = AppColors.light;
        final dividers = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color == colors.gray200 &&
              w.constraints?.maxHeight == StudentMyPage.shortcutDividerHeight,
        );
        expect(dividers, findsNWidgets(2));
        expect(tester.getSize(dividers.first), const Size(2, 36));
      });
    });

    // 위젯 테스트 기본 뷰포트는 800×600인데 실기기는 ~390이고 **오버플로는
    // 좁은 쪽에서 산다**(규율 #14). 바로가기 카드는 320 고정이라 특히 빡빡하다.
    group('폰 너비(390pt)', () {
      testWidgets('기본 데이터가 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);

        await pump(tester);

        expect(tester.takeException(), isNull);
      });

      testWidgets('긴 이름과 긴 이메일이 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);
        adapter.me = _defaultMe()
          ..['socialType'] = 'KAKAO'
          ..['name'] = '아주아주기다란회원이름입니다정말로'
          ..['email'] =
              'very.long.email.address.for.overflow@geonganghaejim.site';

        await pump(tester);

        expect(tester.takeException(), isNull);
      });
    });
  });
}
