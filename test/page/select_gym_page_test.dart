import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/model/auth_state.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';
import 'package:geonganghaejim/entity/auth/ui/auth_scope.dart';
import 'package:geonganghaejim/entity/gym/api/gym_api.dart';
import 'package:geonganghaejim/feature/gym/ui/gym_select_list.dart';
import 'package:geonganghaejim/page/protected/select_gym_page.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_otp_input.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';
import '../support/auth_fakes.dart';

/// 경로별로 다른 응답을 돌려주는 어댑터.
///
/// 이 화면은 요청이 둘이고(`GET /gyms`, `POST /gyms/{id}`) 테스트마다
/// 한쪽만 실패시켜야 해서, 경로를 보고 갈라야 한다.
class _StubAdapter implements HttpClientAdapter {
  /// `GET /api/v1/gyms` 응답 바디.
  String listBody =
      '{"status":200,"message":"성공","data":['
      '{"gymId":1,"name":"건강해짐 강남점"},'
      '{"gymId":2,"name":"건강해짐 판교점"}]}';

  /// 등록(POST) 응답 상태. 200이 아니면 dio가 던진다.
  int registerStatus = 200;
  String registerBody =
      '{"status":200,"message":"성공","data":{"id":1,"name":"건강해짐 강남점"}}';

