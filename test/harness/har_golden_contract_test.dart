import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'parity_matcher.dart';

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

    // 골든 파일에 평문 자격증명이 남지 않는다.
    final raw = fixture.readAsStringSync();
    expect(raw, isNot(contains('hunter2')));
    expect(raw, isNot(contains('real@user.com')));

    // 이 골든으로 패리티 검증이 실제로 돌아간다(더미 값으로도 통과).
    expectParity(fixtureName, [golden[0], golden[1]]);
  });
}
