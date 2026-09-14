# Task 5 리포트: 백엔드 OpenAPI 스냅샷 + 로그인 DTO

**Status:** DONE
**Commit:** `d43cab2` feat(auth): 백엔드 OpenAPI 스냅샷 확보 및 로그인 DTO 정의
**Branch:** `feature/flutter-phase0` (변경 없음)

---

## 1. 구현한 것

| 파일 | 내용 |
|------|------|
| `openapi/api-docs.json` | 배포 서버 `https://geonganghaejim.site/v3/api-docs` 스냅샷 (손대지 않은 pretty-print 원본) |
| `lib/entity/auth/model/sign_in_request.dart` | `SignInRequest` — 백엔드 `CommandLoginMember` 대응, `toJson()` |
| `lib/entity/auth/model/sign_in_response.dart` | `SignInResponse` — `ApiResultTokens` envelope를 벗겨 `data(Tokens)` 파싱 |
| `test/entity/auth/sign_in_dto_test.dart` | DTO 6개 테스트 (요청 직렬화 2 / 응답 파싱 3 / 스냅샷 대조 1) |

코드 생성기는 도입하지 않았다(브리프 지시대로 Phase 1에서 재평가).

## 2. 스냅샷 확보 (Step 1)

```
$ curl -sf -m 30 https://geonganghaejim.site/v3/api-docs | python3 -m json.tool > openapi/api-docs.json
$ python3 -c "import json;d=json.load(open('openapi/api-docs.json'));print(len(d['paths']),'paths');print(len(d['components']['schemas']),'schemas')"
108 paths
202 schemas
$ wc -c openapi/api-docs.json
  597188 openapi/api-docs.json
```

- **경로 수: 108** — 브리프 Expected(`108 paths 내외`)와 정확히 일치.
- 스키마 202개, 파일 597KB(14,114줄). Phase 1에서 DTO가 늘면 이 스냅샷이 커밋 diff 노이즈가 될 수 있다(§7 우려사항).
- `openapi: 3.1.0`, `servers: [{"url": "/"}]`, `securitySchemes: [jwtAuth]` — 자격증명·토큰 등 민감값 없음을 확인하고 커밋했다.
- 백엔드는 **로컬에서 띄우지 않았다** (`backend/.env`의 `DB_URL`이 원격 DB(주소는 `backend/.env`의 `DB_URL` 참고)을 가리키는 문제 회피).

## 3. 받은 스펙 vs 브리프 Expected — **완전 일치**

Step 2 스크립트 출력:

```
POST /api/v1/auth/login
  summary: 로그인
  request schema: {'$ref': '#/components/schemas/CommandLoginMember'}
  200 schema: {'$ref': '#/components/schemas/ApiResultTokens'}
```

경로·필드명·타입 모두 브리프 Expected와 다른 점이 **없다.** 브리프 Step 3·4의 코드를 스펙에 맞춰 고칠 필요는 없었다.

스펙이 브리프보다 더 자세히 말해준 것 3가지(계약 해석에 영향을 주므로 기록):

1. **`CommandLoginMember.required`는 `["memberType"]` 하나뿐이다.** 브리프는 `userId`/`password`도 Dart에서 `required`로 뒀다 — 이건 맞다. 근거는 스펙이 아니라 백엔드 소스다:
   `CommandLoginMember.java`의 `userId`/`password`에 `@NotEmpty`가 붙어 있고 `memberType`에 `@NotNull`이 붙어 있다. springdoc은 `@NotNull`만 `required`로 내보내고 `@NotEmpty`는 `minLength: 1`로만 내보내서 생긴 차이다(실제로 스펙에 `minLength: 1`이 찍혀 있다). 즉 셋 다 실질 필수. 이 판단 근거를 `sign_in_request.dart` dartdoc에 적어 뒀다.
2. **`Tokens`에는 `required` 배열이 아예 없다.** 스펙만 보면 "전부 nullable"로 읽히지만 그렇지 않다. `gymId`만 nullable인 근거는 `Tokens.java`의 딱 한 줄이다:
   ```java
   this.gymId = gym != null ? gym.getId() : null;
   ```
   나머지 6개는 생성자에서 항상 채워진다. 스펙 단독으로는 알 수 없는 부분이라 이 줄을 `sign_in_response.dart` dartdoc에 인용해 뒀다.
