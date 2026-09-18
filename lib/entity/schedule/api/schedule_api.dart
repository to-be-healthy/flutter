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

  /// 백엔드 `TrainerController`의 `@GetMapping("/reservation/new")`.
  static const String trainerReservationNewPath =
      '/api/v1/trainers/reservation/new';

  /// 백엔드 `TrainerController`의 `@GetMapping("/reservation/old")`.
  static const String trainerReservationOldPath =
      '/api/v1/trainers/reservation/old';

  /// 노쇼 토글. **메서드가 동작을 가른다**(경로는 같다).
  static String noShowPath(Object scheduleId) =>
      '/api/v1/schedule/no-show/$scheduleId';

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

  /// 웹 `useTrainerStudentReservationListQuery(memberId)` — 다가오는 예약.
  ///
  /// 백엔드 `TrainerController.java:151`. 응답이 학생 지난 예약과 **같은
  /// `MyReservationResponse`**라 모델을 공유한다. 이쪽은 `course`가 채워져
  /// 오지만 화면이 읽지 않아 [LastReservationList]가 버리는 것과 맞다.
  Future<LastReservationList> trainerStudentUpcoming(Object memberId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      trainerReservationNewPath,
      queryParameters: <String, dynamic>{'memberId': memberId},
    );
    return LastReservationList.fromJson(response.data?['data']);
  }

  /// 웹 `useTrainerStudentLastReservationListQuery({searchDate, memberId})`.
  ///
  /// 백엔드 `TrainerController.java:161`. **쿼리 순서가 `searchDate`,
  /// `memberId`다** — 골든이 쿼리까지 대조하므로 실측 그대로 보낸다.
  Future<LastReservationList> trainerStudentPast({
    required String searchDate,
    required Object memberId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      trainerReservationOldPath,
      queryParameters: <String, dynamic>{
        'searchDate': searchDate,
        'memberId': memberId,
      },
    );
    return LastReservationList.fromJson(response.data?['data']);
  }

  /// **노쇼 처리.** 동사가 직관과 반대다 — `DELETE`가 "노쇼로 표시"다
  /// (`TrainerScheduleCommandController.java:114`, 서베이 §4.3⑱).
  /// 웹도 이렇게 쓰고 있다: 현재 `COMPLETED`(출석)일 때 이 요청을 보낸다.
  ///
  /// **"DELETE니까 삭제"라고 짐작하면 정반대로 동작한다.**
  Future<String?> markNoShow(Object scheduleId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      noShowPath(scheduleId),
    );
    return response.data?['message'] as String?;
  }

  /// **노쇼 해제**(출석으로 되돌림). `POST`다 — 위와 짝이다.
  Future<String?> revertNoShow(Object scheduleId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      noShowPath(scheduleId),
    );
    return response.data?['message'] as String?;
  }
}
