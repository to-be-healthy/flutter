# 다음 세션 시작점 (2026-09-14 기준)

**이 파일부터 읽어라.** `progress.md`는 "왜 그렇게 결정했나"의 시간순 원장이고,
이 파일은 "이제 무엇을 하나"다. 둘의 역할이 다르다.

---

## 1. 지금 상태 한 줄

웹 라우트 **73개 중 4개** 이관 완료(`/`·`/sign-in`·`/find/id`·`/find/pw`).
Dart 238 테스트 통과, `verify.sh` 4/4, `flutter analyze` clean.
**커밋 안 됨**(변경 11 + 신규 20), **푸시 안 됨**(로컬 커밋 다수).

### 가장 눈에 띄는 구멍

로그인이 **자리표시자에 착지한다.** 로그인에 성공하면 `/student`·`/trainer`로
가는데 둘 다 `NotImplementedPage`이고, 헬스장 미선택 계정은 `/select-gym`으로
튕기는데 그것도 자리표시자다. 즉 **지금 앱은 로그인까지만 쓸 수 있다.**

---

## 2. 바로 다음에 할 일 (권장 순서)

### ① `/select-gym` — 막다른 길 뚫기

- 규모: 화면 133줄, 전이 UI 합계 ~317줄, API 2건(인증 필요)
- 새로 필요한 것: **OTP 스타일 입력** 1종 (토스트는 이미 있다)
- 왜 먼저인가: 신규 가입자가 로그인 직후 **처음 보는 화면**이다. 라우터의
  `gymId == null → /select-gym` 규칙(`app_router.dart`)이 이미 살아 있어서,
  이 화면만 채우면 그 경로가 실제로 연결된다.

### ② `/student` 홈 — 인프라를 한 번에 끌고 오는 화면

- 규모: 화면 469줄, 전이 UI 합계 **~1,133줄**, API **7건**
- 새로 필요한 컴포넌트: Card, Collapsible(애니메이션), Progress, BottomSheet,
  **하단 네비게이션**(트레이너 매핑을 비동기로 확인하는 탭 가드)
- 새로 필요한 인프라: **FCM**, **S3 presigned 업로드**, **dayjs `ko` 로케일**
- 여기서 한 번 크게 치고 나면 나머지 회원 화면 25개는 조립 작업이 된다.

> **홈을 옮길 때 반드시 확인할 것:** `StudentHomePage`의
> `PUT {presignedUrl}`은 `api`도 `authApi`도 아닌 **bare axios**다. 패리티
> 하네스가 캡처하는 dio 인스턴스 **밖으로 나가는 유일한 요청**이라,
> 하네스 경계를 다시 설계해야 한다.

> **이미 준비된 골든이 하나 있다.** `test/fixtures/requests/home-student.json`
> (GET 3건: `members/trainer-mapping`·`home/student`·`notification/red-dot`)이
> `har/home-student.har`에서 생성돼 있는데 **소비하는 테스트가 아직 없다.**
> 홈 화면을 만들면 `expectParity('home-student', ...)`로 바로 쓴다.

### 대안: 몸풀기가 필요하면 `/sign-up/complete`

55줄, **API 0건**, 새 컴포넌트 0개. 가장 싼 화면이다. 다만 `/sign-up`을
거치지 않으면 도달할 수 없어 단독으로는 가치가 낮다.

---

## 3. 화면 인벤토리 — 69개 남음

### 공개 (9개 남음 / 13개 중 4개 완료)

| 라우트 | 상태 | 비고 |
|---|---|---|
| `/` | ✅ | 온보딩 — 쿼리 없으면 역할 선택, `?type=`이면 로그인 수단 선택 |
| `/sign-in` | ✅ | |
| `/find/id` | ✅ | |
| `/find/pw` | ✅ | |
| `/select-gym` | 자리표시자 | **①번 권장 대상** |
| `/sign-up` | 자리표시자 | **5단계 누적형 퍼널** — 아래 주의 참고 |
| `/sign-up/complete` | 미착수 | 55줄, API 0건 |
| `/cs` | 자리표시자 | 고객센터 |
| `/invite` | 미착수 | 초대 링크 수락 |
| `/policy` `/policy/terms` `/policy/privacy` | 미착수 | 정적 약관 3개 |
| `/[provider]/callback` | 미착수 | 소셜 로그인 콜백 (네이버·구글·카카오·애플) |

### 회원 student (26개 남음)

홈 · 알림 · 커뮤니티(2) · 수강내역 · 식단(4) · 로그(2) · 마이페이지(9) ·
포인트내역 · 일정 · 운동기록(4)

### 트레이너 trainer (34개 남음)

홈 · 알림 · 수업시간설정 · 커뮤니티(2) · **회원관리(15)** · 마이페이지(7) ·
일정(3) · 회원추가(2) · 피드백 · 초대

