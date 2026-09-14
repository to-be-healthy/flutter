# Task 4 리포트 — API 요청 패리티 하네스

- **Status:** DONE_WITH_CONCERNS — 브리프 Step 1~6은 완결됐으나, **Task 9가 이 하네스를 쓰기 전에 손봐야 할 항목 3건**을 실측으로 확인했다(§7-1·7-2·7-3). 지금 고치지 않은 이유는 셋 다 유효한 선택지가 여럿인 설계 결정이고, 브리프가 코드를 verbatim으로 지정했기 때문이다.
- **커밋:** `242509f` test(harness): API 요청 패리티 검증 하네스 및 HAR 변환 스크립트 추가
- **브랜치:** `feature/flutter-phase0` (변경 없음)
- **수행 범위:** 브리프 Step 1~6. **Step 7(HAR 캡처)·Step 8은 미수행 — 사람 대기.**

---

## 1. 구현한 것

| 파일 | 역할 |
|------|------|
| `test/harness/request_capture.dart` | `CapturedRequest`(method/path/query/body 4필드 + `toJson`/`fromJson`), `RequestCapture extends Interceptor`(dio에 끼워 요청 수집, `captured`는 unmodifiable, `clear()`) |
| `test/harness/parity_matcher.dart` | `kMaskedKeys`(9개), `diffRequests()`, `loadGolden()`, `expectParity()`, `ParityFailure` |
| `test/harness/parity_matcher_test.dart` | 브리프 Step 1의 8개 테스트 (dio_client import 제외) |
| `tool/har_to_golden.py` | Chrome HAR → 골든 픽스처 변환 (실행 권한 `100755`) |
| `test/fixtures/requests/.gitkeep` | 골든 픽스처 디렉터리 (현재 비어 있음) |
| `pubspec.yaml` / `pubspec.lock` | `dio: ^5.11.1` 추가 |

**캡처·비교 분리 준수:** 캡처(`request_capture.dart`)와 비교(`parity_matcher.dart`)를 별도 파일로 뒀고, 비교 쪽만 캡처 쪽을 import한다(단방향). 둘 다 `test/` 아래 — 프로덕션 코드 아님.

### dio 추가 (컨트롤러 ruling)
```
$ flutter pub add dio
+ dio 5.11.1  (+ dio_web_adapter 2.2.2, http_parser, mime, typed_data, web)
```
브리프의 `Interceptor.onRequest(RequestOptions, RequestInterceptorHandler)` 시그니처는 dio 5.11.1과 그대로 호환됐다(아래 §5의 실제 dio 호출 검증으로 확인). `HttpClientAdapter.fetch(RequestOptions, Stream<Uint8List>?, Future<void>?)`도 동일.

### 브리프 대비 의도적 차이
1. `parity_matcher_test.dart`에서 `import 'package:geonganghaejim/core/network/dio_client.dart';` 제외 (컨트롤러 지시 2번 — Task 6 산출물이라 아직 없음). Step 5의 "제거한다"를 애초에 넣지 않는 것으로 대체.
2. 그 외 Dart/Python 코드는 브리프 verbatim. `dart format`이 0 파일 변경(이미 규격 준수), `flutter analyze`(strict-casts/strict-raw-types 포함) 이슈 0건이라 스타일 수정도 불필요했다.
   - 참고: `json['query'] as Map? ?? {}`의 raw `Map?`이 `strict-raw-types`에 걸릴지 의심돼 `Map<dynamic, dynamic>?`로 바꿔봤다가, 실측 결과 raw 형태도 **No issues found**여서 브리프 원문으로 되돌렸다.

---

## 2. TDD 증거

### RED — Step 2
```
$ flutter test test/harness/parity_matcher_test.dart
test/harness/parity_matcher_test.dart:3:8: Error: Error when reading 'test/harness/parity_matcher.dart': No such file or directory
test/harness/parity_matcher_test.dart:4:8: Error: Error when reading 'test/harness/request_capture.dart': No such file or directory
test/harness/parity_matcher_test.dart:9:22: Error: Method not found: 'CapturedRequest'.
test/harness/parity_matcher_test.dart:22:14: Error: Method not found: 'diffRequests'.
...
00:00 +0 -1: Some tests failed.
EXIT=1
```
**실패 이유:** 테스트만 존재하고 `request_capture.dart`/`parity_matcher.dart`가 없어 컴파일 단계에서 깨진다. 즉 "테스트가 아직 없는 동작을 요구하고 있음"이 확인된 정상 RED.

