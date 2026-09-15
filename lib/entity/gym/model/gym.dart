import 'package:flutter/foundation.dart';

/// 웹 `src/entity/gym/model/types.ts`의 `Gym {gymId, name}`.
///
/// 백엔드 `GymResult`도 같은 두 필드다(`openapi/api-docs.json`,
/// `gymId: integer(int64)` / `name: string`).
@immutable
class Gym {
  const Gym({required this.gymId, required this.name});

  factory Gym.fromJson(Map<String, dynamic> json) =>
      Gym(gymId: json['gymId'] as int, name: json['name'] as String);

  final int gymId;
  final String name;

  /// 목록 응답의 `data`를 그대로 받는다.
  ///
  /// **null을 빈 목록으로 흡수한다.** 웹 `useGymListQuery`의 반환 타입이
  /// `Gym[] | null`이다 — 서버가 data에 null을 줄 수 있다는 뜻이고, 그대로
  /// 흘리면 화면이 null을 map하려다 죽는다. 웹은 `gymList?.map(...)`의
  /// 옵셔널 체이닝으로 같은 일을 한다.
  static List<Gym> listFrom(Object? data) {
    if (data is! List) {
      return const <Gym>[];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(Gym.fromJson)
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      other is Gym && other.gymId == gymId && other.name == name;

  @override
  int get hashCode => Object.hash(gymId, name);
}
