import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'sign_in_response.dart';

/// 로그인한 사용자. 웹 zustand `auth-storage`가 보관하던 필드 집합이다.
///
/// **토큰은 여기 없다.** 웹은 localStorage에 accessToken·refreshToken까지
/// 평문으로 같이 넣었지만, 네이티브에서는 토큰을 OS 보안 저장소
/// (`TokenStorage`)에 두고 이 객체는 화면·라우팅이 쓰는 프로필만 담는다.
/// 그래서 이 객체는 로그로 찍혀도 토큰이 새지 않는다.
///
/// `SignInResponse`와 필드가 겹치지만 별도 타입으로 둔다 — 그쪽은 한 번
/// 파싱하고 버리는 응답 DTO이고, 이쪽은 앱이 들고 사는 상태다. 응답에
/// 필드가 추가돼도 상태가 따라 커지지 않게 경계를 둔다.
@immutable
class AuthUser {
  const AuthUser({
    required this.memberId,
    required this.name,
    required this.userId,
    required this.memberType,
    this.gymId,
  });

  factory AuthUser.fromSignIn(SignInResponse response) => AuthUser(
    memberId: response.memberId,
    name: response.name,
    userId: response.userId,
    memberType: response.memberType,
    gymId: response.gymId,
  );

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    memberId: json['memberId'] as int,
    name: json['name'] as String,
    userId: json['userId'] as String,
    memberType: json['memberType'] as String,
    gymId: json['gymId'] as int?,
  );

  /// 저장소에 넣을 직렬화 형태를 만든다.
  static String encode(AuthUser user) => jsonEncode(user.toJson());

  /// 저장소에서 읽은 문자열을 복원한다. 형식이 깨졌으면 null —
  /// 앱 버전이 올라가 필드가 바뀌었을 때 기동 자체가 막히면 안 된다.
  static AuthUser? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      return AuthUser.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  final int memberId;
  final String name;
  final String userId;

  /// 'STUDENT' | 'TRAINER'.
  final String memberType;

  /// 헬스장 미선택 상태면 null이다.
  final int? gymId;

  /// 웹 `router.replace(`/${data.memberType?.toLowerCase()}`)` 대응.
  String get homeLocation => '/${memberType.toLowerCase()}';

  /// 헬스장만 바꾼 복사본. 웹 `setUserInfo({...auth, gymId: selectGymId})`
  /// 에서 실제로 달라지는 필드가 이것 하나다.
  ///
  /// 범용 `copyWith`를 두지 않는 이유: 이 객체의 나머지 필드는 서버가 준
  /// 로그인 응답에서만 와야 한다. 아무 필드나 갈아끼울 수 있는 문을 열면
  /// `memberType`을 화면에서 바꾸는 코드가 생길 수 있고, 그 순간 라우팅
  /// 근거가 서버가 아니라 화면이 된다.
  AuthUser withGymId(int gymId) => AuthUser(
    memberId: memberId,
    name: name,
    userId: userId,
    memberType: memberType,
    gymId: gymId,
  );

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'name': name,
    'userId': userId,
    'memberType': memberType,
    if (gymId != null) 'gymId': gymId,
  };

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.memberId == memberId &&
      other.name == name &&
      other.userId == userId &&
      other.memberType == memberType &&
      other.gymId == gymId;

  @override
  int get hashCode => Object.hash(memberId, name, userId, memberType, gymId);
}
