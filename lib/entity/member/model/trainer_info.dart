import 'package:flutter/foundation.dart';

/// 웹 `TrainerInfoResponse`(`GET /api/v1/members/trainer-mapping/info`)
/// = 백엔드 `RetrieveTrainerInfo`.
///
/// **매핑이 없으면 `data`가 `null`이다**(`MemberService.java:56~60`의
/// `.orElse(null)`). 그래서 [fromJson]도 null을 돌려주고, 화면은 그것으로
/// 빈 상태를 고른다.
///
/// ## 여섯 필드 중 넷만 담는다
///
/// 담지 않는 것:
/// - `mappingId` — 화면이 읽지 않는다.
/// - `trainer.id` — 역시 읽지 않는다. 이 화면에서 트레이너로 이동하는
///   길이 없다.
///
/// `trainer.gym`은 **`GymDto`**라 id 필드명이 `id`다(`gymId`가 아니다).
/// 화면이 이름만 쓰므로 이름만 담는다 — `MemberInfo`와 같은 판단이고,
/// 그 배경은 `test/entity/gym/gym_test.dart`에 있다.
@immutable
class TrainerInfo {
  const TrainerInfo({
    required this.name,
    required this.email,
    required this.gymName,
    this.profileFileUrl,
  });

  /// 매핑이 없으면 null.
  static TrainerInfo? fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final trainer = data['trainer'];
    if (trainer is! Map<String, dynamic>) {
      // 웹은 `data.trainer.name`을 가드 없이 읽는다 — 서버가 `trainer`만
      // 빠뜨리면 TypeError다. 여기서는 빈 상태로 흡수한다.
      return null;
    }
    final gym = trainer['gym'];
    final profile = trainer['profile'];
    return TrainerInfo(
      name: trainer['name'] as String? ?? '',
      email: trainer['email'] as String? ?? '',
      gymName: gym is Map<String, dynamic> ? gym['name'] as String? ?? '' : '',
      profileFileUrl: profile is Map<String, dynamic>
          ? profile['fileUrl'] as String?
          : null,
    );
  }

  final String name;
  final String email;
  final String gymName;
  final String? profileFileUrl;
}