3. **`Tokens.memberType`은 스펙상 enum(`STUDENT|TRAINER`)이다** — 브리프는 "string"이라고만 적었다. Phase 0에서는 **의도적으로 `String`으로 둔다**(브리프 Produces 계약이 `String memberType`이고, enum 모델링은 아직 소비자가 없다 — YAGNI). 놓친 게 아니라 결정이다. Phase 1에서 `MemberType` enum 도입 시 함께 바꾼다.

부차 확인: `memberId`/`gymId`는 `integer/format: int64` (Java `Long`) → Dart `int`(VM 64-bit)로 대응. 웹 `frontend/src/entity/auth/api/mutations.ts`의 `SignInRequest` 인터페이스가 `{userId, password, memberType, complimentaryLogin?}`로 동일하고, zustand `auth-storage`(`store.ts`)가 보관하는 필드 집합도 `Tokens` 7개와 같다 — 웹과 계약이 어긋나지 않음을 교차 확인했다.

## 4. TDD 증거

### RED 1 — DTO 미존재 (Step 4 Expected: "FAIL — URI 없음")

```
$ flutter test test/entity/auth/sign_in_dto_test.dart
test/entity/auth/sign_in_dto_test.dart:5:8: Error: Error when reading 'lib/entity/auth/model/sign_in_request.dart': No such file or directory
test/entity/auth/sign_in_dto_test.dart:6:8: Error: Error when reading 'lib/entity/auth/model/sign_in_response.dart': No such file or directory
test/entity/auth/sign_in_dto_test.dart:11:19: Error: Method not found: 'SignInRequest'.
test/entity/auth/sign_in_dto_test.dart:52:19: Error: Undefined name 'SignInResponse'.
...
00:00 +0 -1: Some tests failed.
```
이유: 테스트가 참조하는 import URI와 두 클래스가 아직 없어 컴파일 자체가 실패. 브리프가 지정한 형태의 RED다(단언 실패가 아니라 로딩 실패).

### GREEN 1 — DTO 구현 후

```
$ flutter test test/entity/auth/sign_in_dto_test.dart
00:00 +6: All tests passed!
```

### RED 2 — "진단 가능한 오류" 단언 강화 (뮤테이션 검증)

셀프리뷰 기준 "envelope를 벗기는 로직이 `data` 부재 시 **진단 가능한** 오류를 내는가"는 `throwsA(isA<FormatException>())`만으로는 검증되지 않는다(타입만 보고 내용은 안 본다). 그래서 예외 메시지가 서버의 `status`/`message`를 실어 나르는지 단언하도록 바꾸고, 그 단언이 실제로 작동하는지 **프로덕션 코드를 일시 뮤테이션**해서 확인했다.

뮤테이션: `sign_in_response.dart`의 예외 메시지를 진단 정보 없는 상수로 치환
```
'로그인 응답에 data가 없다: ${json['status']} ${json['message']}'  →  '로그인 응답 파싱 실패'
```
```
$ flutter test test/entity/auth/sign_in_dto_test.dart
00:00 +3 -1: SignInResponse data가 없으면 명확한 오류를 낸다 [E]
  Expected: throws <Instance of 'FormatException'> with `message`: (contains '401 UNAUTHORIZED' and contains '아이디 또는 비밀번호가 일치하지 않습니다.')
    Actual: <Closure: () => SignInResponse>
00:00 +5 -1: Some tests failed.
```
→ 단언이 load-bearing임을 확인. **원복은 `git checkout`이 아니라 문자열 역치환으로** 했고(전역 규칙 §3), 뮤테이션 문자열이 파일 내 유일함을 `count == 1` assert로 보장한 뒤 치환했다. 원복 후 `grep`으로 원래 문자열 복귀를 확인했다.

### GREEN 2 — 전체 검증

