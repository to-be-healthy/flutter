# Task 9 리포트 — 참조 화면(로그인) + 팽창률 실측

**Status:** DONE_WITH_CONCERNS
**커밋:** `409fdd4` feat(auth): 로그인 참조 화면 구현 및 팽창률 실측 도구 추가
**브랜치:** `feature/flutter-phase0` (push 안 함)

---

## 1. 구현한 것

| 파일 | 내용 |
|---|---|
| `lib/page/public/sign_in_page.dart` (신규, 183줄) | 웹 `SignInPage.tsx` + `SignInForm.tsx` 대응 참조 화면 |
| `lib/app.dart` (신규) | 조립 지점. `Dio`/`AuthApi`를 `initState`에서 1회 생성 |
| `lib/main.dart` (교체) | `--dart-define=API_BASE_URL` 주입, 기본값 `https://geonganghaejim.site` |
| `test/page/sign_in_page_test.dart` (신규) | 위젯 테스트 5개 + 패리티 테스트 2개(skip) |
| `test/app_test.dart` (신규) | 진입점 스모크 테스트 1개 |
| `test/widget_test.dart` (삭제) | Flutter 기본 카운터 테스트. `MyApp`이 사라져 컴파일 불가 |
| `tool/measure_expansion.sh` (신규) | 팽창률 측정. 생략분·주석 편향을 각각 보정한 4개 기준 출력 |
| `../MOBILE_MIGRATION_ANALYSIS.md` §3 (수정) | Flutter 실측치 기록 **(flutter/ 레포 밖이라 커밋에 포함되지 않음)** |

### 브리프 대비 의도적 변경 3건

1. **에러 메시지를 서버 응답에서 읽는다.** 브리프는 `catch (_)` 후 고정 문구
   `'로그인에 실패했습니다. 다시 시도해 주세요.'`를 띄웠다. 웹 `SignInForm`은
   `errorToast(error.response?.data?.message ?? '문제가 발생했습니다.')`로 **서버 메시지를
   그대로** 보여준다. 고정 문구를 62개 화면이 복사하면 "아이디 또는 비밀번호가 일치하지
   않습니다" 같은 실제 안내가 전부 사라진다. `_serverMessage(Object)` 10줄을 추가해 웹과
   같은 동작으로 맞췄다. 폴백 문구도 웹과 동일한 `'문제가 발생했습니다.'`.
2. **`mounted` 가드를 성공·실패 양쪽에 건다.** 브리프는 `finally`에만 가드가 있고 `catch`의
   `setState`는 무방비였다 — 요청 중 dispose되면 예외가 난다. `await` 뒤 `setState`를 한
   곳으로 모으고 `mounted`를 한 번만 확인하도록 재구성했다.
3. **`app.dart`를 `StatefulWidget`으로.** 브리프는 `build()` 안에서 `DioClient.create()`를
   불렀다. 리빌드마다 새 클라이언트·인터셉터가 생기고 커넥션 풀이 버려진다. 생성자
   시그니처(`{required String baseUrl}`)는 그대로 두어 Step 5의 `--dart-define` 흐름을 보존했다.

### 브리프 대비 추가한 테스트 4개 (사유: 패리티 skip으로 생긴 공백)

패리티 테스트가 skip되면 브리프 원안에서 **제출 경로 전체가 미검증**으로 남는다. 다음을 추가했다.

| 테스트 | 왜 패리티와 겹치지 않나 |
|---|---|
| `입력한 아이디·비밀번호가 요청 본문에 그대로 실린다` | `password`가 `kMaskedKeys`에 있어 골든은 **키 존재만** 본다. userId/password를 뒤바꿔 실어도 패리티는 통과한다. method·path·memberType은 골든의 몫이라 여기서 재단언하지 않는다 |
| `요청이 실패하면 서버 메시지를 화면에 표시한다` | 패리티는 **요청**만 본다. 응답 실패 처리는 범위 밖 |
| `트레이너 타입이면 제목이 트레이너 로그인이다` | `memberType` 분기가 유일하게 검증되는 곳 |
| `앱 진입점이 로그인 화면을 띄운다` (`app_test.dart`) | 삭제한 `widget_test.dart`를 대체. `main.dart`/`app.dart` 결선 검증 |

---

## 2. 웹 원본 대조 결과

### 구조 — 일치

