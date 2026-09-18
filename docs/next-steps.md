# 다음 세션 시작점 (2026-09-18 기준)

**이 파일부터 읽어라.** `progress.md`는 "왜 그렇게 결정했나"의 시간순 원장이고,
이 파일은 "이제 무엇을 하나"다. 둘의 역할이 다르다.

---

## 1. 지금 상태 한 줄

웹 라우트 **73개 중 23개** 이관 완료
(`/`·`/sign-in`·`/find/id`·`/find/pw`·`/select-gym`·`/policy`·
`/sign-up/complete`·`/student`·`/trainer`·`/student/mypage`·
`/student/mypage/info`·`/student/mypage/leave`·
`/student/mypage/edit/password`·`/student/mypage/edit/name`·
`/student/mypage/alarm`·`/student/mypage/trainer-info`·
`/student/mypage/edit/email`·`/student/mypage/last-reservation`·
`/trainer/manage`·`/trainer/manage/[memberId]`·
`/trainer/manage/[memberId]/course-history`·
`/trainer/manage/[memberId]/point-history`·
**`/trainer/manage/[memberId]/reservation`**).
**회원 마이페이지 9개가 전부 끝났고, 트레이너 회원관리 계열 19개 중
다섯이 열렸다.**
Dart 973 테스트 통과, `verify.sh` 4/4, `flutter analyze` clean.

### 로그인 착지점이 전부 닫혔다

`/select-gym` → `/student` → `/trainer` 셋 다 실제 화면이다. **두 역할 모두
로그인해서 자기 홈을 본다.** 남은 자리표시자는 홈에서 나가는 경로들
(회원 10개 · 트레이너 7개)과 `/trainer/class-time-setting`이다.

### 두 홈 다 Phase A까지다

진입 렌더 + 골든 대조까지 끝냈고 **Phase B가 남아 있다**:

| | 남은 것 |
|---|---|
| `/student` | FCM 토큰 등록 · 식단 바텀시트 + S3 presigned 업로드 |
| `/trainer` | FCM 토큰 등록 · 회원 추가 모달 · 수강권 지급 모달 + `PATCH /course/{id}` |
| 공통 | 401 리프레시 |

경계와 근거는 `docs/student-home-brief.md`·`docs/trainer-home-brief.md`.
FCM 블록은 웹에서 **두 화면에 60줄 그대로 복붙**돼 있어(변수명 하나 차이)
한 번 옮기면 둘 다 해결된다.

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

### ~~② `/student` 홈~~ — Phase A 완료 (2026-09-15)

`docs/student-home-brief.md` 참고. 이관하며 알게 된 것 넷:

1. **골든이 Phase 경계를 정했다.** `GET /api/v1/members/trainer-mapping`은
   홈이 아니라 **하단 네비가** 쏜다(웹 쿼리에 `enabled`가 없어 마운트 즉시).
   네비를 Phase B로 미루려 했지만 그러면 요청이 2건이라 `expectParity`가
   떨어진다. **화면을 쪼갤 때 골든의 요청 목록을 먼저 확인할 것.**
2. **`fill="current"`는 flutter_svg에서 아이콘을 통째로 지운다.** 브라우저는
   유효하지 않은 표현 속성을 무시하고 부모 값을 상속하지만 flutter_svg는
   "칠하지 않음"으로 처리한다. `assets_test.dart`의 컴파일 테스트는 이 상태를
   **그대로 통과시킨다.** 아래 규율 #13 참고.
3. **요청 순서는 웹 메커니즘이 아니라 골든으로 맞춘다.** 웹의 순서는 React
   effect가 자식부터 실행되는 결과인데 Flutter `initState`는 부모가 먼저다.
   호출 개시 순서를 명시적으로 고정한다(`addPostFrameCallback`).
4. **웹 TS 타입이 계약과 다르다.** `HomeDataResponse`가 일곱 필드를 전부
   non-optional로 선언하지만 소비 측은 네 필드를 런타임 가드한다. **선언이
   아니라 소비 측 가드를 보고 nullable을 정하라.**
5. **위젯 테스트 기본 뷰포트(800×600)는 실기기 폭이 아니다.** 실기기는
   논리 폭 ~390이고 **오버플로는 좁은 쪽에서 산다.** 800px에서 전부 통과한
   화면이 390pt에서 35px 넘쳤다. 아래 규율 #14 참고.

### ~~③ `/trainer` 홈~~ — Phase A 완료 (2026-09-15)

`docs/trainer-home-brief.md` 참고. 이관하며 알게 된 것 셋:

1. **골든을 먼저 뜬 것이 설계를 바로잡았다.** 학생 홈과 같은 모양일 거라
   가정했는데 1번이 `members/trainer-mapping`이 아니라 `members/me`였다 —
   트레이너 네비에는 쿼리 훅이 없어 **요청을 쏘지 않는다.** 그래서 학생
   홈의 `addPostFrameCallback` 순서 맞추기가 여기서는 불필요했다.
   **화면을 옮기기 전에 골든부터 떠라.**
2. **뮤테이션이 테스트의 구멍을 찾았다.** 하이라이트 단언이 "하나뿐"만
   보고 **어느 카드인지**를 안 봐서, 정렬을 고치는 뮤테이션을 통과시켰다.
   규율 #11의 교훈이 다시 나온 것이다 — 가드가 아니라 테스트를 의심하라.
3. **규율 #12에 두 화면 연속으로 걸렸다.** `Row`에
   `CrossAxisAlignment.stretch`를 주면 `AppLayout` 아래에서는 무조건 터진다.
   웹의 `h-full`/`grid`는 **부모 높이가 이미 정해져 있어서** 되는 것이다.

### ④ 완료 — 회원 마이페이지 계열 (9개 전부)

