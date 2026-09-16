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
import 'package:geonganghaejim/page/protected/trainer_manage_page.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  /// `null`이면 서버가 `"data": null`을 준 것이다 — 회원 0명.
  Object? data = _defaultMembers();

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

/// 2026-09-15 실측 응답(`har/README.md`에 원문이 있다).
///
/// **`isNonmember`가 서로 다른 두 회원**인 점이 중요하다 — BUG-41이
/// 그 차이를 무시한다는 사실을 이 픽스처가 떠받친다.
List<Map<String, dynamic>> _defaultMembers() => <Map<String, dynamic>>[
  <String, dynamic>{
    'memberId': 6,
    'name': '차은우',
    'userId': 'healthy-student0',
    'email': 'healthy-student0@geonganghaejim.site',
    'ranking': 999,
    'lessonCnt': 10,
    'remainLessonCnt': 3,
    'nickName': null,
    'fileUrl': null,
    'courseId': null,
    'isNonmember': false,
  },
  <String, dynamic>{
    'memberId': 15,
    'name': 'rr',
    'userId': null,
    'email': null,
    'ranking': 999,
    'lessonCnt': 3,
    'remainLessonCnt': 3,
    'nickName': null,
    'fileUrl': null,
    'courseId': null,
    'isNonmember': true,
  },
];

Map<String, dynamic> _member({
  required int memberId,
  required String name,
  int ranking = 999,
  int lessonCnt = 10,
  int remainLessonCnt = 3,
  String? nickName,
  String? fileUrl,
  bool isNonmember = false,
}) => <String, dynamic>{
  'memberId': memberId,
  'name': name,
  'userId': null,
  'email': null,
  'ranking': ranking,
  'lessonCnt': lessonCnt,
  'remainLessonCnt': remainLessonCnt,
  'nickName': nickName,
  'fileUrl': fileUrl,
  'courseId': null,
  'isNonmember': isNonmember,
};

