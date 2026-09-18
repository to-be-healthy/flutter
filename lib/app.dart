import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/date/korean_date_format.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/auth_profile_storage.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'entity/auth/api/auth_api.dart';
import 'entity/auth/model/auth_state.dart';
import 'entity/auth/ui/auth_scope.dart';
import 'entity/gym/api/gym_api.dart';
import 'entity/home/api/home_api.dart';
import 'entity/member/api/member_api.dart';
import 'entity/schedule/api/schedule_api.dart';
import 'entity/course/api/course_api.dart';
import 'entity/point/api/point_api.dart';
import 'entity/trainer/api/trainer_api.dart';
import 'entity/notification/api/notification_api.dart';
import 'shared/ui/app_toast.dart';

/// OS 글꼴 배율 상한.
///
/// **왜 상한이 필요한가:** 이 앱의 디자인은 고정 높이를 쓰는 웹에서 픽셀
/// 단위로 옮겨졌고(`AppButton.defaultHeight` 44 = 웹 `h-[44px]`,
/// `AppTextInput.height` 50 = 웹 `h-[50px]`), 그 박스들은 배율에 따라
/// 늘어나지 않는다. 배율을 무제한으로 따르면 글자가 박스를 넘친다 —
/// "고정 높이"와 "무제한 OS 배율"은 동시에 참일 수 없다.
///
/// **왜 1.3인가:** 가장 빡빡한 제약은 44px 버튼 안의 `title1SemiBold`
/// (16px × line-height 1.4 = 22.4px)다. 1.3배면 29.1px로 44px 안에
/// 14.9px 여유가 남고, 50px 입력의 `body1`(16px × 1.5 = 24px)은 31.2px가
/// 된다. 2.0배면 버튼 라인박스가 44.8px로 박스를 넘긴다. 이 계산은
/// `test/app_test.dart`가 단언으로 고정한다.
///
/// **이 값을 올리려면** 두 고정 높이를 함께 다시 설계해야 한다. 상한만
/// 올리면 접근성이 좋아지는 게 아니라 글자가 잘린다.
const double kMaxTextScaleFactor = 1.3;

/// 앱 조립 지점(composition root).
///
/// `StatefulWidget`인 이유는 화면 상태가 있어서가 아니라 **수명이 위젯과 같은
/// 의존성을 한 번만 만들기 위해서다.** `build()` 안에서 `DioClient.create()`나
/// `createRouter()`를 부르면 리빌드마다 새 클라이언트·새 라우터가 생겨
/// 커넥션 풀과 네비게이션 스택이 매번 버려진다.
class GeonganghaejimApp extends StatefulWidget {
  const GeonganghaejimApp({
    required this.baseUrl,
    this.tokenStorage = const SecureTokenStorage(),
    this.profileStorage = const SecureAuthProfileStorage(),
    this.initialLocation = AppRoutes.onboarding,
    this.httpClientAdapter,
    super.key,
  });

  /// 오리진만 넣는다(`https://geonganghaejim.site`). `/api/v1` 같은 경로
  /// 접두사를 여기 넣으면 패리티 하네스가 캡처하는 경로가 골든과 어긋난다.
  final String baseUrl;

  /// 기본값은 OS 보안 저장소다. **테스트는 반드시 페이크를 넣어야 한다** —
  /// `flutter_secure_storage`는 플랫폼 채널을 타서 테스트 바이너리에서
  /// `MissingPluginException`을 던진다.
  final TokenStorage tokenStorage;
  final AuthProfileStorage profileStorage;

  /// 전송 계층만 갈아끼우는 자리. 기본값(null)이면 실제 네트워크를 쓴다.
  ///
  /// 저장소 주입과 같은 이유로 열어 둔다 — 라우팅 테스트는 화면이 쏘는
  /// 요청에 응답이 필요한데, 여기를 막아 두면 `app_test.dart`가 실제
  /// 네트워크를 때리려다 느려지고 흔들린다. 인터셉터 체인(`AuthInterceptor`)
  /// 은 그대로 살아 있어 **조립 자체는 프로덕션과 같은 경로**로 검증된다.
  final HttpClientAdapter? httpClientAdapter;

