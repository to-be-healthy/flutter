# HAR 원본 보관소

`tool/har_to_golden.py`의 입력이 되는 브라우저 HAR 내보내기를 여기에 둔다.

**이 디렉터리는 gitignore 대상이다** — HAR에는 실계정 토큰·쿠키가 평문으로 들어 있다.

## 지우지 마라

골든 픽스처(`test/fixtures/requests/*.json`)는 HAR에서 스크립트로 생성된다.
생성기나 비교기 규칙이 바뀌면(예: Phase 1의 쿼리스트링 id 자리표시자)
저장된 HAR을 다시 변환하면 끝난다.

HAR을 버리고 골든만 남기면 그 경로가 사라지고, **모든 후속 규칙 변경이
사람의 재캡처**가 된다. 캡처는 브라우저를 열어 실제로 로그인해야 하는 수동 작업이다.

## 화면 하나에 HAR 하나

골든은 **그 화면이 스스로 발생시키는 요청**과 대조된다. 로그인 성공 후
리다이렉트된 홈이 쏘는 요청까지 한 HAR에 담으면, 로그인 화면 테스트가
자기가 보내지도 않는 요청 3건을 "누락"으로 잡는다. 그래서 캡처를 흐름별로
쪼개 둔다.

| 파일 | 내용 | 골든 | 쓰는 곳 |
|------|------|------|---------|
| `login.har` | 폼 로그인 `POST /api/v1/auth/login` 1건 | `login` | `SignInPage` |
| `login-complimentary.har` | "체험하기" `POST /api/v1/auth/login` 1건 | `login-complimentary` | `OnboardingPage` |
| `home-student.har` | 로그인 직후 홈이 쏘는 GET 3건 (`members/trainer-mapping`·`home/student`·`notification/red-dot`) | `home-student` | `StudentHomePage` |
| `find-id.har` | 아이디 찾기 `POST /api/v1/auth/find/user-id` 1건 | `find-id` | `FindIdPage` |
| `find-password.har` | 비밀번호 찾기 `POST /api/v1/auth/find/password` 1건 | `find-password` | `FindPasswordPage` |
| `select-gym.har` | 헬스장 선택 화면 진입 `GET /api/v1/gyms` 1건 | `select-gym` | `SelectGymPage` |
| `home-trainer.har` | 트레이너 홈 진입 GET 3건 (`members/me`·`home/trainer`·`notification/red-dot`) | `home-trainer` | `TrainerHomePage` |
| `mypage-student.har` | 회원 마이페이지 허브 진입 GET 2건 (`members/trainer-mapping`·`members/me`) | `mypage-student` | `StudentMyPage` |
| `mypage-student-info.har` | 내 정보 화면 진입 GET 1건 (`members/me`) | `mypage-student-info` | `StudentMyPageInfoPage` |
| `mypage-student-edit-name.har` | 이름 변경 화면 진입 GET 1건 (`members/me`) | `mypage-student-edit-name` | `StudentMyPageEditNamePage` |
| `mypage-student-alarm.har` | 알림 설정 화면 진입 GET 1건 (`members/me`) | `mypage-student-alarm` | `StudentMyPageAlarmPage` |
| `mypage-student-trainer-info.har` | 트레이너 정보 화면 진입 GET 1건 (`members/trainer-mapping/info`) | `mypage-student-trainer-info` | `StudentMyPageTrainerInfoPage` |
| `mypage-student-edit-email.har` | 이메일 변경 화면 진입 GET 1건 (`members/me`) | `mypage-student-edit-email` | `StudentMyPageEditEmailPage` |
| `mypage-student-last-reservation.har` | 지난 예약 화면 진입 GET 1건 (`schedule/student/my-reservation/old?searchDate=`) | `mypage-student-last-reservation` | `StudentMyPageLastReservationPage` |
| `trainer-manage.har` | 회원 관리 허브 진입 GET 1건 (`trainers/members`) | `trainer-manage` | `TrainerManagePage` |
| `trainer-manage-member.har` | 회원 정보 진입 GET 1건 (`trainers/members/6`) | `trainer-manage-member` | `TrainerManageMemberPage` |