**웹 실측이 끝났다: `docs/student-mypage-survey.md`(722줄).** 화면별 요청,
백엔드 계약 대조, 웹 버그 24건, 스타일·아이콘 실측, 이관 순서가 들어 있다.
**이 계열을 건드리기 전에 그 문서부터 읽어라.**

골든 2건은 이미 떠 있다:

| 골든 | 요청 | 비고 |
|---|---|---|
| `mypage-student` | `members/trainer-mapping` → `members/me` | 1번은 하단 네비가 쏜다 |
| `mypage-student-info` | `members/me` | 네비가 없어 1건 |

**두 화면 다 `notification/red-dot`을 부르지 않는다** — 헤더에 알림 종이
없다. 홈 골든과 다른 점이다.

라우터에 하위 8개 경로를 자리표시자로 등록해 뒀다(`app_test`가 등록 여부를
확인한다). 순서는 서베이 §7을 따른다:

| 순 | 화면 | 상태 |
|---|---|---|
| 1 | **허브** `/student/mypage` | ✅ 완료 (2026-09-15) |
| 2 | **`info`** | ✅ 완료 (2026-09-15). 사진 업로드·드롭다운은 Phase B |
| 3 | **`leave`** | ✅ 완료 (2026-09-15). 확인 다이얼로그는 **공용으로 올리지 않았다** |
| 4 | **`edit/password`** | ✅ 완료 (2026-09-15). 입력 상자는 **아직 사설**이다 |
| 5 | **`edit/name`** | ✅ 완료 (2026-09-15). 입력 상자를 `AppPlainInput`으로 승격했다 |
| 6 | **`alarm`** | ✅ 완료 (2026-09-15). BUG-1을 **뮤테이션으로 지킨다** |
| 7 | **`trainer-info`** | ✅ 완료 (2026-09-15). BUG-10을 **뮤테이션으로 지킨다** |
| 8 | **`edit/email`** | ✅ 완료 (2026-09-15). **`/auth/validation/` 공개 경로 누락을 여기서 메웠다** |
| 9 | **`last-reservation`** | ✅ 완료 (2026-09-15). `AppMonthPicker` 신규, 시트 둘 |

**`AuthState.signOut()`의 호출자 0개(§6)는 `info`에서 풀렸다** — 로그아웃
버튼이 거기 있다. 남은 Phase B는 프로필 사진 업로드·삭제와 그것을 여는
카메라 드롭다운뿐이다(버튼은 그렸고 눌러도 아무 일도 하지 않는다).

### ⑤ 진행 중 — `/trainer/manage` 계열 19개 (2/19 완료)

서베이는 `docs/trainer-manage-survey.md`(1,825줄), S1 픽셀 실측은
`docs/trainer-manage-s1-measurements.md`다.

| 화면 | 상태 |
|---|---|
| **S1 `/trainer/manage` 나의 회원** | ✅ 완료 (2026-09-16) |
| **S2 `[memberId]` 회원 정보** | ✅ 완료 (2026-09-16) |
| **S3 `[memberId]/course-history` {name}님 수강권** | ✅ 완료 (2026-09-18) |
| **S4 `[memberId]/point-history` {name}님 포인트** | ✅ 완료 (2026-09-18) |
| **S5 `[memberId]/reservation` {name}님 예약 내역** | ✅ 완료 (2026-09-18) |
| S6~S19 (14개) | 자리표시자 — 라우트만 등록됨 |

S2 픽셀 실측은 `docs/trainer-manage-s2-measurements.md`(822줄),
S3는 `docs/trainer-manage-s3-measurements.md`, S4는
`docs/trainer-manage-s4-measurements.md`, S5는
`docs/trainer-manage-s5-measurements.md`다.

#### 서베이 권장 순서를 두 가지 바꿨다

1. **Phase 0(공용 위젯 4개 선행)을 건너뛴다.** 서베이는
   `AppBottomSheet`·`AppAlertDialog`·`AppDropdownMenu`·`AppTextarea`를 먼저
   만들라고 권한다. 이 프로젝트의 규칙은 **두 번째 사용처가 생길 때 승격**
   (`AppPlainInput`이 그렇게 만들어졌다)이고, 사용처 없이 만든 위젯은 실제
   화면을 만나면 어차피 모양이 바뀐다. S1에서 드롭다운과 다이얼로그를
   **화면 안 private 위젯으로** 만들었다 — 두 번째 화면이 같은 것을 쓰면
   그때 `lib/shared/ui`로 올린다.
2. **S14가 아니라 S1부터 시작했다.** 골든이 이미 잡혀 있고(`trainer-manage`),
   계열의 진입점이며, 사용자가 "첫 화면부터"라고 지정했다.

#### S2에서 드러난 것 — 공용 승격 세 건

**두 번째 사용처가 생겨 올린 것들이다.** Phase 0을 건너뛴 판단이 여기서
값을 했다 — 무엇이 같고 무엇이 다른지를 **실측으로 알고** 만들었다.

| 위젯 | 첫 사용처 | 두 번째 | 확인한 것 |
|---|---|---|---|
| **`AppDropdownMenu`** | S1 정렬 | S2 케밥 | 폭·위치만 다르고 패딩 4·라운드 8·테두리·그림자·항목 45·간격 0·글꼴이 전부 같다 |
| **`AppCheckbox`** | 회원 탈퇴 | S2 환불 시트 | 20 / 15×12 / `rounded-sm` / gray300 / primary500 — 상수까지 같다 |
| **`AppToastController.showSuccess`** | (없음) | S2 환불 삭제 성공 | 에러 토스트와 **아이콘만** 다르다 |

**다이얼로그는 올리지 않았다.** 웹에서 아예 다른 컴포넌트다 — 회원 탈퇴는
`Dialog`(폭 320, `p-7`, 제목+본문, 버튼 높이가 내용으로), S2는
`AlertDialog`(폭 400, `px-7 py-11`, 제목만 가운데, 버튼 `h-12` 고정).
공통이 라운드와 테두리색뿐이라 합치면 옵션만 늘어난다.

