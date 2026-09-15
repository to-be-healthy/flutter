import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/auth_state.dart';
import '../../entity/gym/api/gym_api.dart';
import '../../page/protected/select_gym_page.dart';
import '../../page/public/find_id_page.dart';
import '../../page/public/find_password_page.dart';
import '../../page/public/not_implemented_page.dart';
import '../../page/public/onboarding_page.dart';
import '../../page/public/policy_page.dart';
import '../../page/public/sign_up_complete_page.dart';
import '../../page/public/sign_in_page.dart';
import '../../page/public/splash_page.dart';

/// 웹 URL을 그대로 옮긴 라우트 표.
///
/// 경로 문자열을 화면 코드에 흩어놓지 않는 이유는 웹과의 대조 때문이다 —
/// 73개 라우트를 옮기는 동안 "웹의 어느 URL인가"를 한곳에서 확인할 수 있어야
/// 한다.
abstract final class AppRoutes {
  /// 복원 중 화면. 웹 `app/page.tsx`의 `role === undefined` 분기
  /// (스플래시 GIF) 대응. 웹은 URL 없이 같은 자리에서 분기하지만,
  /// go_router는 리다이렉트가 경로로 표현돼야 해서 자리를 하나 준다.
  static const String splash = '/splash';

  /// 웹 `/` — 온보딩. `?type=`이 붙으면 로그인 수단 선택 화면이 된다.
  static const String onboarding = '/';

  /// 웹 `/sign-in?type=student|trainer`.
  static const String signIn = '/sign-in';

  static const String signUp = '/sign-up';

  /// 웹 `(login-unrequired)/sign-up/complete?type=&name=`.
  ///
  /// 가입 자체는 `/sign-up`의 mutation이 끝냈고, 이 화면은 그 결과를
  /// 쿼리스트링으로 받아 보여주기만 한다.
  static const String signUpComplete = '/sign-up/complete';

  /// 웹 `(login-unrequired)/policy` 계열. `/policy`는 자체 콘텐츠가 없는
  /// 허브이고, 약관 두 화면으로 들어가는 유일한 경로다.
  static const String policy = '/policy';
  static const String policyTerms = '/policy/terms';
  static const String policyPrivacy = '/policy/privacy';

  /// 웹 `/cs` — 고객센터. 온보딩 하단 링크의 목적지.
  static const String customerService = '/cs';

  static const String findId = '/find/id';
  static const String findPassword = '/find/pw';

  /// 웹 `(login-required)/student`·`/trainer`.
  static const String studentHome = '/student';
  static const String trainerHome = '/trainer';

  /// 웹 `(login-required)/trainer/class-time-setting`.
  ///
  /// **트레이너가 헬스장 등록을 마치면 `/trainer`가 아니라 여기로 간다**
  /// (웹 `SelectGymPage`의 `router.push('/trainer/class-time-setting')`).
  /// `/trainer`로 보내면 웹과 다른 화면이 된다.
  static const String trainerClassTimeSetting = '/trainer/class-time-setting';

  /// 웹 `(login-required)/select-gym` — 헬스장 미선택 사용자가 홈 대신 먼저
  /// 보는 화면. `UserRoleMiddleware`가 `gymId === null`이면 여기로 튕긴다.
  static const String selectGym = '/select-gym';

  /// 웹 `?name=` 쿼리 이름. 가입완료 화면이 인사말에 쓴다.
  static const String nameQuery = 'name';

  /// 웹 `?type=` 쿼리 이름. 온보딩과 로그인이 공유한다.
  static const String memberTypeQuery = 'type';

  /// 복원이 끝난 뒤 되돌아갈 곳을 스플래시가 들고 있는 쿼리 이름.
  ///
  /// 이게 없으면 **복원 중에 들어온 경로가 통째로 버려진다** — 스플래시로
  /// 리다이렉트된 뒤 복원이 끝나면 온보딩이나 홈으로만 가기 때문이다.
  /// Phase 3의 푸시 알림 딥링크가 정확히 이 경로로 들어온다.
  static const String returnToQuery = 'from';
}

