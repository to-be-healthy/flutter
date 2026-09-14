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

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('path:'));
      expect(diffs.single, contains('/api/v1/members/signin'));
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

    test('헤더는 allowlist만 골든에 실린다', () {
      // 휘발성 헤더(User-Agent·타임스탬프)는 버리지만 allowlist는 남긴다 —
      // 헤더를 통째로 버리면 Authorization을 안 붙이는 화면이 올바른 화면과
      // 구별되지 않는다.
      const r = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {},
        body: null,
        headers: {'authorization': '***'},
      );
      expect(r.toJson()['headers'], {'authorization': '***'});
    });

    test('골든에 있는 Authorization이 실제에 없으면 차이를 보고한다', () {
      // A1의 핵심: 토큰을 아예 안 붙이는 화면이 통과해서는 안 된다.
      const golden = CapturedRequest(
        method: 'GET',
        path: '/api/v1/members/me',
        query: {},
        body: null,
        headers: {'authorization': '***'},
      );
      const actual = CapturedRequest(
        method: 'GET',
        path: '/api/v1/members/me',
        query: {},
        body: null,
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('headers.authorization'));
      expect(diffs.single, contains('누락됨'));
    });

    test('Authorization은 값이 달라도 존재하면 일치로 판정한다', () {
      const golden = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {},
        body: null,
        headers: {'authorization': '***'},
      );
      const actual = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {},
        body: null,
        headers: {'authorization': 'Bearer real-token'},
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('content-type은 값까지 비교한다', () {
      // 백엔드 스펙은 application/json;charset=UTF-8, dio는 application/json.
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: null,
        headers: {'content-type': 'application/json;charset=UTF-8'},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: null,
        headers: {'content-type': 'application/json'},
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('headers.content-type'));
      expect(diffs.single, contains('charset=UTF-8'));
    });

    test('예상치 못한 Authorization의 실제 토큰은 출력하지 않는다', () {
      const golden = CapturedRequest(
        method: 'GET',
        path: '/api/v1/auth/login',
        query: {},
        body: null,
      );
      const actual = CapturedRequest(
        method: 'GET',
        path: '/api/v1/auth/login',
        query: {},
        body: null,
        headers: {'authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.real'},
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('headers.authorization'));
      expect(diffs.single, contains('***'));
      expect(diffs.single, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('골든의 헤더 키 대소문자를 소문자로 정규화한다', () {
      // HAR은 `Content-Type`, dio는 `content-type`을 쓴다.
      final golden = CapturedRequest.fromJson({
        'method': 'POST',
        'path': '/x',
        'query': <String, dynamic>{},
        'headers': {'Content-Type': 'application/json'},
        'body': null,
      });

      expect(golden.headers, {'content-type': 'application/json'});
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

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.memberType'));
      expect(diffs.single, contains('STUDENT'));
      expect(diffs.single, contains('TRAINER'));
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

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('query.page'));
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

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      // '기대 0, 실제 0'처럼 보이면 진짜 타입 버그를 읽어낼 수 없다.
      expect(diffs.single, contains('body.count'));
      expect(diffs.single, contains('"0"'));
      expect(diffs.single, contains('String'));
      expect(diffs.single, contains('int'));
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
      expect(diffs.single, contains('FormData'));
      expect(diffs.single, isNot(contains('Phase')));
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

  group('중첩 맵', () {
    test('중첩된 마스킹 키는 값이 달라도 일치로 판정한다', () {
      // har_to_golden.py 의 mask()는 중첩까지 재귀 마스킹한다.
      // 비교도 같은 깊이까지 가지 않으면 골든이 영원히 불일치한다.
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members',
        query: {},
        body: {
          'member': {'email': '***', 'memberType': 'STUDENT'},
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members',
        query: {},
        body: {
          'member': {'email': 'test@example.com', 'memberType': 'STUDENT'},
        },
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('중첩 맵의 키 순서가 달라도 일치로 판정한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'member': {'a': 1, 'b': 2},
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'member': {'b': 2, 'a': 1},
        },
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('중첩 키 누락을 경로 라벨과 함께 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'member': {'email': '***', 'memberType': 'STUDENT'},
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'member': {'memberType': 'STUDENT'},
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.member.email'));
      expect(diffs.single, contains('누락됨'));
    });

    test('중첩 값 불일치를 경로 라벨과 함께 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'member': {'memberType': 'STUDENT'},
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'member': {'memberType': 'TRAINER'},
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.member.memberType'));
      expect(diffs.single, contains('TRAINER'));
    });
  });

  group('경로 id 자리표시자', () {
    CapturedRequest req(String path) =>
        CapturedRequest(method: 'GET', path: path, query: const {}, body: null);

    test('{id} 자리표시자는 숫자 세그먼트와 일치한다', () {
      // 골든은 HAR을 뜬 계정의 id를 담는다. 자리표시자가 없으면 모든 화면
      // 테스트가 그 계정의 id를 하드코딩해야 하고 다른 계정으로 다시 뜰 수 없다.
      final diffs = diffRequests(
        req('/api/v1/members/$kPathIdPlaceholder/memo'),
        req('/api/v1/members/17/memo'),
      );

      expect(diffs, isEmpty);
    });

    test('자리표시자 여러 개도 각각 숫자와 일치한다', () {
      final diffs = diffRequests(
        req('/api/v1/schedule/$kPathIdPlaceholder/$kPathIdPlaceholder'),
        req('/api/v1/schedule/40/7'),
      );

      expect(diffs, isEmpty);
    });

    test('{id} 자리에 숫자가 아닌 세그먼트가 오면 차이를 보고한다', () {
      // `/members/{id}` 대신 `/members/me`를 치는 것은 진짜 버그다.
      // 자리표시자가 "아무 값이나"를 뜻하면 이걸 놓친다 — 값이 아니라
      // **형태**만 맞춘다.
      final diffs = diffRequests(
        req('/api/v1/members/$kPathIdPlaceholder/memo'),
        req('/api/v1/members/me/memo'),
      );

      expect(diffs, hasLength(1));
      expect(diffs.single, contains('path:'));
      expect(diffs.single, contains('me'));
    });

    test('열거형 세그먼트는 자리표시자가 아니라 값까지 비교한다', () {
      // OpenAPI 실측: 경로 파라미터 64개 중 60개가 integer(int64)이고
      // 나머지 4개(status·type·notificationCategory)는 문자열 열거형이다.
      // 숫자만 치환하는 규칙이라 열거형은 리터럴로 남아 값이 대조된다.
      final diffs = diffRequests(
        req('/api/v1/schedule/trainer/COMPLETED'),
        req('/api/v1/schedule/trainer/RESERVED'),
      );

      expect(diffs, hasLength(1));
      expect(diffs.single, contains('RESERVED'));
    });

    test('세그먼트 개수가 다르면 차이를 보고한다', () {
      final diffs = diffRequests(
        req('/api/v1/members/$kPathIdPlaceholder/memo'),
        req('/api/v1/members/17'),
      );

      expect(diffs, hasLength(1));
      expect(diffs.single, contains('path:'));
    });

    test('자리표시자가 없으면 리터럴 비교 그대로다', () {
      expect(
        diffRequests(req('/api/v1/auth/login'), req('/api/v1/auth/login')),
        isEmpty,
      );
      expect(
        diffRequests(req('/api/v1/auth/login'), req('/api/v1/auth/signin')),
        hasLength(1),
      );
    });

    test('숫자 세그먼트를 리터럴로 담은 골든은 다른 숫자와 일치하지 않는다', () {
      // --path-template 없이 뜬 골든은 예전처럼 그 계정의 id에 묶인다.
      // 자리표시자 치환이 생성기 쪽 opt-in임을 비교기 쪽에서 고정한다.
      final diffs = diffRequests(
        req('/api/v1/members/17/memo'),
        req('/api/v1/members/18/memo'),
      );

      expect(diffs, hasLength(1));
    });
  });

  group('리스트 재귀', () {
    test('리스트 안 맵의 마스킹 키는 값이 달라도 일치로 판정한다', () {
      // Python mask()는 리스트 안까지 재귀 마스킹한다. 비교가 리스트를
      // 리프로 보고 jsonEncode로 대조하면 '***' vs 실제값으로 **보장된**
      // 오탐이 난다 — 그 오탐의 자연스러운 반응이 마스크를 넓히거나 단언을
      // 지우는 것이라, 이 하네스가 절대 겪으면 안 되는 침식이다.
      const golden = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/invite',
        query: {},
        body: {
          'members': [
            {'email': '***', 'memberType': 'STUDENT'},
            {'email': '***', 'memberType': 'TRAINER'},
          ],
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/api/v1/members/invite',
        query: {},
        body: {
          'members': [
            {'email': 'a@b.com', 'memberType': 'STUDENT'},
            {'email': 'c@d.com', 'memberType': 'TRAINER'},
          ],
        },
      );

      expect(diffRequests(golden, actual), isEmpty);
    });

    test('리스트 인덱스를 라벨 경로에 넣어 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'items': [
            {'memberType': 'STUDENT'},
            {'memberType': 'STUDENT'},
          ],
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'items': [
            {'memberType': 'STUDENT'},
            {'memberType': 'TRAINER'},
          ],
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.items[1].memberType'));
      expect(diffs.single, contains('TRAINER'));
    });

    test('리스트 안 맵의 키 누락도 인덱스와 함께 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'items': [
            {'email': '***', 'memberType': 'STUDENT'},
          ],
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'items': [
            {'memberType': 'STUDENT'},
          ],
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.items[0].email'));
      expect(diffs.single, contains('누락됨'));
    });

    test('길이가 다르면 길이 불일치로 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'items': [1, 2],
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'items': [1, 2, 3],
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.items'));
      expect(diffs.single, contains('기대 2'));
      expect(diffs.single, contains('실제 3'));
    });

    test('중첩 리스트도 인덱스를 이어 붙여 보고한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'grid': [
            [
              {'slot': 'A'},
            ],
          ],
        },
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {
          'grid': [
            [
              {'slot': 'B'},
            ],
          ],
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.grid[0][0].slot'));
    });

    test('본문 자체가 리스트여도 재귀한다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: [
          {'email': '***', 'memberType': 'STUDENT'},
        ],
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: [
          {'email': 'a@b.com', 'memberType': 'TRAINER'},
        ],
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body[0].memberType'));
    });

    test('중복 쿼리 키 리스트에도 타입 정규화가 적용된다', () {
      // parse_qs는 `?t=1&t=2`를 ['1','2']로, dio는 [1, 2]로 보낸다.
      const golden = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {
          't': ['1', '2'],
        },
        body: null,
      );
      const actual = CapturedRequest(
        method: 'GET',
        path: '/x',
        query: {
          't': [1, 2],
        },
        body: null,
      );

      expect(diffRequests(golden, actual), isEmpty);
    });
  });

  group('예상치 못한 추가', () {
    test('마스킹 키의 실제 값은 출력하지 않는다', () {
      // 실패 출력은 CI 로그에 남는다. 실토큰이 평문으로 찍히면 안 된다.
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
        body: {
          'memberType': 'STUDENT',
          'accessToken': 'eyJhbGciOiJIUzI1NiJ9.real-token',
        },
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('body.accessToken'));
      expect(diffs.single, contains('***'));
      expect(diffs.single, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('마스킹되지 않은 키는 값을 그대로 보여준다', () {
      const golden = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: <String, dynamic>{},
      );
      const actual = CapturedRequest(
        method: 'POST',
        path: '/x',
        query: {},
        body: {'memberType': 'STUDENT'},
      );

      final diffs = diffRequests(golden, actual);
      expect(diffs, hasLength(1));
      expect(diffs.single, contains('STUDENT'));
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

    test('headers 키가 없는 옛 형식 골든은 거부한다', () {
      // headers를 비교하지 않던 시절의 골든을 그대로 읽으면 인증 헤더 검증이
      // **조용히** 빠진다(없는 키는 비교되지 않으므로). A1이 막으려던 구멍이
      // 기본값을 통해 되돌아오는 경로라, 형식 자체를 거부한다.
      writeFixture([
        {
          'method': 'POST',
          'path': '/api/v1/auth/login',
          'query': <String, dynamic>{},
          'body': {'userId': '***'},
        },
      ]);

      Object? caught;
      try {
        expectParity(_tmpFixture, const []);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<StateError>());
      expect(caught.toString(), contains('headers'));
      expect(caught.toString(), contains('har_to_golden.py'));
    });

    test('요청 개수가 다르면 기대·실제 목록을 담아 실패한다', () {
      writeFixture([
        {
          'method': 'POST',
          'path': '/api/v1/members/login',
          'query': <String, dynamic>{},
          'headers': {'content-type': 'application/json'},
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
          'headers': {'content-type': 'application/json'},
          'body': {'email': '***', 'password': '***', 'memberType': 'STUDENT'},
        },
        {
          'method': 'GET',
          'path': '/api/v1/workouts',
          'query': {'page': '0'},
          'headers': <String, dynamic>{},
          'body': null,
        },
      ]);

      expectParity(_tmpFixture, const [
        CapturedRequest(
          method: 'POST',
          path: '/api/v1/members/login',
          query: {},
          headers: {'content-type': 'application/json'},
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

    test('골든이 비어 있으면 공허한 통과 대신 실패한다', () {
      // --host 오타 등으로 전부 걸러진 골든은 어떤 플로우든 통과시킨다.
      writeFixture([]);

      Object? caught;
      try {
        expectParity(_tmpFixture, const []);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ParityFailure>());
      expect(caught.toString(), contains('비어'));
    });

    test('골든과 다르면 순번·엔드포인트가 붙은 리포트로 실패한다', () {
      writeFixture([
        {
          'method': 'POST',
          'path': '/api/v1/members/login',
          'query': <String, dynamic>{},
          'headers': {'content-type': 'application/json'},
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