| 웹 (`SignInPage.tsx` / `SignInForm.tsx`) | Flutter | 결과 |
|---|---|---|
| `<Layout className='bg-white'>` (셸 gray-100을 흰색으로 덮음) | `AppLayout(backgroundColor: Colors.white)` | 일치 |
| `Layout.Header` + `<h2>` 제목 | `AppLayoutHeader(title:)` | 일치 (타이포는 아래 델타) |
| `memberType === 'student' ? '회원 로그인' : '트레이너 로그인'` | `widget._title` (STUDENT/TRAINER) | 일치 |
| `Layout.Contents` > `<div className='px-7'>` | `Padding(horizontal: spacing.s7)` = 20px | 일치 — **셸이 아니라 화면이 패딩을 준다** |
| 필드 그룹 `gap-y-3` (label↔input 8px) | `AppTextInput` 내부 `spacing.s3` = 8px | 일치 |
| 첫 필드 그룹 `mb-8` (24px) | `SizedBox(height: spacing.s8)` = 24px | 일치 |
| 제출 버튼이 **폼 안**(`mt-[46px]` 블록), footer가 아님 | `contents` Column 안 `AppButton` | 일치 — `bottomArea` 쓰지 않음 |
| 필드 에러: `Typography.BODY_4` + `text-point` | `AppTextInput` → `body4` + `colors.point` | 일치 |
| 에러 문구 `'아이디를 입력해주세요.'` / `'비밀번호를 입력해주세요.'` | 글자까지 동일 | 일치 |
| `errorToast(error.response.data.message)` | 폼 안 인라인 `Text` (같은 메시지) | 표시 위치만 다름 (토스트 위젯은 Phase 1) |

타이포 토큰 자체는 웹 `typography.ts`와 1:1로 확인됨 — `TITLE_1` 16px/140% bold,
`TITLE_3` 14px/150% semibold, `BODY_3` 13px/150%, `BODY_4` 12px/150% ↔ Dart 동일.

### 의도적 생략 (브리프 명시, 추가하지 않음)

로고(`IconLogo` 64x64), 회원가입 버튼(outline), 비밀번호/아이디 찾기 링크,
뒤로가기 `router.push('/')`, `onSuccess`의 토큰 저장·웹뷰 브리지·라우팅.

### 발견한 델타 — **전부 Task 7·8 위젯에서 유래, 이번 태스크에서 고치지 않음**

참조 화면을 웹과 나란히 대조하면서 드러난 것들이다. 사용자 전역 규칙("요구사항↔구현
불일치는 고치기 전에 보고")에 따라 **수정하지 않고 보고만 한다.** 전부 Step 5(실기기 시각
대조) 확인 항목으로 넘긴다.

| # | 항목 | 웹 | 현재 Flutter | 출처 |
|---|---|---|---|---|
| D1 | 헤더 제목 타이포 | `HEADING_4_SEMIBOLD` 18px/130% semibold | `AppTypography.title1` 16px/140% **bold** | Task 8 `AppLayoutHeader` |
| D2 | 로그인 버튼 라벨 타이포 | `TITLE_1_SEMIBOLD` 16px **semibold** | `AppTypography.title1` 16px **bold** | Task 7 `AppButton` |
| D3 | 입력 라벨 색 | `text-gray-800` | `colors.gray700` | Task 7 `AppTextInput` |
| D4 | 버튼 높이 | `h-[44px]` 고정 | 세로 패딩 16×2 + 라인높이 22.4 ≈ **54px** | Task 7 `AppButton` |
| D5 | 입력 높이 | `h-[50px]` 고정 | 세로 패딩 16×2 + 라인높이 24 ≈ **56px** | Task 7 `AppTextInput` |
| D6 | 버튼 앞 간격 | `mt-[46px]` (임의값) | `spacing.s12` = 48px | 이번 태스크 (의도적, 아래) |

D1·D2는 `heading4SemiBold` / `title1SemiBold` 토큰이 이미 `AppTypography`에 **존재한다** —
잘못 고른 것이지 없는 게 아니다. D4·D5는 고정 높이 대신 패딩 기반으로 설계한 결과라
"고칠지"가 아니라 "어느 쪽이 맞는지"를 먼저 정해야 한다(한글 폰트 메트릭 차이 때문에
고정 높이가 항상 옳지도 않다).

D6은 내 판단이다: 46은 스페이싱 스케일(4/6/8/10/12/16/20/24/28/32/36/48)에 없지만,
필드 그룹 사이 간격은 `AppLayoutHeader.height = 56`처럼 **컴포넌트 고유 치수**가 아니라
정확히 간격 토큰이 다루는 값이다. 가장 가까운 단계 s12(48px)로 맞추고 2px 차이를 코드에
기록했다.

---

## 3. TDD 증거

### RED (Step 2)

```
$ flutter test test/page/sign_in_page_test.dart
Failed to load ".../test/page/sign_in_page_test.dart":
  Error: Error when reading 'lib/page/public/sign_in_page.dart': No such file or directory
  Error: Method not found: 'SignInPage'.
00:00 +0 -1: Some tests failed.
```
이유: 구현 파일이 없다. (첫 시도에는 `skip: kGoldenPending` 타입 오류도 섞여 있었다 —
`flutter_test`의 `testWidgets`는 `package:test`의 `test`와 달리 `skip`이 `bool?`이라 사유
문자열을 못 받는다. 사유를 **테스트 이름**에 붙이고 `skip: true`로 바꿔 해소.)

