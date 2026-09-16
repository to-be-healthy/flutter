import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/home/model/trainer_home.dart';
import 'package:geonganghaejim/entity/member/model/member_info.dart';

Map<String, dynamic> _lesson(int id, String time, {int? applicantId}) =>
    <String, dynamic>{
      'scheduleId': id,
      'duration': 1.0,
      'lessonStartTime': time,
      'lessonEndTime': '10:00:00',
      'reservationStatus': 'COMPLETED',
      'applicantId': applicantId,
      'applicantName': applicantId == null ? null : '회원$applicantId',
    };

void main() {
  group('TrainerHome.fromJson', () {
    test('세 필드를 읽는다', () {
      final home = TrainerHome.fromJson(<String, dynamic>{
        'studentCount': 12,
        'bestStudents': <dynamic>[
          <String, dynamic>{'memberId': 3, 'name': '김회원', 'courseId': 9},
        ],
        'todaySchedule': <String, dynamic>{
          'trainerName': '박트레이너',
          'scheduleTotalCount': 2,
          'schedule': <dynamic>[_lesson(1, '09:00:00', applicantId: 3)],
        },
        // 백엔드는 주지만 웹이 쓰지 않는 둘. 모델이 담지 않는다.
        'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
        'redDotStatus': true,
      });

      expect(home.studentCount, 12);
      expect(home.bestStudents.single.name, '김회원');
      expect(home.bestStudents.single.courseId, 9);
      expect(home.todaySchedule.single.scheduleId, 1);
      expect(home.todaySchedule.single.applicantName, '회원3');
    });

    // 웹 타입은 `todaySchedule`을 non-optional로 선언하지만 소비 측은
    // `homeInfo?.todaySchedule.schedule`처럼 첫 단계만 가드한다 —
    // 서버가 null을 주면 웹은 TypeError다.
    test('todaySchedule 이 null이면 빈 목록으로 흡수한다', () {
      final home = TrainerHome.fromJson(<String, dynamic>{
        'studentCount': 0,
        'todaySchedule': null,
      });

      expect(home.todaySchedule, isEmpty);
      expect(home.hasTodaySchedule, isFalse);
    });

    // 웹 타입이 유일하게 정직한 필드(`BestStudent[] | null`).
    test('bestStudents 가 null이면 빈 목록이다', () {
      final home = TrainerHome.fromJson(<String, dynamic>{
        'bestStudents': null,
      });

      expect(home.bestStudents, isEmpty);
    });

    test('data 가 맵이 아니면 빈 홈이다', () {
      expect(TrainerHome.fromJson(null).studentCount, 0);
      expect(TrainerHome.fromJson('이상한값').todaySchedule, isEmpty);
    });

    test('시각은 서버 문자열 그대로 둔다', () {
      final home = TrainerHome.fromJson(<String, dynamic>{
        'todaySchedule': <String, dynamic>{
          'schedule': <dynamic>[_lesson(1, '14:30:00', applicantId: 3)],
        },
      });

      // 트레이너 홈에는 dayjs `format()` 호출이 한 번도 없다 — 서버가 주는
      // `LocalTime` 문자열을 그대로 찍는다.
      expect(home.todaySchedule.single.lessonStartTime, '14:30:00');
    });

    // BUG-3: `reservationStatus`가 있는데 필터에 쓰지 않아, 예약자 없는
    // 슬롯이 섞이면 웹은 `/trainer/manage/null`로 이동한다.
    test('예약자가 없는 수업도 그대로 담는다 (웹이 거르지 않는다)', () {
      final home = TrainerHome.fromJson(<String, dynamic>{
        'todaySchedule': <String, dynamic>{
          'schedule': <dynamic>[_lesson(1, '09:00:00')],
        },
      });

      expect(home.todaySchedule.single.applicantId, isNull);
      expect(home.todaySchedule.single.applicantName, isNull);
    });
  });

  group('TrainerHome.highlightedLesson — 웹 버그를 그대로 옮겼다 (BUG-1)', () {
    TrainerHome of(List<Map<String, dynamic>> lessons) =>
        TrainerHome.fromJson(<String, dynamic>{
          'todaySchedule': <String, dynamic>{'schedule': lessons},
        });

    test('수업이 없으면 null이다', () {
      expect(of(<Map<String, dynamic>>[]).highlightedLesson, isNull);
    });

    // 웹 `findClosestSchedule`은 `dayjs("09:00:00")`이 Invalid Date라
    // 비교가 전부 false가 되어 **언제나 첫 원소**를 고른다.
    //
    // **이 단언들이 결정을 고정한다** — `intl`로 제대로 파싱해 "진짜 가장
    // 가까운 수업"을 구현하면 여기가 먼저 깨져서 웹과 달라졌음을 알게 된다.
    test('시각 순서와 무관하게 언제나 첫 원소다', () {
      final home = of(<Map<String, dynamic>>[
        _lesson(1, '23:00:00', applicantId: 1),
        _lesson(2, '08:00:00', applicantId: 2),
        _lesson(3, '12:00:00', applicantId: 3),
      ]);

      // "가장 가까운 수업"이라면 08:00짜리(id 2)가 골라져야 한다.
      expect(home.highlightedLesson!.scheduleId, 1);
    });

    test('이미 지난 수업도 걸러지지 않는다', () {
      // 웹은 `lessonStartTime.isBefore(now)`로 지난 수업을 건너뛰려 하지만
      // Invalid Date 비교가 false라 아무것도 걸러지지 않는다.
      final home = of(<Map<String, dynamic>>[
        _lesson(1, '00:00:00', applicantId: 1),
        _lesson(2, '23:59:00', applicantId: 2),
      ]);

      expect(home.highlightedLesson!.scheduleId, 1);
    });
  });

  group('MemberInfo.fromJson', () {
    test('gym.name 만 담는다', () {
      final me = MemberInfo.fromJson(<String, dynamic>{
        'id': 5,
        'userId': 'healthy-trainer0',
        'email': 'trainer@example.com',
        'name': '박트레이너',
        'memberType': 'TRAINER',
        'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
      });

      expect(me.gymName, '건강해짐 홍대점');
    });

    test('gym 이 null이면 빈 문자열이다', () {
      expect(MemberInfo.fromJson(<String, dynamic>{'gym': null}).gymName, '');
    });

    test('data 가 맵이 아니면 빈 정보다', () {
      expect(MemberInfo.fromJson(null).gymName, '');
    });
  });
}
