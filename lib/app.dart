import 'package:flutter/material.dart';

import 'core/network/dio_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'entity/auth/api/auth_api.dart';
import 'page/public/sign_in_page.dart';

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
      home: SignInPage(authApi: _authApi),
    );
  }
}