`app.dart`도 같은 순서로 진행했다:
```
$ flutter test test/app_test.dart
  Error: Couldn't find constructor 'GeonganghaejimApp'.
00:00 +0 -1: Some tests failed.
```

### GREEN (Step 4)

```
$ flutter test test/page/sign_in_page_test.dart
00:00 +5 ~2: All tests passed!
```
5 통과 / 2 skip. skip 사유는 출력에 그대로 보인다:
`... (패리티) — 보류: 골든 픽스처 없음 — Task 4 Step 7(HAR 캡처) 대기`

### 단언이 실제로 잡는가 — 뮤테이션 3건

"단언을 지우면 통과하는가"를 역으로 검증했다. **`git checkout`을 쓰지 않았다** —
`sign_in_page.dart`가 당시 untracked라 `git checkout`은 파일을 통째로 날린다
(`destructive-command-safety.md` §3). 문자열 역치환으로만 원복하고, 대상이 파일 내에서
유일한지(`count == 1`) 치환 전후 양쪽에서 검사했다. 마지막에 `'MUTANT' not in source`로
잔여물 없음을 확인했다.

| 뮤테이션 | 결과 | 잡은 테스트 |
|---|---|---|
| `_validate()` → `return true` (유효성 검사 무력화) | FAIL ✓ | `빈 입력으로 제출하면 오류를 표시하고 요청을 보내지 않는다` (`Actual: [Instance of 'CapturedRequest']` — 요청이 나갔다) |
| 요청 본문의 `userId`/`password` 뒤바꿈 | FAIL ✓ | `입력한 아이디·비밀번호가 요청 본문에 그대로 실린다` |
| `_serverMessage()` → `return null` (서버 메시지 무시) | FAIL ✓ | `요청이 실패하면 서버 메시지를 화면에 표시한다` |

각 뮤테이션이 **의도한 그 테스트 하나만** 떨어뜨렸다(다른 테스트는 계속 통과). 단언이
과잉도 아니고 헐겁지도 않다는 뜻이다.

`빈 입력` 테스트는 브리프의 `find.textContaining('입력')`을 **정확 문자열 2개**로 조였다.
`AppTextInput`에 placeholder가 없어서 지금은 둘 다 통과하지만, 웹 placeholder 문구가
`'아이디를 입력해주세요.'`로 에러 문구와 같다 — 누가 placeholder를 붙이는 순간
`textContaining('입력')`은 **유효성 검사가 깨져도 통과한다.**

### 검증 루프 (Step 3, 커밋 직전)

```
$ ./tool/verify.sh
== dart format ==      Formatted 33 files (0 changed)
== flutter analyze ==  No issues found! (ran in 0.6s)
== har_to_golden.py 테스트 ==  Ran 14 tests — OK
== flutter test ==     00:02 +90 ~2: All other tests passed!
OK: 모든 검증 통과
```
Dart 90 통과 / 2 skip, Python 14 통과. (Task 8 종료 시점 85개 → `widget_test.dart` 1개
삭제, 신규 8개 추가 = 92개 중 90 활성.)

`flutter analyze`가 1차에 `unused_element_parameter` 경고를 냈다(`_StubAdapter({this.statusCode = 200})`의
기본값을 한 번도 명시적으로 넘기지 않음). 생성자 파라미터를 없애고 필드 초기화(`int statusCode = 200;`)로
바꿔 해소. **경고를 무시하지 않았다.**

---

## 4. 리터럴 감사 — 확인 방법과 결과

대상: 이번에 만든 production 파일 3개
(`lib/page/public/sign_in_page.dart`, `lib/app.dart`, `lib/main.dart`).

> zsh는 따옴표 없는 변수를 단어 분할하지 않아 첫 시도가 "파일 없음"으로 조용히 0건
> 처리됐다. 배열(`new=(...)` → `"${new[@]}"`)로 바꾸고 `대상 3개` 출력으로 건수를 대조했다.

| # | 무엇을 찾았나 | 명령 | 결과 |
|---|---|---|---|
| 1 | 색 리터럴 | `grep -nE 'Color\(0x\|Colors\.' "${new[@]}"` | **1건 — 의도된 예외.** `sign_in_page.dart:137 backgroundColor: Colors.white` (+ 그 사유를 적은 주석 2줄). `Colors.white`는 `AppColors`에 대응 토큰이 없는 프레임워크 상수 — `AppButton`이 세운 것과 같은 예외이고, 사유를 코드 135-136행에 남겼다 |
| 2 | 간격·치수 숫자 리터럴 | `grep -nE '(EdgeInsets[A-Za-z.]*\(\|SizedBox\(\|height:\|width:\|padding:\|margin:\|borderRadius\|radius\|fontSize\|letterSpacing\|elevation\|strokeWidth)[^)]*[^A-Za-z0-9_.]-?[0-9]' "${new[@]}"` | **0건** |
| 3 | 타이포 리터럴 | `grep -nE 'TextStyle\(\|FontWeight\|fontFamily' "${new[@]}"` | **0건** |
| 4 | 테마 경유 지점(있어야 하는 것) | `grep -nE 'extension<App\|AppTypography\.\|AppTheme\.' "${new[@]}"` | 4건 — `extension<AppColors>()`, `extension<AppSpacing>()`, `AppTypography.body3`, `AppTheme.light()` |