```
$ ./tool/verify.sh
== dart format ==
== flutter analyze ==
No issues found! (ran in 3.1s)
== har_to_golden.py 테스트 ==
Ran 14 tests in 0.003s
OK
== flutter test ==
00:01 +46: All tests passed!
OK: 모든 검증 통과
```
Dart 46개(기존 40 + 신규 6), Python 14개. 전부 통과.

> 참고: 태스크 컨텍스트에는 verify.sh 순서가 `format → analyze → test → python`으로 적혀 있으나, 실제 `tool/verify.sh`는 **`format → analyze → python unittest → flutter test`** 순이다. 4단계인 것은 동일.

## 5. DTO ↔ 스펙 스키마 대조표

### `CommandLoginMember` ↔ `SignInRequest.toJson()`

| 스펙 속성 | 타입 / 제약 | Dart 필드 | toJson 키 | 비고 |
|---|---|---|---|---|
| `userId` | string, minLength 1 | `String userId` (required) | `'userId'` | `@NotEmpty` → 실질 필수 |
| `password` | string, minLength 1 | `String password` (required) | `'password'` | `@NotEmpty` → 실질 필수 |
| `memberType` | string enum STUDENT\|TRAINER, **required** | `String memberType` (required) | `'memberType'` | Phase 0은 String |
| `complimentaryLogin` | boolean, default false | `bool? complimentaryLogin` | `'complimentaryLogin'` (null이면 **키 자체를 생략**) | 백엔드가 primitive `boolean`이라 미전송 시 false |

스펙에 없는 키를 내보내지 않고, 스펙에 있는 키를 빠뜨리지도 않는다(4/4 대응).

### `ApiResultTokens.data(Tokens)` ↔ `SignInResponse`

| 스펙 속성 | 타입 | Dart 필드 | 대조 |
|---|---|---|---|
| `memberId` | integer(int64) | `int memberId` | OK |
| `name` | string | `String name` | OK |
| `accessToken` | string | `String accessToken` | OK |
| `refreshToken` | string | `String refreshToken` | OK |
| `userId` | string | `String userId` | OK |
| `memberType` | string enum STUDENT\|TRAINER | `String memberType` | OK (enum 미모델링 — 의도) |
| `gymId` | integer(int64) | `int? gymId` | OK (유일한 nullable) |

envelope 3필드 중 `status`/`message`는 DTO 필드로 만들지 않았다 — 로그인 결과에 필요한 건 `data`뿐이고, 두 값은 파싱 실패 시 예외 메시지에만 쓰인다(스펙에 없는 필드를 안 만든다는 YAGNI 기준). `ApiResult<T>` 공통 래퍼 도입은 Phase 1 과제다(§7).

## 6. 셀프 리뷰

diff를 직접 읽고 점검했다(`git diff --cached -- lib test`).

- [x] **요청 키 대응**: 위 표 4/4. 오타·추가 키 없음.
- [x] **응답 필드 대응**: 7/7. 타입 포함(`memberId` int, `gymId` int?).
- [x] **envelope 벗기기**: `data`가 `Map<String, dynamic>`이 아니면 `FormatException`. 테스트가 실제로 태우는 건 **`data` 키 자체가 없는 경로 하나**다. `data: null`도 같은 `is!` 분기에 걸리지만(구조상 그렇다는 것이지 테스트로 확인한 것은 아니다) 코드 경로가 동일해 별도 테스트를 두지 않았다. 예외 메시지에 서버가 준 `status`/`message`가 실려 원인 추적이 가능하며, 이 점을 뮤테이션으로 검증했다(§4 RED 2).
- [x] **선택 필드 null 처리**: `complimentaryLogin` null → JSON 키 생략(테스트 1), `gymId` 부재 → `null`(테스트 1). 둘 다 전용 테스트 있음.
- [x] **타입 안전**: `final data = json['data'];`를 `dynamic`으로 두고 `is!` 가드로 promote한다. 앞에서 `as Map<String, dynamic>`으로 캐스팅했다면 `TypeError`가 나서 진단 가능한 `FormatException`을 못 냈을 것이다. `strict-casts: true` 아래서도 명시적 `as int` 캐스트는 허용되므로 analyze 무경고.
- [x] **YAGNI**: 스펙에 없는 필드 추가 없음. `copyWith`/`==`/`toString`/`fromJson(SignInRequest)` 같이 지금 쓰이지 않는 편의 메서드도 만들지 않았다. 코드 생성기 미도입.
- [x] **파일 분리**: 계획대로 request/response 2개 파일. 각각 35줄·49줄로 계획 의도를 넘지 않는다.
- [x] **테스트 출력 청결도**: 실패·경고·print 없음. `flutter analyze` "No issues found!".
- [x] **스냅샷 무편집**: `curl | python3 -m json.tool` 출력 그대로. 손으로 고친 부분 없음.
- [x] **브랜치**: `feature/flutter-phase0` 유지, 전환 없음.

