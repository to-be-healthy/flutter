import 'package:dio/dio.dart';

import '../model/last_reservation.dart';

/// 웹 `feature/schedule/api/queries.ts` 중 마이페이지가 쓰는 부분.
class ScheduleApi {
  ScheduleApi(this._dio);

  /// 백엔드 `StudentScheduleController`의
  /// `@GetMapping("/student/my-reservation/old")`
  /// (`@PreAuthorize("hasAuthority('ROLE_STUDENT')")`).
  static const String lastReservationPath =
      '/api/v1/schedule/student/my-reservation/old';

  final Dio _dio;

  /// 웹 `useStudentMyLastReservationListQuery(searchDate)`.
  ///
  /// [searchDate]는 `YYYY-MM`이다. **웹은 이 값이 `Invalid Date`가 될 수
  /// 있다** — `?month=` 쿼리가 없으면 `dayjs(null)`이 그렇게 된다
  /// (서베이 BUG-8). 화면이 그 상태를 그대로 보내는 것까지 옮겼다.
  Future<LastReservationList> studentLastReservations(String searchDate) async {
    final response = await _dio.get<Map<String, dynamic>>(
      lastReservationPath,
      queryParameters: <String, dynamic>{'searchDate': searchDate},
    );
    return LastReservationList.fromJson(response.data?['data']);
  }
}