결론: 색 1건(사유 기록된 프레임워크 상수)을 빼면 색·간격·타이포가 **전부 테마를 경유**한다.
`AppTypography`는 `ThemeExtension`이 아니라 정적 상수 모음이고 `AppTheme.light()`가 같은
상수로 `TextTheme`을 구성하므로, 정적 참조가 곧 테마 경유다(Task 7이 세운 규약).

---

## 5. 팽창률 실측치와 해석

`./tool/measure_expansion.sh` 실행 결과:

```
웹 원본 (SignInPage + SignInForm)
  SignInPage.tsx: 59줄 (생략 대응 24줄)
  SignInForm.tsx: 118줄 (생략 대응 21줄)
  합계: 177줄 / 생략 제외 132줄 / 코드만·생략 제외 118줄
Flutter (sign_in_page.dart): 183줄 / 코드만 124줄

  ① 단순 비율        183 / 177 = 1.03x   raw↔raw지만 생략분이 분모에 남음 → 과소평가. 진단용
  ② 생략 보정(raw)   183 / 132 = 1.39x   raw↔raw + 생략 보정 — 역산 기준
  ③ 코드 라인만      124 / 161 = 0.77x   code↔code지만 생략분이 분모에 남음 → 과소평가. 진단용
  ④ 코드+생략 보정   124 / 118 = 1.05x   code↔code + 생략 보정 — 코드 밀도 기준

전체 UI 22,257줄 역산:
  ② 1.39x → 약 30,856줄 (주석 포함 Dart 파일 총량)
  ④ 1.05x → 약 23,388줄 (주석 제외 순수 코드)
```

### 왜 4개를 내는가 — 두 편향이 반대 방향으로 섞인다

**편향 1 (팽창률을 과소평가):** 웹 177줄에는 Flutter가 **의도적으로 생략한** 45줄이 들어
있다. 분모가 부풀어 비율이 낮게 나온다. 생략 구간을 줄 번호 단위로 확정했다:

| 웹 파일 | 구간 | 사유 |
|---|---|---|
| `SignInPage.tsx` | L6, L8, L14, L30-32, L36-38, L40-54 (24줄) | 로고·뒤로가기 `router.push('/')`·찾기 링크 + 그 전용 import |
| `SignInForm.tsx` | L1, L13, L29-37, L105-114 (21줄) | 회원가입 버튼·`onSuccess`(토큰 저장·웹뷰 브리지·라우팅) + 전용 import |

**편향 2 (팽창률을 과대평가):** Flutter 쪽은 Task 7·8이 세운 *"토큰을 쓰지 않는 리터럴은
이유를 코드에 남긴다"* 규율 때문에 주석이 두껍다(183줄 중 59줄이 주석·빈 줄).

**①은 두 편향이 우연히 상쇄된 값이라 쓰면 안 된다.** 1.03x는 "Flutter가 웹과 거의 같다"로
읽히지만 실제로는 45줄 적은 기능을 59줄 많은 주석으로 채운 결과다.

### 권장 기준: ② 1.39x

§2의 22,257줄이 주석·빈 줄을 포함한 raw 값이므로, 단위가 맞는 것은 raw끼리 비교한 ②다.
역산 결과는 **약 30,900줄**(스크립트 원값 30,856을 반올림. `MOBILE_MIGRATION_ANALYSIS.md`에
기록한 값과 같다).
**②(1.39x)와 ④(1.05x)의 차이는 Flutter가 더 복잡해서가 아니라 주석 때문이다** — 코드
밀도 자체는 웹과 거의 같다. 규율을 버리면 ④에 수렴하지만 그러면 AI 이식 시 토큰 우회를
잡을 근거가 사라진다. Phase 1~8이 규율을 유지한다는 전제에서 ②가 맞다.

RN 실측(1.05x, NativeWind가 Tailwind 클래스를 그대로 받음)과 비교하면 Flutter의 추가
비용은 **약 1.32배**다. §3이 예측한 "Flutter는 팽창한다"는 방향은 맞았지만, 그 팽창의
정체는 위젯 트리 중첩이 아니라 **주석 규율**이었다 — ④가 그 구분을 만들어 준다.

### 한계 (문서에도 기록)

- **폼 화면 1개** 기준이다. 리스트·그리드·캘린더(§8 재현 난이도 상위)는 위젯 트리 중첩이
  깊어 더 팽창할 수 있다 → Phase 3~5 착수 시 각 도메인 첫 화면에서 재측정.
