import 'package:flutter/widgets.dart';

import '../model/auth_state.dart';

/// [AuthState]를 위젯 트리에 흘린다. 웹에서 아무 컴포넌트나
/// `useAuthAction()`/`auth()`를 부를 수 있던 것과 같은 역할이다.
///
/// `InheritedNotifier`라 `AuthScope.of(context)`로 읽은 위젯은 상태가
/// 바뀔 때 자동으로 다시 빌드된다. 상태를 바꾸기만 하고 구독할 필요가 없는
/// 곳(버튼 콜백 등)은 [read]를 써서 불필요한 리빌드를 만들지 않는다.
class AuthScope extends InheritedNotifier<AuthState> {
  const AuthScope({
    required AuthState super.notifier,
    required super.child,
    super.key,
  });

  /// 구독한다. 상태가 바뀌면 호출한 위젯이 다시 빌드된다.
  static AuthState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope가 위에 없다');
    return scope!.notifier!;
  }

  /// 구독하지 않고 읽는다. 콜백 안에서 `signIn`/`signOut`을 부를 때 쓴다.
  static AuthState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope가 위에 없다');
    return scope!.notifier!;
  }
}
