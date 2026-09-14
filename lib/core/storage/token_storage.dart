import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 토큰 보관소.
///
/// 웹은 zustand persist로 localStorage 키 `auth-storage`에 토큰을 평문
/// 보관했다. 네이티브에서는 OS 보안 저장소를 쓴다.
///
/// 인터페이스로 두는 이유는 테스트가 페이크를 끼울 수 있어야 하기 때문이다 —
/// `FlutterSecureStorage`는 플랫폼 채널을 타서 테스트 바이너리에서 동작하지
/// 않는다.
abstract interface class TokenStorage {
  Future<String?> readAccess();

  Future<String?> readRefresh();

  Future<void> writeTokens({required String access, required String refresh});

  Future<void> clear();
}

/// OS 보안 저장소 기반 구현.
///
/// iOS/macOS는 Keychain, Android는 AES-GCM으로 값을 암호화하고 그 키를
/// KeyStore의 RSA-OAEP(SHA-256/MGF1)로 래핑한다 — Jetpack
/// `EncryptedSharedPreferences`가 아니다(`AndroidOptions` 기본값 참조).
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

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
