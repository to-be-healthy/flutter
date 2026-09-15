# 다음 세션 시작점 (2026-09-15 기준)

**이 파일부터 읽어라.** `progress.md`는 "왜 그렇게 결정했나"의 시간순 원장이고,
이 파일은 "이제 무엇을 하나"다. 둘의 역할이 다르다.

---

## 1. 지금 상태 한 줄

웹 라우트 **73개 중 7개** 이관 완료
(`/`·`/sign-in`·`/find/id`·`/find/pw`·`/select-gym`·**`/policy`**·
**`/sign-up/complete`**).
Dart 316 테스트 통과, `verify.sh` 4/4, `flutter analyze` clean.
브랜치 `feature/select-gym`, **커밋 안 됨**.

### 남은 구멍

로그인·헬스장 등록까지는 실제로 동작한다. 그 다음이 전부 자리표시자다 —
`/student`·`/trainer`·`/trainer/class-time-setting`.

### `/select-gym` 골든 — 첨부 완료 (2026-09-15)

`har/select-gym.har` → `test/fixtures/requests/select-gym.json`.
`GET /api/v1/gyms` 1건이고 `expectParity('select-gym', ...)`가 소비한다.

등록 `POST`는 **골든을 만들지 않았다** — 그 계정의 소속 헬스장을 실제로
바꾸는 공유 상태 뮤테이션이고, TRAINER `joinCode` 경로는 유효한 가입 코드가
없으면 캡처 자체가 불가능하다. 계약 테스트가 대신한다.

---

## 2. 바로 다음에 할 일 (권장 순서)

### ~~① `/select-gym`~~ — 완료 (2026-09-15)

`docs/select-gym-brief.md` 참고. 이관하며 알게 된 것 셋:

1. **`context.go`가 없으면 화면이 넘어가지 않는다.** `_redirect`를
   `/select-gym` 위치에서 돌리면 어느 규칙에도 걸리지 않아 `null`을 반환한다.
   `refreshListenable` 알림만으로는 부족하다 — 뮤테이션으로 확인했다
   (이동 테스트 3건이 함께 깨진다).
2. **`AppButton`의 높이·라벨 굵기를 열었다.** 웹 실측에서 버튼 높이가 화면마다
   다르다(`h-[48px]` 25회, `h-[57px]` 9회, `h-[44px]` 5회). 44는 로그인
   화면이 고른 값이지 컴포넌트 고유 치수가 아니었다. `AppButton.height`
   상수는 `AppButton.defaultHeight`로 이름이 바뀌었다.
3. **`pumpAndSettle`은 기본 100ms씩 시간을 진행시킨다.** 그보다 짧은 지연은
   한 pump에 통째로 삼켜져서, 경합을 재현하려는 테스트가 조용히 무력해진다
   (50ms 지연으로는 순서 뒤집기 뮤테이션이 잡히지 않았고 2초로 늘려야 잡혔다).
   비동기 순서를 고정하는 테스트를 쓸 때 기억할 것.

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

### ~~대안: 몸풀기~~ — 완료 (2026-09-15)

`/policy` 허브와 `/sign-up/complete`를 옮겼다. 실측 결론은
`docs/policy-screens-survey.md`에 있다.

**약관 본문 2개(`/policy/terms`·`/policy/privacy`)는 자리표시자로 남겼다.**
"싼 화면"이 아니었다 — 코드 줄 수(336·154)보다 **본문 15,000자 + `<li>` 157개 +
2단계 중첩 리스트**가 본체이고, `.policy-container` CSS를 옮기면 사실상 약관
문서 렌더러를 새로 만드는 일이다. 형식(Dart 위젯 직역 vs Markdown 에셋 vs
원격 fetch)을 먼저 정해야 한다 — 서베이 문서 §"결정이 필요한 것" 참고.

---

## 3. 화면 인벤토리 — 66개 남음

### 공개 (6개 남음 / 13개 중 7개 완료)

| 라우트 | 상태 | 비고 |
|---|---|---|
| `/` | ✅ | 온보딩 — 쿼리 없으면 역할 선택, `?type=`이면 로그인 수단 선택 |
| `/sign-in` | ✅ | |
| `/find/id` | ✅ | |
| `/find/pw` | ✅ | |
| `/select-gym` | ✅ | 골든 `select-gym`(GET 1건) |
| `/sign-up` | 자리표시자 | **5단계 누적형 퍼널** — 아래 주의 참고 |
| `/sign-up/complete` | ✅ | 요청 0건 |
| `/cs` | 자리표시자 | 고객센터 |
| `/invite` | 미착수 | 초대 링크 수락 |
| `/policy` | ✅ | 허브(링크 2행). 요청 0건 |
| `/policy/terms` `/policy/privacy` | 자리표시자 | **본문 15,000자** — 형식 결정 필요 |
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

## 4. 공용 컴포넌트 — 웹 21종 중 5종 완료

**완료:** `AppButton` · `AppTextInput` · `AppTextLink` · `AppToast` ·
**`AppOtpInput`**(웹 `input-otp`)
**`widget` 계층 완료:** `AppLayout`(Header/Contents/BottomArea)
**feature 계층:** `GymSelectList` · `GymVerificationCode`

> `AppOtpInput`은 **입력 하나 + 슬롯 6개 렌더**다(웹 `input-otp`와 같은 구조).
> `TextField` 6개로 만들면 붙여넣기와 슬롯 경계 backspace가 달라진다.

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

- **커밋·푸시 결정** — `feature/select-gym` 브랜치에 변경 9 + 신규 8이 있다.
  커밋·푸시는 **사용자가 요청할 때만** 한다(workspace CLAUDE.md).
- **`/select-gym`에 웹에 없는 게이트를 넣었다.** 웹 `(login-required)` 그룹에는
  `layout.tsx`가 없어 실제로 막는 것이 없지만, 이 화면이
  `auth.user!.memberType`으로 제목을 갈라서 그대로 두면 null 역참조로 죽는다.
  미로그인 접근을 온보딩으로 돌려보낸다(`app_router.dart` 주석에 명시).
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
12. **`AppLayout`의 `contents` 안에서 `Expanded`/`Flexible(flex)`를 쓸 수 없다.**
    셸이 본문을 `SingleChildScrollView`로 감싸 세로 제약이 unbounded라
    `RenderFlex children have non-zero flex but incoming height constraints
    are unbounded`로 터진다. 웹의 `h-full` + `justify-center`는 **높이 0짜리
    자식을 맨 위에 두고 `spaceBetween`**으로 재현한다 — 자식이 셋이면 남는
    공간이 두 등분되어 가운데 블록 위아래 간격이 같아진다
    (`sign_up_complete_page.dart` 참고).
11. **비동기 순서를 고정하는 테스트는 지연을 100ms보다 크게 잡는다.**
    `pumpAndSettle`이 기본 100ms씩 시간을 진행시켜서, 그보다 짧은 창은 한
    pump에 통째로 삼켜진다 — 뮤테이션을 넣어도 테스트가 그대로 통과해
    **가드가 있는 줄 알고 넘어간다.** 실측: 50ms는 안 잡히고 2초는 잡혔다
    (`app_test.dart`의 `_SlowProfileStorage`).

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