### `select-gym` 재캡처 시 — 버튼을 누르지 마라

- **캡처 방법:** 체험 계정으로 로그인한 뒤 `/select-gym`을 연다. 헬스장 목록
  GET 하나만 담긴다. `(login-required)` 그룹에 `layout.tsx`가 없어서 소속
  헬스장이 이미 있는 계정으로 열어도 화면이 뜨고 GET이 나간다(2026-09-15
  실측: `healthy-student0`, `gymId=1`).
- **`POST /api/v1/gyms/{gymId}`는 그 계정의 소속 헬스장을 실제로 바꾼다.**
  `find/password`와 같은 부류의 공유 상태 뮤테이션이다. 화면을 띄우기만 하고
  "다음"·"완료"는 누르지 마라.
- **등록 POST는 골든을 만들지 않는다**(결정: 2026-09-15). 위 부작용 때문이고,
  TRAINER `joinCode` 경로는 유효한 가입 코드가 없으면 캡처 자체가 불가능하다.
  요청 모양은 `select_gym_page_test.dart`의 계약 테스트가 고정하며, 근거는 웹
  `entity/gym/api/mutations.ts`와 `openapi/api-docs.json`이다.
- **이 HAR의 `authorization` 값은 캡처 시점에 지웠다.** 변환기가 이 헤더를
  presence-only로 `***` 마스킹하므로 실토큰이 있든 없든 생성되는 골든은 같다.
  다른 HAR들은 실토큰을 품고 있으니 gitignore는 그대로 유지한다.
- 이 요청에는 **`content-type`이 없다**(실측). 본문 없는 GET이라 브라우저가
  붙이지 않는다 — `DioClient.create`가 전역 `contentType`을 지정하지 않는
  이유가 이것이고, 그래서 앱 쪽 요청도 일치한다.

### 두 찾기 골든도 바꿔 쓰지 마라

본문이 **완전히 같다**(`{name, email}`, 키 순서까지). 다른 것은 경로뿐이다 —
`find/user-id` vs `find/password`. 바꿔 쓰면 경로 불일치로 떨어지며,
`find_password_page_test.dart`가 그 사실을 테스트로 직접 확인한다.

### 찾기 화면 재캡처 시 — 반드시 가짜 계정으로

**`POST /api/v1/auth/find/password`는 실존 회원의 비밀번호를 실제로
초기화하고 메일을 보낸다.** 캡처는 RFC 2606 예약 도메인으로만 하라.

- 이름 `홍길동` / 이메일 `parity-harness@example.com`
- 서버가 **HTTP 404 + `{"message":"회원이 존재하지 않습니다.","code":"400"}`**를
  돌려주는 것이 정상이다. 골든은 요청의 모양만 쓰므로 응답 실패는 무관하다.
- 성공 응답이 나오면 가정이 틀린 것이다 — 중단하고 값을 다시 확인하라.

`name`은 `MASKED_KEYS`에 **없어 값까지 대조된다.** 다른 이름으로 재캡처하면
`find_id_page_test.dart`가 먼저 깨진다. 그때 테스트를 고치지 말고 같은 이름으로
다시 뜨거나 양쪽을 함께 바꿔라.

두 요청 모두 `authorization` 헤더가 **없다**(실측). 웹은 토큰 없는 `api`
인스턴스를 쓰고(`mutations.ts`), 앱은 `AuthInterceptor._publicPaths`의
`/auth/find/`가 같은 일을 한다.

### 두 로그인 골든을 바꿔 쓰지 마라

둘은 **정확히 한 키가 다르다**. "체험하기" 버튼
(`frontend/src/page/public/ui/ComplimentaryButton.tsx`)만 본문에
`complimentaryLogin: true`를 붙이고, 폼 로그인
(`frontend/src/feature/auth/ui/SignInForm.tsx`)은 그 키를 **보내지 않는다**.

바꿔 쓰면 `body.complimentaryLogin: 누락됨` 또는 `예상치 못한 추가`로
떨어진다. 두 방향 모두 뮤테이션으로 확인했다 — 이 한 키가 두 골든을
구별하는 전부이자, 골든이 공허하게 통과하지 않는다는 증거다.