**공유 백엔드 DTO도 함께 올렸다.** `entity/home/model/student_home.dart`가
사실 공유 DTO 묶음이었다(S2가 11개 선언 중 8개를 쓴다) →
`entity/course/` · `entity/point/` · `entity/diet/`로 분리하고
파일 전용 `_asInt`를 `core/json/json_number.dart`로 올렸다.

#### S1에서 정한 것

- **BUG-41(가입 배지가 전원에게 붙는다)은 버그째 옮겼다.** 서베이는
  "사용자 확인 필요"로 남겼지만, `/student` 홈에서 이미 정한 "웹 버그는
  그대로 옮기고 기록한다"가 답한다. 브라우저 실측에서도 `isNonmember`가
  `false`/`true`인 두 회원 모두 배지를 달고 있었다.
- **BUG-22(검색어만 소문자화)도 그대로 옮겼다.**
- **요청 실패는 "회원 0명"이 아니다.** 웹 `data`가 `undefined`로 남아
  `등록된 회원이 없습니다.`가 아니라 `검색 결과가 없습니다.`가 뜬다.
  화면이 `_received`로 그 둘을 가른다.

#### S3에서 나온 것 — 서베이가 틀렸던 두 가지

실측 전문은 `docs/trainer-manage-s3-measurements.md`. **서베이만 믿었으면
둘 다 틀렸을 것이다.**

1. **헤더 `+`는 "만료일 때만"이 아니다.** 웹 조건이
   `course?.totalLessonCnt === course?.completedLessonCnt`라 **수강권이 없으면
   `undefined === undefined` → true**다. 즉 만료·수강권없음·**로딩중**(아직
   데이터가 없다) 셋 다 렌더된다. 서베이는 "만료일 때만"이라고 적었다.
   앱은 `course == null || course.isExpired` 한 줄로 그 셋을 옮겼고,
   뮤테이션 M1이 두 테스트로 잡는다.
2. **빈 목록은 `[]`이지 `null`이 아니다**(실측). 웹 타입 선언과 화면 가드가
   `null`을 상정해서 서베이도 그렇게 적었는데, 실서버는 빈 배열을 준다.
   **양쪽 다 파싱한다.**

그리고 **와이어 키는 `isLast`가 맞았다** — Java `boolean isLast`의 빈 게터가
`last`로 직렬화되는 흔한 함정에 걸리지 않았다. 추측이 아니라 실측으로 확인했고
모델 테스트가 `last`로는 읽히지 않는다는 것까지 고정한다.

#### 골든을 뜰 때 토큰이 살아 있는지 먼저 보라

첫 캡처가 **401 → `POST /auth/refresh-token` → 재요청** 3건이었다. 그대로
골든을 떴으면 앱(401 리프레시 없음)이 매번 2건 누락으로 떨어진다. 한 번
진입해 토큰을 갱신시킨 뒤 다시 캡처했다 — `har/README.md`에 적었다.

> 부수 소득: 웹 401 경로를 실제로 봤다. **갱신 뒤 원 요청이 재시도된다** —
> §5가 "재시도하지 않는다"고 적어 둔 것과 다르다(인터셉터가 아니라 React
> Query 쪽에서 나가는 것으로 보인다). 401 리프레시를 옮길 때 이 실측을
> 근거로 다시 판단할 것.

#### 승격하지 않은 것 둘, 승격한 것 하나

- **삭제 알럿을 공용으로 올리지 않았다.** S2 알럿과 상자(폭 400·패딩 36/20·
  라운드 8·제목~버튼 34·버튼 48·간격 8)는 같지만 **버튼이 다르다**:
  S2는 `TITLE_1_SEMIBOLD`(600) + `flex`라 테두리 탓에 폭이 175.55/174.45로
  어긋나고, S3는 `text-base font-normal`(16/24/400) + `grid grid-cols-2`라
  **175/175 균등**이다(둘 다 실측). 올리면 글꼴과 폭 분배를 옵션으로 받아야
  해서 회원 탈퇴 `Dialog` 때와 같은 판단을 했다. **네 번째가 생기면 상자만
  올리는 것을 재검토한다.**
- **시트는 반대로 하나로 합쳤다.** 등록 시트와 추가 시트를 각각 재 보니
  **치수가 완전히 같고 제목·버튼 문구 둘만 다르다**(420×233.4, 패딩
  24/20/28/20, 입력 100×57, 버튼 380×52). 파라미터 둘짜리 사설 위젯 하나다.
- **`CourseCardHeader`·`CourseCardContent`를 공개했다.** 웹도 이 둘을
  `CourseCard` 컨테이너 안에 조합해 쓴다 — S3는 포인트 바 없이 둘만 쓴다.

#### BUG-9은 도달 불가다

웹이 `Number(course?.courseId)`로 만들어 수강권이 없으면 `NaN`이 되지만,
그 값을 쓰는 두 버튼(`수업 횟수 추가`·`수강권 삭제`)이 **`course &&` 분기
안에만 있다.** 수강권이 없을 때 눌리는 것은 `courseId`가 없는 등록(POST)뿐이다.
Dart에 `NaN` 대응물을 만들지 않았다 — 만들면 웹에 없는 경로가 된다.

#### S4에서 나온 것 — 서베이 정정 세 건, 전부 실측이 잡았다

실측 전문은 `docs/trainer-manage-s4-measurements.md`.
**서베이가 "S3와 동일 형태"라고 적은 화면인데 셋이 달랐다.**

1. **요청이 3건이고 순서가 추론과 반대였다.** 서베이는 화면 본체 →
   네비로 추론하고 `(추론)`을 달아 뒀는데, 실제로는
   **`members/trainer-mapping`(학생 하단바)이 1번**이다. 두 번 캡처해
   확인했다. 학생 홈에서 겪은 것과 같은 함정이라 같은 해법
   (`addPostFrameCallback`)을 썼고, 뮤테이션 M10이 골든으로 잡는다.
