import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';

/// 백엔드 `CourseHistoryType`. 웹 `feature/course/const.ts`의 여섯 키다.
///
/// **`@JsonValue`가 없다** — 백엔드가 이름 그대로 직렬화한다(서베이 §4.4).
/// 그래서 와이어 값이 곧 enum 이름이다.
enum CourseHistoryType {
  courseCreate('COURSE_CREATE', '수강권 생성'),
  plusCnt('PLUS_CNT', '수강권 연장'),
  minusCnt('MINUS_CNT', '수강권 차감'),
  oneLesson('ONE_LESSON', '1회권 지급'),
  reservation('RESERVATION', '수업 예약'),
  reservationCancel('RESERVATION_CANCEL', '수업 예약 취소');

  const CourseHistoryType(this.wireValue, this.label);

  /// 서버가 주는 문자열. 모르는 값이면 null이다.
  ///
  /// 웹은 `courseHistoryTypes[item.type]`로 곧장 색인해서 모르는 타입이 오면
  /// `undefined`를 그린다(빈 칸). 여기서는 null을 돌려주고 화면이 빈 문자열을
  /// 그린다 — 같은 결과다.
  static CourseHistoryType? fromWire(Object? value) {
    for (final type in CourseHistoryType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }

  final String wireValue;

  /// 화면에 그리는 한국어 문구.
  final String label;
}

/// 백엔드 `CourseHistoryDto`. 웹 `CourseHistoryItem`.
///
/// 2026-09-18 실측 응답(`GET /api/v1/members/6/course?searchDate=2026-03`):
/// ```json
/// {"courseHistoryId":7,"cnt":1,"calculation":"MINUS",
///  "type":"RESERVATION","createdAt":"2026-03-29T14:44:48"}
/// ```
@immutable
class CourseHistory {
  const CourseHistory({
    required this.courseHistoryId,
    required this.cnt,
    required this.isPlus,
    required this.type,
    required this.createdAt,
  });

  static CourseHistory? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return CourseHistory(
      courseHistoryId: asIntOrNull(json['courseHistoryId']) ?? 0,
      cnt: asIntOrNull(json['cnt']) ?? 0,
      // 웹 `item.calculation === 'PLUS' ? '+' : '-'` — `PLUS`만 참이고
      // 나머지는 전부 음수로 그린다. 값이 비어도 `-`가 되는 것이 웹과 같다.
      isPlus: json['calculation'] == 'PLUS',
      type: CourseHistoryType.fromWire(json['type']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  final int courseHistoryId;
  final int cnt;

  /// `calculation == 'PLUS'`.
  final bool isPlus;

  /// 모르는 타입이면 null — 웹의 `undefined`와 같은 자리다.
  final CourseHistoryType? type;

  /// 파싱 실패는 null. 화면이 빈 문자열을 그린다.
  final DateTime? createdAt;

  /// 웹 `{item.calculation === 'PLUS' ? '+' : '-'}{item.cnt}` → `+10` / `-1`.
  String get signedCount => '${isPlus ? '+' : '-'}$cnt';

  /// 웹 `courseHistoryTypes[item.type]`.
  String get typeLabel => type?.label ?? '';
}