/// 앱 라우터를 만든다.
///
/// [authState]는 `refreshListenable`로 물린다 — 로그인·로그아웃·복원 완료가
/// 곧 리다이렉트 재평가다. 이 배선이 없으면 로그인에 성공해도 화면이 그대로
/// 남는다.
GoRouter createRouter({
  required AuthState authState,
  required AuthApi authApi,
  required GymApi gymApi,
  String initialLocation = AppRoutes.onboarding,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authState,
    redirect: (context, state) => _redirect(authState, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingPage(
          memberType: state.uri.queryParameters[AppRoutes.memberTypeQuery],
          authApi: authApi,
        ),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => SignInPage(
          authApi: authApi,
          // 웹 `SignInPage.tsx`는 type이 student/trainer가 아니면
          // `throw new Error('잘못된 접근입니다.')`로 에러 화면을 띄운다.
          // 앱에서 같은 상황은 아래 `_redirect`가 온보딩으로 돌려보내므로,
          // 여기까지 왔다면 값이 유효하다.
          memberType: _memberTypeOf(state)!.toUpperCase(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) =>
            const NotImplementedPage(title: '회원가입', webRoute: '/sign-up'),
      ),
      GoRoute(
        path: AppRoutes.signUpComplete,
        builder: (context, state) => SignUpCompletePage(
          // 아래 `_redirect`가 둘 다 있는 경우만 통과시키므로 여기서는 유효하다.
          name: state.uri.queryParameters[AppRoutes.nameQuery]!,
          memberType: _memberTypeOf(state)!,
          onConfirm: (memberType) => context.go(
            Uri(
              path: AppRoutes.signIn,
              queryParameters: {AppRoutes.memberTypeQuery: memberType},
            ).toString(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.policy,
        builder: (context, state) => PolicyPage(
          onBack: () => _backOr(context, AppRoutes.onboarding),
          onOpen: context.go,
        ),
      ),
      GoRoute(
        path: AppRoutes.policyTerms,
        builder: (context, state) => const NotImplementedPage(
          title: '서비스 이용약관',
          webRoute: '/policy/terms',
        ),
      ),
      GoRoute(
        path: AppRoutes.policyPrivacy,
        builder: (context, state) => const NotImplementedPage(
          title: '개인정보 처리방침',
          webRoute: '/policy/privacy',
        ),
      ),
      GoRoute(
        path: AppRoutes.customerService,
        builder: (context, state) =>
            const NotImplementedPage(title: '고객센터', webRoute: '/cs'),
      ),
      GoRoute(
        path: AppRoutes.findId,
        builder: (context, state) => FindIdPage(authApi: authApi),
      ),
      GoRoute(
        path: AppRoutes.findPassword,
        builder: (context, state) => FindPasswordPage(authApi: authApi),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) =>
            const NotImplementedPage(title: '회원 홈', webRoute: '/student'),
      ),
      GoRoute(
        path: AppRoutes.trainerHome,
        builder: (context, state) =>
            const NotImplementedPage(title: '트레이너 홈', webRoute: '/trainer'),
      ),
      GoRoute(
        path: AppRoutes.trainerClassTimeSetting,
        builder: (context, state) => const NotImplementedPage(
          title: '수업시간 설정',
          webRoute: '/trainer/class-time-setting',
        ),
      ),
      GoRoute(
        path: AppRoutes.selectGym,
        builder: (context, state) => SelectGymPage(gymApi: gymApi),
      ),
    ],
  );
}

/// 돌아갈 곳이 있으면 pop, 없으면 [fallback]으로 보낸다.
///
/// 딥링크·푸시로 화면에 바로 진입하면 스택이 비어 있어 pop이 아무 일도 하지
/// 않는다 — 그러면 뒤로가기 버튼이 죽은 것처럼 보인다.
void _backOr(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// 유효한 `?type=` 값만 돌려준다. 그 외(없음·오타)는 null.
String? _memberTypeOf(GoRouterState state) {
  final type = state.uri.queryParameters[AppRoutes.memberTypeQuery];
  return (type == 'student' || type == 'trainer') ? type : null;
}

/// 웹 `app/page.tsx` + `_providers/UserRoleMiddleware.tsx`의 리다이렉트 체인.
String? _redirect(AuthState auth, GoRouterState state) {
  final location = state.matchedLocation;

  // ① 복원 전에는 어떤 판단도 하지 않는다. 여기서 로그인 여부를 따지면
  //    로그인 상태인 사용자가 매번 온보딩을 스치고 지나간다
  //    (웹의 `role === undefined` → 스플래시 분기와 같은 이유).
  if (auth.isRestoring) {
    if (location == AppRoutes.splash) {
      return null;
    }
    // 가려던 곳을 들고 간다. 복원이 끝나면 그리로 되돌려 보낸다.
    return Uri(
      path: AppRoutes.splash,
      queryParameters: {AppRoutes.returnToQuery: state.uri.toString()},
    ).toString();
  }
  if (location == AppRoutes.splash) {
    final returnTo = state.uri.queryParameters[AppRoutes.returnToQuery];
    // 스플래시로 되돌아오는 값은 받지 않는다 — 무한 리다이렉트가 된다.
    if (returnTo != null &&
        returnTo.isNotEmpty &&
        !returnTo.startsWith(AppRoutes.splash)) {
      // 그 경로에 대한 인증 규칙은 이 반환값으로 이동한 **다음 평가**에서
      // 적용된다(로그인 상태로 `/sign-in`에 가면 홈으로 다시 튕긴다).
      return returnTo;
    }
    return auth.isSignedIn ? auth.user!.homeLocation : AppRoutes.onboarding;
  }

  // ② 경로 자체의 유효성(인증과 무관). 웹 `SignInPage.tsx`는 type이
  //    student/trainer가 아니면 `throw new Error('잘못된 접근입니다.')`로
  //    에러 화면을 띄운다. 앱에서 화면을 던지는 것은 과하므로 온보딩으로
  //    돌려보낸다 — 이 규칙이 없으면 아래 builder의 `!`가 터진다.
  if (location == AppRoutes.signIn && _memberTypeOf(state) == null) {
    return AppRoutes.onboarding;
  }

  // 웹 `SignUpCompletePage`는 `type`·`name`이 없으면 화면 안에서 인자 없는
  // `throw new Error()`를 던져 `app/error.tsx`에 떨어진다. **앱에서 크래시는
  // 부적절하므로** 그 판단을 여기로 올렸다 — 바로 위 `/sign-in` 게이트와
  // 같은 패턴이고, 이 규칙이 없으면 위 builder의 `!`가 터진다.
  if (location == AppRoutes.signUpComplete) {
    final name = state.uri.queryParameters[AppRoutes.nameQuery];
    if (_memberTypeOf(state) == null || name == null || name.isEmpty) {
      return AppRoutes.onboarding;
    }
  }

  final isHome =
      location == AppRoutes.studentHome || location == AppRoutes.trainerHome;

  if (!auth.isSignedIn) {
    // 웹 `UserRoleMiddleware`: `role === null` → `redirect('/')`.
    //
    // `/select-gym`도 함께 막는다. **웹에는 이 가드가 없다** —
    // `(login-required)` 그룹에 `layout.tsx`가 없어서 그룹 이름과 달리
    // 실제로 막는 것이 아무것도 없고, 미로그인 상태로 열면 토큰 없는
    // 요청이 나간다(웹 쪽 결함이다). 앱에서는 그 화면이
    // `auth.user!.memberType`으로 제목을 갈라서 그대로 두면 null 역참조로
    // 죽는다. 명시적 이탈로 온보딩에 돌려보낸다.
    return (isHome || location == AppRoutes.selectGym)
        ? AppRoutes.onboarding
        : null;
  }

  // 웹 `app/page.tsx`: 로그인 상태로 `/`에 오면 자기 홈으로 보낸다.
  // `?type=`이 붙어 있어도 마찬가지다 — 그 분기가 OnboardingPage보다 먼저다.
  if (location == AppRoutes.onboarding) {
    return auth.user!.homeLocation;
  }

  // 웹 `UserRoleMiddleware`: `role !== memberType` → 자기 홈으로.
  if (isHome && location != auth.user!.homeLocation) {
    return auth.user!.homeLocation;
  }

  // 웹 `UserRoleMiddleware`: `gymId === null` → `/select-gym`.
  //
  // 역할 확인 **다음**에 온다(웹의 순서 그대로). 헬스장을 아직 고르지 않은
  // 계정은 홈을 볼 수 없다 — 신규 가입자가 처음 보는 화면이 홈이 아니라
  // 여기다. 이 규칙이 빠지면 그 계정이 데이터 없는 홈을 보게 된다.
  if (isHome && auth.user!.gymId == null) {
    return AppRoutes.selectGym;
  }

  // 로그인 상태로 로그인 화면에 오면 홈으로. 웹은 `(login-unrequired)`라
  // 막지 않지만, 앱에서는 뒤로가기로 도달할 수 있어 같은 규칙을 적용한다.
  if (location == AppRoutes.signIn) {
    return auth.user!.homeLocation;
  }

  return null;
}