2. **BUG-14는 버그가 아니었다.** `text-blue-100`이 "생성되지 않는다"고
   적혀 있었지만 실측 색이 `rgb(219,234,254)`(Tailwind 기본 `blue-100`)다.
   `tailwind.config.js`의 `colors.blue`가 **`theme.extend` 안**이라 기본
   팔레트를 덮어쓰지 않고 병합한다. **규율 #5가 스페이싱에 대해 말한 것과
   같은 규칙인데 서베이가 색에는 적용하지 않았다** — 색 토큰도 같은 눈으로
   읽어라.
3. **내역 날짜의 굵기가 S3와 다르다.** S3는 `BODY_4_MEDIUM`(500),
   S4는 `BODY_4`(400)다. "동일 형태"를 믿고 위젯을 공유했으면 틀린 채
   통과했을 것이다.

#### 헤더 X가 뒤로가기가 아니다

웹이 `<Link href='./'>`라 **현재 경로의 디렉터리**로 간다 —
`/trainer/manage/6/point-history` → `/trainer/manage/6`. 눌러서 확인했다.
그리고 그 링크는 폭이 400인데 **제목이 위에 그려져 가운데가 안 눌린다**
(playwright 클릭이 `intercepts pointer events`로 실패해서 드러났다).
**rect가 겹친다고 눌리는 게 아니다.**

> Flutter도 `Stack`에 같은 순서로 넣으면 **저절로 같은 동작**이 된다.
> 처음엔 `AbsorbPointer`로 감쌌는데 **뮤테이션이 그것을 통과시켜서**
> 불필요하다는 게 드러났고, 걷어냈다. 순서를 뒤집는 뮤테이션은 잡힌다.

#### 페이징 봉투를 공용으로 올렸다

S3와 S4의 응답 봉투가 **완전히 같았다**(`content`·`isLast`·`pageNumber`·
`mainData`, `mainData`만 다름). 두 번째 사용처가 생겨
`core/json/paged_response.dart`로 올렸고 두 화면이 그것을 쓴다.
계열에 페이징 화면이 더 남아 있다(S5·S8·S16·S18).

#### S5에서 나온 것 — `twSelector`가 만든 클래스는 생성되지 않는다

**새 웹 버그를 찾았다.** 활성 탭이 `HEADING_5`(600)여야 하는데 실측이 400이다.
`shared/utils/tw-utils.ts`의 `twSelector`가 **런타임에** 클래스 문자열을
조립해서(`data-[state=active]:font-semibold`) Tailwind JIT이 스캔하지 못하고,
결국 CSS가 생성되지 않는다. **같은 버튼의 `data-[state=active]:bg-primary-500`은
소스에 리터럴로 적혀 있어 먹는다** — 한 버튼 안에서 리터럴은 되고 런타임
조립은 안 되는 것이 증거다.

`twSelector`는 9개 파일에서 쓰이는데 나머지 8곳은 전부 `placeholder:` 변형이라
입력 자체 타이포를 상속해 **시각적 차이가 없다.** 실제로 드러나는 곳은 S5
활성 탭 하나다. **두 탭 모두 400으로 그렸고 뮤테이션 M20이 지킨다.**

> **S4의 BUG-14와 짝이다.** 거기서는 "클래스가 생성되지 않는다"는 서베이
> 주장이 **틀렸고**(extend라 기본값이 살아 있었다), 여기서는 **맞다**.
> 둘 다 실측으로만 갈렸다 — Tailwind 관련 주장은 재 보고 판단할 것.

#### 노쇼 동사는 반대다 — 뮤테이션으로 지킨다

`DELETE /schedule/no-show/{id}`가 **노쇼 처리**, `POST`가 **해제**다.
웹이 올바르게 쓰고 있고 그대로 옮겼다. **동사를 뒤집는 뮤테이션(M19)이 두
테스트로 잡힌다** — 이 계열에서 가장 사고나기 쉬운 자리라 계약 테스트를
양방향으로 두었다.

#### 예약 카드를 공용으로 올렸다

회원 지난 예약(`/student/mypage/last-reservation`)의 카드와 **치수가 같았다**
(패딩 16/20 · 라운드 12 · 날짜 `TITLE_3` gray-600 · `gap-y-2` 6 ·
시간 `TITLE_1_BOLD` · `ml-2` 6). `feature/schedule/ui/reservation_card.dart`로
올리고 오른쪽 슬롯만 파라미터로 받는다 — 지난 예약은 배지, 트레이너
"다가오는 예약"은 체크 아이콘이다. 회원 화면 테스트 27개가 그대로 통과했다.

**시트는 합치지 않았다** — 회원 쪽은 `pt-[48px]`에 버튼이 `확인` 하나,
S5는 `pt-7`(20)에 X가 제목 줄 오른쪽이고 버튼이 둘이다.

#### 제목이 통째로 사라진다

웹이 `{name && `${name}님 예약 내역`}`이라 쿼리 `name`이 없으면
**`님 예약 내역`조차 렌더되지 않는다**(실측: h2가 0×0). 그대로 옮겼고,
그래서 `app_test`는 이 화면의 도착을 **탭 라벨로** 확인한다.

#### 남은 후보(계열이 끝나면 다시 고른다)

| 후보 | 규모 | 메모 |
|---|---|---|
| 회원 식단(4) · 운동기록(4) · 로그(2) | 중~대 | 홈 카드에서 나가는 경로들. **BUG-45 업로드 계약 불일치**가 섞여 있다 |
| 커뮤니티(2) | 중 | 목록 + 상세 |
| FCM (두 홈 공통 Phase B) | 소~불명 | **웹 동작 여부 확인이 선행**(아래) |
| 401 리프레시 | 소 | `trainer-info` 캡처에서 웹이 실제로 하는 것을 봤다 — 앱에는 아직 없다 |