> 트레이너 `manage/[memberId]/*` 15개는 회원 쪽 화면과 구조가 겹친다.
> 회원 화면을 먼저 끝내면 여기가 싸진다.

---

## 4. 공용 컴포넌트 — 웹 21종 중 4종 완료

**완료:** `AppButton` · `AppTextInput` · `AppTextLink` · `AppToast`
**`widget` 계층 완료:** `AppLayout`(Header/Contents/BottomArea)

**미구현 (웹 `src/shared/ui`):**
`card` · `collapsible` · `progress` · `sheet`(바텀시트) · `alert-dialog` ·
`dialog` · `calendar` · `select` · `tabs` · `switch` · `textarea` ·
`carousel` · `scroll-area` · `time-swiper` · `generic-form` ·
`dropdown-menu` · `separator`

**미구현 (웹 `src/widget`):**
`navigation`(하단 탭) · `month-picker` · `week-picker` · `rolling-banner` ·
`image-slide`

**부분 완료:** `toast` — `errorToast`만 옮겼다. `successToast`는 부르는 화면이
없어 의도적으로 보류했다(`check.svg`에 `fill` 오버라이드를 거는 방식을
추측으로 옮기면 검증할 길이 없다). 쓰는 화면이 생기면 그 화면의 렌더를 보고 추가.

---

## 5. 인프라 — 화면보다 이쪽이 무겁다

| 항목 | 상태 | 메모 |
|---|---|---|
| **FCM 푸시** | 미착수 | 서비스워커·VAPID·딥링크. 기존 `webview` 레포가 하던 일이라 참고 구현이 있다 |
| **S3 presigned PUT** | 미착수 | bare axios — **패리티 하네스 경계 밖**. 홈과 함께 설계 |
| **dayjs `ko` 로케일 + `customParseFormat`** | 미착수 | 일정·캘린더 전반. Flutter는 `intl` 도입 여부를 먼저 결정해야 한다 |
| **401 리프레시** | 미착수 | 아래 주의 |
| **누적형 퍼널** | 미착수 | 아래 주의 |

### 401 리프레시 — 웹을 그대로 옮기면 안 된다

웹 구현에 결함이 **두 개** 있다: ① 갱신 후 **원 요청을 재시도하지 않는다**
② 인터셉터 안에서 React 훅을 부른다. 그대로 옮기면 결함까지 옮긴다.
**제품 판단이 필요하고 HAR도 없다** — 옮기기 전에 사용자와 상의할 것.
현재 `AuthInterceptor`는 토큰 부착만 하고 401을 처리하지 않는다.

### `/sign-up` 퍼널 — 구조를 오해하면 다른 화면이 된다

`useSignUpFunnel`의 `children.filter(child => child.props.id <= step)`가
스텝을 **교체가 아니라 누적**시킨다. step 5에서는 **다섯 필드 블록이 한
화면에 쌓인 채** 단일 `FormProvider` 안에 공존한다. `PageView`나 라우트
push로 옮기면 **원본과 다른 화면이 된다.**
`clickBack`도 단순 pop이 아니다(step 4 → step 2로 점프하며 이메일·아이디
인증 플래그를 리셋).

또 하나: `GET /api/v1/auth/invitation/uuid`는 `(login-unrequired)` 그룹인데
**`authApi`**를 쓴다(토큰이 주입된다). 앱에서 그대로 따를지 결정 필요.

---

## 6. 부채 · 미결

- **커밋·푸시 결정** — 워킹트리에 변경 11 + 신규 20이 있고, 로컬 커밋은 한 번도
  푸시되지 않았다. 커밋·푸시는 **사용자가 요청할 때만** 한다(workspace CLAUDE.md).
- **`AuthState.signOut()`의 프로덕션 호출부가 0개다.** Phase 0에서
  `writeTokens` 호출부가 0개였던 것과 **정확히 같은 냄새**이고, 그건 실제
  버그였다(로그인해도 토큰이 저장되지 않았다). 마이페이지 화면이 생기면 해소된다 —
  그때까지 이 사실을 잊지 말 것.
- **`home-student.json` 골든이 소비되지 않는다.** 위 ②번에서 해소.
- **디자인 검수 3건** — 전부 "웹이 색을 지정하지 않아서 나온 값" 부류다:
  1. 헤더 제목 색: 웹 `#020817`(shadcn 기본 foreground) vs Flutter `gray800 #2E3134`
  2. 입력 에러 문구 굵기: 찾기 화면 `BODY_4_MEDIUM`(500) vs 로그인 `BODY_4`(400) —
     웹 안에서 이미 갈려 있고, 공용 컴포넌트는 400을 골랐다
  3. 입력 라벨 색: 찾기 화면은 미지정(`#020817`) vs 로그인 `text-gray-800`