### GREEN — Step 5 (구현 후, 같은 명령)
```
$ flutter test test/harness/parity_matcher_test.dart
00:00 +1: 패리티 매처 동일한 요청은 일치로 판정한다
00:00 +2: 패리티 매처 본문 키가 빠지면 차이를 보고한다
00:00 +3: 패리티 매처 경로가 다르면 차이를 보고한다
00:00 +4: 패리티 매처 본문 키 순서가 달라도 일치로 판정한다
00:00 +5: 패리티 매처 휘발성 헤더는 비교 대상이 아니다
00:00 +6: 패리티 매처 마스킹 키는 값이 달라도 일치로 판정한다
00:00 +7: 패리티 매처 마스킹 키라도 아예 빠지면 차이를 보고한다
00:00 +8: 패리티 매처 마스킹되지 않은 키는 값까지 비교한다
00:00 +8: All tests passed!
```
브리프 기대치(8 tests PASS)와 일치.

### 커밋 전 전체 검증
```
$ ./tool/verify.sh
== dart format ==   Formatted 13 files (0 changed)
== flutter analyze ==  No issues found! (ran in 3.6s)
== flutter test ==  00:01 +21: All tests passed!
OK: 모든 검증 통과
```
기존 13개 + 신규 8개 = **21개 통과**.

---

## 3. `kMaskedKeys`(Dart) ↔ `MASKED_KEYS`(Python) 대조

눈으로만 보지 않고 Dart 소스에서 정규식으로 키를 뽑아 Python 집합과 기계적으로 비교했다.
```
kMaskedKeys (Dart) : ['accessToken', 'code', 'email', 'id_token', 'newPassword', 'password', 'phoneNumber', 'refreshToken', 'state']
MASKED_KEYS (Py)   : ['accessToken', 'code', 'email', 'id_token', 'newPassword', 'password', 'phoneNumber', 'refreshToken', 'state']
Dart 전용: 없음
Py 전용  : 없음
동일 여부: True
```
**결과: 9개 키 완전 일치.** (양쪽 소스에 "반드시 동일하게 유지" 주석이 이미 달려 있다. 자동 동기화 장치는 없다 — §7 우려사항 참고.)

---

## 4. `har_to_golden.py` 검증

### 4-1. 문법
```
$ python3 -m py_compile tool/har_to_golden.py
py_compile: OK
```

### 4-2. `mask()` 중첩 dict/list 동작 (인라인 실행)
입력에 중첩 dict, dict를 담은 list, 평범한 list, `None`, 스칼라를 섞어 넣었다.
```
{
  "email": "***",
  "password": "***",
  "memberType": "STUDENT",
  "nested": { "refreshToken": "***", "keep": 1,
              "deeper": { "phoneNumber": "***", "age": 30 } },
  "items": [ { "accessToken": "***", "id": 7 },
             { "code": "***", "ok": true } ],
  "plainList": [ "a", "b" ],
  "nullField": null
}
mask(None) -> None
mask('scalar') -> 'scalar'
```
2단계 중첩 dict(`nested.deeper.phoneNumber`), list 안의 dict(`items[].accessToken`, `items[].code`) 모두 마스킹되고, 비민감 값(`memberType`, `keep`, `age`, `id`, `ok`)·`None`·스칼라는 보존된다.

### 4-3. 합성 HAR 엔드투엔드 (CLI 실제 실행)
정적 자원(`.js`), 분석 요청(`google-analytics.com`, 경로에 `/api/` 없음), JSON 본문 로그인, 쿼리 있는 GET(중복 키 `tags` 포함), 비-JSON 본문 5건을 담은 합성 HAR로 실행:
```
$ python3 tool/har_to_golden.py <합성>.har __smoke
test/fixtures/requests/__smoke.json 생성: 3건
  POST /api/v1/members/login
  GET /api/v1/members/me
  POST /api/v1/upload
```
- `.js`·analytics 2건 필터링됨, 소문자 `get` → `GET` 정규화됨
- 본문 `email`/`password` → `"***"`, **쿼리스트링의 `code`도 `"***"`** (마스킹이 body뿐 아니라 query에도 적용됨을 확인)
- 중복 쿼리 키 `tags=a&tags=b` → `["a","b"]`, 단일 값은 스칼라
- JSON 파싱 실패 본문은 원문 문자열로 보존(`"not-json-body"`)
- 인자 부족 시 usage 출력 + `exit 1`

**이 합성 골든(`__smoke.json`)과 검증용 스크래치 테스트는 검증 후 삭제했고 커밋에 포함되지 않는다** (`test/fixtures/requests/`는 `.gitkeep`만 든 상태로 커밋).

---

## 5. 셀프 리뷰 — "이 하네스가 실제로 불일치를 잡는가"

