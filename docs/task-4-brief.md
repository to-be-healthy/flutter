## Task 4: API 요청 패리티 하네스

**Phase 0에서 가장 중요한 태스크다.** 백엔드 계약이 불변이므로 "같은 플로우가 같은 요청을 낸다"는 사람 눈 없이 검증할 수 있다. 이 하네스가 이후 모든 Phase의 동작 검증 기준이 된다.

**Files:**
- Create: `flutter/test/harness/request_capture.dart`
- Create: `flutter/test/harness/parity_matcher.dart`
- Create: `flutter/tool/har_to_golden.py`
- Create: `flutter/test/fixtures/requests/.gitkeep`
- Test: `flutter/test/harness/parity_matcher_test.dart`

**Interfaces:**
- Consumes: 없음 (dio만 의존)
- Produces:
  - `CapturedRequest` — `{String method, String path, Map<String, dynamic> query, Object? body}`
  - `RequestCapture extends Interceptor` — `List<CapturedRequest> get captured`
  - `matchesGolden(String fixtureName)` — `Matcher`. Task 9 및 이후 모든 Phase가 사용

- [ ] **Step 1: 실패하는 매처 테스트 작성**

`test/harness/parity_matcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';

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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
flutter test test/harness/parity_matcher_test.dart
```
Expected: FAIL — `request_capture.dart` / `parity_matcher.dart` 없음

- [ ] **Step 3: 캡처 인터셉터 구현**

`test/harness/request_capture.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 패리티 비교 대상이 되는 요청의 최소 표현.
///
/// Authorization 헤더·타임스탬프·User-Agent는 매 실행 달라지므로
/// 의도적으로 제외한다. 비교 대상은 "어떤 엔드포인트에 무엇을 보내는가"다.
@immutable
class CapturedRequest {
  const CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
  });

  factory CapturedRequest.fromJson(Map<String, dynamic> json) {
    return CapturedRequest(
      method: json['method'] as String,
      path: json['path'] as String,
      query: Map<String, dynamic>.from(json['query'] as Map? ?? {}),
      body: json['body'],
    );
  }

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        'query': query,
        'body': body,
      };
}

/// dio에 끼워 요청을 수집하는 인터셉터. 테스트 전용.
class RequestCapture extends Interceptor {
  final List<CapturedRequest> _captured = [];

  List<CapturedRequest> get captured => List.unmodifiable(_captured);

  void clear() => _captured.clear();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _captured.add(
      CapturedRequest(
        method: options.method.toUpperCase(),
        path: options.path,
        query: Map<String, dynamic>.from(options.queryParameters),
        body: options.data,
      ),
    );
    handler.next(options);
  }
}
```

- [ ] **Step 4: 매처 구현**