**다음에 무엇을 고르든 서베이를 먼저 떠라.** 마이페이지 9개가 그 방식으로
매끄러웠던 이유는 722줄짜리 실측 문서가 먼저 있었기 때문이다 — 특히
`edit/email`의 토큰 없는 요청은 서베이가 표시해 두지 않았으면 놓쳤다.

**서베이만으로는 부족하다는 것도 S1에서 확인했다.** 서베이가 클래스명까지
정확히 적어 뒀는데도 브라우저 실측에서 일곱 가지가 어긋났다 — 배지가
형제에 맞춰 늘어나는 것(18 → 22.41), 드롭다운 항목 간격 0, `mb-[30%]`가
**폭** 기준(120), 정렬 트리거의 콘텐츠 박스 높이 0, 다이얼로그 테두리 1px
때문에 안쪽이 438, `justify-evenly` 무력화, 비정사각 아이콘 네 개.
**클래스를 읽어 계산하지 말고 재라.**

### 그 다음 후보

- **FCM (두 홈 공통 Phase B)** — 웹이 60줄을 복붙해 둬서 한 번에 둘을
  해결한다. 단, 웹 `VAPIDKEY`에 `NEXT_PUBLIC_` 접두사가 없어 클라이언트
  번들에 주입되지 않는 것으로 보인다 — **웹 FCM이 실제로 동작하는지부터
  확인할 것.**

### ~~대안: 몸풀기~~ — 완료 (2026-09-15)

`/policy` 허브와 `/sign-up/complete`를 옮겼다. 실측 결론은
`docs/policy-screens-survey.md`에 있다.

**약관 본문 2개(`/policy/terms`·`/policy/privacy`)는 자리표시자로 남겼다.**
"싼 화면"이 아니었다 — 코드 줄 수(336·154)보다 **본문 15,000자 + `<li>` 157개 +
2단계 중첩 리스트**가 본체이고, `.policy-container` CSS를 옮기면 사실상 약관
문서 렌더러를 새로 만드는 일이다. 형식(Dart 위젯 직역 vs Markdown 에셋 vs
원격 fetch)을 먼저 정해야 한다 — 서베이 문서 §"결정이 필요한 것" 참고.

---

## 3. 화면 인벤토리 — 62개 남음

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

### 회원 student (16개 남음 / 홈 · **마이페이지 9개 전부** 완료)

알림 · 커뮤니티(2) · 수강내역 · 식단(4) · 로그(2) ·
포인트내역 · 일정 · 운동기록(4)

> 이 중 **10개가 이미 라우터에 자리표시자로 등록돼 있다**(홈에서 나가는
> 경로 전부). 화면만 채우면 된다.

### 트레이너 trainer (31개 남음 / 홈 · **회원관리 2개** 완료)

알림 · 수업시간설정 · 커뮤니티(2) · **회원관리(13)** · 마이페이지(7) ·
일정(3) · 회원추가(2) · 피드백 · 초대

> 이 중 **7개가 이미 라우터에 자리표시자로 등록돼 있다**(홈에서 나가는
> 경로 전부). 회원관리 계열은 **19개 전부 라우트가 등록돼 있고** 매칭
> 순서(`feedback`·`invite`·`append` → `:memberId`, `log/write` →
> `log/:logId`)를 `app_test`가 직접 겨눈다.

> 트레이너 `manage/[memberId]/*` 14개는 회원 쪽 화면과 구조가 겹친다.
> 회원 화면을 먼저 끝내면 여기가 싸진다.

---

## 4. 공용 컴포넌트 — 웹 21종 중 8종 완료

> **입력 상자가 두 종류다.** `AppTextInput`(라벨 + 에러 문구, 높이 50)은
> 로그인·찾기 화면의 모양이고, **`AppPlainInput`**(라벨 없음, 높이 52,
> `px-6 py-[13px]`, `rounded-md`)은 마이페이지 편집 폼의 모양이다.
> 웹이 두 모양을 실제로 나눠 쓴다 — 편집 폼은 섹션 제목(`<h3>`)이 따로 있어
> 입력에 라벨을 붙이지 않는다. `/edit/email`도 후자를 쓴다.

**완료:** `AppButton` · `AppTextInput` · `AppTextLink` · `AppToast` ·
`AppOtpInput`(웹 `input-otp`) · **`AppCard`** · **`AppProgress`** ·
**`AppCollapsible`** · **`AppPlainInput`** · **`AppSwitch`**
**`widget` 계층 추가:** **`AppMonthPicker`**(웹 `widget/month-picker`)
**`widget` 계층 완료:** `AppLayout`(Header/Contents/BottomArea/BottomNavigation) ·
**`AppNavigationBar`**(표현) + `AppBottomNavigation`(회원) +
**`AppTrainerBottomNavigation`**(트레이너)

**`AppLayout`에 붙은 슬롯 세 개** (전부 웹에 실제 사용처가 있어서 생겼다):
- **`scrollable: false`** — 웹 `<Layout.Contents className='overflow-y-hidden'>`.
  검색바를 고정하고 목록만 스크롤하는 화면이 쓴다(`/trainer/manage`).
  **이때만 `contents` 안에서 `Expanded`를 쓸 수 있다**(규율 #12의 전제가
  사라진다 — 스크롤뷰가 없으면 높이가 무한이 아니다).
- **`AppLayoutHeader.trailing`** — 헤더 오른쪽 임의 위젯. `onClose`와 배타다.
- **`AppLayoutHeader.titleStyle`** — 웹이 화면마다 `HEADING_4`(bold)와
  `HEADING_4_SEMIBOLD`를 섞어 쓴다. 기본값은 semibold(지금까지 옮긴 아홉
  화면 전부), `/trainer/manage`만 bold다.
