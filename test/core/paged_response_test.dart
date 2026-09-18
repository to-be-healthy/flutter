import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/json/paged_response.dart';

/// 공용 페이징 봉투. S3(수강권)·S4(포인트) 두 응답에서 **같은 모양을 실측**해
/// 올린 것이라, 그 두 결정을 여기서 못박는다.
void main() {
  group('PagedResponse', () {
    PagedResponse<int> parse(Map<String, dynamic> json) =>
        PagedResponse.fromJson<int>(
          json,
          item: (raw) => raw is int ? raw : null,
        );

    test('와이어 키는 `isLast`다 — `last`가 아니다', () {
      // Java `boolean isLast`의 빈 게터가 `last`로 직렬화되는 함정에
      // 걸리지 않았다(S3·S4 실측 응답 둘 다 `isLast`).
      expect(parse(<String, dynamic>{'isLast': false}).isLast, isFalse);
      expect(parse(<String, dynamic>{'last': false}).isLast, isTrue);
    });

    test('`isLast`가 없으면 true다 — 다음 페이지를 조르지 않는다', () {
      expect(parse(<String, dynamic>{}).isLast, isTrue);
    });

    test('`content`는 빈 배열이든 null이든 빈 목록이다', () {
      expect(parse(<String, dynamic>{'content': <dynamic>[]}).content, isEmpty);
      expect(parse(<String, dynamic>{'content': null}).content, isEmpty);
    });

    test('파싱 못 하는 항목은 버린다', () {
      final page = parse(<String, dynamic>{
        'content': <dynamic>[1, 'nope', 2, null],
      });

      expect(page.content, <int>[1, 2]);
    });

    test('`mainData`는 해석하지 않고 그대로 넘긴다', () {
      // 엔드포인트마다 내용이 달라서(S3는 `{course, gymName}`,
      // S4는 `{searchDate, monthPoint, totalPoint}`) 봉투가 알 필요가 없다.
      final page = parse(<String, dynamic>{
        'mainData': <String, dynamic>{'anything': 1},
      });

      expect(page.mainData, <String, dynamic>{'anything': 1});
    });

    test('응답이 Map이 아니어도 죽지 않는다', () {
      final page = PagedResponse.fromJson<int>(<dynamic>[
        '배열이 왔다',
      ], item: (raw) => raw is int ? raw : null);

      expect(page.content, isEmpty);
      expect(page.isLast, isTrue);
      expect(page.pageNumber, 0);
      expect(page.mainData, isNull);
    });
  });
}
