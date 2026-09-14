import 'package:geonganghaejim/core/storage/auth_profile_storage.dart';
import 'package:geonganghaejim/core/storage/token_storage.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';

/// 메모리 위의 토큰 저장소.
///
/// 실제 구현(`SecureTokenStorage`)은 플랫폼 채널을 타서 테스트 바이너리에서
/// `MissingPluginException`을 던진다. 앱 조립 지점을 테스트하려면 이 자리에
/// 페이크가 들어가야 한다.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.access, this.refresh});

  String? access;
  String? refresh;

  /// `writeTokens` 호출 횟수. "토큰이 실제로 저장됐는가"를 단언할 때 쓴다 —
  /// Phase 0에서 이 호출부가 0개였던 것이 `AuthState`를 만든 이유다.
  int writeCount = 0;
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
    writeCount++;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    clearCount++;
  }
}

/// 메모리 위의 프로필 저장소.
class FakeAuthProfileStorage implements AuthProfileStorage {
  FakeAuthProfileStorage({this.user});

  AuthUser? user;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<AuthUser?> read() async => user;

  @override
  Future<void> write(AuthUser user) async {
    this.user = user;
    writeCount++;
  }

  @override
  Future<void> clear() async {
    user = null;
    clearCount++;
  }
}