**feature 계층:** `GymSelectList` · `GymVerificationCode` · **`CourseCard`**
(+ 공개 조각 **`CourseCardHeader`·`CourseCardContent`** — 웹도 이 둘을 컨테이너
안에 조합해 쓴다. S3는 포인트 바 없이 둘만 쓴다) · **`TodayDietTile`**(타일 렌더만)

> `AppOtpInput`은 **입력 하나 + 슬롯 6개 렌더**다(웹 `input-otp`와 같은 구조).
> `TextField` 6개로 만들면 붙여넣기와 슬롯 경계 backspace가 달라진다.

**미구현 (웹 `src/shared/ui`):**
`sheet`(바텀시트) · `alert-dialog` · `calendar` · `select` ·
`tabs` · `textarea` · `carousel` · `scroll-area` ·
`time-swiper` · `generic-form` · `dropdown-menu` · `separator`

> **사설 알럿·시트가 이제 셋·둘이다.** `alert-dialog`는 S2(`_DeleteAlert`)와
> S3(`_DeleteCourseAlert`)에 하나씩 있는데 **상자는 같고 버튼 글꼴·폭 분배가
> 다르다**(S3 절 참고). `sheet`도 S2 환불 시트와 S3 수강권 시트가 사설이다.
> 승격은 "옵션이 늘지 않을 때"가 기준이고, 아직 그 조건이 아니다.
>
> `dialog`는 **회원 탈퇴 화면 안에 사설로 하나 있다**
> (`student_my_page_leave_page.dart`의 `_ConfirmDeleteDialog`). 공용으로
> 올리지 않은 이유는 사용처가 하나뿐이어서다 — 두 번째가 생기면 그때
> 승격한다. 승격에 필요한 실측 치수는 그 파일의 상수에 전부 있다:
> 폭 320, 패딩 20, 모서리 8, 테두리 `#E2E8F0`, 막 `black/80`,
> 본문 간격 20·34, 버튼 높이 50.
>
> **두 버튼이 서로 다르다는 점을 잊지 마라** — `취소`는 16px/400/모서리 8,
> `탈퇴하기`는 14px/500/모서리 12에 배경이 `#EF4444`(point가 아니다).

**미구현 (웹 `src/widget`):**
`week-picker` · `rolling-banner` · `image-slide`

> 네비는 **표현(`AppNavigationBar`)과 동작(두 네비 위젯)**으로 갈라 두었다.
> 학생 네비만 마운트 시 요청을 쏘고 가드를 갖는다 — 그 차이가 두 홈 골든의
> 모양을 가른다. `AppNavigationItem`이 아이콘·라벨 활성을 **따로** 받는
> 이유는 웹 트레이너 홈 탭의 두 조건이 갈려 있어서다.

> `AppCollapsible`은 **controlled**다. 웹은 열림 상태를 `isOpen` useState와
> Radix 내부 상태 두 군데로 관리하는데(같은 클릭으로 함께 움직여 버그는
> 아니다), 여기서는 bool 하나로 합쳤다.

**부분 완료:** `toast` — `errorToast`만 옮겼다. `successToast`는 부르는 화면이
없어 의도적으로 보류했다(`check.svg`에 `fill` 오버라이드를 거는 방식을
추측으로 옮기면 검증할 길이 없다). 쓰는 화면이 생기면 그 화면의 렌더를 보고 추가.

---

## 5. 인프라 — 화면보다 이쪽이 무겁다

| 항목 | 상태 | 메모 |
|---|---|---|
| **FCM 푸시** | 미착수 | 서비스워커·VAPID·딥링크. 기존 `webview` 레포가 하던 일이라 참고 구현이 있다. **웹 `VAPIDKEY`에 `NEXT_PUBLIC_` 접두사가 없어 클라이언트 번들에 주입되지 않는 것으로 보인다** — 웹 FCM이 실제로 동작하는지 먼저 확인할 것 |
| **S3 presigned PUT** | 미착수 | bare axios — **패리티 하네스 경계 밖**. 홈과 함께 설계 |
| ~~dayjs `ko` 로케일~~ | **완료** | `intl` 도입. `KoreanDateFormat`, 초기화는 `app.dart`(조립 지점)가 소유 — `main()`에 두면 테스트·딥링크가 초기화 없이 돈다 |
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