- 줄 수는 공수에 비례하지 않는다(§2와 동일한 단서).
- 생략 구간은 사람이 확정한 값이다. 웹 원본이 바뀌면 스크립트가 `expected_lines` 검사에서
  먼저 멈춘다(조용히 틀린 숫자를 내지 않는다).

---

## 6. 보류 항목 (컨트롤러 지시 + 그 귀결)

| 항목 | 상태 | 사유 / 재개 조건 |
|---|---|---|
| 패리티 테스트 `expectParity('login', ...)` | **skip** | `test/fixtures/requests/login.json` 없음 — Task 4 Step 7(웹 HAR 캡처, 사람만 가능) 대기. **본문은 그대로 뒀다.** `skip: true`와 테스트 이름 접미사만 떼면 동작 |
| 패리티 하네스 자체 검증(`ParityFailure`) | **skip** | 동일. 같은 골든을 읽는다 |
| Step 5 — 실기기/시뮬레이터 시각 확인 | **미수행** | 사람이 해야 함. 확인 항목 5개(간격 s8=24px, Pretendard 폰트, 버튼 `#1990FF`, 키보드가 버튼을 가리지 않는지, 노치·홈 인디케이터)에 **위 §2의 D1~D6을 추가해서** 대조할 것 |
| Step 7 — Phase 0 종료 게이트 | **미수행** | 패리티가 실제로 통과해야 의미가 있다. 게이트 6항목 중 현재 충족: analyze 무경고 ✓, flutter test 전체 통과 ✓, spacing 매핑 테스트 ✓, 팽창률 기록 ✓ / 미충족: 실기기 시각 확인, 로그인 요청 패리티 |
| `../MOBILE_MIGRATION_ANALYSIS.md` 수정 | **커밋 안 됨** | 그 파일은 `flutter/` git 레포 **밖**(`tobehealthy/`는 git 레포가 아님)이다. 디스크에는 반영됐고 별도 버전 관리 대상이 아니다 |

---

## 7. 변경 파일

```
A  lib/app.dart
M  lib/main.dart
A  lib/page/public/sign_in_page.dart
A  test/app_test.dart
A  test/page/sign_in_page_test.dart
D  test/widget_test.dart
A  tool/measure_expansion.sh
```
(커밋 `409fdd4`. 레포 밖 `../MOBILE_MIGRATION_ANALYSIS.md`는 별도)

---

## 8. 셀프 리뷰

**핵심 질문: 이 화면이 Phase 1~8이 복사할 만한 참조인가?**

- **웹 구조 대응** — 예. 배경 흰색 override, 화면이 주는 `px-7`, 폼 안의 제출 버튼,
  memberType별 제목이 전부 웹과 같다. 특히 *"셸(`AppLayout`)은 패딩을 강제하지 않고
  화면이 준다"*는 웹 62개 화면의 실제 관행이고, 이 참조가 그 패턴을 보여준다.
- **테마 경유** — 예. §4 감사 참조. 예외 1건은 사유가 코드에 있다.
- **테스트가 동작을 검증하는가** — 예. 뮤테이션 3건이 각각 의도한 테스트 하나만 떨어뜨렸다(§3).
- **빈 입력에서 요청을 보내지 않는가** — 예. `capture.captured, isEmpty`로 직접 단언하고,
  유효성 검사를 무력화하면 그 단언이 깨진다.
- **완전성** — Step 1~4, 6, 커밋 완료. Step 5·7은 지시대로 미수행(§6).
- **YAGNI** — 추가 코드는 `_serverMessage` 10줄뿐이고, 사용처가 한 곳인 지금 `core/network`로
  올리지 않은 이유를 코드에 남겼다. 파일 183줄은 브리프 원안(139줄) + 웹 대조 주석 +
  에러 처리로, 계획 의도를 넘어선 수준은 아니라고 판단한다.
- **테스트 출력 청결도** — `flutter analyze` 무경고, 테스트 실행 중 예외·경고 출력 없음.
  skip 2건의 사유가 출력에 그대로 보인다.

---

## 9. 우려사항

1. **D1~D5 — Task 7·8 공통 위젯이 웹과 어긋나 있다(§2).** 특히 D1·D2는 올바른 토큰
   (`heading4SemiBold`, `title1SemiBold`)이 **이미 `AppTypography`에 있는데도** 다른 걸
   골랐다. 공통 위젯은 62개 화면 전부에 전파되므로 Phase 1 착수 **전에** 정정하는 게 싸다.
   이번 태스크에서 고치지 않은 이유: 이전 태스크의 확정 결정이고, 전역 규칙이 불일치는
   수정 전에 보고하도록 요구한다. **컨트롤러 판단 필요.**
2. **패리티 skip 동안 계약 검증이 0이다.** 추가한 wiring 테스트는 "폼→본문 결선"만 보고
   경로·메서드·envelope 형태는 아무도 안 본다. `AuthApi.signInPath`가 틀려도 지금은 전부
   통과한다. HAR 캡처가 Phase 1의 **선행 조건**임을 명시하는 게 좋겠다.
