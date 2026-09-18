import 'package:flutter/foundation.dart';

import '../../../core/json/paged_response.dart';
import 'point_history.dart';
import 'student_point.dart';

/// `GET /api/v1/members/{memberId}/point`의 응답 `data`.
///
/// 봉투는 [PagedResponse]가 갖고, 여기서는 `mainData`만 해석한다 —
/// 그 내용이 **학생 홈이 이미 쓰는 [StudentPoint]와 같다**
/// (`{searchDate, monthPoint, totalPoint}`, 2026-09-18 실측으로 확인).
/// 그래서 BUG-3(`webMonthLabel`)도 그대로 재사용된다.
///
/// ## 2026-09-18 실측 본문 (규율 #16)
///
/// ```json
/// {"content":[],"pageNumber":0,"pageSize":20,"totalPages":0,
///  "totalElements":0,"isLast":true,
///  "mainData":{"searchDate":"2026-09","monthPoint":0,"totalPoint":85}}
/// ```
///
/// `totalPoint`는 **그 달까지의 누적**이다(전역 상수가 아니다) — 2026-03에서
/// 0, 2026-04에서 85, 이후 달도 85였다.
@immutable
class PointHistoryPage {
  const PointHistoryPage({
    required this.content,
    required this.isLast,
    required this.pageNumber,
    required this.point,
  });

  static PointHistoryPage fromJson(Object? json) {
    final paged = PagedResponse.fromJson<PointHistory>(
      json,
      item: PointHistory.fromJsonOrNull,
    );

    return PointHistoryPage(
      content: paged.content,
      isLast: paged.isLast,
      pageNumber: paged.pageNumber,
      point: StudentPoint.fromJsonOrNull(paged.mainData),
    );
  }

  final List<PointHistory> content;
  final bool isLast;
  final int pageNumber;

  /// `mainData`. 못 읽으면 null — 화면이 카드를 0으로 그린다.
  final StudentPoint? point;
}
