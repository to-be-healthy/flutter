import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 저장된 액세스 토큰을 요청에 부착한다.
///
/// 401 갱신은 이 인터셉터의 책임이 아니다 — Phase 1에서 추가한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.storage});

  /// 토큰을 붙이면 안 되는 공개 경로.
  ///
  /// 백엔드 `MemberAuthController`/`MemberAuthCommandController`의
  /// `@RequestMapping("/api/v1/auth")` 하위 실측 경로에 맞췄다. 공개
  /// 엔드포인트는 전부 `/api/v1/auth` 아래에 있으므로 `/auth/`로 앵커링해
  /// 다른 컨트롤러의 경로가 우연히 걸리는 일을 막는다.
  ///
  /// 로그아웃은 `/api/v1/auth/logout`이 아니라 **`/api/v1/members/logout`**이며
  /// 토큰이 필요하다. `logout`은 `login`을 부분 문자열로 포함하지 않으므로
  /// 여기에 걸리지 않는다.
  static const List<String> _publicPaths = <String>[
    '/auth/login',
    '/auth/join',
    '/auth/refresh-token',
    '/auth/find/',
    // 이메일 인증번호 발송(`/auth/validation/send-email`).
    //
    // **웹이 토큰 없는 `api` 인스턴스로 보낸다**
    // (`entity/auth/api/mutations.ts`의 `useSendVerificationCodeMutation`).
    // `/student/mypage/edit/email`이 그 유일한 사용처이고, 이 줄이 없으면
    // 앱만 `Authorization`을 붙여 웹과 어긋난다 — 2026-09-15에 그 화면을
    // 옮기다 발견했다.
    '/auth/validation/',
    // 이메일 인증번호 발송(`/auth/validation/send-email`).
    //
    // **웹이 토큰 없는 `api` 인스턴스로 보낸다**
    // (`entity/auth/api/mutations.ts`의 `useSendVerificationCodeMutation`).
    // `/student/mypage/edit/email`이 그 유일한 사용처이고, 이 줄이 없으면
    // 앱만 `Authorization`을 붙여 웹과 어긋난다 — 2026-09-15에 그 화면을
    // 옮기다 발견했다.
  ];

  final TokenStorage storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path)) {
      handler.next(options);
      return;
    }

    final token = await storage.readAccess();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  bool _isPublic(String path) {
    final lower = path.toLowerCase();
    return _publicPaths.any(lower.contains);
  }
}
