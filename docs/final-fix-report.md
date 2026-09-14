# Phase 0 최종 리뷰 fix wave — 실행 보고

**브랜치:** `feature/flutter-phase0` (변경 없음)
**BASE:** `ae5d4d2` → **HEAD:** `7b59c17` (커밋 6개)
**검증:** `./tool/verify.sh` 4/4 통과 — Dart **132 통과 + 2 skip**, Python **30 통과**
(시작 시점: Dart 93 + 2 skip, Python 14)

| 커밋 | 내용 |
|---|---|
| `bc3278b` | fix(harness): 골든 픽스처 형식 동결 — 헤더 allowlist·리스트 재귀·경로 자리표시자 (A1~A4) |
| `057aea9` | fix(verify,widget): 린트 게이트 복구와 참조 위젯 동결 3건 (B1·C1·C3·C4) |
| `4491f79` | fix(ui): 웹 고정 높이(버튼 44·입력 50)를 맞추고 글꼴 배율 상한을 정한다 (C2+D1) |
| `268502b` | fix(android): Auto Backup을 끈다 (D2) |
| `13dc6d9` | fix(harness): 패리티 자체 검증 테스트가 무엇이 실패했는지까지 단언한다 (A1 후속) |
| `7b59c17` | fix(network): 본문 없는 GET에 content-type을 붙이지 않는다 (우려 #1 — 컨트롤러 결정 후 추가 지시) |

C2와 D1을 한 커밋으로 묶은 것은 지시(`D1: C2와 같은 커밋에서 결정하라`)를 따른 것이다 —
"고정 높이"와 "무제한 OS 배율"은 동시에 참일 수 없어 같이 결정해야 한다.

---

## A군 — 픽스처 형식·비교 의미론 (HAR 캡처 전)

### A1. 헤더 allowlist

**변경**
- `test/harness/request_capture.dart`: `kCapturedHeaders = {content-type, authorization}`,
  `kPresenceOnlyHeaders = {authorization}`, `CapturedRequest.headers`,
  `pickCapturedHeaders()`가 **캡처 시점에** allowlist만 소문자 키로 남긴다.
  캡처 시점에 거르는 이유는 걸러지지 않은 레코드가 로그·실패 리포트에 찍히면
  실토큰이 CI 로그로 새기 때문이다.
- `test/harness/parity_matcher.dart`: `diffRequests`가 `headers`를 비교한다.
  `content-type`은 값까지, `authorization`은 존재만(`kMaskedKeys`와 같은 규칙,
  실패 출력에서도 `***`로 마스킹).
- `tool/har_to_golden.py`: `pick_headers()`가 HAR 헤더에서 같은 allowlist를
  뽑고 `authorization` 값을 `***`로 마스킹해 골든에 넣는다.
- **drift 가드**: `HeaderKeyDriftTest`가 `request_capture.dart`를 정규식으로 읽어
  Python 집합과 대조한다(기존 `MaskedKeyDriftTest`와 같은 패턴).

**추가 가드(지시 밖, 자문 결과 반영):** `loadGolden`이 `headers` 키 없는 옛 형식
골든을 `StateError`로 거부한다. 없는 키는 비교되지 않으므로, 옛 골든을 그대로
읽으면 A1이 막으려던 구멍(Authorization 미부착 화면이 조용히 통과)이 기본값을
통해 그대로 돌아온다. 이 가드가 없으면 A1은 권고 사항에 그친다.

**TDD 증거**
```
$ flutter test test/harness/request_capture_test.dart     # RED
test/harness/request_capture_test.dart:58:38: Error: The getter 'headers' isn't
defined for the type 'CapturedRequest'.
...
$ flutter test test/harness/request_capture_test.dart     # GREEN
00:00 +6: All tests passed!
```
```
$ flutter test test/harness/parity_matcher_test.dart      # RED (헤더 비교 3건)
00:00 +26 -3: Some tests failed.
$ flutter test test/harness/parity_matcher_test.dart      # GREEN
00:00 +29: All tests passed!
```
loadGolden 가드 RED — **A1이 실제로 무는 장면**:
```
00:00 +39 -1: expectParity headers 키가 없는 옛 형식 골든은 거부한다 [E]
  Expected: <Instance of 'StateError'>   Actual: ParityFailure:<요청 개수 불일치…>
00:00 +40 -2: expectParity 골든과 일치하면 통과한다 [E]
  API 요청 패리티 불일치:
  [0] POST /api/v1/members/login
       headers.content-type: 누락됨
```

### A2. `_diffMap`의 리스트 재귀

`_diffList()`를 추가해 맵·리스트를 같은 규칙으로 재귀한다. 라벨은
`body.items[0].email` / `body.grid[0][0].slot` 형태. 길이가 다르면 원소 비교로
내려가지 않고 길이 한 줄만 보고한다(인덱스가 밀려 전 원소가 차이로 찍히는 것을
막는다). 최상위 `body`가 리스트인 경우도 처리한다.

```
$ flutter test test/harness/parity_matcher_test.dart      # RED
00:00 +30 -6: Some tests failed.
$ flutter test test/harness/parity_matcher_test.dart      # GREEN
00:00 +36: All tests passed!
```

### A3. 경로 리소스 id 자리표시자 — **설계 결정**

**규칙:** 골든의 `{id}` 세그먼트는 실제 세그먼트가 `^\d+$`일 때만 일치한다.
생성기(`--path-template`)와 비교기가 같은 상수·같은 패턴을 쓰고 drift 테스트로 묶었다.

**결정 1 — 자리표시자는 "아무 값이나"가 아니라 "숫자 형태"다.**
지시가 "값이 아니라 **형태**만 맞추게 하라"였다. 아무 값이나 통과시키면
`/members/{id}` 자리에 `/members/me`를 치는 진짜 버그가 통과한다. 테스트로 고정.

**결정 2 — 숫자 세그먼트만 치환한다. 근거는 백엔드 실측이다.**
`openapi/api-docs.json`을 직접 집계했다:

| 경로 파라미터 타입 | 개수 | 이름 |
|---|---|---|
| `integer / int64` | **60** | memberId, scheduleId, lessonHistoryId, dietId, workoutHistoryId, commentId, courseId, exerciseId, gymId, notificationId, studentId, trainerId, lessonHistoryCommentId |
| `string` | **4** | status, type, notificationCategory |

문자열 4개는 전부 **열거형**이라 값까지 대조돼야 한다
(`/api/v1/schedule/trainer/COMPLETED` vs `RESERVED`는 진짜 차이다).
숫자 전용 규칙이 id와 열거형을 정확히 갈라놓는다 — 이 실측이 없었으면
"경로 파라미터를 전부 치환"이라는 더 단순하고 더 틀린 규칙을 골랐을 것이다.
`v1`·`me`처럼 숫자가 섞이거나 아닌 세그먼트도 그대로 남는다.

**결정 3 — 생성기 쪽은 opt-in(`--path-template`), 다만 침묵하지 않는다.**
항상 치환하면 id가 아닌 숫자 세그먼트(`/version/2` 류)까지 잘못 치환된다.
대신 숫자 세그먼트가 있는데 플래그를 안 줬으면 stderr로 경고한다 — 침묵하면
골든이 캡처 계정의 id에 묶인 채 커밋되고 62개 화면이 그 id를 하드코딩하게 된다.
비교기 쪽은 opt-in이 아니다(자리표시자 없는 골든은 리터럴 대조 그대로).

**대안과 기각 사유**
- OpenAPI 경로 템플릿으로 매칭: 스펙 파일에 하네스를 묶게 되고, 스펙에 없는
  엔드포인트를 캡처하면 동작하지 않는다.
- UUID/해시까지 포괄하는 넓은 패턴: 이 백엔드엔 그런 경로 파라미터가 없다
  (실측 64개 전부 int64 또는 열거형). 쓰지 않는 일반성이다.

```
$ flutter test test/harness/parity_matcher_test.dart      # RED
test/harness/parity_matcher_test.dart:465:31: Error: Undefined name 'kPathIdPlaceholder'.
$ flutter test test/harness/parity_matcher_test.dart      # GREEN
00:00 +43: All tests passed!
```

### A4. `--host`와 `/api/` 필터를 AND로

`tool/har_to_golden.py`의 `if not api_host and '/api/' not in url.path`를 두 개의
독립 조건으로 분리했다. Global Constraint상 웹앱과 API가 같은 오리진이라
현실적 호출은 `--host geonganghaejim.site`인데, OR이면 Next.js 문서·RSC·
`_next/data` 요청이 전부 "골든 API 요청"으로 들어왔다.

```
$ python3 -m unittest discover -s tool -p '*_test.py'      # RED
FAIL: test_같은_오리진의_next_문서_요청을_걸러낸다
- ['/sign-in', '/_next/data/abc/home.json', '/api/v1/members/me']
+ ['/api/v1/members/me']
FAILED (failures=1, errors=14)
$ python3 -m unittest discover -s tool -p '*_test.py'      # GREEN
Ran 30 tests in 0.005s — OK
```

### 생산자↔소비자 계약 테스트 확장

`har_golden_contract_test.dart`가 파이썬이 만든 파일을 Dart가 실제로 읽어
① 헤더 라운드트립(allowlist만, 소문자, authorization 마스킹, `Mozilla`·
`real-token` 평문 부재) ② `--path-template` 라운드트립(`{id}` 생성 →
**다른 계정 id `9999`로도 패리티 통과**, 열거형은 리터럴 유지)를 확인한다.

---

## B군 — 검증 게이트

### B1. `--no-fatal-infos` 삭제

`tool/verify.sh`에서 플래그를 제거하고 이유를 주석으로 남겼다.

**이 플래그가 실제로 린트를 무력화하고 있었다는 증거(뮤테이션):**
`lib/main.dart`에 `print('MUTATION');` 한 줄을 넣고 두 게이트를 비교했다.
```
--- 새 게이트(flutter analyze) ---
exit=1
   info • Don't invoke 'print' in production code … • lib/main.dart:13:3 • avoid_print
--- 옛 게이트(--no-fatal-infos) ---
exit=0
```
원복 후 `git diff --quiet lib/main.dart` → CLEAN.

**비용 0 확인:** 제거 직후 `flutter analyze` → `No issues found! (ran in 0.6s)`.

**즉시 효과:** 같은 커밋에서 내가 새로 쓴 테스트의
`SemanticsNode.hasFlag` deprecation(`deprecated_member_use`)을 이 게이트가
바로 잡아냈고, `matchesSemantics`로 교체했다. 플래그가 있었다면 통과했을 것이다.

---

## C군 — 참조 위젯 동결

### C1. `AppTextInput`의 그림자 `border:` 삭제

`enabledBorder`가 항상 이기므로 도달 불가한 죽은 분기였다. 기존 테스트가 두
에러 상태를 덮지만 **죽은 필드를 되돌려도 아무 테스트도 깨지지 않았으므로**,
부재 자체를 단언하는 테스트를 추가했다(두 에러 상태 모두에서
`decoration.border`가 `isNull`).

코드와 테스트에 부작용을 함께 기록했다: `border:`가 없으므로 향후
`enabled: false`를 붙이면 `disabledBorder`가 Material 기본
`UnderlineInputBorder`로 떨어진다 — 비활성 입력을 추가할 때 명시해야 한다.

```
$ flutter test test/shared/ui/app_text_input_test.dart     # RED
Expected: null   Actual: OutlineInputBorder:<OutlineInputBorder()>
$ flutter test test/shared/ui/app_text_input_test.dart     # GREEN
00:01 +6: All tests passed!
```

### C2. 고정 높이 — 버튼 44 / 입력 50

- `AppButton.height = 44` (웹 `SignInForm.tsx:100` `h-[44px]`),
  `Container`가 `padding` 대신 `height`를 쓴다.
- `AppTextInput.height = 50` (웹 `:58,81` `containerClassName='h-[50px]'`),
  `SizedBox(height:)` + `textAlignVertical: center`, 세로 `contentPadding` 제거.
- 두 위젯의 `TextStyle`에 `leadingDistribution: TextLeadingDistribution.even`.
- 두 상수 모두 `AppLayoutHeader.height`(56)와 같은 형식의 예외 주석을 달았다
  (44·50 둘 다 `AppSpacing.standard` 12단 밖이고, 웹도 같은 이유로 임의값 문법을 썼다).

**`leadingDistribution`을 전역(`AppTypography` 16종)에 적용하지 않은 이유:**
지시가 "**해당** TextStyle에"였고, 전역 적용은 앱 전체 텍스트의 베이스라인을
1~2px 옮기는 변경이라 시각 확인 없이 넣을 일이 아니다. Phase 1 후보로 남긴다.

**RED 증거**
```
test/shared/ui/app_text_input_test.dart:37:22: Error: Member not found: 'height'.
test/shared/ui/app_button_test.dart:53:19: Error: Member not found: 'height'.
$ flutter test test/shared/ui/                              # GREEN
00:01 +23: All tests passed!
```
렌더 높이는 공통 위젯 테스트뿐 아니라 `app_test.dart`가 **실제 앱 트리
(GeonganghaejimApp → SignInPage)** 안에서도 단언한다.

### C3. `AppButton` 시맨틱

`Semantics(button: true, enabled: isEnabled, label: label, onTap: …,
excludeSemantics: true)`.

지시는 세 줄이었지만 **두 줄을 더 넣어야 했다.** `excludeSemantics` 없이는
자식 `Text`가 같은 라벨의 노드를 하나 더 만들고, `excludeSemantics`만 넣으면
`GestureDetector`가 만들던 tap 액션까지 사라져 **스크린리더로는 누를 수 없는
버튼**이 된다. 그래서 `onTap`을 Semantics에서 직접 노출한다. 코드 주석에 이
이유를 남겼다.

단언은 `matchesSemantics(label, isButton, hasEnabledState, isEnabled,
hasTapAction)`. 활성/비활성/로딩 3개 상태를 덮는다.
(`isFocusable`은 `Focus` 위젯이 세우는 플래그라 단언에서 제외 — 실측 확인.)

```
$ flutter test test/shared/ui/app_button_test.dart          # RED
Which: missing flags: isButton,isFocusable,hasEnabledState,isEnabled
00:01 +8 -3: Some tests failed.
$ flutter test test/shared/ui/app_button_test.dart          # GREEN
00:01 +12: All tests passed!
```

### C4. `AppLayoutHeader` 선언 높이 ↔ 렌더 높이

`AppBar(toolbarHeight: height)`를 넘긴다.

**첫 테스트가 틀렸다는 것을 발견해 고쳤다.** `tester.getSize(find.byType(AppBar))
.height`는 Scaffold가 `preferredSize`로 잡아주는 **박스**라 선언값을 그대로
따라온다 — 상수를 64로 바꿔도 통과했다. 실제로 어긋나는 것은 **툴바 내용의
배치**다. 그래서 **제목의 세로 중심**을 단언하도록 바꿨다.

```
--- RED (상수 64, toolbarHeight 미전달) ---
Expected: 32.0 (±0.5)   Actual: <28.0>          ← kToolbarHeight(56)/2
--- GREEN (상수 64 + toolbarHeight) ---   00:01 +15: All tests passed!
--- 상수를 웹 h-[56px] 값 56으로 복원 ---  00:01 +15: All tests passed!
```

---

## D군 — 플랫폼

### D1. `textScaler` 정책

`MaterialApp.builder`에 `MediaQuery.withClampedTextScaling(maxScaleFactor:
kMaxTextScaleFactor)`. 상수는 `lib/app.dart`에 두고 **값을 고른 근거를 문서주석과
테스트 단언 양쪽에** 남겼다.

가장 빡빡한 제약은 44px 버튼 안의 `title1SemiBold`(16 × 1.4 = 22.4px):

| 배율 | 버튼 라인박스 | 44px 안에 | 입력 라인박스(16×1.5) | 50px 안에 |
|---|---|---|---|---|
| 1.3 | 29.1px | 예 (여유 14.9px) | 31.2px | 예 |
| 2.0 | 44.8px | **아니오** | 48.0px | 아슬 |

테스트 3개: ① 3.0배 요청 시 1.3으로 클램프 ② 1.1배는 그대로 따름(무시가 아니라
클램프) ③ 3.0배에서도 버튼 렌더 높이가 44 유지 + 위 부등식.

```
$ flutter test test/app_test.dart                           # RED
test/app_test.dart:36:35: Error: Undefined name 'kMaxTextScaleFactor'.
$ flutter test test/app_test.dart                           # GREEN
00:01 +4: All tests passed!
```

### D2. `android:allowBackup="false"`

미설정이라 플랫폼 기본값으로 Auto Backup이 켜져 있었다. 이유(암호화된 prefs는
복원되지만 KeyStore 키는 복원되지 않아 `BadPaddingException`)를 XML 주석으로
남겼고, "켜야 하면 `backup_rules.xml` 제외가 먼저"라는 대안도 적었다.

AndroidManifest는 Dart 테스트가 닿지 않아 아무 가드도 없으므로 파일 내용을
직접 단언하는 `test/platform/android_manifest_test.dart`를 함께 뒀다.

### skip 테스트 본문 보강 (커밋 `13dc6d9`)

`잘못된 경로로 요청하면 패리티가 실패한다`는 A1 이전에는 **경로가 유일한
차이**였기에 `throwsA(isA<ParityFailure>())`만으로 "경로 비교가 동작한다"를
증명했다. 헤더 비교가 들어온 뒤로는 경로와 헤더가 동시에 어긋나므로 그
단언은 **경로 비교를 통째로 지워도 통과한다** — 이름이 약속하는 것을 더는
검증하지 못하는 상태였다(A2가 경고한 침식과 같은 모양이 한 단계 위에서 발생).

실측으로 확인했다. `_diffPath` 호출을 제거하고:

| 단언 형태 | 결과 |
|---|---|
| 강화 전 `throwsA(isA<ParityFailure>())` | **통과** (헤더 차이가 대신 예외를 던짐) |
| 강화 후 `.having((e) => e.message, 'message', contains('path:'))` | **실패** |

검증 절차: 임시 골든(`login.json`, 현재 형식)을 만들고 `skip: true`를 떼어
실제로 돌린 뒤, 골든 삭제·skip 복원·`shasum -c`로 원복을 확인했다.
부수적으로 **첫 번째 패리티 테스트도 임시 골든으로 통과**하는 것을 확인해,
headers를 담은 골든으로 종단 패리티 경로가 실제 동작함을 함께 봤다.

### 신선한 클론에서의 픽스처 디렉터리

두 계약 테스트가 `har_to_golden.py`를 실행하는데, 스크립트는 `open(dest,'w')`를
바로 호출하므로 `test/fixtures/requests/`가 없으면 `FileNotFoundError`로 죽는다
(디렉터리를 지우고 재현 확인). `git ls-files test/fixtures` →
`test/fixtures/requests/.gitkeep`이 **추적되고 있어** 신선한 클론에서도
디렉터리가 존재한다. 조치 불필요.

---

## 뮤테이션 검증 요약

원복은 전부 `git checkout`이 아니라 **유일 문자열 역치환**으로 했고
`shasum -c`로 원본 복구를 확인했다. M3 시도에서 문자열이 유일하지 않아
(count=2) 스크립트가 중단됐고, 더 긴 앵커로 다시 잡았다 — 유일성 가드가
실제로 발화한 사례다.

| # | 뮤테이션 | 결과 |
|---|---|---|
| M1 | 헤더 비교 무력화 | 3 실패 |
| M2 | 캡처 allowlist 무력화 | 3 실패 |
| M3 | `_diffMap` 리스트 재귀 제거 | 5 실패 |
| M4 | `{id}`를 "아무 값이나"로 완화 | 1 실패(`/members/me` 통과 방지) |
| M5 | `loadGolden` 옛형식 가드 제거 | 1 실패 |
| M6 | A4 필터를 OR로 되돌림 | 1 실패 |
| M7 | Python `CAPTURED_HEADERS` drift | 3 실패(drift 가드 포함) |
| M8 | Python 자리표시자 토큰 drift | 3 실패(drift 가드 포함) |
| M9 | 생성기가 `headers` 키 누락 | Dart 계약 테스트 2건 실패 |
| M10 | 죽은 `border:` 재도입 | 1 실패 |
| M11 | `Semantics(button:)` 해제 | 3 실패 |
| M12 | `enabled`를 `true`로 고정 | 2 실패 |
| M13 | `toolbarHeight` 제거 + 상수 64 | 1 실패 (28.0 vs 32.0) |
| M14 | 버튼 고정 높이 → 패딩 | 1 실패 (600.0 vs 44.0) |
| M15 | 버튼 `leadingDistribution` 제거 | 1 실패 |
| M16 | 입력 고정 높이 제거 | 1 실패 (24.0 vs 50.0) |
| M17 | textScaler 클램프 제거 | 1 실패 (48.0 vs 20.8) |
| M18 | `allowBackup` 제거 | 1 실패 |
| M19 | `_diffPath` 호출 제거 | 1 실패 (강화된 skip 테스트가 잡는다; 강화 전 단언이었다면 통과) |

**M13의 모양이 다르다는 점을 명시한다.** `toolbarHeight:` 한 줄만 지우면
테스트는 **통과한다** — 상수 56이 `kToolbarHeight`와 우연히 같기 때문이다.
이 수정이 막는 것은 "지금의 버그"가 아니라 "상수를 바꿨을 때의 조용한 drift"라,
뮤테이션도 그 조건(상수 변경 + 전달 누락)을 함께 재현해야 한다.

**M14가 600.0을 낸 것**도 기록해 둔다: `alignment`가 있고 높이가 없는
`Container`는 주어진 제약을 채우므로, 같은 위젯이 `Center` 안에서는 600,
`Column(stretch)` + `SingleChildScrollView` 안에서는 ~54로 문맥마다 달라졌다.
고정 높이는 그 문맥 의존성 자체를 없앤다 — 62개 화면이 복사할 위젯에서
중요한 성질이다.

---

## 범위 밖 항목 미접촉 확인

`git diff --quiet ae5d4d2..HEAD -- <path>` 로 파일 단위 확인:

```
미변경  lib/core/theme/app_typography.dart      (AppTypography.all 주석)
미변경  lib/core/theme/app_theme.dart           (textTheme 슬롯, scaffoldBackgroundColor, ColorScheme.fromSeed)
미변경  lib/core/theme/app_radius.dart
미변경  lib/core/theme/app_colors.dart
미변경  lib/entity/auth/model/sign_in_response.dart  (필드 가드)
미변경  lib/core/storage/token_storage.dart     (writeTokens 배선)
미변경  lib/page/public/sign_in_page.dart
미변경  lib/core/network/dio_client.dart
미변경  lib/core/network/auth_interceptor.dart
미변경  tool/measure_expansion.sh               (경로 파라미터화)
미변경  README.md                                (README/description)
미변경  pubspec.yaml                             (description, minSdk 인접)
미변경  openapi/api-docs.json                    (스냅샷 테스트 강화)
```
- `test/core/theme/app_radius_test.dart` 신설하지 않음 (존재하지 않음).
- `AppLayout`의 `SingleChildScrollView(child: contents)` 무조건 래핑 유지 (미접촉).
- `lib/widget/app_layout.dart`의 diff는 `toolbarHeight: height` + 주석 5줄뿐.
- `auth_state` 슬라이스 신설하지 않음. 릴리스 서명·orientation·표시 이름 미접촉.
- 패리티 skip 2건은 그대로 두고 **재개 조건 주석과 본문**을 새 형식에 맞춰 갱신했다
  (아래 "skip 테스트 본문 보강" 참조).

---

## 우려사항

### 1. ~~(결정 필요) dio가 본문 없는 GET에도 `content-type`을 붙인다~~ → **해결 (`7b59c17`)**

> 컨트롤러가 "웹에 맞춘다"로 결정하고 범위를 넓혀 지시했다. 아래는 보고 당시
> 기록이며, 처리 내용은 문서 끝 "추가 지시 처리" 절에 있다.


테스트로 **고정했다**(`request_capture_test.dart`: "본문 없는 GET에도
content-type이 붙는다"). `DioClient`가 `BaseOptions.contentType`을 전역으로
지정하므로 GET·POST 가리지 않고 헤더에 들어간다. 브라우저는 본문 없는 GET에
붙이지 않는다.

**결과:** 골든을 뜨면 GET마다 `headers.content-type: 예상치 못한 추가`가 뜬다.
이건 하네스의 오탐이 아니라 실제 차이다.

**대응을 이번 범위에서 하지 않은 이유:** `DioClient` 수정은 지시된 범위에 없고,
네트워크 동작을 바꾸는 프로덕션 변경이다. 임의로 넣지 않았다.

**컨트롤러 판단이 필요하다 — HAR 캡처보다 먼저.** 답이 "웹에 맞춰
`DioClient`를 고친다"라면 그건 62개 화면 테스트가 붙기 전에 들어가야 하는
프로덕션 변경이다. allowlist를 좁히거나 단언을 지우는 것은 답이 아니며,
그 취지를 `kCapturedHeaders` 주석과 skip 테스트 재개 조건에 못박아 뒀다.
같은 성격으로 POST의 `application/json` vs 백엔드 스펙
`application/json;charset=UTF-8` 차이도 첫 대조에서 드러날 것이다.

### 2. (범위 밖, 같은 종류의 내구성 결함) 쿼리스트링의 리소스 id

A3은 **경로**의 id만 다룬다. `?memberId=123` 처럼 쿼리로 오는 id는 값으로
대조되고 `kMaskedKeys`에도 없어서, 골든이 캡처 계정의 id에 묶이는 문제가
한 단계 위에서 그대로 남는다. 이번 지시 범위 밖이라 손대지 않았으나 A3과
같은 실패 양상이므로 기록한다.

### 3. `leadingDistribution`이 두 위젯에만 적용됐다

C2 지시대로 버튼·입력의 TextStyle에만 넣었다. half-leading 차이는 앱의 모든
텍스트에 해당하므로, 고정 높이 박스가 더 생기는 Phase 2에서 `AppTypography`
전역 적용을 검토할 값이 있다. 전역 적용은 모든 텍스트 베이스라인을 옮기므로
시각 확인과 함께 가야 한다.

### 4. `AppButton.backgroundKeyFor(label)`의 알려진 한계 (기존 이월)

같은 라벨의 버튼이 한 화면에 둘이면 여전히 충돌한다. 이번 fix로 그 위젯의
테스트가 늘었으므로(높이·시맨틱) 한계가 노출되는 지점도 늘었다. 기존
deferred 항목이라 손대지 않았다.

### 5. 시각 확인은 여전히 미수행

C2의 44·50과 `leadingDistribution`은 **렌더 박스 높이**를 테스트로 고정했을
뿐, 웹과 나란히 놓고 본 것이 아니다. Phase 0 Step 5(실기기 확인)가 남아 있고,
한글 메트릭의 1~2px 차이는 그 단계에서만 최종 확인된다.


---

# 추가 지시 처리 — 우려 #1 (커밋 `7b59c17`)

**컨트롤러 결정:** 비교를 약화시키지 말고 요청을 고친다. 방향은 "웹에 맞춘다".

## 변경

`lib/core/network/dio_client.dart`의 `BaseOptions`에서
`contentType: Headers.jsonContentType`를 제거하고, 제거한 이유와 대안 동작을
주석으로 남겼다.

## 지시받은 가설의 실측 확인

> "`BaseOptions`에서 제거하면 dio는 `data`가 있을 때만 타입을 추론해 붙인다.
> 이 방식이 맞는지 실제로 확인하고, 다르게 동작하면 보고하라."

**가설대로 동작했다.** 다른 처리가 필요 없었다. 단언 지점은 어댑터가 받아든
최종 `RequestOptions`(`_CapturingAdapter.lastRequest`)로 잡았다 — `RequestCapture`
하네스가 보는 것과 같은 지점이다.

| 요청 | 변경 전 | 변경 후 |
|---|---|---|
| 본문 없는 GET `/api/v1/members/me` | `content-type: application/json` | **헤더 없음** (웹과 동일) |
| 본문 있는 POST `/api/v1/auth/login` | `application/json` | `application/json` (변화 없음) |

## TDD 증거

RED — `test/core/network/auth_interceptor_test.dart`의 `DioClient.create 조립`에
두 테스트 추가:
```
$ flutter test test/core/network/auth_interceptor_test.dart
00:00 +7 -1: DioClient.create 조립 본문 없는 GET에는 content-type을 붙이지 않는다 (웹과 동일) [E]
  Expected: not contains 'content-type'
    Actual: EfficientLengthMappedIterable<String, String>:['content-type']
00:00 +11 -1: Some tests failed.
```
(POST 단언은 이 시점에 이미 통과했다 — 전역 지정이 있었으므로.)

GREEN — `contentType` 제거 후:
```
$ flutter test test/core/network/auth_interceptor_test.dart
00:00 +12: All tests passed!
```

전체 스위트 — **기존 패리티·인터셉터 테스트는 하나도 깨지지 않았다**:
```
$ flutter test --reporter compact
00:02 +134 ~2: All other tests passed!
```

## 뮤테이션 검증

원복은 유일 문자열 역치환, `shasum -c lib/core/network/dio_client.dart` → OK.

| # | 뮤테이션 | 결과 |
|---|---|---|
| M20 | 전역 `contentType` 재도입(수정 원복) | GET 테스트 실패 — `Expected: not contains 'content-type'` / `Actual: ['content-type']` |
| M21 | POST에서 `data:` 제거 | POST 테스트 실패 — `Expected: 'application/json'` / `Actual: <null>` |

M21은 POST 단언이 **전역 설정이 아니라 `data` 기반 추론**에 의존함을 보인다 —
전역 지정이 남아 있었다면 data가 없어도 통과했을 것이므로, 이 테스트가 실제로
새 메커니즘을 고정하고 있음을 뜻한다.

## 옛 가정을 서술하던 문서 3곳 갱신

테스트가 깨지지는 않았지만 **이제 거짓이 된 서술**이 세 군데 있어 함께 고쳤다:

1. `test/harness/request_capture.dart`의 `kCapturedHeaders` 주석 — "DioClient를
   웹과 맞춰라"는 미해결 과제 서술이었다. 이제 **"비교를 느슨하게 하지 말고
   요청을 고친" 선례**로 재서술했다(같은 상황이 또 오면 따라야 할 규칙이 남는다).
2. `test/harness/request_capture_test.dart` — `본문 없는 GET에도 content-type이
   붙는다 (DioClient 전역 설정의 결과)` → `BaseOptions.contentType을 지정하면
   본문 없는 GET에도 붙는다`. dio의 사실 자체는 그대로 고정하되, **왜 고정해
   두는가**(누가 편의로 다시 지정하면 모든 GET 골든이 어긋나므로 그 인과를
   남긴다)를 적었다. `DioClient`의 실제 동작 단언은 `auth_interceptor_test.dart`가 맡는다.
3. `test/page/sign_in_page_test.dart` 패리티 skip 재개 조건 #3 — 로그인은 본문
   있는 POST라 여전히 `application/json`이 붙는다는 점, 그 출처가 이제
   `BaseOptions`가 아니라 `ImplyContentTypeInterceptor`라는 점으로 갱신.
   `charset=UTF-8` 차이가 남을 수 있다는 경고는 유지했다.

## 검증

```
$ ./tool/verify.sh
== dart format ==
== flutter analyze ==
No issues found! (ran in 1.0s)
== har_to_golden.py 테스트 ==
== flutter test ==
00:03 +134 ~2: All other tests passed!
OK: 모든 검증 통과
```

Dart **134 통과 + 2 skip**, Python **30 통과**. 워킹트리 깨끗.

## 나머지 우려 — 컨트롤러 판정대로 미조치

- **#2 쿼리스트링 리소스 id** — Phase 1 이월. 코드 변경 없음.
- **#3 `leadingDistribution` 두 위젯 한정** — 그대로.
- **#4 44·50 실기기 시각 대조 미수행** — 그대로(Phase 0 종료 게이트 항목).
