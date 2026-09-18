import 'package:flutter/foundation.dart';

import '../../../core/json/paged_response.dart';
import 'course.dart';
import 'course_history.dart';

/// `GET /api/v1/members/{memberId}/course`의 응답 `data`.
///
/// 봉투(`content`·`isLast`·`pageNumber`)는 [PagedResponse]가 갖고, 여기서는
/// 이 엔드포인트의 `mainData`(`{course, gymName}`)만 해석한다.
///
/// ## 2026-09-18 실측 본문 (규율 #16)
///
/// ```json
/// {"content":[],"pageNumber":0,"pageSize":20,"totalPages":0,
///  "totalElements":0,"isLast":true,
///  "mainData":{"course":{"courseId":3,...},"gymName":"건강해짐 홍대점"}}
/// ```
///
/// `mainData.course`는 **null일 수 있다**(수강권 없는 회원). 웹 TS는 non-null로
/// 선언했지만 소비 측이 `mainData.course?.`로 방어한다 — 규율 #16이 말하는
/// "선언이 아니라 소비 측을 보라"의 사례다.
@immutable
class CourseHistoryPage {
  const CourseHistoryPage({
    required this.content,
    required this.isLast,
    required this.pageNumber,
    required this.course,
    required this.gymName,
  });

  static CourseHistoryPage fromJson(Object? json) {
    final paged = PagedResponse.fromJson<CourseHistory>(
      json,
      item: CourseHistory.fromJsonOrNull,
    );
    final mainData = paged.mainData;

    return CourseHistoryPage(
      content: paged.content,
      isLast: paged.isLast,
      pageNumber: paged.pageNumber,
      course: Course.fromJsonOrNull(
        mainData is Map<String, dynamic> ? mainData['course'] : null,
      ),
      gymName:
          (mainData is Map<String, dynamic> ? mainData['gymName'] : null)
              ?.toString() ??
          '',
    );
  }

  final List<CourseHistory> content;
  final bool isLast;
  final int pageNumber;

  /// 수강권이 없으면 null — 화면이 "등록된 수강권이 없습니다." 분기를 그린다.
  final Course? course;
  final String gymName;
}
