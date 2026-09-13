import 'dart:convert';
import 'dart:io';

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

  group('쿼리 값 타입 정규화', () {
    test('HAR의 문자열 쿼리와 dio의 숫자 쿼리를 같게 본다', () {
      // 골든은 parse_qs 결과라 항상 문자열, dio는 int를 보낼 수 있다.
      const golden = CapturedRequest(
        method: 'GET',
        path: '/api/v1/workouts',
        query: {'page': '0', 'size': '20'},
        body: null,
      );
      const actual = CapturedRequest(
        method: 'GET',
        path: '/api/v1/workouts',
        query: {'page': 0, 'size': 20},
        body: null,
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('타입이 같아도 값이 다르면 여전히 차이를 보고한다', () {
      const golden = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {'page': '0'},
        body: null,
      );
      const actual = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {'page': 1},
        body: null,
      );

      expect(diffRequests(golden, actual), hasLength(1));
    });

    test('본문에는 타입 정규화를 적용하지 않는다', () {
      // 본문은 JSON이라 타입이 보존된다. "0"과 0을 같게 보면 타입 버그를 놓친다.
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'count': '0'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'count': 0},
      );

      expect(diffRequests(golden, actual), hasLength(1));
    });
  });

  group('JSON 직렬화 불가 본문', () {
    test('예외 대신 미지원임을 알리는 차이로 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/upload',
        query: {},
        body: 'multipart',
      );
      final actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/upload',
        query: const {},
        body: _NotEncodable(),
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('미지원'));
      expect(diffs.single, contains('_NotEncodable'));
      expect(diffs.single, contains('Phase 7'));
    });

    test('본문 안의 값이 직렬화 불가여도 예외를 던지지 않는다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'file': 'x'},
      );
      final actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: const {},
        body: {'file': _NotEncodable()},
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.file'));
      expect(diffs.single, contains('미지원'));
    });
  });

  group('expectParity', () {
    final fixture = File('test/fixtures/requests/$_tmpFixture.json');

    tearDown(() {
      if (fixture.existsSync()) {
        fixture.deleteSync();
      }
    });

    void writeFixture(List<Map<String, dynamic>> golden) {
      fixture.parent.createSync(recursive: true);
      fixture.writeAsStringSync(jsonEncode(golden));
    }

    test('골든 파일이 없으면 경로와 해결 방법이 담긴 StateError를 던진다', () {
      Object? caught;
      try {
        expectParity('__does_not_exist__', const []);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<StateError>());
      expect(
        caught.toString(),
        contains('test/fixtures/requests/__does_not_exist__.json'),
      );
      expect(caught.toString(), contains('har_to_golden.py'));
    });

    test('요청 개수가 다르면 기대·실제 목록을 담아 실패한다', () {
      writeFixture([
        {
          'method': 'POST',
          'path': '/api/v1/members/login',
          'query': <String, dynamic>{},
          'body': {'email': '***'},
        },
      ]);

      Object? caught;
      try {
        expectParity(_tmpFixture, const []);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ParityFailure>());
      expect(caught.toString(), contains('기대 1건, 실제 0건'));
      expect(caught.toString(), contains('POST /api/v1/members/login'));
    });

    test('골든과 일치하면 통과한다 (마스킹 값·쿼리 타입 차이 포함)', () {
      writeFixture([
        {
          'method': 'POST',
          'path': '/api/v1/members/login',
          'query': <String, dynamic>{},
          'body': {'email': '***', 'password': '***', 'memberType': 'STUDENT'},
        },
        {
          'method': 'GET',
          'path': '/api/v1/workouts',
          'query': {'page': '0'},
          'body': null,
        },
      ]);

      expectParity(_tmpFixture, const [
        CapturedRequest(
          method: 'POST',
          path: '/api/v1/members/login',
          query: {},
          body: {
            'email': 'test@example.com',
            'password': 'password1234',
            'memberType': 'STUDENT',
          },
        ),
        CapturedRequest(
          method: 'GET',
          path: '/api/v1/workouts',
          query: {'page': 0},
          body: null,
        ),
      ]);
    });

    test('골든과 다르면 순번·엔드포인트가 붙은 리포트로 실패한다', () {
      writeFixture([
        {
          'method': 'POST',
          'path': '/api/v1/members/login',
          'query': <String, dynamic>{},
          'body': {'email': '***', 'password': '***'},
        },
      ]);

      Object? caught;
      try {
        expectParity(_tmpFixture, const [
          CapturedRequest(
            method: 'POST',
            path: '/api/v1/members/login',
            query: {},
            body: {'email': 'test@example.com'},
          ),
        ]);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ParityFailure>());
      expect(caught.toString(), contains('[0] POST /api/v1/members/login'));
      expect(caught.toString(), contains('body.password: 누락됨'));
    });
  });
}

/// 임시 골든 픽스처 이름. 실제 골든(`login` 등)과 겹치지 않게 둔다.
const String _tmpFixture = '__expect_parity_tmp';

/// `jsonEncode`가 처리할 수 없는 본문 대역(실제로는 `FormData`).
class _NotEncodable {
  @override
  String toString() => '_NotEncodable';
}