## 캡처 계정 (로그인이 필요한 화면)

`frontend/src/page/public/ui/ComplimentaryButton.tsx`의 상수에 박힌 **공개 체험
계정**을 쓴다. 개인 계정이 아니므로 재캡처에 그대로 써도 된다. 값을 여기 옮겨 적지
않는 이유는 비밀이라서가 아니라, 추적되는 파일에 자격증명 쌍이 들어가면 push
protection·gitleaks가 잡기 때문이다 — 원본 위치만 가리킨다.

그래도 HAR에는 발급된 실토큰이 남으므로 gitignore는 유지한다.

## 변환

```bash
python3 tool/har_to_golden.py har/login.har login \
  --host geonganghaejim.site --path-template
```

변환 직후 확인할 것:
- `test/fixtures/requests/login.json`의 `headers`가 **비어 있지 않은지** (비어 있으면 헤더 검증이 조용히 빈다)
- `userId`·`password`·`authorization` 값이 `***`로 마스킹됐는지

### `home-student` 재캡처 시 — 순서가 계약이다

이 골든은 **순서가 있는** 3건이고 `expectParity`가 인덱스로 대조한다.
`trainer-mapping`이 첫 번째인 이유는 웹에서 그 요청을 **하단 네비가** 쏘고
React effect가 자식부터 실행되기 때문이다(홈 화면이 쏘는 것이 아니다).

- 캡처는 체험 계정으로 로그인해 `/student`에 착지한 직후까지만 담는다.
  탭을 누르면 `trainer-mapping`이 한 번 더 나가 4건이 된다.
- **`redDotStatus`가 홈 응답 안에도 있지만 웹은 `notification/red-dot`을
  따로 부른다.** 중복 조회이고 헤더 빨간 점은 따로 부른 쪽을 쓴다. "고치면"
  요청이 2건이 되어 골든과 어긋난다.
- 세 요청 모두 `authorization`이 붙고 **`content-type`은 없다**(본문 없는
  GET). `select-gym`과 같은 성질이다.

### `home-trainer` 재캡처 시 — 학생 홈과 모양이 다르다

**첫 요청이 `members/me`다.** 학생 홈의 1번은 하단 네비가 쏘는
`members/trainer-mapping`인데 트레이너 쪽은 그 자리에 `members/me`가 온다
(`TrainerNavigation`에는 매핑 가드가 없다). **두 홈 골든을 같은 모양으로
가정하지 마라.**

- 캡처 계정은 `ComplimentaryButton.tsx`의 **트레이너** 체험 계정이다.
  온보딩에서 "트레이너" → "체험하기"를 누른다 — 아이디·비밀번호를 직접
  입력할 필요가 없다.
- **playwright 영속 프로필에 학생 세션이 남아 있으면 루트가 곧바로
  `/student`로 리다이렉트된다.** 그 사이트의 `localStorage`를 비우고 다시
  들어가야 트레이너 온보딩이 보인다.
- 2026-09-15 실측: `gymId=1`(건강해짐 홍대점), `memberId=5`라
  `/select-gym`·`/trainer/class-time-setting`으로 튕기지 않고 `/trainer`에
  바로 착지한다. 헬스장이 빠진 계정으로 캡처하면 다른 화면을 담게 된다.
- 세 요청 모두 `authorization`이 붙고 **`content-type`은 없다**(본문 없는
  GET). `home-student`·`select-gym`과 같다.
- 홈 화면의 버튼·링크는 **누르지 마라.** 트레이너 홈에는 회원 관리·수업
  관련 조작으로 들어가는 링크가 있고, 그 너머는 공유 계정의 실제 데이터다.

### 회원 마이페이지 두 골든 — 하단 네비 유무가 갈랐다

허브(`/student/mypage`)는 **2건**, 내 정보(`/student/mypage/info`)는 **1건**이다.
차이는 `members/trainer-mapping` 하나이고 그것을 쏘는 주체는 **하단 네비**다
(`home-student`의 1번과 같은 요청·같은 이유). 내 정보 화면에는 하단 네비가
없고 뒤로가기 헤더만 있어서 그 요청이 사라진다.