3. **로고 생략 탓에 상단 여백이 웹과 1:1이 아니다.** 웹은 로고 블록이 159px을 차지하는데
   지금은 `spacing.s10`(32px)이다. 임의값이고, Phase 2에서 자산이 들어올 때 되돌려야 한다.
   코드에 그 취지를 적어 뒀다.
4. **웹은 입력 변경 시 에러가 즉시 사라진다**(react-hook-form `reValidateMode: 'onChange'`).
   현재 Flutter는 다음 제출 때까지 에러가 남는다. 브리프 범위 밖이라 구현하지 않았고,
   `AppTextInput`이 `onChanged`를 이미 받으므로 넣는 비용은 필드당 1줄이다.
5. **팽창률은 폼 화면 1개 표본이다.** ②1.39x를 22,257줄에 곱한 약 30,900줄은 단일 표본
   외삽이다. §3에 한계를 적었지만, 실제 의사결정에 쓰기 전에 리스트/캘린더 화면 1개를
   더 재는 편이 안전하다.

---
---

# Fix 라운드 1 — 리뷰 대응

**커밋:** `ae5d4d2` fix(auth): 패리티 마스킹에 userId 추가 및 공통 위젯 토큰 3건 정정
**검증:** `./tool/verify.sh` 4단계 전부 통과 — Dart **93 통과 / 2 skip**, Python 14 통과, analyze 무경고

---

## I2 (보안, 최우선) — `userId` 마스킹 누락

### 무엇이 문제였나
`kMaskedKeys`(Dart)·`MASKED_KEYS`(Python) 어디에도 `userId`가 없어서 ① 골든을 뜰 때 실제 계정
아이디가 평문으로 레포에 커밋되고 ② `_diffMap`이 값까지 대조하므로 테스트의 더미
`'testuser'`와 불일치해 패리티가 **계약과 무관한 이유로** 실패할 상황이었다.

### 고친 것
`'userId'`를 양쪽 집합에 추가하고, `kMaskedKeys` doc에 **왜** 마스킹 대상인지(백엔드
`CommandLoginMember.userId` = 로그인 식별자, 웹은 이메일이 아니라 아이디로 로그인) 기록했다.
사유가 없으면 다음 사람이 "아이디는 비밀번호가 아니니까"라며 도로 뺄 수 있다.

### drift 가드가 실제로 잡는지 먼저 확인

`tool/har_to_golden_test.py:196 MaskedKeyDriftTest`가 있다기에, **Dart 쪽만 먼저 고쳐서**
가드가 실제로 발화하는지 확인했다.

```
$ # Dart kMaskedKeys 에만 'userId' 추가
$ python3 -m unittest discover -s tool -p '*_test.py'
AssertionError: Items in the first set but not the second:
'userId' : Dart kMaskedKeys 와 Python MASKED_KEYS 가 어긋났다.
           한쪽에만 키를 추가하면 골든에 평문이 남거나 비교가 틀어진다.
Ran 14 tests in 0.006s
FAILED (failures=1)
```

Python 쪽까지 동기화 후:
```
$ python3 -m unittest discover -s tool -p '*_test.py'
Ran 14 tests in 0.003s
OK
```

---

## ⚠ I2가 Minor 지시와 충돌한다 — 판단 필요

지시: *"`sign_in_page_test.dart:75-78`의 비중첩 근거 주석("userId와 password를 서로 바꿔
실어도 패리티는 통과한다")은 I2와 같은 이유로 부정확하다 — `userId`가 값 비교되므로 패리티가
잡는다. 근거만 정확히 고쳐라."*

**그 진단은 수정 *전* 트리에서는 맞았지만, I2를 적용하면 뒤집힌다.** `userId`가
`kMaskedKeys`에 들어간 순간 `_diffMap`은 `userId`·`password` **둘 다** 키 존재만 확인하므로,
두 값을 바꿔 실어도 패리티는 통과한다 — 즉 원래 주석의 주장이 다시 **참**이 된다.

지시를 글자 그대로 따르면(`userId`는 패리티가 잡는다고 쓰면) 방금 만든 상태와 어긋나는
주석이 된다. 그래서 **post-I2 상태 기준으로 정확하게** 다시 썼고, 그 결론이 `kMaskedKeys`
구성에 의존한다는 점을 명시해 누가 `userId`를 빼면 근거가 같이 깨진다는 걸 드러냈다:

> `userId`·`password`가 **둘 다** `kMaskedKeys`에 있어(자격증명이 골든에 평문으로 남지
> 않도록) 골든 대조는 그 두 키의 **존재만** 확인하고 값은 보지 않는다. 따라서 폼이 아니라
> 상수를 실어 보내거나 두 값을 서로 바꿔 실어도 패리티는 통과한다 — 폼→본문 결선은
> 여기서만 잡힌다. 반대로 method·path·memberType은 마스킹 대상이 아니라 골든이 값까지
> 대조하므로 여기서 다시 단언하지 않는다.

