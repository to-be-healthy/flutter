import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/model/auth_state.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';
import 'package:geonganghaejim/entity/auth/ui/auth_scope.dart';
import 'package:geonganghaejim/entity/member/api/member_api.dart';
import 'package:geonganghaejim/page/protected/student_my_page_leave_page.dart';
import 'package:geonganghaejim/shared/ui/app_checkbox.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  final Set<String> failingPaths = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failingPaths.contains(options.path)) {
      return ResponseBody.fromString(
        '{"message":"탈퇴에 실패했습니다.","code":"400"}',
        500,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 200,
        'message': '회원 탈퇴 되었습니다.',
        'data': '회원 탈퇴 되었습니다.',
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
  group('StudentMyPageLeavePage', () {
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
      navigated = <String>[];
      backCount = 0;
    });

    tearDown(() {
      toast.dispose();
      auth.dispose();
    });

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap() {
      auth = AuthState(tokens, profile);
      return MaterialApp(
        theme: AppTheme.light(),
        home: AuthScope(
          notifier: auth,
          child: AppToastScope(
            notifier: toast,
            child: AppToastHost(
              child: StudentMyPageLeavePage(
                memberApi: MemberApi(dio),
                onNavigate: navigated.add,
                onBack: () => backCount++,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    /// 동의 체크 → 계정 삭제하기 → 다이얼로그가 열린 상태까지.
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('위 내용을 모두 확인하였으며, 회원 탈퇴합니다.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계정 삭제하기'));
      await tester.pumpAndSettle();
    }

    Future<void> settleWithoutDismissingToast(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Finder checkboxFinder() {
      final colors = AppColors.light;
      return find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == AppCheckbox.size &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == colors.primary500,
      );
    }

    group('진입 — 요청이 없다', () {
      // 골든이 없는 화면이다. 뜨자마자 아무것도 부르지 않는다.
      testWidgets('마운트 시 아무 요청도 보내지 않는다', (tester) async {
        await pump(tester);

        expect(capture.captured, isEmpty);
      });

      testWidgets('유의사항 세 줄을 웹 문구 그대로 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('회원탈퇴 유의사항'), findsOneWidget);
        for (final notice in StudentMyPageLeavePage.notices) {
          expect(find.text(notice), findsOneWidget);
        }
        // **불릿은 CSS가 아니라 문자열의 일부다.**
        expect(
          StudentMyPageLeavePage.notices.every((n) => n.startsWith('• ')),
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

    group('동의 체크박스', () {
      testWidgets('처음에는 꺼져 있다', (tester) async {
        await pump(tester);

        expect(checkboxFinder(), findsNothing);
      });

      testWidgets('문구를 누르면 켜진다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('위 내용을 모두 확인하였으며, 회원 탈퇴합니다.'));
        await tester.pumpAndSettle();

        expect(checkboxFinder(), findsOneWidget);
      });

      // **체크 표시는 꺼져 있을 때도 그려진다** — 흰색이라 안 보일 뿐이다.
      // 웹이 `fill='white'`를 늘 주는 것을 그대로 옮겼다.
      testWidgets('체크 아이콘은 꺼져 있을 때도 트리에 있다', (tester) async {
        await pump(tester);

        expect(
          find.byWidgetPredicate(
            (w) => w is SvgPicture && w.width == AppCheckbox.checkWidth,
          ),
          findsOneWidget,
        );
      });

      testWidgets('다시 누르면 꺼진다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('위 내용을 모두 확인하였으며, 회원 탈퇴합니다.'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('위 내용을 모두 확인하였으며, 회원 탈퇴합니다.'));
        await tester.pumpAndSettle();

        expect(checkboxFinder(), findsNothing);
      });
    });

    group('계정 삭제하기 버튼', () {
      // 웹 `DialogTrigger disabled={!agreement}`.
      testWidgets('동의 전에는 눌러도 다이얼로그가 안 열린다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('계정 삭제하기'));
        await tester.pumpAndSettle();

        expect(find.text('정말로 탈퇴하시겠어요?'), findsNothing);
        expect(capture.captured, isEmpty);
      });

      testWidgets('동의 전에는 회색이다', (tester) async {
        await pump(tester);

        final colors = AppColors.light;
        final label = tester.widget<Text>(find.text('계정 삭제하기'));
        expect(label.style?.color, colors.gray400);
      });

      testWidgets('동의 후에는 point 색이다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('위 내용을 모두 확인하였으며, 회원 탈퇴합니다.'));
        await tester.pumpAndSettle();

        final colors = AppColors.light;
        final label = tester.widget<Text>(find.text('계정 삭제하기'));
        expect(label.style?.color, colors.point);
      });
    });

    group('확인 다이얼로그', () {
      testWidgets('동의 후 누르면 열린다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        expect(find.text('정말로 탈퇴하시겠어요?'), findsOneWidget);
        expect(
          find.text('건강해짐 계정을 삭제하면 회원님의 수강권, 운동기록, 식단 등 모든 정보가 함께 사라지게 됩니다.'),
          findsOneWidget,
        );
        expect(find.text('취소'), findsOneWidget);
        expect(find.text('탈퇴하기'), findsOneWidget);
      });

      // **여는 것만으로는 아무 요청도 나가지 않는다.**
      testWidgets('열기만 해서는 요청이 없다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        expect(capture.captured, isEmpty);
      });

      testWidgets('취소를 누르면 닫히고 요청이 없다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();

        expect(find.text('정말로 탈퇴하시겠어요?'), findsNothing);
        expect(capture.captured, isEmpty);
        expect(tokens.clearCount, 0);
        expect(navigated, isEmpty);
      });

      // 웹 두 버튼은 글꼴도 모서리도 다르다 — 실측으로 확인한 비대칭이다.
      testWidgets('취소와 탈퇴하기는 글꼴이 다르다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        final cancel = tester.widget<Text>(find.text('취소'));
        final confirm = tester.widget<Text>(find.text('탈퇴하기'));

        // 웹 실측: 취소 16 / 400, 탈퇴하기 14 / 500.
        expect(cancel.style?.fontSize, 16);
        expect(cancel.style?.fontWeight, FontWeight.w400);
        expect(confirm.style?.fontSize, 14);
        expect(confirm.style?.fontWeight, FontWeight.w500);
      });

      // `--point-color`(#FF4668)가 아니라 shadcn `--destructive`(#EF4444)다.
      testWidgets('탈퇴하기 배경은 destructive 색이고 point 색이 아니다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        final button = find.ancestor(
          of: find.text('탈퇴하기'),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        final decoration =
            tester.widget<Container>(button.first).decoration! as BoxDecoration;

        expect(decoration.color, const Color(0xFFEF4444));
        expect(decoration.color, isNot(AppColors.light.point));
      });
    });

    group('탈퇴 실행', () {
      testWidgets('POST 를 보내고 세션을 지우고 루트로 간다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        await tester.tap(find.text('탈퇴하기'));
        await tester.pumpAndSettle();

        // **골든이 없는 요청이라 여기가 유일한 계약이다.**
        expect(capture.captured.length, 1);
        final request = capture.captured.single;
        expect(request.method, 'POST');
        expect(request.path, MemberApi.deletePath);
        expect(request.body, isNull, reason: '웹은 본문 없이 보낸다');
        expect(request.headers.containsKey('authorization'), isTrue);

        expect(tokens.clearCount, 1);
        expect(profile.clearCount, 1);
        expect(auth.user, isNull);
        expect(navigated, <String>['/']);
      });

      testWidgets('실패하면 서버 메시지를 띄우고 세션을 유지한다', (tester) async {
        adapter.failingPaths.add(MemberApi.deletePath);

        await pump(tester);
        await openDialog(tester);

        await tester.tap(find.text('탈퇴하기'));
        await settleWithoutDismissingToast(tester);

        expect(find.text('탈퇴에 실패했습니다.'), findsOneWidget);
        expect(tokens.clearCount, 0, reason: '토큰이 남아야 한다');
        expect(tokens.access, 'a');
        expect(navigated, isEmpty);

        toast.dismiss();
        await tester.pumpAndSettle();
      });

      testWidgets('실패 뒤에 다시 시도할 수 있다', (tester) async {
        adapter.failingPaths.add(MemberApi.deletePath);

        await pump(tester);
        await openDialog(tester);
        await tester.tap(find.text('탈퇴하기'));
        await settleWithoutDismissingToast(tester);
        toast.dismiss();
        await tester.pumpAndSettle();

        adapter.failingPaths.clear();
        // 다이얼로그는 이미 닫혔다 — 동의는 켜진 채다.
        await tester.tap(find.text('계정 삭제하기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('탈퇴하기'));
        await tester.pumpAndSettle();

        expect(tokens.clearCount, 1);
        expect(navigated, <String>['/']);
      });
    });

    // 2026-09-15 브라우저 `getBoundingClientRect` 실측값이다(규율 #15).
    // 기댓값은 **리터럴**로 쓴다 — 상수를 양쪽에 쓰면 공허해진다(규율 #18).
    group('치수 — 웹 실측값을 고정한다', () {
      // 자산의 viewBox가 24 × 24(정사각)라 **웹에서도 실제 글리프는 12 × 12**다.
      // 웹은 `width={15} height={12}`를 주지만 SVG 기본
      // `preserveAspectRatio="xMidYMid meet"`가 종횡비를 지켜 15칸 안에
      // 12를 가운데 놓는다. flutter_svg도 같은 규칙이라 위젯이 12 × 12로
      // 잡히고, 둘 다 20 × 20 박스의 가운데라 **보이는 결과가 같다.**
      testWidgets('체크박스는 20 × 20이고 체크 글리프는 12 × 12다', (tester) async {
        await pump(tester);

        final check = find.byWidgetPredicate(
          (w) => w is SvgPicture && w.width == 15,
        );
        expect(tester.getSize(check), const Size(12, 12));

        final box = find.ancestor(
          of: check,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        expect(tester.getSize(box.first), const Size(20, 20));
      });

      testWidgets('계정 삭제하기 버튼 높이가 50이다', (tester) async {
        await pump(tester);

        final button = find.ancestor(
          of: find.text('계정 삭제하기'),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        // py-5(12+12) + 줄 높이 24 + 테두리 2.
        expect(tester.getSize(button.first).height, 50);
      });

      testWidgets('두 섹션 사이가 72다', (tester) async {
        await pump(tester);

        final notice = tester.getRect(
          find.text(StudentMyPageLeavePage.notices.last),
        );
        final label = tester.getRect(find.text('위 내용을 모두 확인하였으며, 회원 탈퇴합니다.'));

        expect(label.top - notice.bottom, 72);
      });

      testWidgets('다이얼로그 폭이 320이고 두 버튼 높이가 50이다', (tester) async {
        await pump(tester);
        await openDialog(tester);

        final content = find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 320,
        );
        expect(tester.getSize(content.first).width, 320);

        // **배경색으로 지목한다.** `find.ancestor(...).first`로 찾으면
        // 바깥 다이얼로그 컨테이너가 잡혀서, 버튼 높이가 갈려도 통과한다
        // (뮤테이션으로 확인했다).
        Size buttonSize(Color background) {
          final finder = find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == background,
          );
          expect(finder, findsOneWidget);
          return tester.getSize(finder);
        }

        final cancel = buttonSize(AppColors.light.gray100);
        final confirm = buttonSize(const Color(0xFFEF4444));

        // 웹 실측: 둘 다 50이다. `탈퇴하기`는 내용상 46인데 flex
        // `align-items: stretch`가 `취소`(50)에 맞춰 늘린다.
        expect(cancel.height, 50);
        expect(
          confirm.height,
          50,
          reason: '탈퇴하기가 취소에 맞춰 늘어나지 않았다 (IntrinsicHeight 누락)',
        );
      });
    });

    group('폰 너비(390pt)', () {
      testWidgets('유의사항과 다이얼로그가 넘치지 않는다', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pump(tester);
        expect(tester.takeException(), isNull);

        await openDialog(tester);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