- **`notification/red-dot`이 없다.** 두 화면 다 헤더에 알림 종이 없다 —
  홈 두 화면과 다른 점이다. 마이페이지라고 홈 골든을 복사하지 마라.
- 캡처는 회원 체험 계정으로 로그인한 뒤 해당 URL을 **직접 연다**(하드 로드).
  `select-gym`과 같은 방식이다.
- **playwright 영속 프로필에 트레이너 세션이 남아 있으면** 루트가 `/trainer`로
  튕긴다. `localStorage`를 비우고 온보딩에서 "회원으로 시작" → "체험하기".
- 2026-09-15 실측 계정: `healthy-student0`(`memberId=6`, `gymId=1`, 이름 `차은우`).
- **`/student/mypage/info`의 "탈퇴하기"와 "로그아웃"을 누르지 마라.** 전자는
  공유 체험 계정을 실제로 지우고, 후자는 세션이 끊겨 재로그인해야 한다.

#### 이 캡처에서 나온 실측 응답 (픽스처의 뿌리)

```json
GET /api/v1/members/trainer-mapping → {"data":{"mapped":true}}
GET /api/v1/members/me → {"data":{
  "id":6,"userId":"healthy-student0","email":"...","name":"차은우",
  "profile":null,"gym":{"id":1,"name":"건강해짐 홍대점"},"memberType":"STUDENT",
  "pushAlarmStatus":"DISABLE","communityAlarmStatus":"DISABLE",
  "feedbackAlarmStatus":"DISABLE","scheduleNoticeStatus":"DISABLE",
  "socialType":"NONE"}}
```

**`gym`의 id 필드명이 `id`다** — `GET /api/v1/gyms` 목록의 `gymId`와 다르다
(`GymDto` vs `GymResult`). 이 한 줄을 눈으로 본 것이 홈 두 화면의 파싱
버그를 찾은 유일한 경로였다. 경위는 `docs/progress.md`의
"헬스장 DTO가 둘이었다" 항목.

**골든은 요청만 대조하고 응답 본문은 대조하지 않는다.** 그러니 새 화면을
캡처할 때 **응답 본문도 한 벌 적어 두고** 그것을 픽스처의 뿌리로 삼아라.

### 요청 목록이 같아도 골든은 따로 뜬다