  /// 목록 응답을 붙잡아 둔다. 로딩 표시를 관찰하려면 응답이 와 있으면 안 된다.
  Completer<void>? listGate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isRegister = options.method.toUpperCase() == 'POST';
    if (!isRegister && listGate != null) {
      await listGate!.future;
    }
    return ResponseBody.fromString(
      isRegister ? registerBody : listBody,
      isRegister ? registerStatus : 200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const AuthUser _studentWithoutGym = AuthUser(
  memberId: 7,
  name: '신규',
  userId: 'student1',
  memberType: 'STUDENT',
);

const AuthUser _trainerWithoutGym = AuthUser(
  memberId: 8,
  name: '트레이너',
  userId: 'trainer1',
  memberType: 'TRAINER',
);

void main() {
  group('SelectGymPage', () {
    late RequestCapture capture;
    late _StubAdapter adapter;
    late Dio dio;
    late AppToastController toast;
    late FakeTokenStorage tokens;
    late FakeAuthProfileStorage profile;
    late AuthState auth;

    setUp(() {
      capture = RequestCapture();
      adapter = _StubAdapter();
      // 저장소를 **하나**로 묶는다. `AuthState`가 쓰는 토큰과 인터셉터가
      // 읽는 토큰이 갈라지면 "요청에 헤더가 붙는가"를 검증할 수 없다 —
      // Phase 0 최종 리뷰가 지적한 바로 그 구멍이다.
      tokens = FakeTokenStorage(access: 'a', refresh: 'r');
      dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: tokens,
        extra: <Interceptor>[capture],
      );
      dio.httpClientAdapter = adapter;
      toast = AppToastController();
    });

    tearDown(() => toast.dispose());

    /// 로그인 상태의 [AuthState]를 만든다.
    Future<void> signedInAs(AuthUser user) async {
      profile = FakeAuthProfileStorage(user: user);
      auth = AuthState(tokens, profile);
      await auth.restore();
    }

    // 라우터를 끼우지 않는다(`next-steps.md` §7-3). 등록 성공 후의 이동은
    // `app_test.dart`에서 본다 — 여기서 라우터를 끼우면 목적지 화면이
    // 트리에 들어와 이 화면의 요청 캡처와 단언이 오염된다.
    Widget wrap() => MaterialApp(
      theme: AppTheme.light(),
      home: AuthScope(
        notifier: auth,
        child: AppToastScope(
          notifier: toast,
          child: AppToastHost(child: SelectGymPage(gymApi: GymApi(dio))),
        ),
      ),
    );

    Future<void> pumpAsStudent(WidgetTester tester) async {
      await signedInAs(_studentWithoutGym);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    Future<void> pumpAsTrainer(WidgetTester tester) async {
      await signedInAs(_trainerWithoutGym);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    bool isEnabled(WidgetTester tester, String label) {
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, label),
      );
      return button.onPressed != null;
    }

    group('step 1 — 헬스장 목록', () {
      // 골든 `select-gym`은 `har/select-gym.har`에서 생성했다 — 2026-09-15,
      // 공개 체험 계정으로 로그인한 상태에서 `/select-gym`을 열어 캡처한
      // `GET /api/v1/gyms` 1건이다. 등록 POST는 그 계정의 소속 헬스장을 실제로
      // 바꾸는 공유 상태 뮤테이션이라 캡처하지 않았고, 아래 등록 그룹의 계약
      // 테스트가 그 요청 모양을 대신 고정한다.
      testWidgets('들어오면 웹과 같은 목록 요청을 보낸다', (tester) async {
        await pumpAsStudent(tester);

        expectParity('select-gym', capture.captured);
      });

      testWidgets('목록 요청은 GET /api/v1/gyms 하나뿐이다', (tester) async {
        await pumpAsStudent(tester);

        expect(capture.captured, hasLength(1));
        expect(capture.captured.single.method, 'GET');
        expect(capture.captured.single.path, '/api/v1/gyms');
      });

      // 웹도 `authApi`를 쓴다. 헤더가 빠지면 서버가 401을 주므로
      // 화면이 통째로 비어 보인다.
      testWidgets('목록 요청에 Authorization이 붙는다', (tester) async {
        await pumpAsStudent(tester);

        expect(
          capture.captured.single.headers.containsKey('authorization'),
          isTrue,
        );
      });

      testWidgets('STUDENT에게는 "다니시는" 제목을 보여준다', (tester) async {
        await pumpAsStudent(tester);

        expect(find.text('다니시는 헬스장을\n선택해주세요.'), findsOneWidget);
      });

      testWidgets('TRAINER에게는 "수업하시는" 제목을 보여준다', (tester) async {
        await pumpAsTrainer(tester);

        expect(find.text('수업하시는 헬스장을\n선택해주세요.'), findsOneWidget);
      });

      testWidgets('불러오는 동안 로딩을 보여주고 목록은 아직 없다', (tester) async {
        adapter.listGate = Completer<void>();
        await signedInAs(_studentWithoutGym);
        await tester.pumpWidget(wrap());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('건강해짐 강남점'), findsNothing);

        adapter.listGate!.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('건강해짐 강남점'), findsOneWidget);
      });

      testWidgets('불러온 헬스장 이름을 모두 보여준다', (tester) async {
        await pumpAsStudent(tester);

        expect(find.text('건강해짐 강남점'), findsOneWidget);
        expect(find.text('건강해짐 판교점'), findsOneWidget);
      });

      testWidgets('고르기 전에는 다음 버튼이 비활성이다', (tester) async {
        await pumpAsStudent(tester);

        expect(isEnabled(tester, '다음'), isFalse);
      });

      testWidgets('고르면 다음 버튼이 활성된다', (tester) async {
        await pumpAsStudent(tester);

        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();

        expect(isEnabled(tester, '다음'), isTrue);
      });

      testWidgets('선택한 타일만 강조된다', (tester) async {
        await pumpAsStudent(tester);

        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();

        BoxDecoration decorationOf(int gymId) {
          final container = tester.widget<Container>(
            find.byKey(GymSelectList.tileKey(gymId)),
          );
          return container.decoration! as BoxDecoration;
        }

        // 웹: 선택 시 `border-2 border-primary-500 bg-white`,
        // 아니면 `bg-gray-100`(테두리 없음).
        expect(decorationOf(1).border, isNotNull);
        expect(decorationOf(1).color, Colors.white);
        expect(decorationOf(2).border, isNull);
        expect(decorationOf(2).color, AppColors.light.gray100);
      });
    });

    group('STUDENT 등록', () {
      testWidgets('다음을 누르면 바디 없이 POST 한다', (tester) async {
        // 실패 응답을 주어 이 테스트가 이동까지 가지 않게 한다 —
        // 라우터가 없으므로 이동하면 터진다. 요청의 모양만 본다.
        adapter.registerStatus = 500;
        await pumpAsStudent(tester);

        await tester.tap(find.text('건강해짐 판교점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        final register = capture.captured.last;
        expect(register.method, 'POST');
        expect(register.path, '/api/v1/gyms/2');
        expect(register.body, isNull);

        // 토스트의 2초 타이머를 남기면 프레임워크가 pending timer로 잡는다.
        toast.dismiss();
      });

      // 웹 `SelectGymPage`의 STUDENT 분기는 `clickNext`를 거치지 않고
      // 곧바로 `handleRegisterGym`이다. step 2로 가면 다른 화면이 된다.
      testWidgets('인증 코드 단계를 거치지 않는다', (tester) async {
        adapter.registerStatus = 500;
        await pumpAsStudent(tester);

        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        expect(find.text('인증 코드를 입력해 주세요.'), findsNothing);
        expect(find.byType(AppOtpInput), findsNothing);

        // 토스트의 2초 타이머를 남기면 프레임워크가 pending timer로 잡는다.
        toast.dismiss();
      });
    });

    group('TRAINER 등록', () {
      testWidgets('다음을 누르면 요청 없이 인증 코드 단계로 간다', (tester) async {
        await pumpAsTrainer(tester);
        final beforeTap = capture.captured.length;

        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        expect(find.text('인증 코드를 입력해 주세요.'), findsOneWidget);
        expect(find.byType(AppOtpInput), findsOneWidget);
        expect(
          capture.captured,
          hasLength(beforeTap),
          reason: 'step 전환은 요청이 아니다',
        );
      });

      testWidgets('코드가 6자 미만이면 완료 버튼이 비활성이다', (tester) async {
        await pumpAsTrainer(tester);
        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        expect(isEnabled(tester, '완료'), isFalse);

        await tester.enterText(find.byType(EditableText), '12345');
        await tester.pump();

        expect(isEnabled(tester, '완료'), isFalse);
      });

      testWidgets('코드가 6자면 완료 버튼이 활성된다', (tester) async {
        await pumpAsTrainer(tester);
        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(EditableText), '123456');
        await tester.pump();

        expect(isEnabled(tester, '완료'), isTrue);
      });

      testWidgets('완료를 누르면 joinCode를 담아 POST 한다', (tester) async {
        adapter.registerStatus = 500;
        await pumpAsTrainer(tester);
        await tester.tap(find.text('건강해짐 판교점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(EditableText), '123456');
        await tester.pump();
        await tester.tap(find.text('완료'));
        await tester.pumpAndSettle();

        final register = capture.captured.last;
        expect(register.method, 'POST');
        expect(register.path, '/api/v1/gyms/2');
        expect(register.body, <String, dynamic>{'joinCode': '123456'});

        // 토스트의 2초 타이머를 남기면 프레임워크가 pending timer로 잡는다.
        toast.dismiss();
      });

      // 웹 `clickNext`: `setStep(prev + 1)` **그리고** `setAuthValue('')`.
      testWidgets('인증 코드 단계에 들어갈 때마다 코드가 비워진다', (tester) async {
        await pumpAsTrainer(tester);
        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(EditableText), '123456');
        await tester.pump();
        expect(isEnabled(tester, '완료'), isTrue);

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        expect(isEnabled(tester, '완료'), isFalse);
      });

      // 웹 `clickBack`은 `setStep(prev - 1)`뿐이다 — `setSelectGymId(null)`이
      // 없다. `clickNext`가 코드를 지우는 것과 **비대칭**이며, 그래서
      // 돌아오면 고른 헬스장이 그대로 남아 다음 버튼이 활성이다.
      testWidgets('뒤로 오면 고른 헬스장은 그대로다', (tester) async {
        await pumpAsTrainer(tester);
        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('다니시는 헬스장을\n선택해주세요.'), findsNothing);
        expect(isEnabled(tester, '다음'), isTrue, reason: '선택이 유지돼야 활성이다');
      });
    });

    group('등록 실패', () {
      testWidgets('서버 메시지를 토스트로 띄운다', (tester) async {
        adapter.registerStatus = 400;
        adapter.registerBody =
            '{"status":400,"message":"가입 코드가 올바르지 않습니다.","data":null}';
        await pumpAsStudent(tester);

        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        expect(find.text('가입 코드가 올바르지 않습니다.'), findsOneWidget);

        // 토스트의 2초 타이머를 남기면 프레임워크가 pending timer로 잡는다.
        toast.dismiss();
      });

      // 실패했는데 프로필이 갱신되면, 헬스장이 없는 계정이 홈을 볼 수 있게
      // 된다(라우터의 `gymId == null` 게이트가 풀린다).
      testWidgets('프로필의 gymId를 갱신하지 않는다', (tester) async {
        adapter.registerStatus = 500;
        await pumpAsStudent(tester);

        await tester.tap(find.text('건강해짐 강남점'));
        await tester.pump();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();

        expect(auth.user!.gymId, isNull);
        expect(profile.writeCount, 0);

        // 토스트의 2초 타이머를 남기면 프레임워크가 pending timer로 잡는다.
        toast.dismiss();
      });
    });
  });
}
