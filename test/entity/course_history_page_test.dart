import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/course/model/course_history.dart';
import 'package:geonganghaejim/entity/course/model/course_history_page.dart';

/// 규율 #16 — 이 파일의 픽스처는 전부 **2026-09-18 브라우저 실측**에서 왔다
/// (`docs/trainer-manage-s3-measurements.md` 산출물 ②). 웹 TS 타입도
/// OpenAPI 문서도 근거로 쓰지 않았다.
void main() {
  group('CourseHistoryPage', () {
    test('실측 응답(내역 0건)을 그대로 파싱한다', () {
      final page = CourseHistoryPage.fromJson(<String, dynamic>{
        'content': <dynamic>[],
        'pageNumber': 0,
        'pageSize': 20,
        'totalPages': 0,
        'totalElements': 0,
        'isLast': true,
        'mainData': <String, dynamic>{
          'course': <String, dynamic>{
            'courseId': 3,
            'totalLessonCnt': 10,
            'remainLessonCnt': 3,
            'completedLessonCnt': 10,
            'createdAt': '2026-03-13T14:44:48',
          },
          'gymName': '건강해짐 홍대점',
        },
      });

      expect(page.content, isEmpty);
      expect(page.isLast, isTrue);
      expect(page.pageNumber, 0);
      expect(page.course?.courseId, 3);
      expect(page.course?.isExpired, isTrue);
      expect(page.gymName, '건강해짐 홍대점');
    });

    test('`content`가 빈 배열이어도 null이어도 빈 목록이다', () {
      // 실서버는 `[]`를 준다(실측). 웹 타입·화면 가드는 null도 상정한다.
      expect(
        CourseHistoryPage.fromJson(<String, dynamic>{
          'content': <dynamic>[],
        }).content,
        isEmpty,
      );
      expect(
        CourseHistoryPage.fromJson(<String, dynamic>{'content': null}).content,
        isEmpty,
      );
    });

    test('와이어 키는 `isLast`다 — `last`가 아니다', () {
      // Java `boolean isLast`의 빈 게터가 `last`로 직렬화되는 함정에
      // 걸리지 않았다는 것을 고정한다(실측으로 확인).
      expect(
        CourseHistoryPage.fromJson(<String, dynamic>{'isLast': false}).isLast,
        isFalse,
      );
      // `last`만 있으면 읽히지 않는다 — 읽히면 키를 잘못 본 것이다.
      expect(
        CourseHistoryPage.fromJson(<String, dynamic>{'last': false}).isLast,
        isTrue,
      );
    });

    test('`isLast`가 없으면 true로 본다', () {
      // false로 두면 다음 페이지를 영원히 조르는 화면이 된다.
      expect(CourseHistoryPage.fromJson(<String, dynamic>{}).isLast, isTrue);
    });

    test('`mainData.course`가 null이면 course도 null이다', () {
      final page = CourseHistoryPage.fromJson(<String, dynamic>{
        'mainData': <String, dynamic>{'course': null, 'gymName': '헬스장'},
      });

      expect(page.course, isNull);
      expect(page.gymName, '헬스장');
    });

    test('`mainData`가 통째로 없어도 죽지 않는다', () {
      final page = CourseHistoryPage.fromJson(<String, dynamic>{});

      expect(page.course, isNull);
      expect(page.gymName, '');
    });
  });

  group('CourseHistory', () {
    Map<String, dynamic> raw({
      String calculation = 'MINUS',
      String type = 'RESERVATION',
      Object? createdAt = '2026-03-29T14:44:48',
      int cnt = 1,
    }) => <String, dynamic>{
      'courseHistoryId': 7,
      'cnt': cnt,
      'calculation': calculation,
      'type': type,
      'createdAt': createdAt,
    };

    test('실측 항목을 파싱한다', () {
      final item = CourseHistory.fromJsonOrNull(raw())!;

      expect(item.courseHistoryId, 7);
      expect(item.cnt, 1);
      expect(item.isPlus, isFalse);
      expect(item.type, CourseHistoryType.reservation);
      expect(item.createdAt, DateTime.parse('2026-03-29T14:44:48'));
    });

    test('부호는 `PLUS`만 +다', () {
      expect(
        CourseHistory.fromJsonOrNull(raw(calculation: 'PLUS'))!.isPlus,
        isTrue,
      );
      expect(
        CourseHistory.fromJsonOrNull(raw(calculation: 'MINUS'))!.isPlus,
        isFalse,
      );
      // 웹 `=== 'PLUS' ? '+' : '-'` — 모르는 값도 -다.
      expect(
        CourseHistory.fromJsonOrNull(raw(calculation: '??'))!.isPlus,
        isFalse,
      );
    });

    test('`signedCount`가 웹 표시와 같다', () {
      expect(
        CourseHistory.fromJsonOrNull(
          raw(calculation: 'PLUS', cnt: 10),
        )!.signedCount,
        '+10',
      );
      expect(
        CourseHistory.fromJsonOrNull(
          raw(calculation: 'MINUS', cnt: 1),
        )!.signedCount,
        '-1',
      );
    });

    test('타입 라벨 6개가 웹 `courseHistoryTypes`와 같다', () {
      const expected = <String, String>{
        'COURSE_CREATE': '수강권 생성',
        'PLUS_CNT': '수강권 연장',
        'MINUS_CNT': '수강권 차감',
        'ONE_LESSON': '1회권 지급',
        'RESERVATION': '수업 예약',
        'RESERVATION_CANCEL': '수업 예약 취소',
      };

      for (final entry in expected.entries) {
        final item = CourseHistory.fromJsonOrNull(raw(type: entry.key))!;
        expect(item.typeLabel, entry.value, reason: entry.key);
      }
    });

    test('모르는 타입은 빈 문구다 — 웹 `undefined`와 같은 자리', () {
      final item = CourseHistory.fromJsonOrNull(raw(type: 'WHAT'))!;

      expect(item.type, isNull);
      expect(item.typeLabel, '');
    });

    test('날짜를 못 읽으면 null이다', () {
      expect(
        CourseHistory.fromJsonOrNull(raw(createdAt: 'nope'))!.createdAt,
        isNull,
      );
      expect(
        CourseHistory.fromJsonOrNull(raw(createdAt: null))!.createdAt,
        isNull,
      );
    });

    test('Map이 아니면 null이다', () {
      expect(CourseHistory.fromJsonOrNull('nope'), isNull);
      expect(CourseHistory.fromJsonOrNull(null), isNull);
    });
  });
}
