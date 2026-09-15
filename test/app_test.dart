import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/app.dart';
import 'package:geonganghaejim/core/router/app_router.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_text_input.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

import 'support/auth_fakes.dart';

/// 앱이 쏘는 요청에 고정 응답을 돌려주는 어댑터.
///
/// 라우팅 테스트는 화면이 실제로 뜨는지를 보는데, `/select-gym` 같은 화면은
/// 뜨자마자 요청을 쏜다. 전송 계층을 막지 않으면 실제 네트워크를 때리려다
/// 느려지고 흔들린다.
class _StubAdapter implements HttpClientAdapter {
  /// 등록(POST) 응답 상태. 200이 아니면 dio가 던진다.
  int registerStatus = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isPost = options.method.toUpperCase() == 'POST';
    return ResponseBody.fromString(
      isPost
          ? '{"status":200,"message":"성공","data":{"id":1,"name":"건강해짐 강남점"}}'
          : '{"status":200,"message":"성공","data":['
                '{"gymId":1,"name":"건강해짐 강남점"},'
                '{"gymId":2,"name":"건강해짐 판교점"}]}',
      isPost ? registerStatus : 200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 저장소를 페이크로 바꾼 앱. 실제 구현은 플랫폼 채널을 타서 테스트에서
/// 뜨지 않는다.
Widget _app({
  FakeTokenStorage? tokens,
  FakeAuthProfileStorage? profile,
  String initialLocation = AppRoutes.onboarding,
  HttpClientAdapter? adapter,
}) {
  return GeonganghaejimApp(
    baseUrl: 'https://example.test',
    tokenStorage: tokens ?? FakeTokenStorage(),
    profileStorage: profile ?? FakeAuthProfileStorage(),
    initialLocation: initialLocation,
    httpClientAdapter: adapter ?? _StubAdapter(),
  );
}

/// 쓰기가 **느린** 프로필 저장소.
///
/// 페이크 저장소는 즉시 반환해서 "저장 먼저, 이동 나중"이라는 순서 제약이
/// 드러나지 않는다. 실제 구현(`flutter_secure_storage`)은 플랫폼 채널을 타는
/// 진짜 비동기라 그 사이에 라우터가 옛 프로필로 리다이렉트를 계산할 수 있다.
/// 이 페이크가 그 창을 테스트에서 재현한다.
///
/// **2초인 이유(실측):** `pumpAndSettle`은 기본 100ms씩 시간을 진행시킨다.
/// 지연이 그보다 짧으면 첫 pump 한 번에 쓰기까지 완료돼 버려서, 순서를
/// 뒤집는 뮤테이션을 넣어도 테스트가 그대로 통과한다(50ms로 확인함).
/// 창이 여러 프레임에 걸쳐야 라우터가 옛 프로필로 리다이렉트를 계산하는
/// 순간이 실제로 관측된다.
class _SlowProfileStorage extends FakeAuthProfileStorage {
  _SlowProfileStorage({super.user});

  @override
  Future<void> write(AuthUser user) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await super.write(user);
  }
}

/// `/select-gym`이 떴음을 알아보는 문구(STUDENT 기준).
const String _selectGymHeadline = '다니시는 헬스장을\n선택해주세요.';

/// 헬스장 미선택 트레이너.
const AuthUser _trainerWithoutGym = AuthUser(
  memberId: 9,
  name: '신규트레이너',
  userId: 'trainer1',
  memberType: 'TRAINER',
);

/// 헬스장 미선택 계정(`Tokens.gymId`가 null인 신규 가입자).
const AuthUser _studentWithoutGym = AuthUser(
  memberId: 7,
  name: '신규',
  userId: 'student1',
  memberType: 'STUDENT',
);

const AuthUser _student = AuthUser(
  memberId: 6,
  name: '홍길동',
  userId: 'student0',
  memberType: 'STUDENT',
  gymId: 1,
);

void main() {
  group('세션 복원', () {
    testWidgets('저장된 세션이 없으면 온보딩(역할 선택)을 띄운다', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // 웹 `app/page.tsx`의 `role === null` → `<OnboardingPage />` 분기.
      expect(find.text('안녕하세요!\n건강해짐입니다!'), findsOneWidget);
      expect(find.text('트레이너로 시작'), findsOneWidget);
      expect(find.text('회원으로 시작'), findsOneWidget);
    });

    testWidgets('토큰과 프로필이 모두 있으면 바로 자기 홈으로 간다', (tester) async {
      // 웹 `app/page.tsx`의 `redirect(`/${role.toLowerCase()}`)` 분기.
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _student),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('회원 홈'), findsOneWidget);
      expect(find.text('트레이너로 시작'), findsNothing);
    });