8개 테스트 통과는 `diffRequests`가 도는 증거일 뿐이라, 커밋 전 임시 스크래치 테스트(삭제됨)로 **Python 골든 → Dart `loadGolden` → `expectParity`** 전체 경로를 실제로 돌려 확인했다. 이건 Step 7에서 사용자가 처음 밟게 될 경로이므로 미리 밟아본 것이다.

| 확인 항목 | 결과 |
|-----------|------|
| Python이 만든 골든 JSON을 `loadGolden`이 파싱하는가 | **통과** — 3건 로드, `body: null`·문자열 body·list 쿼리값 모두 `CapturedRequest.fromJson`이 처리 |
| 마스킹 키가 값 불일치를 통과시키는가 (의도된 동작) | **통과** — 골든 `"***"` vs 실제 `dummy@test.com`/`dummypw`로 `expectParity` 무예외 |
| 마스킹 키라도 **누락**되면 잡는가 | **잡음** — `body.password: 누락됨` |
| 마스킹되지 않은 키는 값까지 비교하는가 | **잡음** — `body.memberType: 기대 STUDENT, 실제 TRAINER`, `query.page: 기대 0, 실제 1` (쿼리도 값 비교됨) |
| 요청 개수 불일치 | **잡음** — `요청 개수 불일치: 기대 3건, 실제 0건` + 기대/실제 목록 동봉 |
| `expectParity`가 골든 파일이 없을 때 유용한 에러를 내는가 | **유용함** — `Bad state: 골든 픽스처 없음: test/fixtures/requests/does_not_exist.json` + `tool/har_to_golden.py 로 ... 변환해 생성하라.` (경로와 다음 행동이 둘 다 들어있음) |
| `RequestCapture`가 실제 dio 요청을 잡는가 | **잡음** — 스텁 어댑터를 단 `Dio`로 POST/GET 2건 발사 → `captured` 2건, method 대문자화, `queryParameters` 보존, body 보존 |
| `captured` 불변성 / `clear()` | **통과** — `captured.add(...)`는 예외, `clear()` 후 비워짐 |

실제로 출력된 불일치 리포트(사람이 읽는 형태):
```
API 요청 패리티 불일치:
[0] POST /api/v1/members/login
     body.password: 누락됨
     body.memberType: 기대 STUDENT, 실제 TRAINER
[1] GET /api/v1/members/me
     query.page: 기대 0, 실제 1
```

### 무엇이 커밋된 테스트로 보호되고, 무엇이 일회성 확인이었나

**중요 — 통과한 21개를 과신하지 말 것.** 커밋된 테스트 8개는 전부 `diffRequests`만 검증한다.

| 대상 | 보호 수준 |
|------|-----------|
| `diffRequests` (경로·본문·마스킹 8케이스) | **커밋된 회귀 테스트 있음** (`parity_matcher_test.dart`) |
| `RequestCapture` 인터셉터 (실제 dio 요청 수집) | 스크래치로 1회 확인 후 **삭제 — 커밋된 테스트 없음** |
| `loadGolden` / `expectParity` / `ParityFailure` | 스크래치로 1회 확인 후 **삭제 — 커밋된 테스트 없음** |
| Python 골든 → Dart 라운드트립 | 스크래치로 1회 확인 후 **삭제 — 커밋된 테스트 없음** |

브리프가 테스트 8개를 명시했고 골든 픽스처가 아직 없어 YAGNI로 남기지 않았다. Task 9에서 첫 골든이 생기면 `expectParity` 경로는 실사용으로 커버된다. `RequestCapture`는 그때도 간접 커버라, 커밋된 테스트가 필요하면 Task 6/9에서 추가하는 게 자연스럽다.

### 그 밖의 점검
- **완전성:** 브리프 Step 1~6 산출물 5개 파일 전부 생성. Step 7·8은 범위 밖(사람 대기).
- **YAGNI:** 브리프에 없는 헬퍼·추상화·설정 파일을 추가하지 않았다. 검증용 스크래치 테스트도 남기지 않고 지웠다(커밋에는 브리프가 명시한 8개 테스트만).
- **테스트 출력 청결도:** `flutter test` 출력에 `print`·경고·잔여 로그 없음. analyze 0건.
- **비밀값:** 커밋 diff 전체를 `hunter2|real@user|@example.com|authcode`로 스캔 → 브리프가 명시한 더미값(`test@example.com`/`password1234`)만 검출. 실계정 값 없음.
- **실행 권한:** `tool/har_to_golden.py`가 `100755`로 커밋됨(`git ls-files -s` 확인).
- **브랜치:** `feature/flutter-phase0` 유지, 커밋 후 working tree clean.

---

## 6. 변경 파일 (커밋 `242509f`, 7 files / +483)

