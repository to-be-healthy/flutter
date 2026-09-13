import 'package:flutter/foundation.dart';

/// 백엔드 `CommandLoginMember` 대응.
///
/// 웹은 이메일이 아니라 **아이디(`userId`)**로 로그인하며,
/// `memberType`(STUDENT/TRAINER)이 필수다 — 웹은 이 값을
/// `/sign-in?type=student` 쿼리파라미터로 받아 넘긴다.
///
/// 스펙의 `required`는 `memberType` 하나뿐이지만, 백엔드 record의
/// `userId`/`password`에 `@NotEmpty`가 붙어 있어 실질적으로 필수다.
@immutable
class SignInRequest {
  const SignInRequest({
    required this.userId,
    required this.password,
    required this.memberType,
    this.complimentaryLogin,
  });

  final String userId;
  final String password;

  /// 'STUDENT' | 'TRAINER'
  final String memberType;

  /// 체험하기 로그인. 지정하지 않으면 전송하지 않는다(백엔드 기본값 false).
  final bool? complimentaryLogin;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'password': password,
    'memberType': memberType,
    if (complimentaryLogin != null) 'complimentaryLogin': complimentaryLogin,
  };
}