- **디바이스에서 못 본 것:** 찾기 결과 화면 3분기(아이디 카드·`love_letter.svg`·
  소셜 아이콘 4종)와 토스트. 서버 응답이 있어야 뜨는데 시뮬레이터에 텍스트를
  자동 입력할 방법이 없다. **자산 파싱은 `test/shared/assets_test.dart`가 닫았지만
  배치·색은 미확인.**
- **물리 기기 확인** — 시뮬레이터가 재현하지 않는 것: 실제 폰트 힌팅,
  터치 타깃 체감, 저사양 성능.
- `deferred-minors.md`의 Phase 0 이월 항목 — 일부는 이미 해결됐다(Task 7의
  `border:` 건). 다시 훑을 때 해결된 것을 지울 것.

---

## 7. 지켜야 할 규율 (새 세션이 모르면 어긋난다)

1. **패리티 하네스가 이 프로젝트의 중심이다.** 화면을 옮기면 HAR을 캡처하고
   (`tool/har_to_golden.py`) 골든을 만들어 `expectParity`로 대조한다.
   절차는 `har/README.md`.
2. **화면 하나에 HAR 하나.** 로그인 성공 후 홈이 쏘는 요청까지 한 HAR에 담으면
   로그인 화면 테스트가 자기가 보내지도 않는 요청을 "누락"으로 잡는다.
3. **화면 테스트에 라우터를 끼우지 않는다.** 같은 이유다. 라우팅 동작은
   `test/app_test.dart`에서 본다.
4. **웹의 임의값(`[Npx]`)은 스케일로 반올림하지 않고 상수로 옮긴다.**
   스케일 클래스(`mb-8`·`gap-y-3`)는 토큰. 기계적 규칙이라 62개 화면에
   복사해도 흔들리지 않는다.
5. **Tailwind 커스텀 스케일은 비선형이다.** `1:4 2:6 3:8 4:10 5:12 6:16 7:20
   8:24 9:28 10:32 11:36 12:48`. `theme.extend` 안이라 목록에 없는 키
   (`gap-y-2.5` 등)는 **Tailwind 기본값이 그대로 산다.** `h-8`·`p-4` 같은
   크기·패딩 클래스도 이 스케일을 탄다(`h-8` = 32가 아니라 **24**).
6. **가드를 추가하면 뮤테이션으로 확인한다.** 원복은 **문자열 역치환** —
   `git checkout <파일>`은 같은 파일의 커밋 전 작업까지 되돌린다.
7. **완료 기준은 `./tool/verify.sh` 4/4.** `flutter analyze`에
   `--no-fatal-infos`를 붙이지 않는다.
8. **위젯 테스트의 "파싱됨"은 "보인다"가 아니다.** SVG는 파싱에 실패해도
   예외 없이 빈 상자로 렌더된다. 자산을 추가하면
   `test/shared/assets_test.dart`의 목록에도 넣어라.
9. **디바이스 확인은 `--dart-define=INITIAL_LOCATION=/경로`로 바로 연다.**
   ```sh
   flutter run -d <device> --dart-define=INITIAL_LOCATION=/find/id
   ```
10. **커밋·푸시는 사용자가 요청할 때만.**

---

## 8. 문서 지도

| 파일 | 내용 |
|---|---|
| **`next-steps.md`** (이 파일) | 다음에 무엇을 하나 |
| `progress.md` (360줄) | 결정과 근거의 시간순 원장. **왜** 그렇게 했는지는 전부 여기 |
| `har/README.md` (추적됨) | HAR 캡처·골든 생성 절차, 화면별 HAR 표, 재캡처 주의 |
| `deferred-minors.md` | Phase 0 리뷰 이월 항목 (일부 해결됨) |
| `next-screens-survey.md` | **낡음** — find/id·find/pw를 고른 문서이고 그 작업은 끝났다. 6개 후보 실측표만 참고 가치가 있다 |
| `task-*-brief.md` / `task-*-report.md` | Phase 0 태스크별 상세. 필요할 때만 |
| `screenshots/` | 01~07. 원장의 픽셀 수치가 어디서 나왔는지 추적용 |

이 문서들은 원래 `.superpowers/sdd/`(gitignore 대상)에 있어 **커밋되지 않았다** —
워크트리를 지우거나 다른 머신에서 열면 사라지는 상태였다. 2026-09-14에
`docs/`로 옮겨 추적 대상으로 만들었다.

리뷰용 `.diff` 17개(864K)는 **일부러 옮기지 않았다.** 커밋 사이의 `git diff`라
`git diff <sha>..<sha>`로 언제든 재생성되고, 백엔드 OpenAPI 스펙 덤프의
예시 자격증명(아이디·비밀번호·이메일)을 품고 있어 추적되는 문서에 넣을
이유가 없다. 필요하면
`.superpowers/sdd/2026-09-13-flutter-migration-phase0/`에 그대로 있다.
