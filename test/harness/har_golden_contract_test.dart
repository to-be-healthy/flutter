import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'parity_matcher.dart';
import 'request_capture.dart';

/// 생산자(`tool/har_to_golden.py`)와 소비자(`loadGolden`)의 계약 테스트.
///
/// 둘 중 하나가 필드 이름이나 모양을 바꾸면 62개 화면의 패리티 검증이 한 번에
/// 무너진다. 파이썬이 만든 파일을 Dart가 실제로 읽어보는 것만이 이걸 잡는다.
void main() {
  const fixtureName = '__har_contract_tmp';
  final fixture = File('test/fixtures/requests/$fixtureName.json');

  tearDown(() {
    if (fixture.existsSync()) {
      fixture.deleteSync();
    }
  });

  test('har_to_golden.py 가 만든 골든을 loadGolden 이 그대로 읽는다', () {
    final harDir = Directory.systemTemp.createTempSync('har_contract');
    addTearDown(() => harDir.deleteSync(recursive: true));

    final har = File('${harDir.path}/sample.har')
      ..writeAsStringSync(
        jsonEncode({
          'log': {
            'entries': [
              {
                'request': {
                  'method': 'post',
                  'url': 'https://api.example.com/api/v1/members/login',
                  'headers': [
                    {'name': 'Content-Type', 'value': 'application/json'},
                    {'name': 'User-Agent', 'value': 'Mozilla/5.0'},
                  ],
                  'postData': {
                    'mimeType': 'application/json',
                    'text': jsonEncode({
                      'email': 'real@user.com',
                      'password': 'hunter2',
                      'memberType': 'STUDENT',
                    }),
                  },
                },
              },
              {
                'request': {
                  'method': 'GET',
                  'url': 'https://api.example.com/api/v1/workouts?page=0',
                  'headers': [
                    {'name': 'authorization', 'value': 'Bearer real-token'},
                  ],
                },
              },
            ],
          },
        }),
      );

    final result = Process.runSync('python3', [
      'tool/har_to_golden.py',
      har.path,
      fixtureName,
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'har_to_golden.py 실패: ${result.stdout}\n${result.stderr}',
    );

    final golden = loadGolden(fixtureName);

    expect(golden, hasLength(2));
    expect(golden[0].method, 'POST');
    expect(golden[0].path, '/api/v1/members/login');
    expect(golden[0].query, isEmpty);
    expect(golden[0].body, {
      'email': '***',
      'password': '***',
      'memberType': 'STUDENT',
    });
    expect(golden[1].method, 'GET');
    expect(golden[1].query, {'page': '0'});
    expect(golden[1].body, isNull);

    // 헤더: allowlist만 소문자 키로 남고 authorization은 마스킹된다.
    expect(golden[0].headers, {'content-type': 'application/json'});
    expect(golden[1].headers, {'authorization': '***'});

    // 골든 파일에 평문 자격증명이 남지 않는다.
    final raw = fixture.readAsStringSync();
    expect(raw, isNot(contains('hunter2')));
    expect(raw, isNot(contains('real@user.com')));
    expect(raw, isNot(contains('real-token')));
    expect(raw, isNot(contains('Mozilla')));

    // 이 골든으로 패리티 검증이 실제로 돌아간다(더미 값으로도 통과).
    expectParity(fixtureName, [golden[0], golden[1]]);
  });

  test('--path-template 이 만든 자리표시자를 비교기가 같은 규칙으로 읽는다', () {
    // 생성기와 비교기가 자리표시자 규칙에 합의하지 않으면 62개 화면이
    // 한꺼번에 실패하거나(리터럴 대조) 비교가 헐거워진다. 파이썬이 만든
    // 파일을 Dart가 실제로 대조해보는 것만이 이걸 잡는다.
    final harDir = Directory.systemTemp.createTempSync('har_template');
    addTearDown(() => harDir.deleteSync(recursive: true));

    final har = File('${harDir.path}/sample.har')
      ..writeAsStringSync(
        jsonEncode({
          'log': {
            'entries': [
              {
                'request': {
                  'method': 'GET',
                  'url': 'https://api.example.com/api/v1/members/17/memo',
                },
              },
              {
                'request': {
                  'method': 'GET',
                  'url':
                      'https://api.example.com/api/v1/schedule/trainer/'
                      'COMPLETED',
                },
              },
            ],
          },
        }),
      );

    final result = Process.runSync('python3', [
      'tool/har_to_golden.py',
      har.path,
      fixtureName,
      '--path-template',
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'har_to_golden.py 실패: ${result.stdout}\n${result.stderr}',
    );

    final golden = loadGolden(fixtureName);
    expect(golden[0].path, '/api/v1/members/$kPathIdPlaceholder/memo');
    // 문자열 열거형은 치환되지 않는다 — 값까지 대조돼야 하는 세그먼트다.
    expect(golden[1].path, '/api/v1/schedule/trainer/COMPLETED');

    // **다른 계정의 id**로도 통과한다. 이것이 자리표시자를 넣은 이유다.
    expectParity(fixtureName, const [
      CapturedRequest(
        method: 'GET',
        path: '/api/v1/members/9999/memo',
        query: {},
        body: null,
      ),
      CapturedRequest(
        method: 'GET',
        path: '/api/v1/schedule/trainer/COMPLETED',
        query: {},
        body: null,
      ),
    ]);
  });
}