```
M  pubspec.lock                          (+48)
M  pubspec.yaml                          (+1, dio: ^5.11.1)
A  test/fixtures/requests/.gitkeep        (0)
A  test/harness/parity_matcher.dart      (+141)
A  test/harness/parity_matcher_test.dart (+143)
A  test/harness/request_capture.dart      (+59)
A  tool/har_to_golden.py                  (+91, 실행 권한)
```

---

## 7. 우려사항 / 다음 태스크로 넘길 것

앞의 3건은 **Task 9가 이 하네스를 쓰기 전에 결정이 필요한 항목**이다. 전부 실측으로 확인했고, 브리프 코드가 verbatim 지정이라 이 태스크에서 고치지 않았다.

### 7-1. (최우선) 쿼리 파라미터 타입 불일치 — 숫자 쿼리가 있는 화면은 전부 오탐한다

Python `parse_qs`는 값을 **항상 문자열**로 준다(골든: `"page": "0"`). Flutter에서 `queryParameters: {'page': 0}`처럼 int를 넣으면 `_diffMap`이 `jsonEncode(0)`(`0`)과 `jsonEncode("0")`(`"0"`)을 비교해 불일치로 판정한다. 실측:

```
golden.query = {'page': '0', 'size': '20'}   // HAR 유래
actual.query = {'page': 0,   'size': 20}     // dio 호출
diffRequests → [query.page: 기대 0, 실제 0, query.size: 기대 20, 실제 20]
```

메시지가 `기대 0, 실제 0`으로 찍혀 **읽는 사람이 원인을 알 수 없다.** 페이지네이션(`?page=0&size=20`)은 목록 화면 대부분에 있으므로 가정이 아니라 곧 터질 문제다.

선택지(어느 쪽도 유효해서 임의로 고르지 않았다):
- (a) `_diffMap`에서 **쿼리에 한해** 양쪽을 `toString()`으로 정규화 — HAR이 타입을 잃는다는 사실에 맞추는 방식
- (b) Task 6에서 `queryParameters`에 항상 문자열을 넣도록 규약화
- (c) Python 쪽에서 숫자처럼 보이는 값을 숫자로 복원 — 원래 문자열이었던 값을 망칠 수 있어 비추천

본문(body)은 HAR의 JSON을 그대로 파싱하므로 타입이 보존돼 이 문제가 없다(`int 3` vs `int 3` → 일치 확인).

### 7-2. `options.path` vs HAR `url.path` — Task 6 baseUrl 설계 제약

`RequestCapture`는 dio의 `options.path`(baseUrl 제외 상대 경로)를, 골든은 HAR의 **전체 경로**(`/api/v1/members/login`)를 기록한다. `baseUrl`을 `https://호스트`까지만 두면 일치하지만, `baseUrl`에 `/api/v1` 접두사를 넣으면 `options.path`가 `/members/login`이 되어 **모든 패리티 테스트가 path 불일치로 실패**한다. 경로 접두사는 baseUrl이 아니라 각 API path에 두는 쪽이 이 하네스와 맞는다.

### 7-3. JSON 인코딩 불가 본문(`FormData`)은 비교가 아니라 예외로 죽는다

`diffRequests`는 본문 비교에 `jsonEncode`를 쓴다. 멀티파트 업로드(프로필 이미지·운동 사진)의 `FormData`는 인코딩 불가라 **불일치 보고 대신 예외가 튄다.** 실측:

```
diffRequests(..., body: Object())
→ JsonUnsupportedObjectError: Converting object to an encodable object failed
```

파일 업로드 화면을 검증할 때가 되면 `FormData`를 `{필드명: 값}` 형태로 정규화하거나, 인코딩 실패를 붙잡아 "비교 불가" diff로 보고하는 처리가 필요하다.

### 7-4. Step 7이 사용자 대기 상태다

웹앱 로그인 HAR 캡처 → `python3 tool/har_to_golden.py /tmp/login.har login` → `test/fixtures/requests/login.json` 생성 + `grep -E '"(password|email)"'`로 평문 없음 확인까지가 사람의 몫이다. 지금 픽스처 디렉터리는 `.gitkeep`만 있고, 골든이 생기기 전까지 `expectParity`를 쓰는 곳은 없다(`loadGolden`이 안내 메시지와 함께 StateError를 던진다).

### 7-5. 마스킹 키 집합이 두 언어에 수동 복제돼 있다

지금은 완전 일치하지만, 한쪽에만 키를 추가하면 골든에 평문이 남거나(Python 누락) 비교가 과하게 엄격해진다(Dart 누락). 현재는 양쪽 주석으로만 방어 중이다. 필요해지면 Dart 상수를 파싱해 대조하는 검사를 `verify.sh`에 넣는 것을 검토할 수 있다(지금은 YAGNI로 보류).