**이 테스트의 존재 이유 자체는 오히려 강해졌다** — 마스킹 키가 하나 늘어 골든이 값을 보지
않는 필드가 둘이 됐으므로, 폼→본문 결선을 잡는 곳이 이 테스트뿐이라는 사실이 더 확실해졌다.
다르게 원하시면 알려주십시오.

### 패리티 재개 조건도 다시 썼다 (`sign_in_page_test.dart:19`)

"skip만 떼면 된다"는 여전히 부정확했다. 실제 조건 3개를 명시했다:
1. `test/fixtures/requests/login.json` 존재
2. **골든이 STUDENT 로그인으로 캡처돼 있을 것** — `memberType`은 `kMaskedKeys`에 없어 값까지
   대조되는데 테스트는 `wrap()` 기본값 `'STUDENT'`로 요청한다. 트레이너 계정으로 캡처했다면
   골든을 다시 뜨거나 `wrap(memberType: 'TRAINER')`로 맞춰야 한다.
3. 그 둘이 맞으면 `skip: true` + 이름 접미사 제거. `userId`/`password`는 마스킹되므로 더미
   값을 그대로 둬도 통과한다.

---

## D1/D2/D3 — 공통 위젯 토큰 3건 교체 (+ 고정 테스트)

리뷰대로 기존 테스트가 틀린 값을 하나도 고정하지 않고 있었다. **먼저 고정 테스트를 써서
RED를 확인하고**, 그 다음 토큰을 바꿨다.

### RED — 틀린 토큰 대상

```
$ flutter test test/widget/app_layout_test.dart \
               test/shared/ui/app_button_test.dart \
               test/shared/ui/app_text_input_test.dart
00:00 +3 -1: app_button_test.dart: AppButton 라벨 타이포는 웹 TITLE_1_SEMIBOLD와 같다 [E]
00:00 +4 -2: app_text_input_test.dart: AppTextInput 라벨 타이포·색은 웹 TITLE_3 + text-gray-800과 같다 [E]
00:00 +23 -3: app_layout_test.dart: AppLayout 헤더 제목 타이포·색은 웹 HEADING_4_SEMIBOLD + gray-800과 같다 [E]
00:00 +25 -3: Some tests failed.
```
3개 전부 실패 = 새 테스트가 실제로 값을 고정한다(단언을 지우면 통과한다는 뜻).

### 교체

| # | 파일 | 변경 | 웹 근거 |
|---|---|---|---|
| D1 | `lib/widget/app_layout.dart` | `title1` → `heading4SemiBold` | `SignInPage.tsx:27` `HEADING_4_SEMIBOLD` (18px/130% semibold) |
| D2 | `lib/shared/ui/app_button.dart` | `title1` → `title1SemiBold` | `SignInForm.tsx:100` `TITLE_1_SEMIBOLD` (16px/140% semibold) |
| D3 | `lib/shared/ui/app_text_input.dart` | `gray700` → `gray800` | `SignInForm.tsx:50,74` `text-gray-800` |

각 줄에 웹 출처를 주석으로 남겼다. 테스트는 `TextStyle` **전체**를 비교하므로(값 동등성)
폰트 크기·굵기·행간·색이 한꺼번에 고정된다.

### GREEN

```
$ flutter test test/widget/app_layout_test.dart \
               test/shared/ui/app_button_test.dart \
               test/shared/ui/app_text_input_test.dart
00:00 +28: All tests passed!
```

---

## I1 — 기록된 수치가 자기 도구 출력과 달랐다

**원인:** 1차에서 `measure_expansion.sh`를 **`dart format` 이전에** 돌렸다. 포맷이
`sign_in_page.dart`를 183→187줄로 늘렸는데 문서에는 183 기준 1.39x가 박혔다.

**고친 방식 — 재발 방지까지.** 수치를 손으로 고치지 않고, 문서의 **모든 숫자가 스크립트
출력에서 나오도록** 절을 통째로 재생성했다. 커밋된 트리에서 커밋된 스크립트를 돌린 값이다.

```
$ ./tool/measure_expansion.sh
  Flutter sign_in_page.dart: 187줄 / 코드만 128줄
    ① 단순 비율                    187 / 177 = 1.06x
    ② 생략 보정(raw↔raw)           187 / 132 = 1.42x
    ③ 코드 라인만                   128 / 161 = 0.80x
    ④ 코드+생략 보정(code↔code)      128 / 118 = 1.08x
```
문서에 옛 수치(`1.39x`/`183 / 132`/`30,856`/`30,900`/`23,388`/`23,400`)가 남지 않았음을
grep으로 확인했다 — `OK: 옛 수치 잔여 없음`.

---

## I3 — 밴드로 기록 + 두 번째 데이터포인트

스크립트를 다시 써서 **네 항목을 전부 도구가 출력**하게 했다(문서가 다시 drift하지 않도록).

### 1. 밴드 + 명시적 라벨링