    testWidgets('토큰만 있고 프로필이 없으면 로그아웃 취급하고 토큰을 지운다', (tester) async {
      // 이 조합이 위험한 이유: 인터셉터는 헤더를 붙이는데 라우터는 갈 곳을
      // 몰라, "요청은 인증되는데 화면은 비로그인"인 어긋남이 남는다.
      final tokens = FakeTokenStorage(access: 'a', refresh: 'r');

      await tester.pumpWidget(_app(tokens: tokens));
      await tester.pumpAndSettle();

      expect(find.text('트레이너로 시작'), findsOneWidget);
      expect(tokens.access, isNull, reason: '남은 토큰을 지워야 한다');
      expect(tokens.clearCount, 1);
    });
  });

  group('OS 글꼴 배율', () {
    testWidgets('상한까지만 따른다', (tester) async {
      // 디자인이 고정 높이를 가진 웹에서 픽셀 단위로 옮겨졌고
      // `AppButton.defaultHeight`(44)·`AppTextInput.height`(50)가 그 값을 고정한다.
      // "고정 높이"와 "무제한 OS 배율"은 동시에 참일 수 없다.
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('트레이너로 시작'));

      expect(
        MediaQuery.textScalerOf(context).scale(16),
        16 * kMaxTextScaleFactor,
      );
    });

    testWidgets('상한 아래의 배율은 그대로 따른다 (클램프지 무시가 아니다)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('트레이너로 시작'));

      expect(
        MediaQuery.textScalerOf(context).scale(16),
        closeTo(16 * 1.1, 0.01),
      );
    });

    testWidgets('상한 배율에서도 버튼·입력 고정 높이가 넘치지 않는다', (tester) async {
      // 상한값을 고른 근거를 테스트로 고정한다. 가장 빡빡한 제약은 44px
      // 버튼 안의 title1SemiBold(16px × 1.4)다. 그 버튼이 있는 화면에서
      // 시작해야 하므로 로그인 화면을 직접 연다.
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _app(initialLocation: '${AppRoutes.signIn}?type=student'),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(AppButton.backgroundKeyFor('로그인'))).height,
        AppButton.defaultHeight,
      );
      expect(
        16 * 1.4 * kMaxTextScaleFactor,
        lessThan(AppButton.defaultHeight),
        reason: '버튼 라인박스가 44px 안에 들어와야 한다',
      );
      expect(
        16 * 1.5 * kMaxTextScaleFactor,
        lessThan(AppTextInput.height),
        reason: '입력 라인박스가 50px 안에 들어와야 한다',
      );
    });
  });

  group('라우팅', () {
    testWidgets('역할을 고르면 쿼리만 바뀌고 로그인 수단 선택이 뜬다', (tester) async {
      // 웹 `<Link href='?type=student'>` — 경로는 `/` 그대로다.
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('회원으로 시작'));
      await tester.pumpAndSettle();

      expect(find.text('차별화된 PT 서비스를\n경험해보세요!'), findsOneWidget);
      expect(find.text('아이디 로그인'), findsOneWidget);
      expect(find.text('체험하기'), findsOneWidget);
    });

    testWidgets('로그인 수단 선택에서 아이디 로그인을 누르면 로그인 화면으로 간다', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('회원으로 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('아이디 로그인'));
      await tester.pumpAndSettle();

      expect(find.text('회원 로그인'), findsOneWidget);
      expect(find.text('아이디'), findsOneWidget);
    });

    testWidgets('type 없이 로그인 화면으로 들어오면 온보딩으로 돌려보낸다', (tester) async {
      // 웹 `SignInPage.tsx`는 이 경우 `throw new Error('잘못된 접근입니다.')`다.
      // 앱에서 화면을 던지는 대신 되돌린다 — 이 규칙이 없으면 라우터 builder가
      // 터진다.
      await tester.pumpWidget(_app(initialLocation: AppRoutes.signIn));
      await tester.pumpAndSettle();

      expect(find.text('트레이너로 시작'), findsOneWidget);
      expect(find.text('회원 로그인'), findsNothing);
    });

    testWidgets('헬스장을 고르지 않은 계정은 홈 대신 헬스장 선택으로 간다', (tester) async {
      // 웹 `UserRoleMiddleware`: `gymId === null` → `redirect('/select-gym')`.
      // 신규 가입자가 로그인 직후 처음 보는 화면이 홈이 아니라 여기다.
      // 이 규칙이 빠지면 그 계정이 데이터 없는 홈을 보게 된다.
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _studentWithoutGym),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_selectGymHeadline), findsOneWidget);
      expect(find.text('회원 홈'), findsNothing);
    });

    testWidgets('헬스장이 있으면 홈으로 간다 (위 규칙이 과하지 않다)', (tester) async {
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _student),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('회원 홈'), findsOneWidget);
      expect(find.text(_selectGymHeadline), findsNothing);
    });

    // **화면 테스트에서는 볼 수 없는 것이다.** `select_gym_page_test.dart`는
    // 라우터를 끼우지 않으므로(규율 §7-3) 이동 자체가 일어나지 않는다.
    // 여기가 그 경로를 보는 유일한 자리다.
    testWidgets('헬스장을 고르고 등록하면 회원 홈으로 간다', (tester) async {
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _studentWithoutGym),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('건강해짐 강남점'));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('회원 홈'), findsOneWidget);
      expect(find.text(_selectGymHeadline), findsNothing);
    });

    // 등록에 성공해도 프로필의 gymId가 갱신되지 않으면, 홈에 도착한 직후
    // 라우터가 `isHome && gymId == null`로 다시 `/select-gym`에 튕긴다 —
    // 화면이 왕복하며 갇힌다. 그래서 **저장까지** 확인한다.
    testWidgets('등록하면 프로필에 gymId가 남아 홈에 머문다', (tester) async {
      final profile = FakeAuthProfileStorage(user: _studentWithoutGym);
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: profile,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('건강해짐 판교점'));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(profile.user!.gymId, 2);
      expect(find.text('회원 홈'), findsOneWidget);
    });

    // **순서 제약을 고정한다.** 프로필 저장보다 이동이 먼저 일어나면,
    // 아직 `gymId == null`인 상태로 홈에 들어가 라우터의
    // `isHome && gymId == null` 규칙에 다시 `/select-gym`으로 튕긴다.
    // 저장이 느릴수록 창이 넓어지므로 느린 저장소로 재현한다.
    testWidgets('저장이 느려도 홈에 도착한다 (저장 → 이동 순서)', (tester) async {
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: _SlowProfileStorage(user: _studentWithoutGym),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('건강해짐 강남점'));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('회원 홈'), findsOneWidget);
      expect(find.text(_selectGymHeadline), findsNothing);
    });

    // 웹 TRAINER 분기는 `/trainer`가 아니라 수업시간 설정으로 간다.
    testWidgets('트레이너는 인증 코드를 넣고 등록하면 수업시간 설정으로 간다', (tester) async {
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _trainerWithoutGym),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('건강해짐 강남점'));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      expect(find.text('수업시간 설정'), findsOneWidget);
      expect(find.text('트레이너 홈'), findsNothing);
    });

    // **명시적 이탈이다.** 웹 `(login-required)` 그룹에는 `layout.tsx`가 없어
    // 실제로 막는 것이 없고, 미로그인 상태로 열면 토큰 없는 요청이 나간다.
    // 앱에서는 이 화면이 `auth.user!.memberType`으로 제목을 갈라서 그대로
    // 두면 null 역참조로 죽는다.
    testWidgets('로그인하지 않고 헬스장 선택에 오면 온보딩으로 돌려보낸다', (tester) async {
      await tester.pumpWidget(_app(initialLocation: AppRoutes.selectGym));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('트레이너로 시작'), findsOneWidget);
      expect(find.text(_selectGymHeadline), findsNothing);
    });

    testWidgets('복원 중에 들어온 경로는 복원이 끝난 뒤 그대로 열린다', (tester) async {
      // 기동 직후에는 저장소를 읽는 동안 스플래시로 돌려보내는데, 그때
      // 목적지를 들고 가지 않으면 **경로가 통째로 버려진다**. Phase 3의
      // 푸시 알림 딥링크가 정확히 이 경로로 들어온다.
      await tester.pumpWidget(_app(initialLocation: AppRoutes.findId));
      await tester.pumpAndSettle();

      expect(find.text('아이디 찾기'), findsOneWidget);
      expect(find.text('트레이너로 시작'), findsNothing);
    });

    testWidgets('로그인 화면에서 아이디 찾기로 갔다가 닫으면 역할을 유지한 채 돌아온다', (tester) async {
      // 로그인 화면이 자리표시자로 보내던 링크가 실제 화면으로 닫혔다.
      // 돌아왔을 때 `?type=trainer`가 살아 있어야 한다 — 온보딩으로
      // 되돌리면 사용자가 역할을 다시 고르게 된다.
      await tester.pumpWidget(
        _app(initialLocation: '${AppRoutes.signIn}?type=trainer'),
      );
      await tester.pumpAndSettle();
      expect(find.text('트레이너 로그인'), findsOneWidget);

      await tester.tap(find.text('아이디 찾기'));
      await tester.pumpAndSettle();
      expect(find.text('이름을 입력해주세요.'), findsOneWidget);
      // 스택이 있는 상태에서도 Material 기본 뒤로가기가 끼어들면 안 된다.
      // 웹 헤더에는 X 하나뿐이다.
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(find.byKey(AppLayoutHeader.closeButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('트레이너 로그인'), findsOneWidget);
      expect(find.text('이름을 입력해주세요.'), findsNothing);
    });

    testWidgets('비밀번호 찾기도 같은 왕복을 한다', (tester) async {
      await tester.pumpWidget(
        _app(initialLocation: '${AppRoutes.signIn}?type=student'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('비밀번호 찾기'));
      await tester.pumpAndSettle();
      expect(find.text('가입하신 이메일 주소로 초기화된 비밀번호를 보내드립니다.'), findsOneWidget);

      await tester.tap(find.byKey(AppLayoutHeader.closeButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('회원 로그인'), findsOneWidget);
    });

    testWidgets('딥링크로 바로 연 찾기 화면은 닫으면 온보딩으로 간다', (tester) async {
      // 돌아갈 스택이 없는 경우다(푸시 알림·외부 링크). `/sign-in`으로
      // 보내지 않는 이유는 그 화면이 `?type=`을 필수로 요구하는데 이 경로엔
      // 역할 정보가 없기 때문이다 — 타입 없이 보내면 라우터가 온보딩으로
      // 다시 튕겨 한 단계를 헛돈다.
      await tester.pumpWidget(_app(initialLocation: AppRoutes.findPassword));
      await tester.pumpAndSettle();
      expect(find.text('비밀번호 찾기'), findsOneWidget);

      await tester.tap(find.byKey(AppLayoutHeader.closeButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('트레이너로 시작'), findsOneWidget);
      expect(find.text('회원으로 시작'), findsOneWidget);
    });

    testWidgets('리다이렉트가 연쇄돼도 한도 안에서 끝난다', (tester) async {
      // 규칙이 다섯 개가 됐고 서로 연쇄된다. 가장 긴 사슬은
      // 복원 중 딥링크 → 스플래시 → 원래 경로 → 역할 확인 → 헬스장 확인이다.
      // go_router 는 리다이렉트가 한도(기본 5)를 넘으면 예외를 던지므로,
      // "그냥 동작한다"가 아니라 **끝난다**는 것을 확인해야 한다.
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _studentWithoutGym),
          // 상대 역할의 홈으로 딥링크 — 역할 불일치와 헬스장 미선택이
          // 동시에 걸리는 최악의 조합이다.
          initialLocation: AppRoutes.trainerHome,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 트레이너 홈으로 딥링크했지만 계정은 STUDENT다 — 자기 홈으로 돌려진 뒤
      // 헬스장 미선택 규칙에 다시 걸려 여기 선다.
      expect(find.text(_selectGymHeadline), findsOneWidget);
    });

    testWidgets('약관 허브는 로그인 없이도 열린다', (tester) async {
      // 웹 `(login-unrequired)` 그룹이다. 인바운드는 마이페이지뿐이지만
      // 딥링크·앱스토어 심사를 생각하면 비로그인 접근을 막을 이유가 없다.
      await tester.pumpWidget(_app(initialLocation: AppRoutes.policy));
      await tester.pumpAndSettle();

      expect(find.text('약관 및 정책'), findsOneWidget);
      expect(find.text('서비스 이용약관'), findsOneWidget);
    });

    testWidgets('약관 허브에서 이용약관을 누르면 그 화면으로 간다', (tester) async {
      await tester.pumpWidget(_app(initialLocation: AppRoutes.policy));
      await tester.pumpAndSettle();

      await tester.tap(find.text('서비스 이용약관'));
      await tester.pumpAndSettle();

      // 아직 자리표시자다 — 본문 15,000자 이관은 별도 작업으로 남겼다.
      expect(find.text('약관 및 정책'), findsNothing);
    });

    testWidgets('가입완료는 쿼리의 이름으로 인사한다', (tester) async {
      await tester.pumpWidget(
        _app(initialLocation: '/sign-up/complete?type=student&name=홍길동'),
      );
      await tester.pumpAndSettle();

      expect(find.text('홍길동님, 환영합니다!'), findsOneWidget);
    });

    testWidgets('가입완료에서 확인을 누르면 가입한 역할로 로그인에 간다', (tester) async {
      await tester.pumpWidget(
        _app(initialLocation: '/sign-up/complete?type=student&name=홍길동'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      // 역할이 빠지면 `/sign-in`의 `?type=` 게이트가 온보딩으로 되돌린다.
      expect(find.text('회원 로그인'), findsOneWidget);
    });

    // **명시적 이탈.** 웹은 화면 안에서 인자 없는 `throw new Error()`를 던져
    // 에러 화면에 떨어진다. 앱에서 크래시는 부적절하므로 라우터가 막는다.
    testWidgets('가입완료에 이름이 없으면 온보딩으로 돌려보낸다', (tester) async {
      await tester.pumpWidget(
        _app(initialLocation: '/sign-up/complete?type=student'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('트레이너로 시작'), findsOneWidget);
    });

    testWidgets('가입완료에 역할이 없으면 온보딩으로 돌려보낸다', (tester) async {
      await tester.pumpWidget(
        _app(initialLocation: '/sign-up/complete?name=홍길동'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('트레이너로 시작'), findsOneWidget);
    });

    testWidgets('로그인 상태로 상대 역할의 홈에 가면 자기 홈으로 돌려보낸다', (tester) async {
      // 웹 `UserRoleMiddleware`: `role !== memberType` → 자기 홈으로.
      await tester.pumpWidget(
        _app(
          tokens: FakeTokenStorage(access: 'a', refresh: 'r'),
          profile: FakeAuthProfileStorage(user: _student),
          initialLocation: AppRoutes.trainerHome,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('회원 홈'), findsOneWidget);
      expect(find.text('트레이너 홈'), findsNothing);
    });
  });
}