- ⚠️ **이 머신에서 `flutter test`가 Xcode 라이선스 미동의로 막힌다**(2026-09-18).
  `xcrun`이 stdout에 아무것도 못 내서 `objective_c`(→ `flutter_secure_storage_darwin`)
  네이티브 빌드 훅이 `Bad state: No element`로 죽고 **테스트가 한 개도 실행되지
  않는다.** 정식 해결은 터미널에서 `sudo xcodebuild -license accept` 한 번이다
  (Claude Code의 `!` 경로에서는 TTY가 없어 sudo가 비밀번호를 못 읽는다).
  임시 우회는 PATH 앞에 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`를
  export하는 `xcrun` shim을 두는 것 — `DEVELOPER_DIR`만 export하면 flutter가
  훅 하위 프로세스에 전달하지 않아 듣지 않는다. **레포 문제가 아니라 환경
  문제다**(`pubspec.lock` 무변경).
- 커밋·푸시는 **사용자가 요청할 때만** 한다(workspace CLAUDE.md).
- **`/select-gym`에 웹에 없는 게이트를 넣었다.** 웹 `(login-required)` 그룹에는
  `layout.tsx`가 없어 실제로 막는 것이 없지만, 이 화면이
  `auth.user!.memberType`으로 제목을 갈라서 그대로 두면 null 역참조로 죽는다.
  미로그인 접근을 온보딩으로 돌려보낸다(`app_router.dart` 주석에 명시).
- ~~**`AuthState.signOut()`의 프로덕션 호출부가 0개다.**~~ **해소됐다
  (2026-09-15).** `/student/mypage/info`의 로그아웃 버튼이 부른다
  (`student_my_page_info_page.dart`). Phase 0에서 `writeTokens` 호출부가
  0개였던 것과 같은 냄새였고 그건 실제 버그였는데, 이번에는 부채를 적어 둔
  덕에 화면을 옮기면서 바로 연결됐다.

  **남은 같은 부류가 있는지 주기적으로 볼 것** — "구현은 있는데 프로덕션
  호출부가 0개"인 API는 테스트만 통과하고 실제로는 죽어 있다.
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
- **홈에서 이관한 웹 버그 2건** — 월 표시(10~12월에 "0월/1월/2월"), 포인트·
  랭킹이 수강권에 종속. 사용자 결정으로 버그째 옮겼고 **잘못된 결과가 단언으로
  고정돼 있다.** 고칠 때는 웹과 앱, 그리고 그 단언들을 함께 바꾼다
  (`deferred-minors.md` 참고).
- **홈의 이미지를 실기기에서 못 봤다.** 식단 사진·트레이너 프로필이
  `Image.network`라 위젯 테스트에서는 항상 `errorBuilder`로 떨어진다.

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
14. **화면을 옮기면 폰 너비(390pt) 테스트를 하나 둔다.** 위젯 테스트 기본
    뷰포트는 800×600인데 실기기는 논리 폭 ~390이고, **오버플로는 좁은 쪽에서
    산다.** 로그인 게이트 뒤의 화면은 `INITIAL_LOCATION`으로 실기기에서 열 수
    없으므로(규율 #9의 한계) 이 테스트가 그 자리를 대신한다. 디버그 빌드에서
    `RenderFlex overflowed`가 예외로 올라오므로 **펌프만 해도 검증이 된다.**
    ```dart
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ```
    긴 이름·만료 분기처럼 **가장 넓어지는 데이터**를 함께 넣는다. 웹의 flex
    자식은 저절로 줄지만 Flutter `Row`의 `Text`는 `Flexible` 없이는 넘친다 —
    실제로 이 프로젝트에서 두 번 같은 자리에 걸렸다.
13. **웹에서 가져온 SVG의 `fill="current"`는 flutter_svg에서 아이콘을
    통째로 지운다.** 유효하지 않은 값이라 브라우저는 **무시하고 부모 값을
    상속**해서 SVGR 컴포넌트에 넘긴 `fill` prop 색이 내려오지만, flutter_svg는
    "칠하지 않음"으로 처리한다(실측: `arrow_filled_up`이 한 픽셀도 안 그려짐).
    `assets_test.dart`의 컴파일 테스트는 **이 상태를 그대로 통과시킨다** —
    규율 #8의 가장 날카로운 사례다.
    자산을 새로 가져오면 `grep -l 'fill="current"' assets/images/*.svg`로
    먼저 확인하고, 표준 `currentColor`로 바꾼 뒤 화면에서
    `SvgTheme(currentColor:)`로 웹이 prop에 넘기던 색을 주입한다.
    `width`/`height`의 `current`는 **건드리지 않는다**(무시돼도 정상 렌더).
11. **비동기 순서를 고정하는 테스트는 지연을 100ms보다 크게 잡는다.**
    `pumpAndSettle`이 기본 100ms씩 시간을 진행시켜서, 그보다 짧은 창은 한
    pump에 통째로 삼켜진다 — 뮤테이션을 넣어도 테스트가 그대로 통과해
    **가드가 있는 줄 알고 넘어간다.** 실측: 50ms는 안 잡히고 2초는 잡혔다
    (`app_test.dart`의 `_SlowProfileStorage`).
15. **웹이 픽셀로 못박은 치수는 수치로 단언한다.** "색이 맞나 / 위젯이 있나"
    단언은 **"얼마나"를 못 잡는다.** 실측: 트레이너 홈의 파란 배너를 웹보다
    56px 길게(170 → 226) 그린 채로 테스트 43개가 전부 통과했다 — 높이를 재는
    단언이 하나도 없었기 때문이다. 특히 **웹의 `absolute top-0`은 헤더를
    포함한 컨테이너 기준**인데 Flutter `AppBar`는 본문과 별개 레이어라
    본문이 그 뒤를 칠할 수 없다. 헤더를 직접 칠하고 본문에는 **뺀 값**을
    그리되, `헤더 높이 + 본문 높이 == 웹 값`을 단언해 그 합을 고정한다.
16. **응답 픽스처는 실측에서 온 것만 믿어라 — 골든은 요청만 대조한다.**
    하네스는 "무엇을 보냈나"를 고정하지 "무엇을 받았나"는 보지 않는다.
    그래서 응답 모양을 잘못 가정하면 **테스트가 그 가정을 충실히 확인해
    주면서 실서버에서만 터진다.** 실측: `gym`을 `{gymId, name}`으로 가정해
    픽스처를 지었는데 실제로는 `{id, name}`이었고(`GymDto` vs `GymResult` —
    백엔드에 같은 도메인 record가 둘이다), 비-null 캐스트가 던져 **학생 홈
    응답 전체의 파싱이 죽었다.** 호출부의 `catch (_)`가 삼켜서 화면은 멀쩡히
    "데이터 없음"을 그렸고, 테스트 465개가 전부 통과했다.
    **웹 TS 타입도 OpenAPI 문서도 근거가 못 된다** — 이번엔 필드 이름 자체가
    달랐다. 골든을 뜰 때 **응답 본문도 한 벌 받아 적고**(`har/README.md`에
    화면별로 남긴다) 그것을 픽스처의 뿌리로 삼아라.
17. **위젯 테스트는 실제 글꼴을 싣고 재라 — 기본 글꼴은 글자당 1em이다.**
    `flutter test`의 기본 글꼴은 플랫폼 간 결정성을 위해 모든 글자를 1em
    정사각형으로 그리고, `pubspec.yaml`에 선언한 글꼴은 **자동으로 실리지
    않는다.** 실측: `수업일지`(4자, 16px)가 테스트에서 **64.0**, 실제
    Pretendard로는 **55.31**(웹 `getBoundingClientRect`와 일치) — 17% 차이다.
    `test/flutter_test_config.dart`가 네 무게를 싣는다. 이게 없으면 두 방향
    으로 틀린다: **거짓 양성**(실기기에서 멀쩡한 화면이 테스트에서 넘쳐,
    고치려다 웹에 없는 `Flexible`을 넣게 된다)과 **거짓 음성**(테스트 글꼴이
    더 좁은 경우 실기기에서만 넘쳐, 규율 #14의 폰 너비 테스트가 못 잡는다).
    함께: **`AppTypography`의 모든 스타일이 `letterSpacing: 0`을 못박는다.**
    `Scaffold` 안에서는 Material 3 `bodyMedium`의 자간 **0.25**가
    `DefaultTextStyle`로 상속되고, `TextStyle.inherit`가 기본 true라 명시하지
    않으면 그대로 섞인다 — 웹에는 `letter-spacing` 선언이 없다(= 0).
18. **치수 단언의 기댓값은 리터럴로 써라 — 상수를 양쪽에 쓰면 공허해진다.**
    ```dart
    // 나쁨: 상수를 82에서 80으로 바꿔도 통과한다
    expect(tester.getSize(avatar), const Size(Page.avatarSize, Page.avatarSize));
    // 좋음
    expect(tester.getSize(avatar), const Size(82, 82));
    ```
    실측: 내 정보 화면의 아바타(82)를 이렇게 써 뒀다가 82 → 80 뮤테이션이
    그대로 통과했다. 허브는 80이고 이 화면만 82라(웹이 여기서만
    `width={82}`를 쓴다) **맞춰 버리면 웹과 달라지는데 테스트가 침묵한다.**
    상수는 **찾는 데(predicate)** 쓰고, **재는 값**은 리터럴로 박는다.
    리터럴 옆에 웹 실측 출처를 주석으로 남긴다.
19. **`find.ancestor(...).first`가 네가 생각한 그 위젯이 아닐 수 있다.**
    치수·색을 잴 때는 **그 위젯만의 성질로 직접 지목하라** — 배경색, 고유
    크기, 키. 조상 탐색은 조용히 바깥 컨테이너를 집어서 단언을 공허하게
    만든다. 이 세션에서 두 번 밟았다:
    - 다이얼로그 버튼 높이를 `find.ancestor(...).first`로 쟀더니 바깥
      다이얼로그가 잡혀서, 버튼이 50 → 46으로 갈려도 통과했다.
    - 소셜 배지를 "흰 원"으로 찾았더니 카메라 버튼(흰 원)과 함께 잡혔다.
    같은 부류로 **색만 보는 predicate**도 위험하다. 로고·아이콘처럼 그
    안에 있는 고유 자산을 먼저 찾고 `find.ancestor`로 감싸면 안전하다.
20. **`tester.getSize(SvgPicture)`는 네가 넘긴 크기가 아니라 viewBox 고유
    크기를 잰다.** flutter_svg는 안쪽에 `FittedBox` +
    `SizedBox.fromSize(pictureInfo.size)`를 두는데, `getSize`가 찾아내는
    렌더박스가 그쪽이다. 실측: `alert_circle.svg`의 `width`를 35 → 36으로
    바꿔도 `getSize`는 그대로 `Size(35, 36)`을 돌려줬다(뮤테이션 M16이
    통째로 살아남았다). 자산의 viewBox와 요청 크기가 같은 동안은 단언이
    맞아 보이지만 **아무것도 지키지 않는다.**
    → 요청 크기를 확인하려면 **위젯의 선언값을 읽어라**:
    ```dart
    final picture = tester.widget<SvgPicture>(finder);
    expect(Size(picture.width!, picture.height!), const Size(35, 36));
    ```
    `getSize`는 그 SVG를 감싼 **부모 상자**를 잴 때만 의미가 있다.
21. **Flutter는 줄 상자 높이를 정수로 반올림한다 — 웹과 0.5px까지 맞지
    않는다.** 실측: `16px × 1.4`는 웹에서 22.4인데 Flutter는 **22.0**,
    `13px × 1.5`는 웹 19.5인데 Flutter는 **20.0**이다(반올림 방향도
    일정하지 않다). 그래서 글자 높이가 섞인 치수는 웹 실측값과 소수점이
    어긋난다 — 이관 오류가 아니다.
    → 글자가 관여하는 치수는 **절대값 대신 관계를 단언하라**
    (`배지 높이 == 이름 높이`). 절대값을 쓸 거면 Flutter 쪽 값을 박고
    **웹 값과의 차이를 주석으로 남겨라**(S1 다이얼로그: 웹 149.5 / 앱 150).

---

## 8. 문서 지도

| 파일 | 내용 |
|---|---|
| **`next-steps.md`** (이 파일) | 다음에 무엇을 하나 |
| `student-mypage-survey.md` (722줄) | 회원 마이페이지 9개 화면 웹 실측. 요청·계약·웹 버그 24건·스타일·이관 순서 |
| **`trainer-manage-survey.md`** (1,825줄) | 트레이너 회원관리 19개 화면 웹 실측 + 백엔드 계약 대조. **웹 버그 45건**, 위험한 요청 표(캡처 전 필독), 권장 순서 |
| **`trainer-manage-s3-measurements.md`** | S3 수강권 화면 픽셀·네트워크 실측(440×900). 서베이가 틀렸던 두 가지와 401 캡처 함정이 여기서 나왔다 |
| **`trainer-manage-s1-measurements.md`** (335줄) | S1 `/trainer/manage` 픽셀 실측(440×900). 서베이가 못 잡은 일곱 가지가 여기서 나왔다 |
| `test/flutter_test_config.dart` | **코드지만 읽어라.** 위젯 테스트에 실제 Pretendard를 싣는 이유와 실측값(규율 #17) |
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
