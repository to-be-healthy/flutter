import 'package:flutter/foundation.dart';

import '../../../core/storage/auth_profile_storage.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_user.dart';
import 'sign_in_response.dart';

/// 웹 zustand `auth-storage` 슬라이스 대응.
///
/// Phase 0에 **없었던 조각**이다. 그래서 로그인에 성공해도 토큰이 그대로
/// 버려졌고 `TokenStorage.writeTokens`의 프로덕션 호출부가 0개였다 —
/// "인증 요청이 헤더 없이 나가도 패리티가 통과한다"는 최종 리뷰 지적의 근원.
///
/// **왜 `ChangeNotifier`인가:** `go_router`의 `refreshListenable`이
/// `Listenable`을 받는다. 로그인·로그아웃이 곧 리다이렉트 재평가로 이어져야
/// 하는데, 그 배선이 추가 패키지 없이 이 한 타입으로 끝난다. 상태 관리
/// 패키지를 얹으면 Phase 1이 쓰지도 않을 개념(provider scope, family,
/// autoDispose)을 62개 화면이 먼저 배워야 한다.
class AuthState extends ChangeNotifier {
  /// 인자를 이름 있는 매개변수로 받지 않는 이유: Dart는 이름 있는
  /// 매개변수가 밑줄로 시작하는 것을 금지해서 `required this._tokens`를
  /// 쓸 수 없고, 그러면 `_tokens = tokens` 형태가 되어 린트
  /// (`prefer_initializing_formals`)에 걸린다. 두 인자는 타입이 서로 달라
  /// 순서를 바꾸면 컴파일이 깨지므로 위치 인자로 충분하다.
  AuthState(this._tokens, this._profile);

  final TokenStorage _tokens;
  final AuthProfileStorage _profile;

  AuthUser? _user;

  /// 저장소에서 복원을 시도하기 전인가. 라우터가 이 값을 보고 스플래시를
  /// 유지한다 — 복원 전에 리다이렉트를 계산하면 로그인 상태인 사용자가
  /// 매번 온보딩 화면을 스치고 지나간다(웹의 `role === undefined` 분기와
  /// 같은 이유다).
  bool get isRestoring => _isRestoring;
  bool _isRestoring = true;

  AuthUser? get user => _user;

  bool get isSignedIn => _user != null;

  /// 앱 기동 시 1회. 토큰과 프로필이 **둘 다** 있어야 로그인으로 본다.
  ///
  /// 한쪽만 있으면 지운다 — 토큰만 있으면 라우터가 갈 곳을 모르고,
  /// 프로필만 있으면 요청에 헤더가 안 붙는다. 어느 쪽이든 조용히 깨진
  /// 세션이라 로그아웃이 정답이다.
  Future<void> restore() async {
    final access = await _tokens.readAccess();
    final stored = await _profile.read();

    if (access == null || stored == null) {
      if (access != null || stored != null) {
        await _clearBoth();
      }
      _user = null;
    } else {
      _user = stored;
    }

    _isRestoring = false;
    notifyListeners();
  }

  /// 로그인 성공 처리. 웹 `setUserInfo(data)` 대응.
  ///
  /// **`memberType`은 요청한 값이 아니라 응답 값을 쓴다.** 웹도
  /// `router.replace(`/${data.memberType?.toLowerCase()}`)`로 서버가 준
  /// 값을 따른다 — 요청은 STUDENT로 보냈는데 계정이 TRAINER면 서버 쪽이
  /// 옳다.
  Future<void> signIn(SignInResponse response) async {
    final user = AuthUser.fromSignIn(response);
    await _tokens.writeTokens(
      access: response.accessToken,
      refresh: response.refreshToken,
    );
    await _profile.write(user);
    _user = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clearBoth();
    _user = null;
    notifyListeners();
  }

  Future<void> _clearBoth() async {
    await _tokens.clear();
    await _profile.clear();
  }
}