  /// 앱이 처음 여는 경로. 기본값은 웹 `/`와 같다.
  ///
  /// 열어둔 이유는 둘이다: 특정 화면에서 시작하는 테스트, 그리고 Phase 3의
  /// 푸시 알림 딥링크(알림을 누르면 해당 화면에서 앱이 뜬다).
  final String initialLocation;

  @override
  State<GeonganghaejimApp> createState() => _GeonganghaejimAppState();
}

class _GeonganghaejimAppState extends State<GeonganghaejimApp> {
  late final AuthState _authState;
  late final GoRouter _router;

  /// 화면이 아니라 **앱**이 토스트를 소유한다. 웹의 토스트 스토어가 모듈
  /// 전역이라 컴포넌트가 언마운트돼도 살아 있는 것과 같은 수명이다
  /// (`shared/ui/app_toast.dart`).
  final AppToastController _toastController = AppToastController();

  @override
  void initState() {
    super.initState();

    // 웹 `StudentHomePage.tsx:3-6`의 모듈 스코프 `dayjs.locale('ko')` +
    // `dayjs.extend(customParseFormat)` 대응.
    //
    // **`main()`이 아니라 여기다.** `main()`에만 두면 `GeonganghaejimApp`을
    // 직접 만드는 테스트와 딥링크 진입이 초기화 없이 돌고, `intl`은 로케일
    // 데이터가 없으면 `DateFormat(..., 'ko')` 생성에서 던진다 — 예약이 있는
    // 계정에서만 홈이 죽는, 데이터가 있어야 드러나는 실패가 된다.
    // 라우터·dio와 같은 이유로 조립 지점이 소유한다.
    KoreanDateFormat.ensureInitialized();

    _authState = AuthState(widget.tokenStorage, widget.profileStorage);

    // 클라이언트는 **하나**다. API별로 만들면 커넥션 풀과 인터셉터 체인이
    // 갈라지고, 패리티 하네스가 어느 인스턴스를 캡처하는지도 흐려진다.
    final dio = DioClient.create(
      baseUrl: widget.baseUrl,
      storage: widget.tokenStorage,
    );
    if (widget.httpClientAdapter != null) {
      dio.httpClientAdapter = widget.httpClientAdapter!;
    }

    _router = createRouter(
      authState: _authState,
      authApi: AuthApi(dio),
      gymApi: GymApi(dio),
      homeApi: HomeApi(dio),
      notificationApi: NotificationApi(dio),
      memberApi: MemberApi(dio),
      scheduleApi: ScheduleApi(dio),
      trainerApi: TrainerApi(dio),
      courseApi: CourseApi(dio),
      pointApi: PointApi(dio),
      initialLocation: widget.initialLocation,
    );

    // 저장된 세션을 복원한다. 끝날 때까지 라우터는 스플래시를 보여주고,
    // 끝나면 `refreshListenable`이 리다이렉트를 다시 계산한다.
    _authState.restore();
  }

  @override
  void dispose() {
    _authState.dispose();
    _toastController.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '건강해짐',
      theme: AppTheme.light(),
      routerConfig: _router,
      // `AuthScope`를 여기 두는 이유: `MaterialApp.router`의 `builder`는
      // 라우터가 그리는 모든 화면의 **위**에 있다. 화면마다 감싸면 62개가
      // 각자 감싸야 하고, 하나라도 빠뜨리면 그 화면에서만 `AuthScope.of`가
      // 터진다.
      builder: (context, child) => AuthScope(
        notifier: _authState,
        // OS 글꼴 배율 정책. 화면마다 정하면 62개 화면이 제각각이 되므로
        // 조립 지점에서 한 번만 정한다.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: kMaxTextScaleFactor,
          // `AppToastHost`는 라우터가 그리는 화면 **위**에 겹친다. 화면
          // 전환이 일어나도 토스트가 그대로 떠 있는 것이 웹과 같은 동작이다
          // (웹 `ToastProvider`도 라우트 바깥 루트 레이아웃에 있다).
          child: AppToastScope(
            notifier: _toastController,
            child: AppToastHost(child: child!),
          ),
        ),
      ),
    );
  }
}
