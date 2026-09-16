import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geonganghaejim/entity/auth/model/auth_state.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';
import 'package:geonganghaejim/entity/auth/ui/auth_scope.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_info_page.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> me = _defaultMe();

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
      return ResponseBody.fromString(
        '{"message":"로그아웃에 실패했습니다.","code":"400"}',
        500,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    // **로그아웃 응답에는 본문이 없다** — 컨트롤러가 `void`를 반환한다.
    if (path == MemberApi.logoutPath) {
      return ResponseBody.fromString('', 200);
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 200,
        'message': '성공',
        'data': path == MemberApi.mePath ? me : null,
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

/// 2026-09-15 실측 응답(`healthy-student0`). `gym`의 id 필드명은 `id`다.
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
  group('StudentMyPageInfoPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
    late AppToastController toast;
    late List<String> navigated;
    late int backCount;
    late FakeTokenStorage tokens;
    late FakeAuthProfileStorage profile;
    late AuthState auth;

    setUp(() {
      capture = RequestCapture();
      adapter = _StubAdapter();
      tokens = FakeTokenStorage(access: 'a', refresh: 'r');
      profile = FakeAuthProfileStorage(
        user: const AuthUser(
          memberId: 6,
          name: '차은우',
          userId: 'healthy-student0',
          memberType: 'STUDENT',
          gymId: 1,
        ),
      );
      dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: tokens,
        extra: <Interceptor>[capture],
      );
      dio.httpClientAdapter = adapter;
      toast = AppToastController();
      auth = AuthState(tokens, profile);
      navigated = <String>[];
      backCount = 0;
    });

    tearDown(() {
      toast.dispose();
      auth.dispose();
    });

    // 라우터를 끼우지 않는다(규율 #3). `AuthScope`는 로그아웃이 쓰므로 둔다 —
    // 앱에서도 `MaterialApp.router`의 builder가 트리 전체를 감싼다.
    /// [key]를 주면 **State가 새로 만들어진다.** 같은 테스트 안에서 응답을
    /// 바꿔 다시 펌프할 때 필요하다 — 키가 없으면 Flutter가 기존 Element를
    /// 재사용해 `initState`가 다시 돌지 않고, 바꾼 응답이 반영되지 않는다.
    Widget wrap({Key? key}) => MaterialApp(
      theme: AppTheme.light(),
      home: AuthScope(
        notifier: auth,
        child: AppToastScope(
          notifier: toast,
          child: AppToastHost(
            child: StudentMyPageInfoPage(
              key: key,
              memberApi: MemberApi(dio),
              onNavigate: navigated.add,
              onBack: () => backCount++,
            ),
          ),
        ),
      ),
    );

    Future<void> pump(WidgetTester tester, {Key? key}) async {
      await tester.pumpWidget(wrap(key: key));
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// 토스트는 2초 뒤 스스로 사라진다 — `pumpAndSettle`은 그 타이머를
    /// 지나쳐 버린다(규율 #11과 같은 뿌리).
    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> usePhoneViewport(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    group('요청 1건 — 골든 `mypage-student-info`', () {
      // 골든은 `har/mypage-student-info.har`에서 생성했다(2026-09-15).
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('mypage-student-info', capture.captured);
      });

      // 허브와 갈리는 지점이다. 이 화면에는 하단 네비가 없다.
      testWidgets('하단 네비가 없어 매핑 조회를 하지 않는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.where((r) => r.path == MemberApi.trainerMappingPath),
          isEmpty,
        );
        expect(find.text('마이'), findsNothing);
      });

      testWidgets('Authorization이 붙는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.single.headers.containsKey('authorization'),
          isTrue,
        );
      });
    });

    group('본문 전체가 `{data && ...}`로 가려진다', () {
      // 허브는 프로필 카드만 가렸는데 여기는 본문 전체다.
      testWidgets('데이터가 오기 전에는 헤더만 보인다', (tester) async {
        adapter.gate = Completer<void>();

        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.byType(AppLayoutHeader), findsOneWidget);
        expect(find.text('차은우'), findsNothing);
        expect(find.text('로그아웃'), findsNothing);
        expect(find.text('이름'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });

      // 웹에 `isError` 분기가 없어 **실패와 로딩이 구분되지 않는다.**
      testWidgets('요청이 실패해도 헤더만 남고 에러 문구는 없다', (tester) async {
        adapter.failingPaths.add(MemberApi.mePath);

        await pump(tester);

        expect(find.byType(AppLayoutHeader), findsOneWidget);
        expect(find.text('로그아웃'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('뒤로가기는 데이터와 무관하게 동작한다', (tester) async {
        adapter.gate = Completer<void>();

        await tester.pumpWidget(wrap());
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(backCount, 1);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });
    });

    group('일반 계정 — 세 줄 다 링크다', () {
      testWidgets('이름·이메일·비밀번호 변경을 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('이름'), findsOneWidget);
        expect(find.text('이메일'), findsOneWidget);
        expect(find.text('비밀번호 변경'), findsOneWidget);
        // 이름은 프로필 제목과 카드 안 값, 두 군데에 나온다.
        expect(find.text('차은우'), findsNWidgets(2));
        expect(
          find.text('healthy-student0@geonganghaejim.site'),
          findsOneWidget,
        );
        // 소셜 전용 줄은 없다.
        expect(find.text('계정 연동 설정'), findsNothing);
      });

      testWidgets('각 줄이 웹과 같은 경로로 간다', (tester) async {
        const expected = <String, String>{
          '이름': '/student/mypage/edit/name',
          '이메일': '/student/mypage/edit/email',
          '비밀번호 변경': '/student/mypage/edit/password',
        };

        for (final entry in expected.entries) {
          navigated.clear();
          await pump(tester);

          await tapVisible(tester, find.text(entry.key));

          expect(navigated, <String>[
            entry.value,
          ], reason: '${entry.key} 줄이 엉뚱한 곳으로 간다');
        }
      });

      // **비밀번호 변경 줄만 값이 없다** — 라벨과 화살표뿐이다.
      testWidgets('화살표가 세 개다', (tester) async {
        await pump(tester);

        expect(_arrowFinder(), findsNWidgets(3));
      });
    });

    group('소셜 계정 — 세 줄 다 링크가 아니다', () {
      Future<void> pumpSocial(WidgetTester tester, String socialType) async {
        adapter.me = _defaultMe()..['socialType'] = socialType;
        await pump(tester, key: ValueKey<String>(socialType));
      }

      testWidgets('계정 연동 설정 줄이 비밀번호 변경을 대신한다', (tester) async {
        await pumpSocial(tester, 'KAKAO');

        expect(find.text('계정 연동 설정'), findsOneWidget);
        expect(find.text('비밀번호 변경'), findsNothing);
      });

      testWidgets('화살표가 하나도 없다', (tester) async {
        await pumpSocial(tester, 'KAKAO');

        expect(_arrowFinder(), findsNothing);
      });

      testWidgets('줄을 눌러도 아무 데도 가지 않는다', (tester) async {
        await pumpSocial(tester, 'KAKAO');

        await tapVisible(tester, find.text('이름'));
        await tapVisible(tester, find.text('이메일'));

        expect(navigated, isEmpty);
      });

      testWidgets('카카오·구글·네이버는 각자 로고와 배지 색을 쓴다', (tester) async {
        // 색만으로 찾으면 **구글 배지(흰 원)가 카메라 버튼(흰 원)과 함께
        // 잡힌다.** 로고를 먼저 지목하고 그 조상 배지를 본다.
        const expected = <String, (double, Color)>{
          'KAKAO': (18, Color(0xFFFEE500)),
          'GOOGLE': (14, Colors.white),
          'NAVER': (18, Color(0xFF03C75A)),
        };

        for (final entry in expected.entries) {
          final (size, color) = entry.value;
          await pumpSocial(tester, entry.key);

          final logo = find.byWidgetPredicate(
            (w) => w is SvgPicture && w.width == size,
          );
          expect(logo, findsOneWidget, reason: '${entry.key} 로고가 없다');

          final badge = find.ancestor(
            of: logo,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
                  (w.decoration! as BoxDecoration).color == color,
            ),
          );
          expect(badge, findsOneWidget, reason: '${entry.key} 배지 색이 다르다');
        }
      });

      // 웹에 `APPLE` 분기가 없어 그 자리가 빈다 — 발명하지 않는다.
      testWidgets('애플은 배지가 없지만 줄은 남는다', (tester) async {
        await pumpSocial(tester, 'APPLE');

        expect(find.text('계정 연동 설정'), findsOneWidget);
        expect(find.byType(SizedBox), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      // `socialType !== 'NONE'`이라 **모르는 값도 소셜로 친다**(BUG-5).
      testWidgets('빈 socialType 도 소셜로 친다', (tester) async {
        adapter.me = _defaultMe()..remove('socialType');

        await pump(tester);

        expect(find.text('계정 연동 설정'), findsOneWidget);
        expect(find.text('비밀번호 변경'), findsNothing);
      });
    });

    group('로그아웃', () {
      testWidgets('POST 를 보내고 토큰·프로필을 지우고 루트로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('로그아웃'));

        expect(
          capture.captured.map((r) => '${r.method} ${r.path}').toList(),
          <String>['GET ${MemberApi.mePath}', 'POST ${MemberApi.logoutPath}'],
        );
        expect(tokens.clearCount, 1, reason: '토큰을 지워야 한다');
        expect(profile.clearCount, 1, reason: '프로필을 지워야 한다');
        expect(auth.user, isNull);
        expect(navigated, <String>['/']);
      });

      // **실패하면 로그아웃하지 않는다** — 토큰이 그대로 남는다.
      testWidgets('실패하면 서버 메시지를 띄우고 로그인 상태를 유지한다', (tester) async {
        adapter.failingPaths.add(MemberApi.logoutPath);

        await pump(tester);
        await tester.tap(find.text('로그아웃'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('로그아웃에 실패했습니다.'), findsOneWidget);
        expect(tokens.clearCount, 0, reason: '토큰이 남아야 한다');
        expect(tokens.access, 'a');
        expect(navigated, isEmpty);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      // 실패 뒤 다시 누를 수 있어야 한다 — 재진입 가드가 풀리지 않으면
      // 화면이 영영 잠긴다.
      testWidgets('실패 뒤에 다시 시도할 수 있다', (tester) async {
        adapter.failingPaths.add(MemberApi.logoutPath);

        await pump(tester);
        await tester.tap(find.text('로그아웃'));
        await settleWithoutDismissingToast(tester);
        toast.dismiss();
        await tester.pumpAndSettle();

        adapter.failingPaths.clear();
        await tapVisible(tester, find.text('로그아웃'));

        expect(tokens.clearCount, 1);
        expect(navigated, <String>['/']);
      });

      testWidgets('탈퇴하기는 탈퇴 화면으로 간다', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('탈퇴하기'));

        expect(navigated, <String>['/student/mypage/leave']);
        // 탈퇴는 이 화면에서 요청을 쏘지 않는다.
        expect(capture.captured.length, 1);
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값이다. 색·존재만
    // 보는 단언은 "얼마나"를 못 잡는다(규율 #15).
    group('치수 — 웹 실측값을 고정한다', () {
      // 웹 실측 38 × 34. **테두리 1px이 양쪽에 더해진 값**이다
      // (패딩 6 + 아이콘 24 + 패딩 6 = 36, 여기에 보더 2). Flutter `Container`도
      // `decoration`의 보더 두께를 패딩에 더하므로 같은 값이 나온다.
      testWidgets('카메라 버튼은 38 × 34다', (tester) async {
        await pump(tester);

        final camera = find.byWidgetPredicate(
          (w) => w is SvgPicture && w.width == 24,
        );
        expect(camera, findsOneWidget, reason: '카메라 아이콘이 없다');

        final button = find.ancestor(
          of: camera,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        expect(tester.getSize(button.first), const Size(38, 34));
      });

      // 웹 `-bottom-1 -right-1` — 아바타 **밖으로** 4px씩 나간다.
      testWidgets('카메라 버튼이 아바타 밖으로 4px씩 나간다', (tester) async {
        await pump(tester);

        final avatar = find.byWidgetPredicate(
          (w) => w is SvgPicture && w.width == 82,
        );
        final camera = find.byWidgetPredicate(
          (w) => w is SvgPicture && w.width == 24,
        );
        final button = find.ancestor(
          of: camera,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );

        final avatarBox = tester.getRect(avatar);
        final buttonBox = tester.getRect(button.first);

        expect(buttonBox.right - avatarBox.right, 4);
        expect(buttonBox.bottom - avatarBox.bottom, 4);
      });

      // 웹 실측 142.59 = pt 16 + 아바타 82 + gap 16 + 이름 28.6.
      //
      // **허용 오차 0.5는 글꼴 여백이 아니라 줄 높이 반올림 때문이다.**
      // Flutter는 줄 높이를 정수 픽셀로 반올림한다 — `HEADING_2`는
      // `22 × 1.3 = 28.6` → **29.0**, `TITLE_1_SEMIBOLD`는
      // `16 × 1.4 = 22.4` → **22.0**. 브라우저는 소수를 그대로 쓴다.
      // 패딩이 한 단만 틀려도 4px 이상 어긋나므로 이 오차로 가려지지 않는다.
      testWidgets('프로필 섹션 높이가 웹과 같다', (tester) async {
        await pump(tester);

        final section = find.ancestor(
          of: find.byWidgetPredicate((w) => w is SvgPicture && w.width == 82),
          matching: find.byType(Padding),
        );
        expect(tester.getSize(section.first).height, closeTo(142.59, 0.5));
      });

      // 웹 실측: 카드 폭 400(440 - 좌우 20), 행 높이 63.41 / 63.41 / 62.41.
      // 마지막 줄만 1px 작은 이유는 **`border-b`가 없어서**다.
      testWidgets('카드 행 높이가 웹과 같고 마지막 줄만 1px 작다', (tester) async {
        await pump(tester);

        double rowHeight(String label) {
          final row = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is Container),
          );
          return tester.getSize(row.first).height;
        }

        expect(rowHeight('이름'), closeTo(63.41, 0.5));
        expect(rowHeight('이메일'), closeTo(63.41, 0.5));
        // 구분선이 없는 마지막 줄. **1px 차이가 이 단언의 요점이다** —
        // 마지막 줄에 `border-b`를 실수로 붙이면 여기서 잡힌다.
        expect(rowHeight('비밀번호 변경'), closeTo(62.41, 0.5));
        expect(rowHeight('이름') - rowHeight('비밀번호 변경'), 1);
      });

      // 웹이 **이 화면에서만** 82를 쓴다(허브는 80). 맞추면 웹과 달라진다.
      testWidgets('사진이 없을 때 아바타는 82다', (tester) async {
        await pump(tester);

        // **기댓값을 리터럴로 쓴다.** 상수를 양쪽에 쓰면 상수를 바꿔도
        // 단언이 따라 움직여 아무것도 못 잡는다 — 실제로 그렇게 써 뒀다가
        // 82 → 80 뮤테이션이 통과했다.
        final avatar = find.byWidgetPredicate(
          (w) => w is SvgPicture && w.width == 82,
        );
        expect(avatar, findsOneWidget, reason: '아바타가 82가 아니다');
        expect(tester.getSize(avatar), const Size(82, 82));
        // 허브는 80이다. 둘을 맞추면 웹과 달라진다.
        expect(StudentMyPageInfoPage.avatarFallbackSize, 82);
      });

      testWidgets('로그아웃과 탈퇴하기 사이 세로선은 1 × 10이다', (tester) async {
        await pump(tester);

        final colors = AppColors.light;
        final divider = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color == colors.gray300 &&
              w.constraints?.maxWidth ==
                  StudentMyPageInfoPage.actionDividerWidth,
        );
        expect(tester.getSize(divider.first), const Size(1, 10));
      });

      testWidgets('루트 배경이 흰색이다', (tester) async {
        await pump(tester);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, Colors.white);
      });
    });

    // 규율 #14. 이 화면은 **긴 이메일**이 가장 빡빡하다.
    group('폰 너비(390pt)', () {
      testWidgets('기본 데이터가 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);

        await pump(tester);

        expect(tester.takeException(), isNull);
      });

      testWidgets('아주 긴 이메일과 이름이 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);
        adapter.me = _defaultMe()
          ..['name'] = '아주아주기다란회원이름입니다정말로'
          ..['email'] =
              'very.long.email.address.for.overflow.test@geonganghaejim.site';

        await pump(tester);

        expect(tester.takeException(), isNull);
      });

      testWidgets('소셜 계정에서도 넘치지 않는다', (tester) async {
        await usePhoneViewport(tester);
        adapter.me = _defaultMe()
          ..['socialType'] = 'NAVER'
          ..['email'] =
              'very.long.email.address.for.overflow.test@geonganghaejim.site';

        await pump(tester);

        expect(tester.takeException(), isNull);
      });
    });
  });
}

/// 오른쪽 화살표(`arrow_right_small.svg`) 찾기.
///
/// 고유 폭(7)으로 지목한다 — 이 화면의 다른 SVG는 아바타(82)와 카메라(24)라
/// 겹치지 않는다.
Finder _arrowFinder() => find.byWidgetPredicate(
  (w) => w is SvgPicture && w.width == StudentMyPageInfoPage.arrowWidth,
);
