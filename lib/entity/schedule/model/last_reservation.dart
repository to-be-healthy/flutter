import 'package:flutter/foundation.dart';

/// 웹 `ScheduleData`(`feature/schedule/model/type.ts:13~20`)
/// = 백엔드 `MyReservation`.
///
/// **아홉 필드 중 넷만 담는다.** 화면이 읽는 것이 그뿐이다:
/// - `trainerName` — 응답에 오지만(`"김트레이너 트레이너"`, 백엔드가
///   `+ " 트레이너"`를 붙인다) 지난 예약 화면은 쓰지 않는다.
/// - `round`·`applicantName`·`waitingByName` — 다른 화면(`AllScheduleData`)의
///   필드라 이 응답에 아예 없다.
@immutable
class LastReservation {
  const LastReservation({
    required this.scheduleId,
    required this.lessonDt,
    required this.lessonStartTime,
    required this.lessonEndTime,
    required this.reservationStatus,
  });

  /// 웹 `item.reservationStatus === 'COMPLETED'` — 출석/미출석을 가르는 값.
  static const String completed = 'COMPLETED';

  static LastReservation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return LastReservation(
      scheduleId: _asInt(json['scheduleId']) ?? 0,
      // `LocalDate` → `"2026-04-13"`.
      lessonDt: json['lessonDt'] as String? ?? '',
      // `LocalTime` → `"04:00:00"`. **초까지 온다.**
      lessonStartTime: json['lessonStartTime'] as String? ?? '',
      lessonEndTime: json['lessonEndTime'] as String? ?? '',
      reservationStatus: json['reservationStatus'] as String? ?? '',
    );
  }

  final int scheduleId;
  final String lessonDt;
  final String lessonStartTime;
  final String lessonEndTime;
  final String reservationStatus;

  /// 웹의 삼항 분기 그대로. `COMPLETED`가 아니면 전부 미출석이다.
  bool get isCompleted => reservationStatus == completed;
}

/// 웹 `MyReservationResponse` = 백엔드 `MyReservationResponse`.
///
/// **`course`는 담지 않는다.** 이 조회에서는 서버가 언제나 `null`을 넣고
/// (`StudentScheduleService.java:129`의 `MyReservationResponse.create(null, ...)`)
/// 화면도 읽지 않는다 — 웹 타입만 non-optional로 선언해 두었다(서베이 BUG-20).
/// 2026-09-15 실측 응답에서도 `"course": null`이었다.
@immutable
class LastReservationList {
  const LastReservationList({required this.reservations});

  /// **비어 있으면 `reservations`가 `null`이다**(빈 배열이 아니다).
  /// `MyReservationResponse.java:16`이 그렇게 만든다.
  ///
  /// 화면이 그 null로 빈 상태를 고르므로(`data?.reservations === null`)
  /// **여기서 빈 목록으로 흡수하면 안 된다.**
  static LastReservationList fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return const LastReservationList(reservations: null);
    }
    final list = data['reservations'];
    if (list is! List) {
      return const LastReservationList(reservations: null);
    }
    return LastReservationList(
      reservations: list
          .map(LastReservation.fromJson)
          .whereType<LastReservation>()
          .toList(growable: false),
    );
  }

  /// null이면 "서버가 목록 자체를 주지 않았다"는 뜻이다.
  final List<LastReservation>? reservations;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