### 7-6. `diffRequests`는 요청 순서를 순번 그대로 비교한다

병렬로 나가는 요청이 섞이면(화면 진입 시 동시 GET 여러 건) 순서 차이만으로 실패할 수 있다. 로그인 플로우(순차)엔 문제없지만, 병렬 요청이 있는 화면을 검증할 땐 순서 무관 비교 옵션이 필요해질 수 있다. 골든 실물을 보기 전이라 추측이 되므로 지금 넣지 않았다.

---

# Fix 라운드 1 (커밋 `ca1f8c3`)

컨트롤러 지시 3건을 수정했다. 수정 범위는 지목된 지점으로 한정했고 하네스 구조는 그대로다.
**우려 #2(baseUrl 접두사)는 컨트롤러가 계획의 Global Constraints로 해결했으므로 코드를 건드리지 않았다.**

## 1. 쿼리 값 타입 불일치 → query 비교에만 타입 정규화

`_diffMap`에 `required bool coerceScalarTypes`를 추가하고 **query 호출부만 `true`**, body 호출부는 `false`로 뒀다. 동작은 지시대로 "`jsonEncode`가 다르면 `toString()`으로 한 번 더 확인해 같으면 일치":

```dart
if (goldenEncoded == actualEncoded) {
  continue;
}
if (coerceScalarTypes && '${golden[key]}' == '${actual[key]}') {
  continue; // 타입만 다르고 표기가 같다 (예: 골든 '0' vs 실제 0)
}
diffs.add('$label.$key: 기대 ${golden[key]}, 실제 ${actual[key]}');
```

비대칭이 의도임은 `diffRequests` 문서 주석에 남겼다("이 비대칭은 의도된 것이다. 한쪽에 맞춰 통일하지 말 것."). 호출부에도 `coerceScalarTypes: true, // HAR 쿼리는 타입이 소실된다` / `coerceScalarTypes: false, // 본문은 타입까지 비교한다`로 이유를 적었다.

## 2. 직렬화 불가 본문 → 예외 대신 진단 가능한 차이

`jsonEncode`를 `_tryEncode()`(실패 시 `null`)로 감싸고, 한쪽이라도 인코딩 불가면 `_unsupportedTypeDiff()` 메시지를 차이로 보고한다. 예외가 호출부로 새어나가지 않으므로 `expectParity`의 `ParityFailure` 리포트에 다른 차이들과 함께 실린다. FormData 비교는 **구현하지 않았다** — 미지원임이 메시지에서 읽히게만 했다.

실제 출력 메시지:
```
body: 패리티 비교 미지원 타입 (기대 String, 실제 _NotEncodable) — JSON 직렬화가
불가능한 본문은 아직 비교할 수 없다. FormData(파일 업로드) 지원은 Phase 7에서 필요하다.
```
본문 맵 **안쪽 값**이 직렬화 불가인 경우도 같은 경로로 처리된다(`body.file: 패리티 비교 미지원 타입 ...`).

## 3. 커밋된 회귀 테스트 보강 (하네스 8 → 19)

지웠던 스크래치 검증을 전부 테스트로 남겼다.

| 파일 | 추가 테스트 |
|------|-------------|
| `test/harness/request_capture_test.dart` (신규) | ① `Dio` + stub adapter로 POST/GET 2건 발사 → `captured`에 method·path·query·body가 담긴다 ② `captured`는 수정 불가(`throwsUnsupportedError`)이고 `clear()`로 비워진다 |
| `test/harness/parity_matcher_test.dart` | ③ 문자열 쿼리 vs int 쿼리 일치 ④ 타입 같고 값 다르면 여전히 불일치 ⑤ **본문**에는 정규화 미적용 ⑥ 직렬화 불가 본문이 미지원 메시지로 보고됨 ⑦ 본문 안쪽 값이 직렬화 불가여도 예외 없음 ⑧ 골든 부재 시 경로+해결법 담은 `StateError` ⑨ 요청 개수 불일치 ⑩ 골든 일치 시 통과(마스킹 값·쿼리 타입 차이 포함) ⑪ 불일치 시 순번·엔드포인트 붙은 리포트 |

`expectParity` 테스트는 `test/fixtures/requests/__expect_parity_tmp.json`을 만들어 쓰고 `tearDown`에서 지운다. 실행 후 디렉터리에 `.gitkeep`만 남는 것을 확인했다.

## 실행 명령과 출력

