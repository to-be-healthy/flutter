# `/select-gym` 이관 brief (2026-09-15)

웹 `src/app/(login-required)/select-gym/page.tsx` → Flutter. Phase 0 이후 첫
**로그인 필요** 화면이자, 로그인이 착지하던 자리표시자 셋 중 첫 번째를 뚫는 작업이다.

## 웹 원본

| 파일 | 줄 | 역할 |
|---|---|---|
| `page/mypage/ui/SelectGymPage.tsx` | 133 | step 1/2 상태, 등록 뮤테이션, 이동 |
| `feature/mypage/ui/SelectGym.tsx` | 60 | 헬스장 목록 + 선택 |
| `feature/mypage/ui/GymVerificationCode.tsx` | 55 | 제목 + OTP 6자리 |
| `shared/ui/input-otp.tsx` | 88 | `input-otp` 래핑 (입력 1개 + 슬롯 6개) |
| `entity/gym/*` | 50 | `GET /api/v1/gyms`, `POST /api/v1/gyms/{gymId}` |

## 흐름

| | STUDENT | TRAINER |
|---|---|---|
| step 1 제목 | "**다니시는** 헬스장을\n선택해주세요." | "**수업하시는** 헬스장을\n선택해주세요." |
| "다음" | 바로 등록 → `/student` | step 2로 (`authValue` 리셋) |
| step 2 | — | 뒤로가기 헤더 + OTP → "완료" → `/trainer/class-time-setting` |

등록 = `POST /api/v1/gyms/{gymId}`. **STUDENT는 바디 없음**, TRAINER는 `{joinCode}`.
성공 → `setGymId` → 이동. 실패 → `errorToast(서버 메시지)`.

## 파일

**신규**

```
lib/entity/gym/model/gym.dart                  Gym(gymId, name), data null → []
lib/entity/gym/api/gym_api.dart                list() / registerGym(gymId, joinCode?)
lib/shared/ui/app_otp_input.dart               숨긴 TextField 1개 + 슬롯 6개
lib/feature/gym/ui/gym_select_list.dart        선택 타일 목록
lib/feature/gym/ui/gym_verification_code.dart  제목 + OTP
lib/page/protected/select_gym_page.dart        step 상태
```

**수정**

- `AuthState.setGymId(int)` 신설 — `AuthUser` 재생성 → 프로필 저장 → `notifyListeners()`
- `app_router.dart` — `selectGym`을 실제 페이지로, `trainerClassTimeSetting` 라우트 추가,
  `/select-gym` 미로그인 게이트

## 틀리기 쉬운 지점

1. **성공 후 `context.go`가 필수다.** `_redirect`를 `/select-gym`에서 돌리면 splash 아님 →
   signIn 아님 → `isHome` false → **`null` 반환**이다. `notifyListeners()`만으로는 화면이
   넘어가지 않는다. 순서도 강제된다 — `setGymId` 완료(저장소 write까지) → `go`. 반대면
   `gymId == null`인 채 홈에 들어가 `isHome && gymId == null`에 다시 튕긴다.
2. **STUDENT POST는 바디가 없다.** 웹 axios는 `data === undefined`면 `Content-Type`을
   붙이지 않는데 dio는 붙이는 경향이 있다. 하네스 `CAPTURED_HEADERS`에 `content-type`이
   있으므로 실측해서 맞춘다.
3. **OTP는 입력 1개 + 슬롯 6개 렌더**다. TextField 6개로 만들면 붙여넣기·경계 backspace가
   달라진다.
4. **헬스장 타일에 `AppButton`을 재사용하지 않는다.** 80px·`gray100`·검정 `HEADING_4`·선택 시
   `border-2 primary500`이 기존 4개 variant에 없고, `backgroundKeyFor(label)`은 동명 헬스장
   둘이면 키가 충돌한다(`deferred-minors.md` 기록).
