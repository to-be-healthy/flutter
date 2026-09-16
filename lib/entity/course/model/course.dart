import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';

/// 백엔드 `CourseDto`. 웹 `feature/manage/model/types.ts`의 `CourseItem`.
@immutable
class Course {
  const Course({
    required this.courseId,
    required this.totalLessonCnt,
    required this.remainLessonCnt,
    required this.completedLessonCnt,
  });

  static Course? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return Course(
      courseId: asIntOrNull(json['courseId']) ?? 0,
      totalLessonCnt: asIntOrNull(json['totalLessonCnt']) ?? 0,
      remainLessonCnt: asIntOrNull(json['remainLessonCnt']) ?? 0,
      completedLessonCnt: asIntOrNull(json['completedLessonCnt']) ?? 0,
    );
  }

  final int courseId;
  final int totalLessonCnt;
  final int remainLessonCnt;
  final int completedLessonCnt;

  /// 웹 `expiration={completedLessonCnt === totalLessonCnt}`.
  ///
  /// 이 하나가 카드 전체를 가른다 — 배경색(primary500 vs gray500), 헤더 문구,
  /// 진행바 색, 그리고 하단이 펼침형이냐 고정 바냐까지.
  bool get isExpired => completedLessonCnt == totalLessonCnt;

  /// 웹 `CourseCardContent`의 `(completedLessonCnt / totalLessonCnt) * 100`.
  ///
  /// 웹은 0으로 나누면 `NaN`이 되고 `translateX(-NaN%)`는 브라우저가 무시해
  /// 바가 가득 찬 것처럼 보인다. 앱에서 그 값을 그대로 옮기면 레이아웃이
  /// 터지므로 0으로 떨어뜨린다 — 총 0회짜리 수강권은 존재하지 않아
  /// 실제로 도달하지 않는 경로다.
  double get progress =>
      totalLessonCnt == 0 ? 0 : (completedLessonCnt / totalLessonCnt) * 100;
}
