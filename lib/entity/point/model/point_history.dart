import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';

/// 백엔드 `PointType`. 웹 `feature/point/const.ts`의 네 키다.
///
/// `@JsonValue`가 없어 와이어 값이 곧 enum 이름이다(서베이 §4.4).
enum PointHistoryType {
  noShow('NO_SHOW', '노쇼'),
  noShowCancel('NO_SHOW_CANCEL', '노쇼취소'),
  workout('WORKOUT', '개인운동'),
  diet('DIET', '식단등록');

  const PointHistoryType(this.wireValue, this.label);

  /// 모르는 값이면 null. 웹은 `pointHistoryTypes[item.type]`로 곧장 색인해
  /// `undefined`(빈 칸)를 그린다 — 여기서는 빈 문자열이 같은 자리다.
  static PointHistoryType? fromWire(Object? value) {
    for (final type in PointHistoryType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }

  final String wireValue;
  final String label;
}

/// 백엔드 `PointHistoryDto`. 웹 `pointHistoryType`.
///
/// 2026-09-18 실측 응답(`GET /api/v1/members/6/point?searchDate=2026-04`):
/// ```json
/// {"pointId":12,"type":"DIET","calculation":"PLUS","point":5,
///  "createdAt":"2026-04-11T14:47:52"}
/// ```
///
/// **[CourseHistory]와 모양이 거의 같지만 합치지 않았다** — 키 이름이 다르고
/// (`pointId`/`point` vs `courseHistoryId`/`cnt`) 타입 enum도 다르다.
/// 공통은 `calculation`과 `createdAt`뿐이라 합치면 필드명이 어느 쪽에도
/// 맞지 않는 이름이 된다.
@immutable
class PointHistory {
  const PointHistory({
    required this.pointId,
    required this.point,
    required this.isPlus,
    required this.type,
    required this.createdAt,
  });

  static PointHistory? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return PointHistory(
      pointId: asIntOrNull(json['pointId']) ?? 0,
      point: asIntOrNull(json['point']) ?? 0,
      // 웹 `item.calculation === 'PLUS' ? '+' : '-'` — 나머지는 전부 -다.
      isPlus: json['calculation'] == 'PLUS',
      type: PointHistoryType.fromWire(json['type']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  final int pointId;
  final int point;

  /// `calculation == 'PLUS'`.
  final bool isPlus;
  final PointHistoryType? type;
  final DateTime? createdAt;

  /// 웹 `{item.calculation === 'PLUS' ? '+' : '-'}{item.point}` → `+5` / `-10`.
  String get signedPoint => '${isPlus ? '+' : '-'}$point';

  String get typeLabel => type?.label ?? '';
}
