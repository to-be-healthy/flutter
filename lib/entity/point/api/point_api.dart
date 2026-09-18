import 'package:dio/dio.dart';

import '../model/point_history_page.dart';

/// 웹 `feature/point/api/queries.ts`.
///
/// 조회 하나뿐이다 — **포인트 화면에는 뮤테이션이 없다**(읽기 전용).
class PointApi {
  PointApi(this._dio);

  /// 백엔드 `MemberController.java:140` — 트레이너 전용.
  static String historyPath(Object memberId) =>
      '/api/v1/members/$memberId/point';

  /// 웹 `ITEMS_PER_PAGE`(`StudentPointDetailPage.tsx`).
  static const int pageSize = 20;

  final Dio _dio;

  /// 웹 `useStudentPointHistoryQuery` — `useInfiniteQuery`.
  ///
  /// [page]는 웹 `getNextPageParam: (lastPage, allPages) => allPages.length`
  /// 를 옮긴 것이다(S3와 같다).
  Future<PointHistoryPage> history({
    required Object memberId,
    required String searchDate,
    int page = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      historyPath(memberId),
      queryParameters: {
        'page': page,
        'size': pageSize,
        'searchDate': searchDate,
      },
    );
    return PointHistoryPage.fromJson(response.data?['data']);
  }
}