`test/harness/parity_matcher.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'request_capture.dart';

/// 값을 대조하지 않고 **키 존재만** 확인하는 필드.
///
/// 골든은 실제 계정으로 캡처한 HAR에서 나오고 테스트는 더미 값을 넣으므로
/// 값까지 비교하면 항상 실패한다. 자격증명·개인정보·매 요청 달라지는
/// 토큰류가 여기 해당한다. `har_to_golden.py`는 이 키들의 값을
/// 마스킹해서 저장하므로 골든 파일에 평문이 남지 않는다.
const Set<String> kMaskedKeys = {
  'password',
  'newPassword',
  'email',
  'phoneNumber',
  'accessToken',
  'refreshToken',
  'id_token',
  'code',
  'state',
};

/// 두 요청의 차이를 사람이 읽을 수 있는 문자열 목록으로 반환한다.
/// 비어 있으면 일치.
///
/// [maskedKeys]에 든 키는 **존재 여부만** 비교하고 값은 비교하지 않는다.
List<String> diffRequests(
  CapturedRequest golden,
  CapturedRequest actual, {
  Set<String> maskedKeys = kMaskedKeys,
}) {
  final diffs = <String>[];

  if (golden.method != actual.method) {
    diffs.add('method: 기대 ${golden.method}, 실제 ${actual.method}');
  }
  if (golden.path != actual.path) {
    diffs.add('path: 기대 ${golden.path}, 실제 ${actual.path}');
  }

  _diffMap('query', golden.query, actual.query, diffs, maskedKeys);

  final goldenBody = golden.body;
  final actualBody = actual.body;
  if (goldenBody is Map && actualBody is Map) {
    _diffMap(
      'body',
      Map<String, dynamic>.from(goldenBody),
      Map<String, dynamic>.from(actualBody),
      diffs,
      maskedKeys,
    );
  } else if (jsonEncode(goldenBody) != jsonEncode(actualBody)) {
    diffs.add('body: 기대 $goldenBody, 실제 $actualBody');
  }

  return diffs;
}

void _diffMap(
  String label,
  Map<String, dynamic> golden,
  Map<String, dynamic> actual,
  List<String> diffs,
  Set<String> maskedKeys,
) {
  for (final key in golden.keys) {
    if (!actual.containsKey(key)) {
      diffs.add('$label.$key: 누락됨');
      continue;
    }
    if (maskedKeys.contains(key)) {
      continue; // 키 존재만 확인하고 값은 대조하지 않는다
    }
    if (jsonEncode(golden[key]) != jsonEncode(actual[key])) {
      diffs.add('$label.$key: 기대 ${golden[key]}, 실제 ${actual[key]}');
    }
  }
  for (final key in actual.keys) {
    if (!golden.containsKey(key)) {
      diffs.add('$label.$key: 예상치 못한 추가 (실제값 ${actual[key]})');
    }
  }
}

/// `test/fixtures/requests/<name>.json` 을 읽어 골든 요청 목록을 반환한다.
List<CapturedRequest> loadGolden(String name) {
  final file = File('test/fixtures/requests/$name.json');
  if (!file.existsSync()) {
    throw StateError(
      '골든 픽스처 없음: ${file.path}\n'
      'tool/har_to_golden.py 로 웹에서 캡처한 HAR을 변환해 생성하라.',
    );
  }
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return decoded
      .map((e) => CapturedRequest.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 캡처된 요청 목록이 골든과 순서까지 일치하는지 검사하고,
/// 다르면 사람이 읽을 수 있는 리포트를 예외로 던진다.
void expectParity(
  String fixtureName,
  List<CapturedRequest> actual, {
  Set<String> maskedKeys = kMaskedKeys,
}) {
  final golden = loadGolden(fixtureName);

  if (golden.length != actual.length) {
    throw ParityFailure(
      '요청 개수 불일치: 기대 ${golden.length}건, 실제 ${actual.length}건\n'
      '기대: ${golden.map((r) => '${r.method} ${r.path}').join(', ')}\n'
      '실제: ${actual.map((r) => '${r.method} ${r.path}').join(', ')}',
    );
  }

  final report = <String>[];
  for (var i = 0; i < golden.length; i++) {
    final diffs = diffRequests(golden[i], actual[i], maskedKeys: maskedKeys);
    if (diffs.isNotEmpty) {
      report.add('[$i] ${golden[i].method} ${golden[i].path}');
      report.addAll(diffs.map((d) => '     $d'));
    }
  }

  if (report.isNotEmpty) {
    throw ParityFailure('API 요청 패리티 불일치:\n${report.join('\n')}');
  }
}

/// `package:flutter_test`의 `TestFailure`와 이름이 겹치지 않도록 분리한다.
class ParityFailure implements Exception {
  ParityFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
```

- [ ] **Step 5: 테스트 통과 확인**

`parity_matcher_test.dart`의 `import 'package:geonganghaejim/core/network/dio_client.dart';` 줄은 아직 Task 6 전이므로 **제거**한다.

```bash
flutter test test/harness/parity_matcher_test.dart
```
Expected: PASS (8 tests)

- [ ] **Step 6: HAR → 골든 변환 스크립트 작성**

웹에서 플로우를 수행하고 Chrome DevTools Network 탭에서 **"Export HAR"** 한 파일을 골든으로 변환한다.

`tool/har_to_golden.py`:

```python
#!/usr/bin/env python3
"""Chrome DevTools HAR → 패리티 골든 픽스처 변환.

사용법:
  python3 tool/har_to_golden.py <input.har> <fixture-name> [--host api.example.com]

api 호출만 남기고 정적 자원·분석 요청은 걸러낸다.
"""
import json
import sys
from urllib.parse import urlparse, parse_qs

SKIP_EXT = ('.js', '.css', '.png', '.jpg', '.svg', '.woff', '.woff2', '.ico')

# parity_matcher.dart 의 kMaskedKeys 와 반드시 동일하게 유지할 것.
# 골든 파일에 실계정 자격증명이 평문으로 커밋되는 것을 막는다.
MASKED_KEYS = {
    'password', 'newPassword', 'email', 'phoneNumber',
    'accessToken', 'refreshToken', 'id_token', 'code', 'state',
}


def mask(value):
    """민감 키의 값을 재귀적으로 마스킹한다."""
    if isinstance(value, dict):
        return {k: '***' if k in MASKED_KEYS else mask(v)
                for k, v in value.items()}
    if isinstance(value, list):
        return [mask(v) for v in value]
    return value


def convert(har_path, api_host=None):
    with open(har_path, encoding='utf-8') as f:
        har = json.load(f)

    out = []
    for entry in har['log']['entries']:
        req = entry['request']
        url = urlparse(req['url'])

        if any(url.path.endswith(ext) for ext in SKIP_EXT):
            continue
        if api_host and url.netloc != api_host:
            continue
        if not api_host and '/api/' not in url.path:
            continue

        body = None
        post = req.get('postData')
        if post and post.get('text'):
            try:
                body = json.loads(post['text'])
            except json.JSONDecodeError:
                body = post['text']

        query = {k: v[0] if len(v) == 1 else v
                 for k, v in parse_qs(url.query).items()}

        out.append({
            'method': req['method'].upper(),
            'path': url.path,
            'query': mask(query),
            'body': mask(body),
        })

    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    har_path, name = sys.argv[1], sys.argv[2]
    api_host = None
    if '--host' in sys.argv:
        api_host = sys.argv[sys.argv.index('--host') + 1]

    result = convert(har_path, api_host)
    dest = f'test/fixtures/requests/{name}.json'
    with open(dest, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f'{dest} 생성: {len(result)}건')
    for r in result:
        print(f"  {r['method']} {r['path']}")


if __name__ == '__main__':
    main()
```

```bash
chmod +x tool/har_to_golden.py
mkdir -p test/fixtures/requests && touch test/fixtures/requests/.gitkeep
```

- [ ] **Step 7: 로그인 플로우 골든 캡처**

**사람이 수행하는 단계다.** 웹앱에서 이메일 로그인을 1회 수행하고 HAR을 내보낸다.

1. 크롬에서 웹앱 로그인 페이지를 연다
2. DevTools → Network 탭 → **Preserve log 체크**
3. 이메일/비밀번호로 로그인 수행
4. Network 탭 우클릭 → **Save all as HAR with content** → `/tmp/login.har`

```bash
python3 tool/har_to_golden.py /tmp/login.har login
cat test/fixtures/requests/login.json
```

Expected: 로그인 POST 요청이 최소 1건 포함된 JSON. `email`·`password` 값이 `"***"`로 마스킹돼 있어야 한다.

```bash
grep -E '"(password|email)"' test/fixtures/requests/login.json
```

Expected: 값이 전부 `"***"`. 평문이 보이면 `MASKED_KEYS`에 키가 빠진 것이므로 스크립트를 고치고 **골든 파일을 지운 뒤 다시 생성한다.** 평문이 담긴 파일을 커밋하지 않는다.

동시에 이 파일이 **`AuthApi.signInPath`의 근거**가 된다 — 여기 찍힌 경로가 웹이 실제로 호출하는 경로다. Task 5·6에서 이 값과 다른 경로를 쓰고 있으면 이쪽이 정답이다.

- [ ] **Step 8: 커밋**

```bash
git add tool/har_to_golden.py test/harness test/fixtures
git commit -m "test(harness): API 요청 패리티 검증 하네스 및 HAR 변환 스크립트 추가"
```

---
