import 'package:flutter/material.dart';

import 'core/network/dio_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'entity/auth/api/auth_api.dart';
import 'page/public/sign_in_page.dart';

/// OS 글꼴 배율 상한.
///
/// **왜 상한이 필요한가:** 이 앱의 디자인은 고정 높이를 쓰는 웹에서 픽셀
/// 단위로 옮겨졌고(`AppButton.height` 44 = 웹 `h-[44px]`,
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
/// `StatefulWidget`인 이유는 화면 상태가 있어서가 아니라 **`Dio`를 한 번만
/// 만들기 위해서다.** `build()` 안에서 `DioClient.create()`를 부르면 리빌드마다
/// 새 클라이언트와 인터셉터가 생기고 커넥션 풀이 매번 버려진다. 수명이
/// 위젯과 같은 의존성은 `initState`에서 만든다 — Phase 1에서 DI 컨테이너를
/// 넣기 전까지 화면이 늘어도 이 패턴을 그대로 쓴다.
///
/// 라우터는 Phase 1 범위라 지금은 로그인 화면을 `home`에 직접 건다.
class GeonganghaejimApp extends StatefulWidget {
  const GeonganghaejimApp({required this.baseUrl, super.key});

  /// 오리진만 넣는다(`https://geonganghaejim.site`). `/api/v1` 같은 경로
  /// 접두사를 여기 넣으면 패리티 하네스가 캡처하는 경로가 골든과 어긋난다.
  final String baseUrl;

  @override
  State<GeonganghaejimApp> createState() => _GeonganghaejimAppState();
}

class _GeonganghaejimAppState extends State<GeonganghaejimApp> {
  late final AuthApi _authApi;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(
      DioClient.create(
        baseUrl: widget.baseUrl,
        storage: const SecureTokenStorage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '건강해짐',
      theme: AppTheme.light(),
      // OS 글꼴 배율 정책. 화면마다 정하면 62개 화면이 제각각이 되므로
      // 조립 지점에서 한 번만 정한다.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: kMaxTextScaleFactor,
        child: child!,
      ),
      home: SignInPage(authApi: _authApi),
    );
  }
}
