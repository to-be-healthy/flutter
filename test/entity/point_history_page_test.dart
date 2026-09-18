import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/point/model/point_history.dart';
import 'package:geonganghaejim/entity/point/model/point_history_page.dart';

/// 규율 #16 — 픽스처는 2026-09-18 브라우저 실측에서 왔다
/// (`docs/trainer-manage-s4-measurements.md` 산출물 ②).
void main() {
  group('PointHistoryPage', () {
    test('실측 응답(내역 0건)을 파싱한다', () {
      final page = PointHistoryPage.fromJson(<String, dynamic>{
        'content': <dynamic>[],
        'pageNumber': 0,
        'pageSize': 20,
        'totalPages': 0,
        'totalElements': 0,
        'isLast': true,
        'mainData': <String, dynamic>{
          'searchDate': '2026-09',
          'monthPoint': 0,
          'totalPoint': 85,
        },
      });

      expect(page.content, isEmpty);
      expect(page.isLast, isTrue);
      expect(page.point?.searchDate, '2026-09');
      expect(page.point?.monthPoint, 0);
      expect(page.point?.totalPoint, 85);
    });

    test('`mainData`가 없으면 point가 null이다', () {
      final page = PointHistoryPage.fromJson(<String, dynamic>{});

      expect(page.point, isNull);
      expect(page.content, isEmpty);
      expect(page.isLast, isTrue);
    });

    test('`mainData`가 학생 홈의 StudentPoint와 같은 모양이다', () {
      // BUG-3(`webMonthLabel`)이 그대로 재사용되는 근거다.
      final page = PointHistoryPage.fromJson(<String, dynamic>{
        'mainData': <String, dynamic>{
          'searchDate': '2026-12',
          'monthPoint': 3,
          'totalPoint': 88,
        },
      });

      // 웹 버그: `'12'`의 두 번째 글자라 `2`다.
      expect(page.point?.webMonthLabel, '2');
    });
  });

  group('PointHistory', () {
    Map<String, dynamic> raw({
      String type = 'DIET',
      String calculation = 'PLUS',
      int point = 5,
      Object? createdAt = '2026-04-11T14:47:52',
    }) => <String, dynamic>{
      'pointId': 12,
      'type': type,
      'calculation': calculation,
      'point': point,
      'createdAt': createdAt,
    };

    test('실측 항목을 파싱한다', () {
      final item = PointHistory.fromJsonOrNull(raw())!;

      expect(item.pointId, 12);
      expect(item.point, 5);
      expect(item.isPlus, isTrue);
      expect(item.type, PointHistoryType.diet);
      expect(item.createdAt, DateTime.parse('2026-04-11T14:47:52'));
    });

    test('타입 라벨 4개가 웹 `pointHistoryTypes`와 같다', () {
      const expected = <String, String>{
        'NO_SHOW': '노쇼',
        'NO_SHOW_CANCEL': '노쇼취소',
        'WORKOUT': '개인운동',
        'DIET': '식단등록',
      };

      for (final entry in expected.entries) {
        final item = PointHistory.fromJsonOrNull(raw(type: entry.key))!;
        expect(item.typeLabel, entry.value, reason: entry.key);
      }
    });

    test('모르는 타입은 빈 문구다', () {
      final item = PointHistory.fromJsonOrNull(raw(type: 'WHAT'))!;

      expect(item.type, isNull);
      expect(item.typeLabel, '');
    });

    test('부호는 `PLUS`만 +다', () {
      expect(
        PointHistory.fromJsonOrNull(raw(calculation: 'PLUS'))!.signedPoint,
        '+5',
      );
      expect(
        PointHistory.fromJsonOrNull(raw(calculation: 'MINUS'))!.signedPoint,
        '-5',
      );
      // 웹 `=== 'PLUS' ? '+' : '-'` — 모르는 값도 -다.
      expect(
        PointHistory.fromJsonOrNull(raw(calculation: '??'))!.signedPoint,
        '-5',
      );
    });

    test('날짜를 못 읽으면 null이다', () {
      expect(
        PointHistory.fromJsonOrNull(raw(createdAt: 'nope'))!.createdAt,
        isNull,
      );
    });

    test('Map이 아니면 null이다', () {
      expect(PointHistory.fromJsonOrNull('nope'), isNull);
    });
  });
}
