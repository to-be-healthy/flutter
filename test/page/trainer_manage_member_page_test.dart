import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/trainer/api/trainer_api.dart';
import 'package:geonganghaejim/page/protected/trainer_manage_member_page.dart';
import 'package:geonganghaejim/shared/ui/app_checkbox.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

/// 골든 `trainer-manage-member`가 **`/6`을 경로에 담고 있다.**
/// `--path-template`을 쓰지 않은 이유는, 캡처한 회원의 실측 응답을 그대로
/// 픽스처로 쓰기 때문이다 — 둘이 어긋나면 테스트가 먼저 깨져야 한다.
const int _memberId = 6;

class _StubAdapter implements HttpClientAdapter {
  Object? detail = _defaultDetail();

  Completer<void>? gate;
  bool fails = false;

  /// 삭제(DELETE) 응답. null이면 성공.
  int? deleteStatus;
  String deleteMessage = '환불 삭제되었습니다.';

  final List<String> deleted = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method.toUpperCase() == 'DELETE') {
      deleted.add(options.path);
      if (deleteStatus != null) {
        return ResponseBody.fromString(
          '{"message":"삭제할 수 없습니다."}',
          deleteStatus!,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'message': deleteMessage, 'data': null}),
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
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'message': '학생 상세가 조회되었습니다.',
        'data': detail,
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

/// 2026-09-16 실측 응답(`docs/trainer-manage-s2-measurements.md` K45-1).
///
/// **`completedLessonCnt`가 `totalLessonCnt`와 같아 만료 분기다** —
/// `remainLessonCnt`가 3인데도 그렇다. 서버가 실제로 그렇게 보냈다.
Map<String, dynamic> _defaultDetail() => <String, dynamic>{
  'memberId': 6,
  'name': '차은우',
  'nickName': null,
  'fileUrl': null,
  'memo': 'eedd2',
  'ranking': 999,
  'lessonDt': null,
  'lessonStartTime': null,
  'diet': <String, dynamic>{
    'dietId': null,
    'member': null,
    'likeCnt': null,
    'commentCnt': null,
    'createdAt': null,
    'updatedAt': null,
    'eatDate': null,
    'liked': false,
    'feedbackChecked': false,
    'breakfast': <String, dynamic>{'fast': false, 'dietFile': null},
    'lunch': <String, dynamic>{'fast': false, 'dietFile': null},
    'dinner': <String, dynamic>{'fast': false, 'dietFile': null},
  },
  'course': <String, dynamic>{
    'courseId': 3,
    'totalLessonCnt': 10,
    'remainLessonCnt': 3,
    'completedLessonCnt': 10,
    'createdAt': '2026-03-13T14:44:48',
  },
  'point': <String, dynamic>{
    'searchDate': '2026-09',
    'monthPoint': 0,
    'totalPoint': 85,
  },
  'rank': <String, dynamic>{
    'ranking': 999,
    'lastMonthRanking': 999,
    'totalMemberCnt': 2,
  },
  'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
  'isNonmember': false,
};

void main() {
  group('TrainerManageMemberPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
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
    });

    late AppToastController toast;

    setUp(() {
      // 토스트는 앱 루트가 소유하지만(화면보다 오래 산다), 테스트마다
      // 새로 만들어야 이전 테스트의 토스트가 남지 않는다.
      toast = AppToastController();
      addTearDown(toast.dispose);
    });

    // 라우터를 끼우지 않는다(규율 #3). 토스트는 앱 루트가 소유하므로
    // 여기서도 화면 **위쪽**에 둔다(`app.dart`와 같은 구조).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => AppToastScope(
        notifier: toast,
        child: AppToastHost(child: child!),
      ),
      home: TrainerManageMemberPage(
        trainerApi: TrainerApi(dio),
        memberId: _memberId,
        onNavigate: navigated.add,
        onBack: () => backCount++,
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

    group('요청 1건 — 골든 `trainer-manage-member`', () {
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('trainer-manage-member', capture.captured);
      });

      testWidgets('경로에 memberId가 들어간다', (tester) async {
        await pump(tester);

        expect(capture.captured.single.path, '/api/v1/trainers/members/6');
      });

      testWidgets('하단 네비가 없어 추가 요청이 없다', (tester) async {
        await pump(tester);

        // 웹 `<Layout>`에 `type`이 없다 — 학생 화면들과 다른 점이다.
        expect(capture.captured, hasLength(1));
        expect(find.text('스케줄'), findsNothing);
        expect(find.text('마이'), findsNothing);
      });
    });

    group('응답 전에는 화면이 통째로 비어 있다', () {
      testWidgets('로딩 중에는 헤더조차 없다', (tester) async {
        adapter.gate = Completer<void>();
        useWebViewport(tester);
        await tester.pumpWidget(wrap());
        await tester.pump();

        // 웹 `{memberInfo && (<><Header/><Layout.Contents/></>)}` —
        // 헤더까지 감싼다. 뒤로가기 버튼도 없다.
        expect(find.text('회원 정보'), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('요청이 실패해도 마찬가지다', (tester) async {
        adapter.fails = true;

        await pump(tester);

        // 에러 분기가 없는 웹(BUG-13)의 결과다.
        expect(find.text('회원 정보'), findsNothing);
        expect(find.text('차은우'), findsNothing);
      });

      testWidgets('응답이 오면 헤더와 본문이 함께 나타난다', (tester) async {
        await pump(tester);

        expect(find.text('회원 정보'), findsOneWidget);
        expect(find.text('차은우'), findsOneWidget);
      });
    });

    group('본문', () {
      testWidgets('바로가기 3열이 보인다', (tester) async {
        await pump(tester);

        expect(find.text('예약 내역'), findsOneWidget);
        expect(find.text('회원 메모'), findsOneWidget);
        expect(find.text('수업 일지'), findsOneWidget);
      });

      testWidgets('세 열이 각자 경로로 간다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('예약 내역'));
        await tester.tap(find.text('회원 메모'));
        await tester.tap(find.text('수업 일지'));
        await tester.pump();

        expect(navigated, <String>[
          // 웹도 `?name=${memberInfo?.name}`을 붙인다 — 예약 내역 화면이
          // 이름을 쿼리에서만 읽고, 없으면 제목이 통째로 사라진다.
          '/trainer/manage/6/reservation?name=%EC%B0%A8%EC%9D%80%EC%9A%B0',
          '/trainer/manage/6/edit/memo',
          '/trainer/manage/6/log',
        ]);
      });

      testWidgets('열과 열 사이를 눌러도 이동하지 않는다', (tester) async {
        await pump(tester);

        // 웹 `<a>`는 내용 크기라 **48.03**뿐이고, 열 사이 ~103px은 링크가
        // 아니다(측정 F절). `find.text(...)`만 누르는 위 테스트는 카드
        // 전체가 눌려도 통과하므로, 탭 영역의 폭은 이 단언이 고정한다 —
        // 열에 `Expanded`를 붙이면 중간점이 열 안으로 들어와 깨진다.
        final first = tester.getRect(find.text('예약 내역'));
        final second = tester.getRect(find.text('회원 메모'));
        expect(second.left - first.right, greaterThan(20));

        // 탭 영역 자체가 글자 폭이다 — 열에 폭을 주면 여기서 먼저 깨진다.
        final target = find
            .ancestor(
              of: find.text('예약 내역'),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(target).width, first.width);

        await tester.tapAt(
          Offset((first.right + second.left) / 2, first.center.dy),
        );
        await tester.pump();

        expect(navigated, isEmpty);
      });

      testWidgets('개인 운동 기록 카드가 항상 있다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('개인 운동 기록'));
        await tester.pump();

        expect(navigated, <String>['/trainer/manage/6/workout']);
      });

      testWidgets('랭킹이 999면 랭킹 줄이 없다', (tester) async {
        await pump(tester);

        // 실측 계정이 정확히 이 상태였다 — 그 줄의 높이가 0이었다.
        expect(find.textContaining('랭킹'), findsNothing);
      });

      testWidgets('랭킹이 있으면 숫자를 보여준다', (tester) async {
        adapter.detail = <String, dynamic>{..._defaultDetail(), 'ranking': 3};

        await pump(tester);

        expect(find.textContaining('랭킹'), findsOneWidget);
      });
    });

    group('수강권 분기', () {
      testWidgets('만료면 접이식이 아니다', (tester) async {
        await pump(tester);

        // 실측 응답이 `completed 10 / total 10`이라 만료다.
        expect(find.text('10회 PT수강 만료'), findsOneWidget);
        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();
        expect(find.text('이번달 포인트'), findsNothing);
      });

      testWidgets('활성이면 눌러서 펼칠 수 있다', (tester) async {
        adapter.detail = <String, dynamic>{
          ..._defaultDetail(),
          'course': <String, dynamic>{
            'courseId': 3,
            'totalLessonCnt': 3,
            'remainLessonCnt': 3,
            'completedLessonCnt': 0,
            'createdAt': '2026-03-13T14:44:48',
          },
        };

        await pump(tester);
        expect(find.text('3회 예약할 수 있어요!'), findsOneWidget);

        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();

        expect(find.text('이번달 포인트'), findsOneWidget);
        expect(find.text('랭킹'), findsOneWidget);
      });

      testWidgets('수강권이 없으면 안내 카드가 뜬다', (tester) async {
        adapter.detail = <String, dynamic>{..._defaultDetail(), 'course': null};

        await pump(tester);

        expect(find.text('현재 등록된 수강권이 없습니다.'), findsOneWidget);
        expect(find.textContaining('활동 포인트'), findsNothing);
      });
    });

    group('식단 카드 — 두 분기는 서로의 반대가 아니다', () {
      testWidgets('dietId가 null이면 등록 식단', (tester) async {
        await pump(tester);

        expect(find.text('등록 식단'), findsOneWidget);
        expect(find.text('오늘 식단'), findsNothing);
      });

      testWidgets('dietId가 있으면 오늘 식단 + 3칸', (tester) async {
        final detail = _defaultDetail();
        (detail['diet']! as Map<String, dynamic>)['dietId'] = 11;
        ((detail['diet']! as Map<String, dynamic>)['lunch']!
                as Map<String, dynamic>)['fast'] =
            true;
        adapter.detail = detail;

        await pump(tester);

        expect(find.text('오늘 식단'), findsOneWidget);
        expect(find.text('식단전체'), findsOneWidget);
        expect(find.text('단식'), findsOneWidget);
        expect(find.text('등록 식단'), findsNothing);
      });

      testWidgets('dietId가 0이면 식단 카드가 아예 없다', (tester) async {
        final detail = _defaultDetail();
        (detail['diet']! as Map<String, dynamic>)['dietId'] = 0;
        adapter.detail = detail;

        await pump(tester);

        expect(find.text('오늘 식단'), findsNothing);
        expect(find.text('등록 식단'), findsNothing);
        // 그래도 나머지는 그대로다.
        expect(find.text('개인 운동 기록'), findsOneWidget);
      });
    });

    group('케밥 메뉴', () {
      Future<void> openMenu(WidgetTester tester) async {
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('세 항목이 나온다', (tester) async {
        await pump(tester);
        await openMenu(tester);

        expect(find.text('별칭 설정'), findsOneWidget);
        expect(find.text('회원 삭제'), findsOneWidget);
        expect(find.text('환불 회원 삭제'), findsOneWidget);
      });

      testWidgets('환불 회원 삭제만 빨갛다', (tester) async {
        await pump(tester);
        await openMenu(tester);

        expect(
          tester.widget<Text>(find.text('환불 회원 삭제')).style?.color,
          AppColors.light.point,
        );
        expect(
          tester.widget<Text>(find.text('회원 삭제')).style?.color,
          AppColors.light.gray800,
        );
      });

      testWidgets('별칭 설정으로 간다', (tester) async {
        await pump(tester);
        await openMenu(tester);

        await tester.tap(find.text('별칭 설정'));
        await tester.pumpAndSettle();

        expect(navigated, <String>['/trainer/manage/6/edit/nickname']);
      });
    });

    group('회원 삭제 — 확인 없이는 요청이 나가지 않는다', () {
      Future<void> openAlert(WidgetTester tester) async {
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('회원 삭제'));
        await tester.pumpAndSettle();
      }

      testWidgets('이름이 들어간 문구를 보여준다', (tester) async {
        await pump(tester);
        await openAlert(tester);

        expect(find.text('차은우님을 삭제하시겠습니까?'), findsOneWidget);
        expect(find.text('아니요'), findsOneWidget);
        expect(find.text('예'), findsOneWidget);
      });

      testWidgets('`아니요`를 누르면 아무 요청도 안 나간다', (tester) async {
        await pump(tester);
        await openAlert(tester);

        await tester.tap(find.text('아니요'));
        await tester.pumpAndSettle();

        expect(adapter.deleted, isEmpty);
        expect(navigated, isEmpty);
      });

      testWidgets('`예`를 누르면 DELETE 후 목록으로 간다', (tester) async {
        await pump(tester);
        await openAlert(tester);

        await tester.tap(find.text('예'));
        await tester.pumpAndSettle();

        expect(adapter.deleted, <String>['/api/v1/trainers/members/6']);
        // 웹 `router.replace('/trainer/manage')`.
        expect(navigated, <String>['/trainer/manage']);
      });

      testWidgets('실패하면 서버 메시지를 띄우고 머무른다', (tester) async {
        adapter.deleteStatus = 400;

        await pump(tester);
        await openAlert(tester);
        await tester.tap(find.text('예'));
        await tester.pumpAndSettle();

        expect(find.text('삭제할 수 없습니다.'), findsOneWidget);
        expect(navigated, isEmpty);
        // 실패는 에러 아이콘이다.
        expect(_svg('assets/images/error.svg'), findsOneWidget);
        expect(_svg('assets/images/check.svg'), findsNothing);

        // 토스트가 2초 타이머를 걸고 `pumpAndSettle`은 그것을 소진하지
        // 않는다 — 남기면 "Timer is still pending"으로 떨어진다.
        toast.dismiss();
        await tester.pump();
      });
    });

    group('환불 회원 삭제 시트', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('환불 회원 삭제'));
        await tester.pumpAndSettle();
      }

      testWidgets('경고 문구와 체크박스를 보여준다', (tester) async {
        await pump(tester);
        await openSheet(tester);

        expect(find.text('환불 회원 삭제하기'), findsOneWidget);
        expect(
          find.text('회원 삭제시 회원 정보, 운동 기록, 예약 내역, 수강권 등은 복구되지 않습니다.'),
          findsOneWidget,
        );
        expect(find.byType(AppCheckbox), findsOneWidget);
      });

      testWidgets('체크 전에는 눌러도 요청이 안 나간다', (tester) async {
        await pump(tester);
        await openSheet(tester);

        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundConfirm')),
        );
        await tester.pumpAndSettle();

        expect(adapter.deleted, isEmpty);
        // 시트도 닫히지 않는다.
        expect(find.text('환불 회원 삭제하기'), findsOneWidget);
      });

      testWidgets('체크 전 버튼은 gray300이다', (tester) async {
        await pump(tester);
        await openSheet(tester);

        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('회원 삭제'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          AppColors.light.gray300,
        );
      });

      testWidgets('체크하면 point 색이 되고 삭제가 나간다', (tester) async {
        await pump(tester);
        await openSheet(tester);

        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundCheck')),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('회원 삭제'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((box.decoration! as BoxDecoration).color, AppColors.light.point);

        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundConfirm')),
        );
        await tester.pumpAndSettle();

        expect(adapter.deleted, <String>['/api/v1/trainers/members/6/refund']);
        expect(navigated, <String>['/trainer/manage']);

        // 성공 토스트가 함께 떠 있다(다음 테스트가 그 내용을 확인한다).
        toast.dismiss();
        await tester.pump();
      });

      testWidgets('성공하면 서버 message를 토스트로 띄운다', (tester) async {
        adapter.deleteMessage = '환불 삭제되었습니다.';

        await pump(tester);
        await openSheet(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundCheck')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundConfirm')),
        );
        await tester.pumpAndSettle();

        // 웹 `onSuccess: ({message}) => successToast(message)`.
        expect(find.text('환불 삭제되었습니다.'), findsOneWidget);
        // **에러 토스트와 아이콘이 다르다** — 문구만 보면 둘을 구분하지
        // 못한다(뮤테이션 M66). 웹 `<IconCheck fill='var(--primary-500)'/>`.
        expect(_svg('assets/images/check.svg'), findsOneWidget);
        expect(_svg('assets/images/error.svg'), findsNothing);

        toast.dismiss();
        await tester.pump();
      });

      testWidgets('`취소`는 요청을 보내지 않는다', (tester) async {
        await pump(tester);
        await openSheet(tester);

        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundCancel')),
        );
        await tester.pumpAndSettle();

        expect(adapter.deleted, isEmpty);
        expect(navigated, isEmpty);
      });
    });

    /// 2026-09-16 브라우저 실측(440×900,
    /// `docs/trainer-manage-s2-measurements.md`).
    ///
    /// 기댓값은 **리터럴**이다(규율 #18) — 상수를 양쪽에 쓰면 공허해진다.
    group('치수 실측 (440×900)', () {
      testWidgets('헤더 56 · 케밥 24×36 · 케밥 아이콘 4×16', (tester) async {
        await pump(tester);

        expect(tester.getSize(find.byType(AppLayoutHeader)).height, 56);
        expect(
          tester.getSize(
            find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
          ),
          const Size(24, 36),
        );
        expect(
          _svgRequestedSize(tester, _svg('assets/images/dots_vertical.svg')),
          const Size(4, 16),
        );
      });

      testWidgets('제목은 순수 검정이다 (본문 글자색이 아니다)', (tester) async {
        await pump(tester);

        // 웹 `text-black` — 다른 화면 제목의 gray800과 다르다(실측 A3).
        final title = tester.widget<Text>(find.text('회원 정보'));
        expect(title.style?.color, Colors.black);
        expect(title.style?.color, isNot(AppColors.light.gray800));
        expect(title.style?.fontWeight, FontWeight.w600);
      });

      testWidgets('기본 프로필 아이콘은 80이 아니라 82다', (tester) async {
        await pump(tester);

        // 웹이 `IconDefaultProfile`에 크기 prop을 주지 않아 자산 고유
        // 크기로 뜬다. 사진 분기의 `h-[80px]`와 **2px 다르다.**
        final icon = _svg('assets/images/icon_default_profile.svg');
        expect(_svgRequestedSize(tester, icon), const Size(82, 82));
        expect(tester.getSize(icon), const Size(82, 82));
      });

      testWidgets('프로필과 이름 사이 24 · 이름 22px', (tester) async {
        await pump(tester);

        final avatar = _svg('assets/images/icon_default_profile.svg');
        expect(
          tester.getTopLeft(find.text('차은우')).dx -
              tester.getBottomRight(avatar).dx,
          24,
        );
        final name = tester.widget<Text>(find.text('차은우'));
        expect(name.style?.fontSize, 22);
        expect(name.style?.fontWeight, FontWeight.w700);
      });

      testWidgets('본문 좌우 20 · 위 24', (tester) async {
        await pump(tester);

        // 웹 `p-7 pt-8` — 커스텀 스케일이라 28/32가 아니라 20/24다.
        final avatar = _svg('assets/images/icon_default_profile.svg');
        expect(tester.getTopLeft(avatar).dx, 20);
        // 헤더 56 + 본문 위 패딩 24 = 80.
        expect(tester.getTopLeft(avatar).dy, 80);
      });

      testWidgets('바로가기 카드 400 폭 · 구분선 1×36', (tester) async {
        await pump(tester);

        final card = find
            .ancestor(
              of: find.text('예약 내역'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).boxShadow != null,
              ),
            )
            .first;
        expect(tester.getSize(card).width, 400);

        final dividers = find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.color == AppColors.light.gray100,
        );
        expect(dividers, findsNWidgets(2));
        expect(tester.getSize(dividers.first), const Size(1, 36));
      });

      testWidgets('바로가기 아이콘 셋의 고유 크기가 제각각이다', (tester) async {
        await pump(tester);

        // 웹이 크기 prop을 주지 않아 자산 viewBox가 그대로 렌더 크기다.
        expect(
          _svgRequestedSize(
            tester,
            _svg('assets/images/icon_calendar_blue.svg'),
          ),
          const Size(19, 18),
        );
        expect(
          _svgRequestedSize(tester, _svg('assets/images/icon_edit.svg')),
          const Size(21, 20),
        );
        expect(
          _svgRequestedSize(tester, _svg('assets/images/icon_dumbel.svg')),
          const Size(20, 11),
        );
      });

      testWidgets('식단·운동 카드의 오른쪽 화살표는 10×17이다', (tester) async {
        await pump(tester);

        final arrows = _svg('assets/images/icon_arrow_right.svg');
        // `등록 식단` + `개인 운동 기록` 두 장.
        expect(arrows, findsNWidgets(2));
        expect(_svgRequestedSize(tester, arrows.first), const Size(10, 17));
      });

      testWidgets('수강권 없음 카드 높이 127', (tester) async {
        adapter.detail = <String, dynamic>{..._defaultDetail(), 'course': null};

        await pump(tester);

        final card = find
            .ancestor(
              of: find.text('현재 등록된 수강권이 없습니다.'),
              matching: find.byType(Container),
            )
            .first;
        expect(tester.getSize(card).height, 127);
      });

      testWidgets('케밥 드롭다운 130 폭 · 우변 정렬 · 아래 4', (tester) async {
        await pump(tester);
        final kebab = find.byKey(
          const ValueKey('TrainerManageMemberPage.kebab'),
        );
        final kebabRect = tester.getRect(kebab);

        await tester.tap(kebab);
        await tester.pumpAndSettle();

        final panel = find
            .ancestor(
              of: find.text('환불 회원 삭제'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).border != null,
              ),
            )
            .first;
        final panelRect = tester.getRect(panel);

        expect(panelRect.width, 130);
        // 실측 B6: 우변이 정확히 맞고, 케밥 아래로 4 내려온다.
        expect(panelRect.right - kebabRect.right, 0);
        expect(panelRect.top - kebabRect.bottom, 4);
      });

      testWidgets('드롭다운 항목 45 높이 · 간격 0', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();

        final first = find
            .ancestor(of: find.text('별칭 설정'), matching: find.byType(Container))
            .first;
        final second = find
            .ancestor(of: find.text('회원 삭제'), matching: find.byType(Container))
            .first;

        // 패널 130 − 좌우 패딩 4 − 테두리 1 = 120.
        expect(tester.getSize(first), const Size(120, 45));
        expect(
          tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
          0,
        );
      });

      testWidgets('삭제 알럿 400 폭 · 버튼 48 · 사이 8', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('회원 삭제'));
        await tester.pumpAndSettle();

        final panel = find
            .ancestor(
              of: find.text('차은우님을 삭제하시겠습니까?'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).border != null,
              ),
            )
            .first;
        expect(tester.getSize(panel).width, 400);

        final cancel = tester.getRect(
          find.byKey(const ValueKey('TrainerManageMemberPage.deleteCancel')),
        );
        final confirm = tester.getRect(
          find.byKey(const ValueKey('TrainerManageMemberPage.deleteConfirm')),
        );
        expect(cancel.height, 48);
        expect(confirm.height, 48);
        expect(confirm.left - cancel.right, 8);
      });

      testWidgets('알럿 제목과 버튼 줄 사이는 34다 (24 + 10)', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('회원 삭제'));
        await tester.pumpAndSettle();

        // 웹 제목 래퍼 `mb-8`(24)과 다이얼로그 `gap-4`(10)가 **함께** 걸린다.
        // 둘 중 하나만 옮기면 절반이 된다.
        final title = tester.getRect(find.text('차은우님을 삭제하시겠습니까?'));
        final cancel = tester.getRect(
          find.byKey(const ValueKey('TrainerManageMemberPage.deleteCancel')),
        );
        expect(cancel.top - title.bottom, 34);
      });

      testWidgets('환불 시트 — 체크박스 20 · 문구와 8 · 버튼 48', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('환불 회원 삭제'));
        await tester.pumpAndSettle();

        final box = tester.getRect(find.byType(AppCheckbox));
        final label = tester.getRect(find.text('위 내용을 확인하였으며, 회원을 삭제합니다.'));
        expect(box.size, const Size(20, 20));
        expect(label.left - box.right, 8);

        expect(
          tester
              .getSize(
                find.byKey(
                  const ValueKey('TrainerManageMemberPage.refundCancel'),
                ),
              )
              .height,
          48,
        );
      });

      testWidgets('알럿은 넓은 화면에서도 400을 넘지 않는다', (tester) async {
        // 440에서는 좌우 `insetPadding` 20이 이미 400으로 깎아서 상한이
        // 있으나 없으나 같다 — **넓은 화면에서만 드러난다**(뮤테이션 M60).
        // 웹 `max-w-[calc(var(--max-width)-20px*2)]`가 그 상한이다.
        tester.view.physicalSize = const Size(900 * 3, 900 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('회원 삭제'));
        await tester.pumpAndSettle();

        final panel = find
            .ancestor(
              of: find.text('차은우님을 삭제하시겠습니까?'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).border != null,
              ),
            )
            .first;
        expect(tester.getSize(panel).width, 400);
      });

      testWidgets('포인트 바 높이는 고정이 아니라 내용이 정한다', (tester) async {
        adapter.detail = <String, dynamic>{
          ..._defaultDetail(),
          'course': <String, dynamic>{
            'courseId': 3,
            'totalLessonCnt': 3,
            'remainLessonCnt': 3,
            'completedLessonCnt': 0,
            'createdAt': '2026-03-13T14:44:48',
          },
        };

        await pump(tester);

        final bar = find.ancestor(
          of: find.text('9월 활동 포인트'),
          matching: find.byType(SizedBox),
        );
        final collapsed = tester.getSize(bar.first).height;

        await tester.tap(find.text('9월 활동 포인트'));
        await tester.pumpAndSettle();
        final expanded = tester.getSize(bar.first).height;

        // **웹에 `h-[54px]`가 없다** — 접힘 54.4 / 펼침 51.5로 달라진다
        // (실측 G35·G36). 학생 홈은 고정 54라 둘이 같다. 높이가 같아지면
        // 고정값을 넘긴 것이다(뮤테이션 M65).
        expect(collapsed, isNot(expanded));
        expect(expanded, lessThan(collapsed));
      });

      testWidgets('환불 시트 세로 간격 20 / 32 / 32', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManageMemberPage.kebab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('환불 회원 삭제'));
        await tester.pumpAndSettle();

        final title = tester.getRect(find.text('환불 회원 삭제하기'));
        final desc = tester.getRect(
          find.text('회원 삭제시 회원 정보, 운동 기록, 예약 내역, 수강권 등은 복구되지 않습니다.'),
        );
        final box = tester.getRect(find.byType(AppCheckbox));
        final cancel = tester.getRect(
          find.byKey(const ValueKey('TrainerManageMemberPage.refundCancel')),
        );

        // **시트의 `gap-4`(10)는 더해지지 않는다** — `mb-*` 값 그대로다
        // (실측 D19). 같은 shadcn 껍데기인데 알럿에서는 더해졌다.
        expect(desc.top - title.bottom, 20);
        // 두 간격 모두 실측 32인데 여기서는 **32.5**로 나온다.
        // Flutter가 줄 상자 높이를 반올림하면서 글자 박스가 레이아웃
        // 박스보다 0.5 짧아지기 때문이고(규율 #21), 간격 자체는 32다.
        // 제목→설명(20)은 양쪽이 한 줄이라 어긋나지 않는다.
        expect(box.top - desc.bottom, closeTo(32, 0.5));
        expect(cancel.top - box.bottom, closeTo(32, 0.5));
      });
    });

    group('이동', () {
      testWidgets('뒤로가기는 pop이다 (홈 고정이 아니다)', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // 웹 `router.back()` — S1의 `<Link href='/trainer'>`와 다르다.
        expect(backCount, 1);
        expect(navigated, isEmpty);
      });
    });
  });
}

/// 자산 경로로 `SvgPicture`를 집는다.
Finder _svg(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is SvgPicture &&
      widget.bytesLoader is SvgAssetLoader &&
      (widget.bytesLoader as SvgAssetLoader).assetName == asset,
);

/// `SvgPicture`가 **요청한** 크기. `tester.getSize`로는 확인할 수 없다
/// (규율 #20 — flutter_svg는 viewBox 고유 크기를 돌려준다).
Size _svgRequestedSize(WidgetTester tester, Finder finder) {
  final picture = tester.widget<SvgPicture>(finder);
  expect(picture.width, isNotNull, reason: 'width 를 넘기지 않은 SvgPicture다');
  expect(picture.height, isNotNull, reason: 'height 를 넘기지 않은 SvgPicture다');
  return Size(picture.width!, picture.height!);
}
