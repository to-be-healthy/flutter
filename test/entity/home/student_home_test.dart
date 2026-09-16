import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/course/model/course.dart';
import 'package:geonganghaejim/entity/diet/model/diet.dart';
import 'package:geonganghaejim/entity/home/model/student_home.dart';
import 'package:geonganghaejim/entity/point/model/student_point.dart';

/// 실제 응답 모양에 가까운 픽스처. 백엔드 `StudentHomeResult`의 8필드다.
Map<String, dynamic> _fullResponse() =>
    jsonDecode('''
{
  "course": {"courseId": 3, "totalLessonCnt": 10, "remainLessonCnt": 4,
             "completedLessonCnt": 6, "createdAt": "2026-08-01T10:00:00"},
  "point": {"searchDate": "2026-09", "monthPoint": 120, "totalPoint": 980},
  "rank": {"ranking": 3, "lastMonthRanking": 5, "totalMemberCnt": 42},
  "myReservation": {"scheduleId": 77, "lessonDt": "2026-09-15",
                    "lessonStartTime": "14:30:00", "lessonEndTime": "15:30:00",
                    "trainerName": "김트레이너 트레이너",
                    "reservationStatus": "COMPLETED"},
  "lessonHistory": {"id": 12, "title": "9월 15일 수업", "content": "오늘은 하체",
                    "feedbackChecked": "UNREAD",
                    "trainerProfile": "https://cdn.test/t.png",
                    "lessonDt": "09월 15일 화요일", "lessonTime": "14:30 - 15:30"},
  "diet": {
    "breakfast": {"fast": true, "type": "BREAKFAST", "dietFile": null},
    "lunch": {"fast": false, "type": "LUNCH",
              "dietFile": {"fileUrl": "https://cdn.test/lunch.png"}},
    "dinner": {"fast": false, "type": "DINNER", "dietFile": null}
  },
  "gym": {"id": 1, "name": "건강해짐 강남점"},
  "redDotStatus": true
}
''')
        as Map<String, dynamic>;