`mypage-student-info` · `mypage-student-edit-name` · `mypage-student-alarm`은
**셋 다 `members/me` 한 건**이라 내용이 완전히 같다. 그래도 화면마다 따로
캡처한다(규율 #2).

공유하면 한쪽 화면이 요청을 늘렸을 때 **어느 화면이 달라졌는지 알 수 없다** —
두 테스트가 같이 깨지고, 고치는 사람은 둘 중 하나를 임의로 고른다.
"두 찾기 골든을 바꿔 쓰지 마라"와 같은 이유이고, 여기서는 내용까지 같아서
유혹이 더 크다.

### 골든을 만들지 않는 화면들

아래는 **의도적으로** 골든이 없다. 진입 시 요청이 0건이거나, 요청을 캡처하는
것 자체가 위험하다.

| 화면 | 이유 |
|---|---|
| `/student/mypage/leave` | 진입 요청 0건. `POST members/delete`는 **공유 체험 계정을 실제로 지운다** |
| `/student/mypage/edit/password` | 진입 요청 0건. 두 요청 다 **본문에 비밀번호가 들어가** HAR에 평문이 남는다 |

요청의 모양은 각 화면의 테스트가 계약 단언으로 고정한다 — 메서드·경로·
본문 키·`authorization` 유무까지. 본문 키는 뮤테이션으로 확인했다.

### `alarm` 재캡처 시 — 스위치를 누르지 마라

`/student/mypage/alarm`은 진입 요청이 1건이지만, **스위치를 누르면 공유 체험
계정의 알림 설정이 실제로 바뀐다**(`PATCH /api/v1/members/alarm/{type}/{status}`).
화면을 띄워 치수만 재고 나와라.

2026-09-15 캡처 시점의 계정 상태는 **네 알림이 전부 `DISABLE`**이었다.
그래서 **켜진 스위치의 색을 눈으로 확인하지 못했다** — `#1990FF`는
`switch.tsx`의 `data-[state=checked]:bg-primary`와 `tailwind.config.js`의
`primary.DEFAULT = var(--primary-500)`에서 읽은 값이다.

### 401 리프레시가 섞여 들어오면 골든에서 빼라

`trainer-info` 캡처(2026-09-15) 중 네트워크에 이렇게 찍혔다:

```
GET /api/v1/members/trainer-mapping/info  => 401
POST /api/v1/auth/refresh-token           => 200
GET /api/v1/members/trainer-mapping/info  => 200
```

**액세스 토큰이 만료돼 웹 인터셉터가 자동으로 갱신한 것**이고, 화면이 의도해서
보내는 요청이 아니다. 골든에는 **성공한 1건만** 담았다.

담았다면 앱 테스트가 "리프레시 요청이 없다"는 이유로 영영 실패한다 —
401 리프레시는 이 프로젝트의 **Phase B 항목**이라 앱에 아직 그 경로가 없다.

캡처가 길어지면 토큰이 만료되므로, 변환 전에 `har/*.har`의 entries를 눈으로
훑어 **401과 `refresh-token`이 섞이지 않았는지** 확인하라.

### `edit/email` 2단계를 보려면 — 예약 도메인으로만

2단계(인증번호 입력)는 `인증 요청`을 눌러야 나온다. 그 버튼은
`POST /api/v1/auth/validation/send-email`로 **실제 메일을 보낸다.**

`find/password` 재캡처와 같은 규칙을 쓴다: **RFC 2606 예약 도메인**
`parity-harness@example.com`을 넣는다. 메일이 배달되지 않으므로 아무에게도
가지 않는다. 2026-09-15 실측에서 서버는 200을 돌려줬고 화면이 2단계로 넘어갔다.

- **`인증 완료`는 누르지 마라.** 그것이 계정의 이메일을 실제로 바꾼다.
- 계정의 이메일은 그대로 남는다(대기 중인 인증 키만 생긴다).

### `last-reservation` 재캡처 시 — 데이터가 있는 달을 먼저 찾아라

이 골든은 **쿼리스트링까지** 담는다(`searchDate=2026-09`).

2026-09-15 실측에서 `healthy-student0`은 **2026-04에만 10건**이 있었고 나머지
달은 전부 `reservations: null`이었다. 카드 렌더를 보려면 달을 바꿔야 한다.

달을 하나씩 열어 보는 대신, 로그인 상태에서 콘솔로 한 번에 훑는 편이 빠르다:

```js
const token = JSON.parse(localStorage.getItem('auth-storage')).state.accessToken;
for (const m of ['2026-09','2026-08','2026-07','2026-06','2026-05','2026-04']) {
  const r = await fetch(`/api/v1/schedule/student/my-reservation/old?searchDate=${m}`,
    { headers: { Authorization: `Bearer ${token}` } });
  console.log(m, (await r.json()).data?.reservations?.length ?? 'null');
}
```

- **월 선택 시트와 상세 시트는 열어도 안전하다** — 둘 다 읽기 전용이다.
- 목록이 길면 데스크톱 스크롤바가 생겨 카드 폭이 **400이 아니라 385**로
  잡힌다. 그 15px은 브라우저 스크롤바지 디자인 값이 아니다.

### `trainer-manage` 재캡처 시 — 트레이너 계정이고, 아무것도 누르지 마라

- **계정을 바꿔야 한다.** playwright 영속 프로필에 회원 세션이 남아 있으면
  루트가 `/student`로 튕긴다. `localStorage`를 비우고
  `/?type=trainer` → "체험하기"다.
- 2026-09-15 실측: `healthy-trainer0`(`memberId=5`, `gymId=1`), 관리 회원 2명.
- **하단 네비는 요청을 쏘지 않는다** — 그래서 진입 요청이 1건뿐이다
  (회원 쪽 네비와 다른 점. `home-trainer` 캡처 때 확인한 것과 같다).
- 이 화면의 버튼들은 **회원 추가·초대·수강권 조작으로 이어진다.**
  치수만 재고 나와라. 눌러도 되는 것은 셋뿐이다 — 정렬 드롭다운 트리거,
  헤더 `+`(다이얼로그가 열릴 뿐), 검색창 타이핑(클라이언트 필터링뿐).
  **다이얼로그 안의 `회원 직접 추가`·`가입된 회원 추가` 링크는 누르지 마라**
  (다른 화면으로 넘어간다). 회원 카드도 마찬가지다.
- **뷰포트는 440 × 900으로 맞춰라.** 웹 `--max-width: 440px`이고, 이 폭에서는
  데스크톱 스크롤바가 0px이라 440이 그대로 확보된다(지난 예약 화면에서
  카드 폭이 385로 잡혔던 것과 다르다 — 그쪽은 목록이 길어 스크롤바가 생겼다).
  잰 폭이 425 같은 값이면 스크롤바가 낀 것이니 기록에 그렇게 남겨라.
- 픽셀 실측 결과는 `docs/trainer-manage-s1-measurements.md`에 있다.

#### 이 캡처에서 나온 실측 응답 (픽스처의 뿌리)

```json
GET /api/v1/trainers/members → {"data":[
  {"memberId":6,"name":"차은우","userId":"healthy-student0",
   "email":"healthy-student0@geonganghaejim.site","ranking":999,
   "lessonCnt":10,"remainLessonCnt":3,"nickName":null,"fileUrl":null,
   "courseId":null,"isNonmember":false},
  {"memberId":15,"name":"rr","userId":null,"email":null,"ranking":999,
   "lessonCnt":3,"remainLessonCnt":3,"nickName":null,"fileUrl":null,
   "courseId":null,"isNonmember":true}]}
```

**두 회원 다 카드에 `가입` 배지가 붙어 있었다** — `isNonmember`가 각각
`false`/`true`인데도 그렇다. 배지가 그 필드를 보지 않는다는 뜻이고,
옮기기 전에 웹 소스에서 그 조건을 확인해야 한다.

`ranking: 999`는 학생 홈의 "순위 없음" 센티넬과 같은 값이다.

### `trainer-manage-member` 재캡처 시 — 삭제 버튼 둘을 절대 누르지 마라

- **이 화면에는 복구 불가능한 삭제가 둘 있다.**
  - 케밥 → `회원 삭제` → 알럿 **`예`** → `DELETE /api/v1/trainers/members/{id}`
  - 케밥 → `환불 회원 삭제` → 체크 → **`회원 삭제`** → `DELETE .../refund`
    (회원 정보·운동기록·예약내역·수강권이 함께 사라진다)
- **환불 시트의 체크박스도 누르지 마라.** 체크하면 삭제 버튼이 활성화되어
  오클릭 한 번이 사고가 된다. 비활성 상태로만 재라.
- 열어도 되는 것: 케밥 드롭다운, 알럿 **띄우기**, 시트 **띄우기**, 포인트
  접이식 토글. 각각 측정 후 `Escape`로 닫아라.
- 바로가기 3개·수강권 카드·식단·개인 운동 기록은 **다른 화면으로 이동한다.**
- **이 골든의 경로에는 `/6`이 들어 있다**(`--path-template`을 쓰지 않았다).
  캡처한 회원의 실측 응답을 그대로 픽스처로 쓰기 때문이고, 다른 회원으로
  재캡처하면 `trainer_manage_member_page_test.dart`의 `_memberId`와 픽스처를
  **함께** 바꿔야 한다.
- 2026-09-16 실측: `memberId 6`은 **만료 수강권**(`completed 10 / total 10`
  인데 `remain 3`), `memberId 15`는 활성이다. 접이식 포인트 바는 **활성
  분기에서만** 나온다.
- 픽셀 실측은 `docs/trainer-manage-s2-measurements.md`에 있다.