### RED — 수정 전, 새 테스트만 추가한 상태
```
$ flutter test test/harness/
00:00 +10 -1: 쿼리 값 타입 정규화 HAR의 문자열 쿼리와 dio의 숫자 쿼리를 같게 본다 [E]
  Expected: empty
    Actual: ['query.page: 기대 0, 실제 0', 'query.size: 기대 20, 실제 20']
00:00 +12 -2: JSON 직렬화 불가 본문 예외 대신 미지원임을 알리는 차이로 보고한다 [E]
  Converting object to an encodable object failed: Instance of '_NotEncodable'
00:00 +12 -3: JSON 직렬화 불가 본문 본문 안의 값이 직렬화 불가여도 예외를 던지지 않는다 [E]
  Converting object to an encodable object failed: Instance of '_NotEncodable'
00:00 +14 -4: expectParity 골든과 일치하면 통과한다 (마스킹 값·쿼리 타입 차이 포함) [E]
00:00 +15 -4: Some tests failed.
```
**실패 4건이 정확히 고쳐야 할 지점이다.** 오탐 메시지 `기대 0, 실제 0`이 그대로 재현됐고, 미지원 본문은 예외로 터졌다. 나머지 신규 테스트(RequestCapture 2건, 골든 부재, 개수 불일치, 불일치 리포트, 본문 타입 엄격성)는 기존 동작을 고정하는 특성화 테스트라 수정 전에도 통과했다.

### GREEN — 수정 후, 같은 명령
```
$ flutter test test/harness/
00:00 +19: All tests passed!
```

### 커밋 전 전체 검증
```
$ ./tool/verify.sh
== dart format ==   Formatted 14 files (0 changed)
== flutter analyze ==  No issues found! (ran in 4.7s)
== flutter test ==  00:01 +32: All tests passed!
OK: 모든 검증 통과
```
전체 **32개 통과** (이전 21개 + 신규 11개).

## 변경 파일 (커밋 `ca1f8c3`, 3 files / +375 −7)

```
M  test/harness/parity_matcher.dart       (_tryEncode·_unsupportedTypeDiff 추가, _diffMap에 coerceScalarTypes)
M  test/harness/parity_matcher_test.dart  (+9 테스트)
A  test/harness/request_capture_test.dart (+2 테스트)
```

## 남은 사항

- **Step 7(HAR 캡처)은 여전히 사용자 대기다.** 건드리지 않았고 `test/fixtures/requests/`는 `.gitkeep`만 있다.
- §7-5(마스킹 키 이중 관리), §7-6(요청 순서 비교)은 지시 범위 밖이라 그대로 둔다.
- 타입 정규화의 이론적 한계 한 가지: `toString()` 비교이므로 골든이 리스트 `['a','b']`이고 실제가 문자열 `"[a, b]"`인 경우도 같게 본다. 쿼리 파라미터에서 실제로 나올 조합은 아니라고 판단해 그대로 뒀다(지시받은 `toString()` 방식의 고유한 성질).

---

# Fix 라운드 2 (커밋 `8e0ce13`)

