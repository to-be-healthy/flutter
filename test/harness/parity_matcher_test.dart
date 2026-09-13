import 'package:flutter_test/flutter_test.dart';

import 'parity_matcher.dart';
import 'request_capture.dart';

void main() {
  group('패리티 매처', () {
    test('동일한 요청은 일치로 판정한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: {'email': 'a@b.com', 'password': 'pw'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: {'email': 'a@b.com', 'password': 'pw'},
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('본문 키가 빠지면 차이를 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: {'email': 'a@b.com', 'password': 'pw'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: {'email': 'a@b.com'},
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('password'));
    });

    test('경로가 다르면 차이를 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: null,
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/signin',
        query: {},
        body: null,
      );

      expect(diffRequests(golden, actual), hasLength(1));
    });

    test('본문 키 순서가 달라도 일치로 판정한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'a': 1, 'b': 2},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'b': 2, 'a': 1},
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('휘발성 헤더는 비교 대상이 아니다', () {
      // Authorization·타임스탬프는 매 실행 달라지므로 캡처에 포함하지 않는다.
      const r = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {},
        body: null,
      );
      expect(r.toJson().containsKey('headers'), isFalse);
    });

    test('마스킹 키는 값이 달라도 일치로 판정한다', () {
      // 골든은 실제 계정 HAR에서, 테스트는 더미 값에서 온다.
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: {'email': '***', 'password': '***'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/login',
        query: {},
        body: {'email': 'test@example.com', 'password': 'password1234'},
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('마스킹 키라도 아예 빠지면 차이를 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'email': '***', 'password': '***'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'email': 'test@example.com'},
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('password'));
    });

    test('마스킹되지 않은 키는 값까지 비교한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'memberType': 'STUDENT'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'memberType': 'TRAINER'},
      );

      expect(diffRequests(golden, actual), hasLength(1));
    });
  });
}
