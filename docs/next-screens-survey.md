> **이 문서는 낡았다 (2026-09-14).** 여기서 고른 `/find/id` + `/find/pw`는
> 이관이 끝났다. 표에 없는 화면이 63개 남아 있으므로 **다음 작업 선정은
> `next-steps.md`를 보라.** 아래 실측표(6개 후보의 규모·의존)는 그대로 유효하다.

# 다음 마이그레이션 후보 실측 (2026-09-14)

웹 6개 화면의 규모·의존을 실측했다. 목적은 "다음에 무엇을 옮길지"이고,
판단 기준은 줄 수가 아니라 **새로 만들어야 하는 공용 컴포넌트와 인프라**다.

## 실측표

| 후보 | 진입 | 전이 UI 합계 | API | 새 공용 컴포넌트 | 새 인프라 |
|---|---|---|---|---|---|
| `/sign-up/complete` | 55 | 55 | **0개** | 0 | 0 |
| `/find/id` | 204 | ~240 | 1 (공개) | Toast, SocialIcon 4종 | 0 |
| `/find/pw` | 205 | ~240 | 1 (공개) | 위와 동일 | 0 |
| `/select-gym` | 133 | ~317 | 2 (인증) | OTP 입력, Toast | 0 |
| `/sign-up` | 110 | **~801** | 5 | Toast, AlertDialog, 입력 확장 2종 | 폼 컨텍스트 공유, 누적형 퍼널 |
| `/student` | 469 | **~1,133** | **7** | Card, Collapsible, Progress, BottomSheet, BottomNav, Toast | **FCM, S3 presigned 업로드, dayjs ko 로케일** |

## 결정: `/find/id` + `/find/pw` 쌍

근거 셋:

1. **지금 죽은 링크다.** 방금 복원한 로그인 화면의 "비밀번호 찾기 | 아이디 찾기"가
   자리표시자로 간다. 이 둘을 옮기면 로그인 화면의 링크 그래프가 닫힌다.
2. **하나를 옮기면 나머지가 거의 공짜다.** 204줄 vs 205줄에 분기 구조·의존 목록이
   완전히 겹친다. 실제 차이는 성공 화면 아이콘(`love_letter.svg`)과 dayjs 날짜
   포맷 1줄뿐이다.
3. **새 인프라가 0이다.** 인증 불필요한 단일 POST 하나씩. 새로 필요한 것은
   토스트와 소셜 아이콘 4종이며, 토스트는 어차피 6개 후보 중 5개가 요구한다.

`/student` 홈은 **의도적으로 뒤로 미룬다.** 전이 UI가 5배(1,133 vs 240)이고,
컴포넌트가 아니라 **인프라 계층**이 딸려온다 — Firebase FCM(서비스워커·VAPID·
재시도), presigned URL + S3 직접 PUT, 애니메이션 Collapsible, Progress, Card
시스템, BottomSheet, 하단 네비게이션(트레이너 매핑을 비동기로 확인하는 탭 가드),
`ko` 로케일 + `customParseFormat`을 켠 dayjs. 로그인이 자리표시자에 착지하는
불편은 남지만, 여기서 시작하면 반쯤 만든 화면에 갇힌다.

## 옮길 때 주의할 사실 (실측)

- **`SignUpPage`는 4단계가 아니라 5단계다.** 더 중요한 건 형태다:
  `useSignUpFunnel`의 `children.filter(child => child.props.id <= step)`가
  스텝을 **교체가 아니라 누적**시킨다. step 5에서는 다섯 필드 블록이 한 화면에
  쌓인 채 단일 `FormProvider` 안에 공존한다. PageView나 라우트 push로 옮기면
  **원본과 다른 화면이 된다.** `clickBack`도 단순 pop이 아니다(step 4 → step 2로
  점프하며 이메일·아이디 인증 플래그를 리셋).
- `GET /api/v1/auth/invitation/uuid`는 `(login-unrequired)` 그룹인데 **`authApi`**를
  쓴다(토큰 주입됨). 토큰 없이 호출되면 헤더가 빈다 — 그대로 따를지 결정 필요.
- `StudentHomePage`의 `PUT {presignedUrl}`은 `api`도 `authApi`도 아닌 **bare axios**다.
  패리티 하네스가 캡처하는 dio 인스턴스 밖으로 나가는 유일한 요청이라, 홈을
  옮길 때 하네스 경계를 다시 봐야 한다.
- 웹 `FindIdPage`/`FindPasswordPage`가 쓰는 `Input`(21줄)은 `TextInput`(62줄)이
  아니라 **테두리·클리어 버튼이 없는 raw `<input>`**이다. 기존 `AppTextInput`을
  그대로 쓰면 웹보다 장식이 많아진다.
- Flutter에 **토스트/스낵바 인프라가 전무하다**(`SnackBar`/`Toast`/`Overlay` 히트
  0건). 현재 화면들은 에러를 인라인 `Text`로 그린다 — 웹은 `errorToast`다.
  이 차이는 Phase 0이 의식적으로 남긴 것이고, 여기서 갚는다.
