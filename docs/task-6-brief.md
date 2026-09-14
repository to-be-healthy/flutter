## Task 6: dio 클라이언트 + 토큰 저장소

웹의 `shared/api/baseApi.ts`는 21줄로 얇고 인터셉터 기반 토큰 갱신이 거의 없다. **이식이 아니라 새로 설계하는 영역이다.**

**Files:**
- Create: `flutter/lib/core/storage/token_storage.dart`
- Create: `flutter/lib/core/network/auth_interceptor.dart`
- Create: `flutter/lib/core/network/dio_client.dart`
- Create: `flutter/lib/entity/auth/api/auth_api.dart`
- Modify: `flutter/pubspec.yaml`
- Test: `flutter/test/core/network/auth_interceptor_test.dart`

**Interfaces:**
- Consumes: `SignInRequest`, `SignInResponse` (Task 5), `RequestCapture` (Task 4)
- Produces:
  - `TokenStorage` — `Future<String?> readAccess()`, `Future<void> writeTokens({required String access, required String refresh})`, `Future<void> clear()`
  - `DioClient.create({required String baseUrl, TokenStorage? storage, List<Interceptor> extra = const []})` → `Dio`
  - `AuthApi(Dio dio)` — `Future<SignInResponse> signIn(SignInRequest req)`

- [ ] **Step 1: 의존성 추가**

```bash
cd /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
flutter pub add dio flutter_secure_storage flutter_riverpod go_router
flutter pub add --dev mocktail
```

- [ ] **Step 2: 실패하는 인터셉터 테스트 작성**

`test/core/network/auth_interceptor_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/auth_interceptor.dart';
import 'package:geonganghaejim/core/storage/token_storage.dart';

class _FakeStorage implements TokenStorage {
  _FakeStorage({this.access, this.refresh});

  String? access;
  String? refresh;
  int clearCount = 0;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> writeTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    access = null;
    refresh = null;
  }
}

void main() {
  group('AuthInterceptor', () {
    test('액세스 토큰이 있으면 Authorization 헤더를 붙인다', () async {
      final storage = _FakeStorage(access: 'token-abc');
      final interceptor = AuthInterceptor(storage: storage);
      final options = RequestOptions(path: '/x');

      RequestOptions? forwarded;
      await interceptor.onRequest(
        options,
        RequestInterceptorHandler()..next(options),
      );
      forwarded = options;

      expect(forwarded.headers['Authorization'], 'Bearer token-abc');
    });

    test('토큰이 없으면 Authorization 헤더를 붙이지 않는다', () async {
      final storage = _FakeStorage();
      final interceptor = AuthInterceptor(storage: storage);
      final options = RequestOptions(path: '/x');

      await interceptor.onRequest(
        options,
        RequestInterceptorHandler()..next(options),
      );

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('로그인 요청에는 Authorization을 붙이지 않는다', () async {
      final storage = _FakeStorage(access: 'token-abc');
      final interceptor = AuthInterceptor(storage: storage);
      final options = RequestOptions(path: '/api/v1/auth/login');

      await interceptor.onRequest(
        options,
        RequestInterceptorHandler()..next(options),
      );

      expect(options.headers.containsKey('Authorization'), isFalse);
    });
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

```bash
flutter test test/core/network/auth_interceptor_test.dart
```
Expected: FAIL — URI 없음

- [ ] **Step 4: 구현**

`lib/core/storage/token_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 토큰 보관소.
///
/// 웹은 zustand persist로 localStorage 키 `auth-storage`에 토큰을 평문
/// 보관했다. 네이티브에서는 OS 보안 저장소를 쓴다.
abstract interface class TokenStorage {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> writeTokens({required String access, required String refresh});
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccess() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
```

`lib/core/network/auth_interceptor.dart`:

```dart
import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 인증 토큰 부착. 401 갱신은 Phase 1에서 추가한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.storage});

  /// 토큰을 붙이면 안 되는 경로. `/api/v1/auth/login`이 'login'으로 걸린다.
  static const List<String> _publicPaths = [
    'login',
    'join',
    'refresh',
    'find-id',
    'find-password',
  ];

  final TokenStorage storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublic = _publicPaths.any(options.path.toLowerCase().contains);
    if (isPublic) {
      handler.next(options);
      return;
    }

    final token = await storage.readAccess();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

`lib/core/network/dio_client.dart`:

```dart
import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

abstract final class DioClient {
  static Dio create({
    required String baseUrl,
    TokenStorage? storage,
    List<Interceptor> extra = const [],
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        contentType: Headers.jsonContentType,
      ),
    );

    if (storage != null) {
      dio.interceptors.add(AuthInterceptor(storage: storage));
    }
    dio.interceptors.addAll(extra);

    return dio;
  }
}
```

`lib/entity/auth/api/auth_api.dart`:

```dart
import 'package:dio/dio.dart';

import '../model/sign_in_request.dart';
import '../model/sign_in_response.dart';

class AuthApi {
  AuthApi(this._dio);

  /// 배포 서버 OpenAPI에서 확인한 실제 경로.
  static const String signInPath = '/api/v1/auth/login';

  final Dio _dio;

  Future<SignInResponse> signIn(SignInRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      signInPath,
      data: request.toJson(),
    );
    return SignInResponse.fromJson(response.data!);
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
flutter test test/core/network/auth_interceptor_test.dart
```
Expected: PASS (3 tests)

- [ ] **Step 6: 커밋**

```bash
./tool/verify.sh
git add pubspec.yaml pubspec.lock lib/core lib/entity test/core
git commit -m "feat(network): dio 클라이언트·보안 토큰 저장소·인증 인터셉터 추가"
```

---