### 브리프 코드에서 의도적으로 바꾼 3곳 (전부 계약 무관)

1. **테스트 fixture의 `status` 값**: `'success'` → `'200 OK'` / 실패 케이스 `'401 UNAUTHORIZED'`.
   이유는 **fixture 현실성**이다 — 스펙의 `ApiResultTokens.status`는 `"200 OK"`, `"401 UNAUTHORIZED"` 같은 HTTP 상태 문자열 enum이지 `"success"`가 아니다. 계약 재해석이 아니라 가짜 값을 실제 값으로 바꾼 것이며, 어떤 단언도 `status` 값에 의존하지 않는다.
2. **map 리터럴에 명시적 타입 주석**(`<String, dynamic>{...}`): 브리프 원본은 `Map<String, Object>`로 추론되고 `as Map`(raw type)을 쓰는데, 이 레포는 `strict-raw-types: true`다. 동작은 동일, 의미 변화 없음.
3. **`data가 없으면 명확한 오류를 낸다` 단언 강화**: §4 RED 2 참조. 타입만 보던 단언에 메시지 내용 검사를 더했다.

`dart format` 결과 브리프 스니펫의 `=> {` 들여쓰기가 Dart 3.9 tall-style로 재정렬됐다(내용 변화 없음).

## 7. 우려사항 (블로커 아님)

1. **스냅샷 크기 597KB / 14,114줄.** `python3 -m json.tool`이 키 순서·포맷을 안정적으로 내므로 재수집 diff 자체는 실제 백엔드 변경분에 비례한다 — 매번 14k줄이 갈리는 건 아니다. 비용은 레포 무게와 최초 리뷰 노이즈 쪽이다. 갱신 절차를 스크립트(`tool/fetch_openapi.sh`)로 고정하는 정도는 Phase 1에서 검토할 만하지만, 지금 하는 건 과하다고 판단해 넘겼다.
2. **스냅샷 신선도를 강제하는 장치가 없다.** 대조 테스트는 "로그인 경로가 스냅샷에 있는가"만 본다 — 스냅샷이 낡아도 통과한다. 백엔드가 `Tokens`에 필드를 추가/제거해도 Flutter 쪽은 조용히 모른다. Phase 1에서 DTO가 늘면 **스냅샷의 스키마 속성 집합과 Dart 필드 집합을 직접 대조하는 테스트**(또는 생성기)가 필요하다. Phase 0 범위를 넘어 여기서는 하지 않았다.
3. **envelope 처리가 `SignInResponse.fromJson` 안에 하드코딩돼 있다.** 백엔드의 모든 응답이 `ApiResult<T>` 래퍼를 쓰므로, DTO가 늘어나면 이 벗기기 로직을 매 DTO가 중복 구현하게 된다. Phase 1에서 공통 `ApiResult<T>`(또는 dio interceptor에서 한 번에 벗기기)로 올리는 것이 맞다. DTO 1개뿐인 지금 추상화하면 YAGNI 위반이라 하지 않았다.
4. **`memberType`이 String이라 오타가 컴파일 타임에 안 잡힌다**(`'STUDNET'` 등). 스펙에는 enum으로 정의돼 있으니 Phase 1에서 `MemberType` enum + `fromJson` 검증으로 승격할 것을 권한다.