리뷰 지적 Important 5건 + Minor 3건을 전부 수정했다. deferred 지정 항목(#7 CWD 상대 경로, #9 form-urlencoded, #10 argparse, #11 CORS preflight, #13 `==`/`@immutable`)은 건드리지 않았다.

**브리프 내부 모순 기록(다음부터 리포트에 적으라는 지시 반영):** 브리프 Interfaces 줄은 `matchesGolden(String) → Matcher`를 산출물로 적었지만 Step 4 코드에는 그런 Matcher가 없고 `expectParity(String, List<CapturedRequest>)`만 있다. Task 9 소비 방식도 `expectParity`다. 코드를 verbatim으로 구현했으므로 산출물은 `expectParity`이며, 컨트롤러가 계획의 stale 줄을 교체했다(코드 변경 없음).

## 항목별 수정

### Important 1 — `_diffMap` 재귀화

`_diffMap`이 중첩 `Map` 값을 만나면 경로 라벨(`body.member.email`)을 합성해 같은 규칙으로 재귀한다. `jsonEncode` 대조는 새로 뺀 `_diffLeaf()`(리프 전용)로 옮겼다. 결과로 ① 중첩된 마스킹 키가 실제로 동작하고 ② 중첩 맵이 키 순서에 흔들리지 않는다.

덮는 테스트 4개(`중첩 맵` 그룹): 중첩 마스킹 키 통과 / 중첩 키 순서 무관 / 중첩 누락이 `body.member.email: 누락됨` / 중첩 값 불일치가 `body.member.memberType: ...`.

**남은 구멍(의도적 미수정):** 리스트 **안쪽** 맵은 여전히 리프로 `jsonEncode` 비교된다(`{"items":[{"email":"***"}]}`). Python `mask()`는 리스트 안까지 마스킹하므로 같은 종류의 불일치가 남아 있다. 지시가 "중첩 Map 값에 대해 재귀"로 한정돼 범위를 넘지 않았다 — 리스트 응답 본문을 보내는 화면이 나오면 그때 `_diffList`가 필요하다.

### Important 2 — `har_to_golden.py` 회귀 테스트 + 계약 테스트

- `tool/har_to_golden_test.py`(stdlib `unittest`, 14 테스트): `mask()` 4종(최상위/중첩 dict/list 안 dict/스칼라·None), `convert()` 7종(정적·비api·호스트 필터, 메서드 대문자화, 본문·쿼리 마스킹, 중복 쿼리키, 빈 쿼리값, 비-JSON 본문, 본문 없음), 빈 결과 2종, drift 가드 1종.
- `test/harness/har_golden_contract_test.dart`(신규): Dart 테스트가 **실제로 `python3 tool/har_to_golden.py`를 실행**해 골든을 만들고 `loadGolden`으로 읽어 필드·마스킹·`expectParity` 동작까지 확인한다. 골든 원문에 `hunter2`·`real@user.com`이 없는지도 본다.
- `tool/verify.sh`에 단계 추가:
  ```bash
  echo "== har_to_golden.py 테스트 =="
  python3 -m unittest discover -s tool -p '*_test.py'
  ```
  지시의 `discover tool`은 기본 패턴이 `test*.py`라 지시된 파일명(`har_to_golden_test.py`)을 못 잡는다. `-s tool -p '*_test.py'`로 맞췄다.

**계약 테스트가 실제로 무는지 뮤테이션으로 확인했다.** `har_to_golden.py`의 `'path': url.path,` → `'pathx':`로 바꾸고 돌리니 실패, 되돌리니 통과. 원복은 문자열 역치환으로 했고 `shasum`으로 뮤테이션 전 파일과 동일함을 확인했다(`git checkout` 미사용).

### Important 3 — 마스킹 키 drift 가드 커밋

`MaskedKeyDriftTest`가 `test/harness/parity_matcher.dart`에서 `kMaskedKeys` 블록을 정규식으로 뽑아 Python `MASKED_KEYS`와 집합 비교한다. 경로는 `__file__` 기준으로 잡아 CWD에 의존하지 않는다. 정규식이 아무것도 못 잡는 vacuous pass를 막으려고 "선언을 찾았는가 / 비어 있지 않은가"도 함께 단언한다.

### Important 4 — 불일치 메시지에 인코딩·타입

`_diffLeaf`가 이미 계산한 인코딩 결과와 `runtimeType`을 메시지에 싣는다.
```
이전: body.count: 기대 0, 실제 0
이후: body.count: 기대 "0"(String), 실제 0(int)
```
그리고 `hasLength(1)`만 보던 단언들을 메시지 내용까지 보도록 보강했다: 본문 타입 엄격성(`body.count`·`"0"`·`String`·`int`), 경로 불일치(`path:`·`/api/v1/members/signin`), 마스킹되지 않은 키(`body.memberType`·`STUDENT`·`TRAINER`), 쿼리 값 불일치(`query.page`).

### Important 5 — 빈 골든의 공허한 통과 차단

- `convert()`가 `(항목들, 통계)`를 반환한다. 통계는 `total`/`skipped_ext`/`skipped_host`/`skipped_non_api`/`kept`.
- 결과가 비면 파일을 쓰지 않고 stderr에 어느 필터가 전부 걸렀는지 찍은 뒤 `exit 1`.
- `expectParity`는 로드한 골든이 비어 있으면 `ParityFailure`("골든이 비어 있다 … 요청 0건짜리 골든은 어떤 플로우든 통과시키므로 검증이 되지 않는다").

### Minor 6 — "예상치 못한 추가"도 마스킹

`final shown = maskedKeys.contains(key) ? '***' : actual[key];`. 테스트에서 실토큰 문자열(`eyJhbGciOiJIUzI1NiJ9…`)이 출력에 없고 `***`가 있는지 확인한다.

### Minor 7 — `keep_blank_values=True`

`?keyword=`가 `{'keyword': ''}`로 남는다(`test_빈_쿼리값을_보존한다`).

### Minor 8 — 에러 메시지에서 단계 번호 제거

`FormData 등 JSON 직렬화가 불가능한 본문은 아직 지원하지 않는다.` 테스트도 `contains('Phase 7')` → `contains('FormData')` + `isNot(contains('Phase'))`로 바꿨다.

## 실행 명령과 출력

### RED (1) — Dart 쪽, 수정 전
```
$ flutter test test/harness/parity_matcher_test.dart
00:00 +10 -1: 본문에는 타입 정규화를 적용하지 않는다 [E]
  Expected: contains '"0"'    Actual: 'body.count: 기대 0, 실제 0'
00:00 +10 -2: 예외 대신 미지원임을 알리는 차이로 보고한다 [E]
  Expected: not contains 'Phase'
00:00 +11 -3: 중첩된 마스킹 키는 값이 달라도 일치로 판정한다 [E]        Expected: empty
00:00 +11 -4: 중첩 맵의 키 순서가 달라도 일치로 판정한다 [E]
  Actual: ['body.member: 기대 {a: 1, b: 2}, 실제 {b: 2, a: 1}']
00:00 +11 -5: 중첩 키 누락을 경로 라벨과 함께 보고한다 [E]
  Expected: contains 'body.member.email'
00:00 +11 -6: 중첩 값 불일치를 경로 라벨과 함께 보고한다 [E]
  Expected: contains 'body.member.memberType'
00:00 +11 -7: 마스킹 키의 실제 값은 출력하지 않는다 [E]
  Actual: 'body.accessToken: 예상치 못한 추가 (실제값 eyJhbGciOiJIUzI1NiJ9.real-token)'
00:00 +15 -8: 골든이 비어 있으면 공허한 통과 대신 실패한다 [E]
  Expected: <Instance of 'ParityFailure'>    Actual: <null>
00:00 +16 -8: Some tests failed.
```
실패 8건이 지시 #1·#4·#5·#6·#8과 1:1로 대응한다. 특히 평문 토큰 노출과 "빈 골든이 조용히 통과(`Actual: <null>`)"가 그대로 재현됐다.

### GREEN (1) — 구현 후
```
$ flutter test test/harness/
00:00 +26: All tests passed!
```

### RED (2) — Python 쪽, 수정 전
```
$ python3 -m unittest discover -s tool -p '*_test.py'
ValueError: not enough values to unpack (expected 2, got 1)   (convert 관련 7건)
FAIL: test_전부_걸러지면_비영_종료하고_원인을_말한다
AssertionError: 0 != 1
Ran 14 tests — FAILED (failures=1, errors=7)
```
`mask()` 4종과 drift 가드는 기존 동작이 이미 옳아 처음부터 통과했다(특성화 테스트).

### GREEN (2) — 구현 후
```
$ python3 -m unittest discover -s tool -p '*_test.py'
Ran 14 tests in 0.004s
OK
```

### 계약 테스트 뮤테이션 검증
```
$ # har_to_golden.py: 'path': url.path, → 'pathx': url.path,
$ flutter test test/harness/har_golden_contract_test.dart
00:00 +0 -1: har_to_golden.py 가 만든 골든을 loadGolden 이 그대로 읽는다 [E]
00:00 +0 -1: Some tests failed.
$ # 문자열 역치환으로 원복
복원 확인: OK — 뮤테이션 전과 동일 (shasum 일치)
```

### 커밋 전 전체 검증
```
$ ./tool/verify.sh
== dart format ==              Formatted 15 files (0 changed)
== flutter analyze ==          No issues found! (ran in 3.2s)
== har_to_golden.py 테스트 ==  Ran 14 tests in 0.004s  OK
== flutter test ==             00:01 +40: All tests passed!
OK: 모든 검증 통과
```
Dart **40개** + Python **14개** 통과 (라운드 1 종료 시점 Dart 32개 → 하네스 테스트 8개 추가).

## 변경 파일 (커밋 `8e0ce13`, 6 files / +592 −30)

```
M  test/harness/parity_matcher.dart          (_diffLeaf 분리·재귀·빈 골든·마스킹·메시지)
M  test/harness/parity_matcher_test.dart     (+7 테스트, 기존 단언 4곳 보강)
A  test/harness/har_golden_contract_test.dart (+1 계약 테스트)
M  tool/har_to_golden.py                     (통계 반환·빈 결과 비영 종료·keep_blank_values)
A  tool/har_to_golden_test.py                (+14 테스트, drift 가드 포함)
M  tool/verify.sh                            (python unittest 단계)
```

## 남은 사항

- **Step 7(HAR 캡처)은 여전히 사용자 대기다.** 건드리지 않았다. `test/fixtures/requests/`는 `.gitkeep`만 있고, 라운드 2 이후에도 임시 픽스처가 남지 않는 것을 확인했다.
- 위에 적은 **리스트 안쪽 맵 비교**(`_diffList` 부재)가 같은 결함 계열로 남아 있다.
- `verify.sh`가 이제 `python3`를 요구한다. CI에 python3가 없으면 새 단계에서 멈춘다.
