import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/app.dart';
import 'package:geonganghaejim/core/router/app_router.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';
import 'package:geonganghaejim/shared/ui/app_button.dart';
import 'package:geonganghaejim/shared/ui/app_text_input.dart';

import 'support/auth_fakes.dart';

/// 저장소를 페이크로 바꾼 앱. 실제 구현은 플랫폼 채널을 타서 테스트에서
/// 뜨지 않는다.
Widget _app({
  FakeTokenStorage? tokens,
  FakeAuthProfileStorage? profile,
  String initialLocation = AppRoutes.onboarding,
}) {
  return GeonganghaejimApp(
    baseUrl: 'https://example.test',
    tokenStorage: tokens ?? FakeTokenStorage(),
    profileStorage: profile ?? FakeAuthProfileStorage(),
    initialLocation: initialLocation,
  );
}

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
      // `AppButton.height`(44)·`AppTextInput.height`(50)가 그 값을 고정한다.
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
        AppButton.height,
      );
      expect(
        16 * 1.4 * kMaxTextScaleFactor,
        lessThan(AppButton.height),
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

    testWidgets('복원 중에 들어온 경로는 복원이 끝난 뒤 그대로 열린다', (tester) async {
      // 기동 직후에는 저장소를 읽는 동안 스플래시로 돌려보내는데, 그때
      // 목적지를 들고 가지 않으면 **경로가 통째로 버려진다**. Phase 3의
      // 푸시 알림 딥링크가 정확히 이 경로로 들어온다.
      await tester.pumpWidget(_app(initialLocation: AppRoutes.findId));
      await tester.pumpAndSettle();

      expect(find.text('아이디 찾기'), findsOneWidget);
      expect(find.text('트레이너로 시작'), findsNothing);
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