void main() {
  group('StudentHome.fromJson', () {
    test('전체 응답의 일곱 필드를 읽는다', () {
      final home = StudentHome.fromJson(_fullResponse());

      expect(home.course!.totalLessonCnt, 10);
      expect(home.point!.monthPoint, 120);
      expect(home.rank!.ranking, 3);
      expect(home.myReservation!.scheduleId, 77);
      expect(home.lessonHistory!.id, 12);
      expect(home.diet!.breakfast.isFasting, isTrue);
      // **`gymId`가 아니라 `id`다** — `StudentHomeResult.gym`이 `GymDto`다.
      // 픽스처를 `gymId`로 써 두었던 탓에 실서버에서만 터지는 버그를
      // 테스트가 오래 가려 줬다(`test/entity/gym/gym_test.dart` 참고).
      expect(home.gymName, '건강해짐 강남점');
    });

    // 웹 TS 타입은 이 필드들을 non-optional로 선언하지만 소비 측이 전부
    // 런타임 가드한다 — 서버가 null을 준다는 뜻이다. 그 타입을 그대로
    // 옮겼다면 여기서 죽는다.
    test('네 필드가 null인 응답을 받는다 (웹 타입이 거짓말하는 지점)', () {
      final home = StudentHome.fromJson(<String, dynamic>{
        'course': null,
        'point': null,
        'rank': null,
        'myReservation': null,
        'lessonHistory': null,
        'diet': null,
        'gym': null,
      });

      expect(home.course, isNull);
      expect(home.point, isNull);
      expect(home.rank, isNull);
      expect(home.myReservation, isNull);
      expect(home.lessonHistory, isNull);
      expect(home.diet, isNull);
      expect(home.gymName, '');
    });

    test('data 가 맵이 아니면 빈 홈이다', () {
      expect(StudentHome.fromJson(null).course, isNull);
      expect(StudentHome.fromJson('이상한값').gymName, '');
    });
  });

  group('Course', () {
    test('completed == total 이면 만료다', () {
      final course = Course.fromJsonOrNull(<String, dynamic>{
        'courseId': 1,
        'totalLessonCnt': 10,
        'remainLessonCnt': 0,
        'completedLessonCnt': 10,
      })!;

      expect(course.isExpired, isTrue);
      expect(course.progress, 100);
    });

    test('completed != total 이면 만료가 아니다', () {
      final course = Course.fromJsonOrNull(<String, dynamic>{
        'totalLessonCnt': 10,
        'completedLessonCnt': 6,
      })!;

      expect(course.isExpired, isFalse);
      expect(course.progress, 60);
    });

    // 웹은 0으로 나눠 `NaN`을 만들고 `translateX(-NaN%)`를 브라우저가 무시해
    // 바가 가득 찬 것처럼 보인다. Flutter에서 `NaN`은 레이아웃을 터뜨린다.
    test('총 0회면 진행률이 0이다 (웹의 NaN 자리)', () {
      final course = Course.fromJsonOrNull(<String, dynamic>{
        'totalLessonCnt': 0,
        'completedLessonCnt': 0,
      })!;

      expect(course.progress, 0);
      expect(course.progress.isNaN, isFalse);
    });
  });

  group('StudentPoint.webMonthLabel — 웹 버그를 그대로 옮겼다', () {
    StudentPoint of(String searchDate) => StudentPoint.fromJsonOrNull(
      <String, dynamic>{'searchDate': searchDate},
    )!;

    // 웹 `searchDate.split('-')[1].split('')[1]`. 01~09월에만 우연히 맞는다.
    test('9월은 우연히 맞는다', () {
      expect(of('2026-09').webMonthLabel, '9');
    });

    test('1월도 우연히 맞는다', () {
      expect(of('2026-01').webMonthLabel, '1');
    });

    // 사용자 결정(2026-09-15): 버그째 이관하고 기록한다.
    // **이 단언들이 결정을 고정한다** — 누군가 "개선"으로 조용히 고치면
    // 여기가 먼저 깨져서 결정을 다시 보게 된다. 고칠 때는 웹도 함께 고친다.
    test('10월은 "0"이 된다 (웹 버그)', () {
      expect(of('2026-10').webMonthLabel, '0');
    });

    test('11월은 "1"이 된다 (웹 버그)', () {
      expect(of('2026-11').webMonthLabel, '1');
    });

    test('12월은 "2"가 된다 (웹 버그)', () {
      expect(of('2026-12').webMonthLabel, '2');
    });

    test('형식이 깨지면 빈 문자열이다', () {
      expect(of('').webMonthLabel, '');
      expect(of('2026').webMonthLabel, '');
      expect(of('2026-9').webMonthLabel, '');
    });
  });

  group('StudentRank', () {
    StudentRank of(int ranking, int lastMonth) =>
        StudentRank.fromJsonOrNull(<String, dynamic>{
          'ranking': ranking,
          'lastMonthRanking': lastMonth,
          'totalMemberCnt': 42,
        })!;

    test('999는 순위가 아니라 "없음" 표식이다', () {
      expect(of(999, 999).hasRanking, isFalse);
      expect(of(998, 998).hasRanking, isTrue);
    });

    test('같으면 화살표가 없다', () {
      expect(of(5, 5).trend, RankTrend.flat);
    });

    // 숫자가 클수록 낮은 순위다 — 부등호를 뒤집으면 화살표가 정반대가 된다.
    test('숫자가 커졌으면 하락이다', () {
      expect(of(7, 3).trend, RankTrend.down);
    });

    test('숫자가 작아졌으면 상승이다', () {
      expect(of(3, 7).trend, RankTrend.up);
    });
  });

  group('MyReservation', () {
    test('ISO 날짜와 시각 문자열을 읽는다', () {
      final reservation = MyReservation.fromJsonOrNull(<String, dynamic>{
        'scheduleId': 77,
        'lessonDt': '2026-09-15',
        'lessonStartTime': '14:30:00',
        'trainerName': '김트레이너 트레이너',
      })!;

      expect(reservation.lessonDt, DateTime(2026, 9, 15));
      // 시각은 **문자열 그대로** 둔다 — 날짜 없는 `LocalTime`이라
      // `DateTime`으로 올리면 오늘 날짜가 섞인다.
      expect(reservation.lessonStartTime, '14:30:00');
    });

    test('날짜가 깨져 있으면 null이다', () {
      final reservation = MyReservation.fromJsonOrNull(<String, dynamic>{
        'lessonDt': '이상한값',
      })!;

      expect(reservation.lessonDt, isNull);
    });
  });

  group('LessonHistory', () {
    test('UNREAD 면 배지를 켠다', () {
      expect(
        LessonHistory.fromJsonOrNull(<String, dynamic>{
          'feedbackChecked': 'UNREAD',
        })!.isUnread,
        isTrue,
      );
    });

    test('READ 면 배지를 끈다', () {
      expect(
        LessonHistory.fromJsonOrNull(<String, dynamic>{
          'feedbackChecked': 'READ',
        })!.isUnread,
        isFalse,
      );
    });

    test('트레이너 프로필이 없으면 null이다', () {
      expect(
        LessonHistory.fromJsonOrNull(<String, dynamic>{
          'trainerProfile': null,
        })!.trainerProfile,
        isNull,
      );
    });
  });

  group('DietMeal.tile — 웹 타일 3분기', () {
    test('단식이면 단식 타일', () {
      final meal = DietMeal.fromJson(<String, dynamic>{
        'fast': true,
      }, MealType.breakfast);

      expect(meal.tile, DietTile.fasting);
    });

    test('사진이 있으면 사진 타일', () {
      final meal = DietMeal.fromJson(<String, dynamic>{
        'fast': false,
        'dietFile': <String, dynamic>{'fileUrl': 'https://cdn.test/a.png'},
      }, MealType.lunch);

      expect(meal.tile, DietTile.photo);
    });

    test('둘 다 없으면 빈 타일', () {
      final meal = DietMeal.fromJson(<String, dynamic>{
        'fast': false,
        'dietFile': null,
      }, MealType.dinner);

      expect(meal.tile, DietTile.empty);
    });

    // 웹이 `{diet.fast && ...}`를 먼저 평가한다. 순서를 뒤집으면 단식이면서
    // 사진이 있는 데이터가 사진 타일로 그려져 웹과 달라진다.
    test('단식이 사진을 이긴다', () {
      final meal = DietMeal.fromJson(<String, dynamic>{
        'fast': true,
        'dietFile': <String, dynamic>{'fileUrl': 'https://cdn.test/a.png'},
      }, MealType.breakfast);

      expect(meal.tile, DietTile.fasting);
    });

    test('끼니가 통째로 null이어도 빈 타일로 흡수한다', () {
      expect(DietMeal.fromJson(null, MealType.lunch).tile, DietTile.empty);
    });

    test('세 끼니가 breakfast·lunch·dinner 순서다', () {
      final diet = HomeDiet.fromJsonOrNull(
        (_fullResponse()['diet'] as Map<String, dynamic>),
      )!;

      expect(diet.meals.map((m) => m.type).toList(), <MealType>[
        MealType.breakfast,
        MealType.lunch,
        MealType.dinner,
      ]);
    });
  });
}
