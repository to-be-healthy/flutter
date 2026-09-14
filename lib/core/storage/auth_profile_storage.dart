import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../entity/auth/model/auth_user.dart';

/// 로그인 프로필 보관소.
///
/// [TokenStorage]와 굳이 나눈 이유는 **읽는 쪽이 다르기 때문이다.** 토큰은
/// 네트워크 계층(`AuthInterceptor`)만 보고, 프로필은 화면과 라우터만 본다.
/// 한 인터페이스로 합치면 인터셉터가 프로필까지 볼 수 있게 되고, 반대로
/// 화면이 토큰을 꺼내 쓰기 쉬워진다.
///
/// 왜 프로필까지 저장하나: 토큰만 저장하면 앱을 다시 켰을 때 "토큰은 있는데
/// STUDENT인지 TRAINER인지 모르는" 상태가 된다 — 인터셉터는 헤더를 붙이는데
/// 라우터는 로그아웃으로 판단하는 어긋남이다. 웹도 zustand persist로
/// `memberType`을 포함한 프로필 전체를 localStorage에 남긴다.
abstract interface class AuthProfileStorage {
  Future<AuthUser?> read();

  Future<void> write(AuthUser user);

  Future<void> clear();
}

/// OS 보안 저장소 기반 구현.
///
/// 프로필은 비밀이 아니지만 토큰과 같은 저장소에 두면 로그아웃 시
/// 지우는 곳이 한 군데로 모인다.
class SecureAuthProfileStorage implements AuthProfileStorage {
  const SecureAuthProfileStorage([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  static const String _key = 'auth_profile';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthUser?> read() async =>
      AuthUser.decode(await _storage.read(key: _key));

  @override
  Future<void> write(AuthUser user) =>
      _storage.write(key: _key, value: AuthUser.encode(user));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
