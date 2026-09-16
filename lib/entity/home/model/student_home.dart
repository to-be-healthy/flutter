import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';
import '../../course/model/course.dart';
import '../../diet/model/diet.dart';
import '../../point/model/student_point.dart';

/// 웹 `feature/home/api/queries.ts`의 `HomeDataResponse`
/// = 백엔드 `StudentHomeResult`(`GET /api/v1/home/student`).
///
/// **웹 타입을 그대로 믿으면 안 된다.** `HomeDataResponse`는 일곱 필드를 전부
/// non-optional로 선언하는데, 소비 측(`StudentHomePage.tsx`)은 네 필드를 전부
/// 런타임 가드한다(`{data?.course && ...}` 등). 서버가 null을 준다는 뜻이고,
/// 선언된 타입이 실제 계약과 다르다. 백엔드 `StudentHomeResult`도 record
/// 필드일 뿐 null 여부를 보장하지 않는다.
///
/// 그래서 **전부 nullable로 받고 화면에서 가드한다.** 웹이 `point`·`rank`·
/// `gym`을 가드 없이 접근하는 것은 웹의 운이지 계약이 아니다.
@immutable
class StudentHome {
  const StudentHome({
    this.course,
    this.point,
    this.rank,
    this.myReservation,
    this.lessonHistory,
    this.diet,
    this.gymName = '',
  });

  /// 응답의 `data`를 그대로 받는다. `data`가 맵이 아니면 전부 null인 빈 홈이다.
  factory StudentHome.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return const StudentHome();
    }
    return StudentHome(
      course: Course.fromJsonOrNull(data['course']),
      point: StudentPoint.fromJsonOrNull(data['point']),
      rank: StudentRank.fromJsonOrNull(data['rank']),
      myReservation: MyReservation.fromJsonOrNull(data['myReservation']),
      lessonHistory: LessonHistory.fromJsonOrNull(data['lessonHistory']),
      diet: HomeDiet.fromJsonOrNull(data['diet']),
      // **`GymResult`가 아니라 `GymDto`다** — id 필드명이 `gymId`가 아니라
      // `id`이고, 화면이 읽는 것은 이름뿐이다. `Gym`(목록용)으로 받으려다
      // 비-null 캐스트가 터져 **홈 전체 파싱이 죽은 적이 있다**.
      // 근거와 경위는 `test/entity/gym/gym_test.dart`.
      gymName: data['gym'] is Map<String, dynamic>
          ? (data['gym'] as Map<String, dynamic>)['name'] as String? ?? ''
          : '',
    );
  }

  final Course? course;
  final StudentPoint? point;
  final StudentRank? rank;
  final MyReservation? myReservation;
  final LessonHistory? lessonHistory;
  final HomeDiet? diet;

  /// 헤더에 찍을 헬스장 이름. 백엔드 `StudentHomeResult.gym`(`GymDto`)의
  /// `name`이다. **id는 담지 않는다** — 화면이 쓰지 않는다.
  final String gymName;

  // 응답의 `redDotStatus`는 **의도적으로 담지 않는다.** 백엔드
  // `StudentHomeResult`에 그 필드가 있지만, 웹은 헤더 빨간 점을 이 값이 아니라
  // 따로 부르는 `GET /api/v1/notification/red-dot`(`useHomeAlarmQuery`)으로
  // 그린다. 중복 조회지만 골든이 3건이라 요청을 줄일 수 없고, 여기서 이 필드를
  // 노출하면 "어느 쪽을 쓰는가"가 흐려진다.
}

/// 백엔드 `MyReservation`.
@immutable
class MyReservation {
  const MyReservation({
    required this.scheduleId,
    required this.lessonDt,
    required this.lessonStartTime,
    required this.trainerName,
  });

  static MyReservation? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return MyReservation(
      scheduleId: asIntOrNull(json['scheduleId']) ?? 0,
      // 서버 `LocalDate` → Spring Boot 기본 Jackson 설정
      // (`WRITE_DATES_AS_TIMESTAMPS=false`)에서 `"2026-09-15"` ISO 문자열이다.
      // 웹 TS 타입도 `string`이라 서로 맞는다.
      lessonDt: DateTime.tryParse(json['lessonDt'] as String? ?? ''),
      // 서버 `LocalTime` → `"14:30:00"`. **문자열 그대로 둔다** —
      // 날짜가 없는 시각이라 `DateTime`으로 올리면 오늘 날짜가 섞인다.
      lessonStartTime: json['lessonStartTime'] as String? ?? '',
      trainerName: json['trainerName'] as String? ?? '',
    );
  }

  final int scheduleId;
  final DateTime? lessonDt;
  final String lessonStartTime;
  final String trainerName;

  // `lessonEndTime`·`reservationStatus`는 응답에 있지만 홈이 그리지 않아
  // 담지 않는다. 예약 화면을 옮길 때 그쪽 모델이 받는다.
}

/// 백엔드 `RetrieveLessonHistoryByDateCondResult` 중 **홈이 쓰는 부분만**.
@immutable
class LessonHistory {
  const LessonHistory({
    required this.id,
    required this.content,
    required this.isUnread,
    this.trainerProfile,
  });

  static LessonHistory? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return LessonHistory(
      id: asIntOrNull(json['id']) ?? 0,
      content: json['content'] as String? ?? '',
      // 백엔드 `LessonHistoryReadStatus` enum(`READ`/`UNREAD`)의 이름이 온다.
      // 웹 `data.lessonHistory.feedbackChecked === 'UNREAD'`와 같은 비교다.
      isUnread: json['feedbackChecked'] == 'UNREAD',
      // 트레이너가 프로필 사진을 올리지 않았으면 서버가 null을 준다
      // (`entity.getTrainer().getMemberProfile() != null ? ... : null`).
      trainerProfile: json['trainerProfile'] as String?,
    );
  }

  final int id;
  final String content;
  final bool isUnread;
  final String? trainerProfile;

  // `files`는 담지 않는다. 웹 타입이 단수 객체(`{fileUrl, fileOrder, createdAt}`)
  // 로 선언했지만 백엔드는 `List<LessonHistoryFileResults>`다 — **웹 타입이
  // 틀렸다.** 홈이 쓰지 않으므로 여기서 그 불일치를 떠안지 않는다.
}
