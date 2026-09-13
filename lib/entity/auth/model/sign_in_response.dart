import 'package:flutter/foundation.dart';

/// 백엔드 `ApiResultTokens` → `data(Tokens)` 대응.
///
/// 응답은 `{status, message, data}` envelope로 감싸여 있다.
/// 웹 zustand `auth-storage`가 보관하던 필드와 같은 집합이다.
@immutable
class SignInResponse {
  const SignInResponse({
    required this.memberId,
    required this.name,
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.memberType,
    this.gymId,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        '로그인 응답에 data가 없다: ${json['status']} ${json['message']}',
      );
    }
    return SignInResponse(
      memberId: data['memberId'] as int,
      name: data['name'] as String,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: data['userId'] as String,
      memberType: data['memberType'] as String,
      gymId: data['gymId'] as int?,
    );
  }

  final int memberId;
  final String name;
  final String accessToken;
  final String refreshToken;
  final String userId;

  /// 'STUDENT' | 'TRAINER'. 스펙상 enum이지만 Phase 0에서는 문자열로 둔다.
  final String memberType;

  /// 헬스장 미선택 상태면 null이다
  /// (`Tokens`: `this.gymId = gym != null ? gym.getId() : null;`).
  final int? gymId;
}
