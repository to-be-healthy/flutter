import 'package:dio/dio.dart';

/// 웹 `entity/alarm/api/queries.ts`의 `useHomeAlarmQuery`.
class NotificationApi {
  NotificationApi(this._dio);

  /// 백엔드 `NotificationController`의 `@GetMapping("/red-dot")`.
  /// 응답은 `ApiResult<Boolean>`이다.
  static const String redDotPath = '/api/v1/notification/red-dot';

  final Dio _dio;

  /// 읽지 않은 알림이 있으면 true.
  ///
  /// **홈 응답의 `redDotStatus`가 아니라 이 요청을 쓴다.** 백엔드
  /// `StudentHomeResult`에 같은 뜻의 필드가 있지만 웹은 헤더 빨간 점을
  /// 이쪽으로 그린다(`StudentHomePage.tsx:51,136`). 중복 조회이고, 골든이
  /// 3건이라 요청을 줄이면 패리티가 깨진다.
  ///
  /// 웹 `useHomeAlarmQuery`에는 **에러 처리가 전혀 없다** — 실패하면 점이
  /// 안 찍힐 뿐이다. 같은 동작을 옮기려고 호출부가 실패를 삼킨다.
  Future<bool> redDot() async {
    final response = await _dio.get<Map<String, dynamic>>(redDotPath);
    return response.data?['data'] == true;
  }
}