void main() {
  group('TrainerManagePage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
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
    });

    // 라우터를 끼우지 않는다(규율 #3).
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: TrainerManagePage(
        trainerApi: TrainerApi(dio),
        onNavigate: navigated.add,
      ),
    );

    /// 실측 뷰포트와 같게 맞춘다 — 치수 단언이 440 기준이라 이걸 빼면
    /// 기본 800×600에서 폭이 달라져 400이 나오지 않는다.
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

    group('요청 1건 — 골든 `trainer-manage`', () {
      testWidgets('들어오면 웹과 같은 요청 1건을 보낸다', (tester) async {
        await pump(tester);

        expectParity('trainer-manage', capture.captured);
      });

      testWidgets('Authorization이 붙는다', (tester) async {
        await pump(tester);

        expect(
          capture.captured.single.headers.containsKey('authorization'),
          isTrue,
        );
      });

      testWidgets('페이지 파라미터를 보내지 않는다 (웹과 같다)', (tester) async {
        await pump(tester);

        // 서버 기본값 `size=100`에 그대로 맡긴다(BUG-44). `size`를 붙이면
        // 골든의 쿼리가 웹과 어긋난다.
        expect(capture.captured.single.query, isEmpty);
      });

      testWidgets('하단 네비는 요청을 쏘지 않는다', (tester) async {
        await pump(tester);

        // 학생 홈과 다른 점이다 — 트레이너 네비에는 react-query 훅이 없다.
        expect(capture.captured, hasLength(1));
      });
    });

    group('로딩 중', () {
      testWidgets('검색바만 뜨고 카운트·목록은 없다', (tester) async {
        adapter.gate = Completer<void>();
        useWebViewport(tester);
        await tester.pumpWidget(wrap());
        await tester.pump();

        // 웹 `{!isLoading && (...)}`가 카운트·정렬·세 분기를 통째로 감싼다.
        expect(find.byType(TextField), findsOneWidget);
        expect(find.textContaining('총 '), findsNothing);
        expect(find.text('기본 순'), findsNothing);
        expect(find.text('차은우'), findsNothing);
        // 스피너도 스켈레톤도 없다(BUG-13과 같은 부류).
        expect(find.byType(CircularProgressIndicator), findsNothing);

        adapter.gate!.complete();
        await tester.pumpAndSettle();
      });
    });

    group('회원 목록', () {
      testWidgets('카드와 잔여 횟수를 보여준다', (tester) async {
        await pump(tester);

        expect(find.text('차은우'), findsOneWidget);
        expect(find.text('rr'), findsOneWidget);
        expect(find.text('잔여'), findsNWidgets(2));
        expect(find.text('/10'), findsOneWidget);
        expect(find.text('/3'), findsOneWidget);
      });

      testWidgets('총 인원을 보여준다', (tester) async {
        await pump(tester);

        expect(find.textContaining('총 2명'), findsOneWidget);
      });

      testWidgets('카드를 누르면 회원 상세로 간다', (tester) async {
        await pump(tester);

        await tester.tap(find.text('차은우'));
        await tester.pump();

        expect(navigated, <String>['/trainer/manage/6']);
      });
    });

    group('BUG-4 — nickName은 타입만 거짓말이다', () {
      testWidgets('별칭이 오면 이름 아래에 그린다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 1, name: '차은우', nickName: '은우님'),
        ];

        await pump(tester);

        expect(find.text('은우님'), findsOneWidget);
      });

      testWidgets('별칭이 있어도 카드 높이는 72 그대로다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 1, name: '차은우', nickName: '은우님'),
        ];

        await pump(tester);

        // 이름(22.4) + 별칭(18) = 40.4 > 콘텐츠 박스 32. 웹에는
        // `overflow-hidden`이 없어 **카드 위아래로 넘쳐 그려질 뿐 높이는
        // 72 그대로**다. `OverflowBox`가 그 동작을 만든다 — 없으면
        // Flutter는 RenderFlex 오버플로로 터진다.
        expect(tester.getSize(_cardOf(tester, '차은우')).height, 72);
        expect(tester.takeException(), isNull);
      });

      testWidgets('빈 문자열 별칭은 그리지 않는다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 1, name: '차은우', nickName: ''),
        ];

        await pump(tester);

        // 웹 `{item.nickName && ...}` — 빈 문자열은 falsy다.
        //
        // `find.text('')`로는 확인할 수 없다 — 비어 있는 검색 입력이
        // 걸린다(규율 #19의 사촌: 찾은 것이 네가 생각한 그것이 아니다).
        // 별칭 줄이 실제로 없으면 이름이 카드 세로 가운데에 놓인다.
        final card = _cardOf(tester, '차은우');
        expect(tester.getSize(card).height, 72);
        expect(
          tester.getCenter(find.text('차은우')).dy,
          closeTo(tester.getCenter(card).dy, 0.01),
        );
      });
    });

    group('BUG-41 — `가입` 배지가 전원에게 붙는다', () {
      testWidgets('isNonmember가 true인 회원에게도 붙는다', (tester) async {
        await pump(tester);

        // 픽스처의 두 회원은 `isNonmember`가 각각 false/true인데 배지는
        // 둘 다 달린다. 웹이 존재하지 않는 키 `nonmember`를 읽기 때문이고,
        // 2026-09-15 브라우저 실측도 같았다.
        expect(find.text('가입'), findsNWidgets(2));
      });

      testWidgets('전원이 미가입이어도 전원에게 붙는다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 1, name: '가', isNonmember: true),
          _member(memberId: 2, name: '나', isNonmember: true),
          _member(memberId: 3, name: '다', isNonmember: true),
        ];

        await pump(tester);

        expect(find.text('가입'), findsNWidgets(3));
      });
    });

    group('정렬', () {
      testWidgets('기본값은 `기본 순`이고 memberId 오름차순이다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 30, name: '삼십', ranking: 1),
          _member(memberId: 10, name: '십', ranking: 3),
          _member(memberId: 20, name: '이십', ranking: 2),
        ];

        await pump(tester);

        expect(find.text('기본 순'), findsOneWidget);
        expect(_names(tester), <String>['십', '이십', '삼십']);
      });

      // 위 두 정렬 테스트가 **보이는 순서**를 재는지 확인한다. 헬퍼가
      // 트리 순서로 읽고 y로 다시 정렬하는데, 둘이 어긋나면 정렬 단언이
      // 사용자가 보는 것과 다른 것을 재고 있다는 뜻이다.
      testWidgets('트리 순서와 화면 순서가 같다 (헬퍼 전제 검증)', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 30, name: '삼십', ranking: 1),
          _member(memberId: 10, name: '십', ranking: 3),
          _member(memberId: 20, name: '이십', ranking: 2),
        ];

        await pump(tester);

        expect(_treeOrderNames(tester), _names(tester));

        // 랭킹 순으로 바꾼 뒤에도 같아야 한다.
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.sortTrigger')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('랭킹 순').last);
        await tester.pumpAndSettle();

        expect(_treeOrderNames(tester), _names(tester));
      });

      testWidgets('`랭킹 순`을 고르면 ranking 오름차순이 된다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 30, name: '삼십', ranking: 1),
          _member(memberId: 10, name: '십', ranking: 3),
          _member(memberId: 20, name: '이십', ranking: 2),
        ];

        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.sortTrigger')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('랭킹 순').last);
        await tester.pumpAndSettle();

        expect(_names(tester), <String>['삼십', '이십', '십']);
      });

      testWidgets('드롭다운은 선택된 것만 검정, 나머지는 gray500이다', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.sortTrigger')),
        );
        await tester.pumpAndSettle();

        // 트리거에도 `기본 순`이 있으므로 패널 쪽(마지막)을 집는다.
        final selected = tester.widget<Text>(find.text('기본 순').last);
        final other = tester.widget<Text>(find.text('랭킹 순').last);
        expect(selected.style?.color, Colors.black);
        expect(other.style?.color, AppColors.light.gray500);
      });

      testWidgets('바깥을 누르면 닫힌다', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.sortTrigger')),
        );
        await tester.pumpAndSettle();
        expect(find.text('랭킹 순'), findsOneWidget);

        await tester.tapAt(const Offset(20, 300));
        await tester.pumpAndSettle();

        expect(find.text('랭킹 순'), findsNothing);
      });
    });

    group('검색', () {
      testWidgets('이름으로 거른다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), '차은');
        await tester.pumpAndSettle();

        expect(find.text('차은우'), findsOneWidget);
        expect(find.text('rr'), findsNothing);
        expect(find.textContaining('총 1명'), findsOneWidget);
      });

      testWidgets('BUG-22 — 검색어만 소문자가 되어 영문 이름을 못 찾는다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 1, name: 'Kim'),
        ];

        await pump(tester);
        await tester.enterText(find.byType(TextField), 'kim');
        await tester.pumpAndSettle();

        // 웹 `student.name.includes(keyword.toLowerCase())` — 이름은
        // 소문자로 바꾸지 않으므로 `Kim`은 `kim`으로 찾아지지 않는다.
        expect(find.text('Kim'), findsNothing);
        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
      });

      testWidgets('BUG-22 — 소문자 부분만 치면 찾아진다', (tester) async {
        adapter.data = <Map<String, dynamic>>[
          _member(memberId: 1, name: 'Kim'),
        ];

        await pump(tester);
        // 대문자가 섞이지 않은 조각(`im`)은 소문자화의 영향을 받지 않아
        // 걸린다. **첫 글자 `K`가 들어간 검색어는 무엇을 쳐도 못 찾는다** —
        // `Ki`도 `ki`가 되어 어긋난다.
        await tester.enterText(find.byType(TextField), 'im');
        await tester.pumpAndSettle();
        expect(find.text('Kim'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Ki');
        await tester.pumpAndSettle();
        expect(find.text('Kim'), findsNothing);
      });
    });

    group('빈 상태 — 두 가지가 다르다', () {
      testWidgets('서버가 null을 주면 `등록된 회원이 없습니다.` + 등록 버튼', (tester) async {
        adapter.data = null;

        await pump(tester);

        expect(find.text('등록된 회원이 없습니다.'), findsOneWidget);
        expect(find.text('회원 등록하기'), findsOneWidget);
        expect(find.text('검색 결과가 없습니다.'), findsNothing);
      });

      testWidgets('검색 결과 0건이면 `검색 결과가 없습니다.`이고 버튼이 없다', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pumpAndSettle();

        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
        expect(find.text('회원 등록하기'), findsNothing);
      });

      testWidgets('요청이 실패하면 null 상태가 아니라 `검색 결과가 없습니다.`다', (tester) async {
        adapter.fails = true;

        await pump(tester);

        // 웹 `data`는 에러일 때 `undefined`라 `studentList === null`이
        // 거짓이 된다. 에러 분기가 아예 없는 웹(BUG-13)의 결과다.
        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
        expect(find.text('등록된 회원이 없습니다.'), findsNothing);
        expect(find.text('회원 등록하기'), findsNothing);
      });

      testWidgets('빈 상태에서도 카운트와 정렬이 함께 보인다', (tester) async {
        adapter.data = null;

        await pump(tester);

        // 웹에서 이 행은 세 분기의 **형제**라 회원이 0명이어도 남는다.
        expect(find.textContaining('총 0명'), findsOneWidget);
        expect(find.text('기본 순'), findsOneWidget);
      });

      // 두 문구의 색을 **한 테스트 안에서** 비교하지 않는다. 같은
      // `pumpWidget`을 두 번 부르면 State가 재사용돼(이 프로젝트에서 세 번
      // 겪은 함정) 두 번째 렌더가 첫 응답 상태를 물고 늘어진다.
      testWidgets('`등록된 회원이 없습니다.`는 gray700이다', (tester) async {
        adapter.data = null;

        await pump(tester);

        final text = tester.widget<Text>(find.text('등록된 회원이 없습니다.'));
        expect(text.style?.color, AppColors.light.gray700);
        expect(text.style?.color, isNot(AppColors.light.gray500));
      });

      testWidgets('`검색 결과가 없습니다.`는 gray500이다', (tester) async {
        await pump(tester);
        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text('검색 결과가 없습니다.'));
        expect(text.style?.color, AppColors.light.gray500);
        expect(text.style?.color, isNot(AppColors.light.gray700));
      });
    });

    group('회원 추가 다이얼로그', () {
      testWidgets('헤더 +를 누르면 열린다', (tester) async {
        await pump(tester);

        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();

        expect(find.text('회원 추가'), findsOneWidget);
        expect(find.text('회원 직접 추가'), findsOneWidget);
        expect(find.text('가입된 회원 추가'), findsOneWidget);
      });

      testWidgets('빈 상태의 `회원 등록하기`도 같은 다이얼로그를 연다', (tester) async {
        adapter.data = null;

        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.register')),
        );
        await tester.pumpAndSettle();

        expect(find.text('회원 직접 추가'), findsOneWidget);
      });

      testWidgets('두 링크가 각자 경로로 간다', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('회원 직접 추가'));
        await tester.pumpAndSettle();
        expect(navigated, <String>['/trainer/manage/invite']);

        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('가입된 회원 추가'));
        await tester.pumpAndSettle();
        expect(navigated, <String>[
          '/trainer/manage/invite',
          '/trainer/manage/append',
        ]);
      });

      testWidgets('닫기를 누르면 닫힌다', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('AddStudentDialog.close')));
        await tester.pumpAndSettle();

        expect(find.text('회원 직접 추가'), findsNothing);
        expect(navigated, isEmpty);
      });
    });

    /// 2026-09-15 브라우저 실측(440×900, `docs/trainer-manage-s1-measurements.md`).
    ///
    /// **값을 상수로 쓰지 않고 리터럴로 적는다**(규율 #18). `expect(h,
    /// TrainerManagePage.cardHeight)`는 상수를 바꾸면 테스트도 따라 바뀌어
    /// 아무것도 지키지 못한다.
    group('치수 실측 (440×900)', () {
      testWidgets('헤더 56 · 우측 + 버튼 20×20', (tester) async {
        await pump(tester);

        expect(tester.getSize(find.byType(AppLayoutHeader)).height, 56);
        expect(
          tester.getSize(
            find.byKey(const ValueKey('TrainerManagePage.addStudent')),
          ),
          const Size(20, 20),
        );
      });

      testWidgets('검색 회색 박스 400×44', (tester) async {
        await pump(tester);

        // `Container`가 아니라 그 자리의 실제 박스를 잰다 — 검색 입력을
        // 품은 조상 중 회색 배경을 가진 것.
        final box = find.ancestor(
          of: find.byType(TextField),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color ==
                    AppColors.light.gray200,
          ),
        );

        expect(tester.getSize(box), const Size(400, 44));
      });

      testWidgets('돋보기 아이콘 20×20 · 검색 좌우 여백 20', (tester) async {
        await pump(tester);

        final icon = _svg('assets/images/search.svg');
        expect(_svgRequestedSize(tester, icon), const Size(20, 20));
        // 440 − 400 = 40(좌우 20씩, `px-7`) + 회색 박스 `px-6` 16 = 36.
        expect(tester.getTopLeft(icon).dx, 36);
      });

      testWidgets('카운트+정렬 행 400×36', (tester) async {
        await pump(tester);

        final row = find.ancestor(
          of: find.textContaining('총 '),
          matching: find.byType(SizedBox),
        );
        expect(tester.getSize(row.first), const Size(400, 36));
      });

      testWidgets('회원 카드 400×72 · 카드 사이 10', (tester) async {
        await pump(tester);

        final first = _cardOf(tester, '차은우');
        final second = _cardOf(tester, 'rr');

        expect(tester.getSize(first), const Size(400, 72));
        expect(tester.getSize(second), const Size(400, 72));
        expect(
          tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
          10,
        );
      });

      testWidgets('카드 세로 위치 — 검색바 아래 실측 좌표와 같다', (tester) async {
        await pump(tester);

        // 헤더 56 + 검색 래퍼 76 + `mt-1` 4 + 카운트행 36 + `mb-4` 10 = 182.
        expect(tester.getTopLeft(_cardOf(tester, '차은우')).dy, 182);
      });

      testWidgets('기본 프로필 아이콘 32×32', (tester) async {
        await pump(tester);

        final avatar = _svg('assets/images/profile_default.svg').first;
        expect(_svgRequestedSize(tester, avatar), const Size(32, 32));
        expect(tester.getSize(avatar), const Size(32, 32));
      });

      testWidgets('`가입` 배지가 이름 높이(22.4)에 맞춰 늘어난다', (tester) async {
        await pump(tester);

        final badge = find.ancestor(
          of: find.text('가입').first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color ==
                    AppColors.light.blue50,
          ),
        );

        // 내용 기준 높이는 15 + 1.5 + 1.5 = 18인데, 웹은 형제(이름)에 맞춰
        // stretch된다. **18이면 stretch가 빠진 것이다.**
        //
        // 웹 실측은 22.41인데 여기서는 22.0이다 — Flutter가 줄 상자 높이를
        // 정수로 반올림하기 때문이고(16×1.4 = 22.4 → 22.0), 이식 오류가
        // 아니다. 그래서 절대값 대신 **이름과 같은 높이인지**를 단언한다.
        final nameHeight = tester.getSize(find.text('차은우')).height;
        expect(tester.getSize(badge).height, nameHeight);
        expect(tester.getSize(badge).height, isNot(closeTo(18, 0.5)));

        // 늘어난 상자 **안에서 글자는 가운데**다(웹 `flex-center`).
        // 이 단언이 없으면 `alignment`를 지워도 아무도 모른다 — 상자 높이는
        // 그대로고 글자만 위로 붙는다.
        expect(
          tester.getCenter(find.text('가입').first).dy,
          closeTo(tester.getCenter(badge).dy, 0.01),
        );
      });

      testWidgets('빈 상태 아이콘 35×36 (정사각형이 아니다)', (tester) async {
        adapter.data = null;

        await pump(tester);

        final icon = _svg('assets/images/alert_circle.svg');
        expect(_svgRequestedSize(tester, icon), const Size(35, 36));
      });

      testWidgets('`회원 등록하기` 146×48', (tester) async {
        adapter.data = null;

        await pump(tester);

        expect(
          tester.getSize(
            find.byKey(const ValueKey('TrainerManagePage.register')),
          ),
          const Size(146, 48),
        );
      });

      testWidgets('드롭다운 패널 96 폭 · 항목 45 · 간격 0', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.sortTrigger')),
        );
        await tester.pumpAndSettle();

        final firstItem = find.ancestor(
          of: find.text('기본 순').last,
          matching: find.byType(Container),
        );
        final secondItem = find.ancestor(
          of: find.text('랭킹 순').last,
          matching: find.byType(Container),
        );

        // 패널 폭 96 − 좌우 패딩 4 − 테두리 1 = 86.
        expect(tester.getSize(firstItem.first), const Size(86, 45));
        expect(
          tester.getTopLeft(secondItem.first).dy -
              tester.getBottomLeft(firstItem.first).dy,
          0,
        );
      });

      testWidgets('드롭다운이 트리거 오른쪽에서 9, 아래로 8 어긋난다', (tester) async {
        await pump(tester);
        final trigger = find.byKey(
          const ValueKey('TrainerManagePage.sortTrigger'),
        );
        final triggerRect = tester.getRect(trigger);

        await tester.tap(trigger);
        await tester.pumpAndSettle();

        final panel = find.ancestor(
          of: find.text('랭킹 순').last,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null,
          ),
        );
        final panelRect = tester.getRect(panel.first);

        expect(panelRect.right - triggerRect.right, -9);
        expect(panelRect.top - triggerRect.bottom, 8);
        expect(panelRect.width, 96);
      });

      testWidgets('다이얼로그가 맨 위에 붙고 폭 440 · 헤더 56', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();

        final panel = find.ancestor(
          of: find.text('회원 추가'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null,
          ),
        );
        final rect = tester.getRect(panel.first);

        expect(rect.top, 0);
        expect(rect.width, 440);
        // 헤더 56 + 사이 10 + 본문(16 + 링크 + 16) + 테두리 1+1.
        //
        // 웹 실측은 149.5, 여기서는 150이다. 링크 높이가 웹 49.5
        // (아이콘 24 + 간격 6 + 글자 19.5)인데 Flutter는 글자를 20으로
        // 올려 50이 된다 — 배지와 같은 반올림이다.
        expect(rect.height, 150);
        expect(rect.height, closeTo(149.5, 1));
      });

      testWidgets('다이얼로그 두 링크가 폭을 정확히 반씩 나눈다', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();

        final invite = tester.getRect(
          find.byKey(const ValueKey('AddStudentDialog.invite')),
        );
        final append = tester.getRect(
          find.byKey(const ValueKey('AddStudentDialog.append')),
        );

        // 웹 `justify-evenly`는 실효가 없다 — 두 링크가 `w-full`이라 여백이
        // 0이고, 테두리 1+1을 뺀 438을 219씩 나눈다.
        expect(invite.width, 219);
        expect(append.width, 219);
        expect(append.left, invite.right);
      });
    });

    group('폰 너비(390pt)', () {
      void usePhoneViewport(WidgetTester tester) {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      testWidgets('긴 이름과 별칭이 있어도 넘치지 않는다', (tester) async {
        usePhoneViewport(tester);
        adapter.data = <Map<String, dynamic>>[
          _member(
            memberId: 1,
            name: '아주아주아주아주아주긴이름을가진회원입니다',
            nickName: '별칭도아주아주아주아주길다',
            lessonCnt: 100,
            remainLessonCnt: 99,
          ),
        ];

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('빈 상태도 넘치지 않는다', (tester) async {
        usePhoneViewport(tester);
        adapter.data = null;

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('다이얼로그도 넘치지 않는다', (tester) async {
        usePhoneViewport(tester);

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('TrainerManagePage.addStudent')),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('이동', () {
      testWidgets('뒤로가기는 pop이 아니라 /trainer로 간다', (tester) async {
        await pump(tester);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // 웹은 `<Link href='/trainer'>`다.
        expect(navigated, <String>['/trainer']);
      });

      testWidgets('하단 네비가 있고 홈 탭이 활성이다', (tester) async {
        await pump(tester);

        // 웹 L33: 아이콘은 `/trainer`와 `/trainer/manage` 둘 다에서 켜진다.
        expect(find.text('스케줄'), findsOneWidget);
        expect(find.text('마이'), findsOneWidget);
      });
    });
  });
}

/// 카드에 그려진 이름을 **화면에 보이는 위쪽부터** 읽는다.
///
/// `widgetList`가 돌려주는 것은 트리 순서(깊이 우선)지 시각 순서가 아니다.
/// 지금은 `ListView.separated`라 둘이 같지만, 그것은 우연이지 보장이 아니다
/// (규율 #19의 사촌 — 공유 성질로 고른 집합은 네가 생각한 순서가 아닐 수
/// 있다). 그래서 **y 좌표로 다시 정렬한다.** 둘이 실제로 같다는 것은
/// 아래 `_treeOrderNames`와 대조하는 테스트가 확인한다.
List<String> _names(WidgetTester tester) {
  final names = _treeOrderNames(tester);
  return names..sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
}

/// 트리 순서 그대로. `_names`와 대조하기 위해서만 쓴다.
List<String> _treeOrderNames(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    // 카드 이름은 `title1`(16/700)이다. `가입`(10/400)·`잔여`(13/400)·
    // `총 n명`(14/400)은 걸리지 않는다.
    .where((text) => text.style?.fontWeight == FontWeight.w700)
    .map((text) => text.data)
    .whereType<String>()
    // 헤더 제목도 w700이다(웹 `HEADING_4`). 빈 상태 문구도 `title1`이라
    // w700이지만 카드와 함께 그려지는 일이 없다.
    .where((name) => name != '나의 회원')
    .toList();

/// 이름으로 그 회원의 카드 상자를 집는다.
Finder _cardOf(WidgetTester tester, String name) => find
    .ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == Colors.white,
      ),
    )
    .first;

/// 자산 경로로 `SvgPicture`를 집는다.
Finder _svg(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is SvgPicture &&
      widget.bytesLoader is SvgAssetLoader &&
      (widget.bytesLoader as SvgAssetLoader).assetName == asset,
);

/// `SvgPicture`가 **요청한** 크기.
///
/// `tester.getSize`로는 이 값을 확인할 수 없다 — flutter_svg는 안쪽에
/// `FittedBox`를 두고, `getSize`가 찾아내는 렌더박스는 요청 크기가 아니라
/// **viewBox 고유 크기**다. 실제로 `width`를 35에서 36으로 바꿔도
/// `getSize`는 그대로 35를 돌려준다(뮤테이션 M16으로 확인). 그래서 위젯의
/// 선언값을 직접 읽는다.
Size _svgRequestedSize(WidgetTester tester, Finder finder) {
  final picture = tester.widget<SvgPicture>(finder);
  // 둘 다 넘기지 않은 `SvgPicture`는 크기를 주장하지 않는 것이라 잴 값이
  // 없다 — 0을 돌려주면 단언이 조용히 어긋나므로 여기서 세운다.
  expect(picture.width, isNotNull, reason: 'width 를 넘기지 않은 SvgPicture다');
  expect(picture.height, isNotNull, reason: 'height 를 넘기지 않은 SvgPicture다');
  return Size(picture.width!, picture.height!);
}
