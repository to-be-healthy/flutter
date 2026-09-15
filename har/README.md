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
| `home-student.har` | 로그인 직후 홈이 쏘는 GET 3건 (`members/trainer-mapping`·`home/student`·`notification/red-dot`) | (아직 없음) | Phase 3 홈 화면 |
| `find-id.har` | 아이디 찾기 `POST /api/v1/auth/find/user-id` 1건 | `find-id` | `FindIdPage` |
| `find-password.har` | 비밀번호 찾기 `POST /api/v1/auth/find/password` 1건 | `find-password` | `FindPasswordPage` |
| `select-gym.har` | 헬스장 선택 화면 진입 `GET /api/v1/gyms` 1건 | `select-gym` | `SelectGymPage` |

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
