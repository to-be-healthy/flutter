import 'package:flutter/foundation.dart';

/// 웹 `feature/home/model/type.ts`의 `TrainerHomeInfo`
/// = 백엔드 `TrainerHomeResult`(`GET /api/v1/home/trainer`)의 **앞 세 필드**.
///
/// 백엔드는 다섯 필드(`studentCount`·`bestStudents`·`todaySchedule`·`gym`·
/// `redDotStatus`)를 주지만 웹 타입은 셋만 선언하고 뒤의 둘을 쓰지 않는다:
/// - `gym` → 헤더의 헬스장 이름은 **`GET /api/v1/members/me`**로 따로 받는다.
///   요청 하나를 아낄 수 있어 보이지만 **줄이면 골든이 깨진다**(3건 고정).
/// - `redDotStatus` → 헤더 빨간 점은 `GET /api/v1/notification/red-dot`을
///   따로 부른다. 학생 홈과 같은 중복이다.
@immutable
class TrainerHome {
  const TrainerHome({
    required this.studentCount,
    required this.bestStudents,
    required this.todaySchedule,
  });

  factory TrainerHome.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return const TrainerHome(
        studentCount: 0,
        bestStudents: <BestStudent>[],
        todaySchedule: <TrainerLesson>[],
      );
    }
    return TrainerHome(
      studentCount: _asInt(data['studentCount']) ?? 0,
      // 웹 타입이 유일하게 정직한 필드다(`BestStudent[] | null`).
      bestStudents: _listOf(data['bestStudents'], BestStudent.fromJson),
      // **웹 타입은 `todaySchedule`을 non-optional로 선언하지만** 소비 측은
      // `homeInfo?.todaySchedule.schedule`처럼 첫 단계만 옵셔널 체이닝한다 —
      // 서버가 null을 주면 웹은 TypeError다. 여기서는 빈 목록으로 흡수한다.
      todaySchedule: _listOf(
        data['todaySchedule'] is Map<String, dynamic>
            ? (data['todaySchedule'] as Map<String, dynamic>)['schedule']
            : null,
        TrainerLesson.fromJson,
      ),
    );
  }

  final int studentCount;
  final List<BestStudent> bestStudents;

  /// 백엔드 `todaySchedule.schedule`. 바깥 래퍼(`trainerName`·
  /// `scheduleTotalCount`)는 **웹이 쓰지 않아** 담지 않는다.
  final List<TrainerLesson> todaySchedule;

  /// 웹 `hasTodaySchedule = Array.isArray(todaySchedule) && length > 0`.
  bool get hasTodaySchedule => todaySchedule.isNotEmpty;

  /// 웹 `findClosestSchedule`이 실제로 고르는 수업.
  ///
  /// **"가장 가까운 수업"이 아니라 언제나 첫 번째다 — 웹 버그를 그대로
  /// 옮긴 것이다.**
  ///
  /// 웹은 `dayjs(schedule.lessonStartTime)`에 파싱 포맷을 주지 않는데,
  /// `lessonStartTime`은 **시각 전용 문자열**이다(백엔드
  /// `LessonDetailResult.lessonStartTime`이 `LocalTime`이라 `"09:00:00"`으로
  /// 직렬화된다). dayjs의 `REGEX_PARSE`는 4자리 연도로 시작해야 매치되므로
  /// 네이티브 `Date`로 폴백해 **Invalid Date**가 되고, 그 결과:
  ///
  /// 1. `lessonStartTime.isBefore(now)` → `false` — 지난 수업이 걸러지지 않는다
  /// 2. `!closestSchedule || lessonStartTime.isBefore(...)` → 첫 항목에서만 참
  /// 3. ⇒ 언제나 배열의 첫 원소
  ///
  /// `intl`로 제대로 파싱해 "진짜 가장 가까운 수업"을 구현하면 **웹과 다른
  /// 화면이 된다.** `trainer_home_test.dart`가 이 성질을 단언으로 고정한다 —
  /// 고칠 때는 웹과 앱, 그 단언을 함께 바꾼다.
  TrainerLesson? get highlightedLesson =>
      todaySchedule.isEmpty ? null : todaySchedule.first;
}

/// 웹 `BestStudent`. 백엔드 `MemberInTeamResult`.
///
/// 11필드 중 화면이 쓰는 것은 셋뿐이다. **`ranking`은 응답에 있는데 쓰지
/// 않는다** — 메달 안 숫자가 하드코딩 `'1'`이다(웹 `:293`).
@immutable
class BestStudent {
  const BestStudent({
    required this.memberId,
    required this.name,
    required this.courseId,
  });

  static BestStudent? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return BestStudent(
      memberId: _asInt(json['memberId']) ?? 0,
      name: json['name'] as String? ?? '',
      // 수강권 지급(`PATCH /api/v1/course/{courseId}`)의 대상. Phase B에서 쓴다.
      courseId: _asInt(json['courseId']),
    );
  }

  final int memberId;
  final String name;
  final int? courseId;
}

/// 웹 `TrainerSchedule`. 백엔드 `LessonDetailResult`.
///
/// 9필드 중 화면이 쓰는 것은 넷이다. **`reservationStatus`가 있는데 필터에
/// 쓰지 않는다** — 서버가 예약된 것만 준다는 암묵적 가정이고, 그래서
/// [applicantId]가 null인 슬롯이 섞이면 웹은 `/trainer/manage/null`로
/// 이동한다(BUG-3).
@immutable
class TrainerLesson {
  const TrainerLesson({
    required this.scheduleId,
    required this.lessonStartTime,
    this.applicantId,
    this.applicantName,
  });

  static TrainerLesson? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return TrainerLesson(
      scheduleId: _asInt(json['scheduleId']) ?? 0,
      // 서버 `LocalTime` → `"09:00:00"`. **웹이 그대로 화면에 찍는다**
      // (`:202`) — 포맷하지 않는다. 트레이너 홈에는 dayjs `format()` 호출이
      // 한 번도 없다.
      lessonStartTime: json['lessonStartTime'] as String? ?? '',
      applicantId: _asInt(json['applicantId']),
      applicantName: json['applicantName'] as String?,
    );
  }

  final int scheduleId;
  final String lessonStartTime;
  final int? applicantId;
  final String? applicantName;
}

/// `data`가 리스트면 [parse]로 변환하고, 아니면 빈 목록.
List<T> _listOf<T>(Object? data, T? Function(Object?) parse) {
  if (data is! List) {
    return <T>[];
  }
  return data.map(parse).whereType<T>().toList(growable: false);
}

/// 서버가 정수를 문자열로 주는 경우까지 흡수한다
/// (`student_home.dart`와 같은 이유 — OpenAPI에 응답 스키마가 비어 있다).
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