```
  작업량 proxy (④ code↔code) 1.08x → 약 24,100줄
  파일 볼륨   (② raw↔raw)   1.42x → 약 31,500줄
  ▶ 밴드: 약 1.08x–1.42x → 24,100–31,500줄
```
밴드 폭 **7,400줄 ≈ 주석**이며 그것이 **팀의 문서화 예산 선택**이지 마이그레이션 비용이
아니라는 문장을 스크립트·문서 양쪽에 넣었다. 1차 리포트가 "차이는 주석 규율"이라고
진단해놓고 주석 포함분(②)을 권고한 모순을 지적받았고, 그 지적이 옳다.

### 2. 주석 구성 분해 (도구가 직접 계산)

```
                           raw   code  comment  blank
  sign_in_page.dart        187    128       40     19
  웹 두 파일                 177    161        2     14
```
리뷰어 측정치와 일치한다. "이 파일의 주석 밀도는 주석 있는 Dart의 대표값도 아니다"(참조
화면 특유의 일회성 서술)도 함께 출력된다.

### 3. 두 번째 데이터포인트 3쌍 — 평균 금지, caveat 동반

**리뷰어가 준 수치를 옮겨 적지 않고 다시 쟀다.** D1~D3 주석 2줄씩이 더해져 Dart 쪽이
2줄씩 늘었기 때문이다(리뷰 시점 100/139/100 → 현재 102/141/102).

| 웹 | Flutter | 비율 | caveat |
|---|---|---|---|
| `button.tsx` 55 | `app_button.dart` 102 | **1.85x** | 웹이 `cva`로 나눈 variant 3개를 한 위젯에 접어넣음 |
| `layout.tsx` 76 | `app_layout.dart` 141 | **1.86x** | 웹 3슬롯 + 화면별 반복 헤더를 표준 헤더로 승격 |
| `TextInput.tsx`+`Input.tsx` 83 | `app_text_input.dart` 102 | **1.23x** | 웹 입력 5종 중 1종만 덮음 |

평균을 내지 말라는 지시를 코드 주석과 문서 양쪽에 명시했다. `src/shared`(.tsx)는
**2,285줄 / 22,257줄 = 10%** — 직접 세어 리뷰 수치와 일치 확인했다. 이 값들이 참조 화면
(1.42x)보다 **위쪽**을 가리킨다는 사실을 기록했다.

### 4. 방향성 caveat

> 생략한 45줄은 네비게이션·SVG 자산·토스트·웹뷰 브릿지 — Flutter에서 **가장 크게 팽창할
> 범주**다. 그걸 **뺀** 나머지로 잰 비율을 그 범주를 **포함한** 22,257줄 전체에 적용하므로,
> 외삽이 측정 영역 밖으로 나가며 **과소평가 방향**이다.

### 5. 리스트·캘린더 재측정 문구 — 유지

"Phase 3~5 착수 시 각 도메인 첫 화면에서 재측정할 것"을 그대로 뒀다.

---

## 검증 (커밋 직전)

```
$ ./tool/verify.sh
== dart format ==      Formatted 33 files (0 changed)
== flutter analyze ==  No issues found! (ran in 1.2s)
== har_to_golden.py 테스트 ==  Ran 14 tests — OK
== flutter test ==     00:02 +93 ~2: 2 skipped tests. / All other tests passed!
OK: 모든 검증 통과
```
Dart 90 → **93** 통과(+3 = 토큰 고정 테스트), skip 2 유지.

## 변경 파일 (`ae5d4d2`)

```
M  lib/shared/ui/app_button.dart        D2 토큰 + 근거 주석
M  lib/shared/ui/app_text_input.dart    D3 토큰 + 근거 주석
M  lib/widget/app_layout.dart           D1 토큰 + 근거 주석
M  test/harness/parity_matcher.dart     kMaskedKeys += userId (+ 사유 doc)
M  test/page/sign_in_page_test.dart     재개 조건·비중첩 근거 주석 정정
M  test/shared/ui/app_button_test.dart      D2 고정 테스트
M  test/shared/ui/app_text_input_test.dart  D3 고정 테스트
M  test/widget/app_layout_test.dart         D1 고정 테스트
M  tool/har_to_golden.py                MASKED_KEYS += userId
M  tool/measure_expansion.sh            밴드·주석분해·참고 3쌍·방향성 caveat
```
(`../MOBILE_MIGRATION_ANALYSIS.md` §3은 flutter/ 레포 밖이라 이 커밋에 없다.)

## 이월 확인 (지시대로 미수정)

D4/D5(버튼 `h-[44px]`·입력 `h-[50px]` vs 패딩 기반 ≈54px) → whole-branch 리뷰,
`app_test.dart:12` 정확 매치 취약성, D6(`s12` 48 vs 46), 로고 갭 대체,
`sign_in_page_test.dart`의 `pumpWidget` 미호출 skip 테스트 — 전부 손대지 않았다.