5. **`clickBack`은 `selectGymId`를 리셋하지 않는다**(`clickNext`는 `authValue`를 리셋).
   웹의 이 비대칭을 그대로 옮긴다.

## 명시적 이탈 2건

- **로딩 표시** — 웹은 `/images/loading.gif` 20×20 + `py-[200px]`. 자산이 없어
  `CircularProgressIndicator`로 대체한다. gif를 가져오면 `assets_test.dart` 목록 관리가
  붙는데 애니메이션 패리티는 검증 수단이 없다.
- **미로그인 게이트** — 웹 `(login-required)`에 `layout.tsx`가 없어 가드가 실제로는 없다.
  하지만 이 화면은 `auth.memberType`으로 분기하므로 Flutter에서는 null 크래시가 난다.
  `/sign-in` 이탈과 같은 패턴으로 라우터에 게이트를 둔다.

## 골든 전략 (사용자 결정, 2026-09-15)

- `GET /api/v1/gyms` → 정식 골든 `select-gym`. **첨부 완료**(2026-09-15).
  `har/select-gym.har` → `test/fixtures/requests/select-gym.json`.
- `POST /api/v1/gyms/{gymId}` 2건 → **골든 없음**. 그 계정의 소속 헬스장을 실제로 바꾸는
  공유 상태 뮤테이션이고, TRAINER `joinCode` 경로는 체험 계정으로 캡처가 불가능하다.
  `request_capture` 기반 계약 테스트로 고정하고 근거를 웹 소스 + `openapi/api-docs.json`으로
  주석에 명시한다.

## 백엔드 계약 (`openapi/api-docs.json` 실측)

- `GET /api/v1/gyms` → `ApiResultListGymResult`, `GymResult {gymId: int64, name: string}`
- `POST /api/v1/gyms/{gymId}` → 요청 `CommandSelectMyGym {joinCode: string}` (선택),
  응답 `CommandSelectMyGymResult {id: int64, name: string}`
- 둘 다 `AuthInterceptor._publicPaths`에 걸리지 않으므로 토큰이 붙는다(웹도 `authApi`)

## 가입 코드(joinCode) 실측 — 백엔드 + 웹 패키지

리뷰에서 "숫자 키보드가 웹과 다른 것 아니냐"는 지적이 나와 양쪽을 확인했다.
**결론: 지금 구현이 패리티다.**

- 웹 `input-otp`의 `inputMode` **기본값이 `'numeric'`**이고
  `GymVerificationCode`는 이 prop을 넘기지 않는다 → 모바일 웹도 숫자 키패드.
- 웹은 `pattern`을 주지 않는다 → **문자 자체는 거르지 않는다**(붙여넣기 포함).
  그래서 Flutter에도 숫자 필터를 넣지 않았다. 넣으면 웹이 받는 입력을 앱이 막는다.
- 백엔드는 `Utils.getAuthCode(6)` = `RandomStringUtils.randomNumeric(6)`,
  `Gym.joinCode`는 `@Column(length = 6)` → **숫자 6자리**.
- **서버 형식 검증은 없다.** `CommandSelectMyGym`에 Bean Validation 애노테이션이
  없고 컨트롤러에 `@Valid`도 없다. 저장값과 문자열 동등 비교만 한다 —
  형식 제약을 서버에 기대면 안 된다.
- 검증은 `MemberType.TRAINER`일 때만 호출된다(`GymCommandService`). STUDENT가
  joinCode 없이 등록하는 웹 분기와 일치한다.

"숫자 키보드 + 문자 필터 없음"은 **짝으로 의도된 것**이라
`app_otp_input_test.dart`가 둘을 함께 고정한다 — 한쪽만 보고 "일관성 있게"
필터를 넣는 수정을 막기 위해서다.

## 완료 기준

`./tool/verify.sh` 4/4 + `flutter analyze` clean(`--no-fatal-infos` 금지).
가드는 뮤테이션으로 확인하고, 원복은 문자열 역치환으로 한다.
