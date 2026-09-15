# 약관·가입완료 4개 화면 실측 (2026-09-15)

> **진행 상태:** `/policy`와 `/sign-up/complete`는 **이관 완료**(2026-09-15).
> `/policy/terms`·`/policy/privacy`는 **자리표시자로 남아 있다** — 아래
> "결정이 필요한 것 ①"(본문 형식)을 먼저 정해야 한다.

`/policy` · `/policy/terms` · `/policy/privacy` · `/sign-up/complete`.
`next-steps.md`가 "싼 화면"으로 분류했던 묶음인데, **절반만 맞다.**

## 한눈에

| | `/policy` | `/policy/terms` | `/policy/privacy` | `/sign-up/complete` |
|---|---|---|---|---|
| 라우트 그룹 | `(login-unrequired)` | 〃 | 〃 | 〃 |
| 페이지 컴포넌트 줄 수 | 47 | **336** | **154** | 55 |
| API 호출 | **0** | **0** | **0** | **0** |
| 폼 입력 | 0 | 0 | 0 | 0 |
| 새 공용 컴포넌트 | 없음 | **문서 렌더러** | **문서 렌더러** | 없음 |

**4개 화면 전부 네트워크 요청이 0건이고 인증 로직이 0줄이다.** `(login-unrequired)`에
`layout.tsx`가 없고 루트에 `middleware.ts`도 없다 — 그룹명은 순전히 폴더링이다.
`/select-gym` 때 확인한 `(login-required)`의 사정과 같다.

## 공수의 70%는 약관 본문이다

| 지표 | terms | privacy |
|---|---:|---:|
| 순수 산문 (공백 포함) | **11,545자** | **3,376자** |
| `<li>` 노드 | 125 | 32 |
| `<section>` / `<h3>` | 26 / 26 | 10 / 9 |
| 리스트 중첩 최대 깊이 | 2 | 2 |
| `<table>` | **0** | **0** |
| 인라인 마크업(`<u>`) | 0 | **2** (이메일) |

본문은 **100% JSX 하드코딩**이다 — 상수 파일·마크다운·iframe·외부 URL 전부 없고,
본문을 내려주는 백엔드 엔드포인트도 없다.

좋은 소식 둘:
- **표가 없다.** 개인정보 처리방침에서 가장 골치아픈 "수집 항목/보유 기간" 표가
  여기선 `<ol>`로 풀려 있다.
- **여러 줄 템플릿 리터럴이 0개다.** `.policy-container`의 `whitespace-pre-wrap`이
  실제로는 아무 일도 하지 않으므로 개행 보존을 신경 쓸 필요가 없다.

백틱 템플릿 리터럴을 쓴 이유는 본문에 큰따옴표(`"회사"`, `"사이트"`)가 많아
JSX 이스케이프를 피하려던 것뿐이다. Dart에서는 자연히 해소된다.

## `.policy-container` — 사실상 문서 렌더러 스펙

`frontend/src/app/_styles/global.css` L246–280.

| 셀렉터 | 웹 | Flutter |
|---|---|---|
| `.policy-container` | `whitespace-pre-wrap break-keep px-7 py-10` | 좌우 20 · 위아래 32 패딩 |
| `h2` | 22px/130% bold | `AppTypography.heading2` |
| `h3` | 14px/150% semibold | `AppTypography.title3` |
| `p` | 14px/150% normal | `AppTypography.body2` |
| `section` | `mt-12 flex flex-col gap-6` | 위 48 · 항목 간 16 |
| `ol` / `ul` | `list-decimal` / `list-disc`, `pl-7` | 수동 번호·불릿 + 20 들여쓰기 |
| `li` | 13px/150% normal | `AppTypography.body3` |
| `u` | `underline underline-offset-4` | `TextDecoration.underline` |

> 주의: `px-7`·`pl-7`·`gap-6`·`mt-12`는 Tailwind **커스텀 스케일**이다
> (7=20, 6=16, 12=48). 기본값(28/24/48)이 아니다 — 규율 #5.

## 결정이 필요한 것 4건

### ① 약관 본문을 무엇으로 옮길 것인가 (가장 큰 갈림길)

| 방식 | 장점 | 단점 |
|---|---|---|
| Dart 위젯 트리 직역 | 타입 안전, 테마 일관, 새 의존성 0 | 코드 1,000줄+, 약관 개정 = 앱 재배포 |
| Markdown 에셋 + `flutter_markdown` | 본문·코드 분리, 구조가 1:1 대응 | 새 의존성, 중첩 `ol`+`ul` 스타일 커스터마이징 |
| 원격 fetch | 앱 배포 없이 개정 | **백엔드 엔드포인트 신설 전제** — 지금 없다 |

### ② `break-keep` — Flutter에 대응물이 없다

한국어 어절 단위 줄바꿈. Flutter 기본 텍스트 레이아웃은 한국어를 글자 단위로
끊는다. 15,000자 산문에서는 가독성 차이가 눈에 띈다. 수용할지, 우회할지
디자인 판단이 필요하다.

### ③ `usePreviousPage` — 앱에서는 단순해진다

웹은 `window.history.length > 1`로 뒤로가기 버튼 노출을 정하고, 판정 전에는
**화면 전체를 `return null`** 한다(첫 렌더가 빈 화면). Flutter에서는
`Navigator.canPop`이 정확한 대응물이라 2단계 렌더가 사라진다. 다만 딥링크로
pop 불가 상태 진입 시 무엇을 보여줄지는 정해야 한다.

### ④ `SignUpCompletePage`의 인자 없는 `throw new Error()`

```ts
if (!type || !name) { throw new Error(); }   // 메시지 없음 → error.tsx로 낙하
```

Flutter에서는 `type`·`name`이 라우트 인자라 이 가드가 컴파일 타임에 해소된다.
**앱에서 그대로 크래시시키는 것은 부적절**하므로 폴백을 명시해야 한다.

## 웹 쪽 기존 버그 (이관 중 발견)

`frontend/src/page/public/ui/PolicyTermsPage.tsx:313` 에 **빈 제목**이 있다.

```jsx
<section>
  <h3></h3>          {/* 제 24조 제목 누락 */}
  <ol> ... 분쟁해결 관련 3개 항목 ... </ol>
```

`제 23조`와 `제 25조` 사이이고 내용은 분쟁해결이다 — `제 24조 [분쟁해결]`이
누락된 것으로 보인다. 현재 웹은 조항 번호 없이 본문만 렌더한다.
**웹도 함께 고치는 것이 맞다.**

## 지금은 4개 다 도달 불가다

```
마이페이지(미구현) ──→ /policy ──┬──→ /policy/terms
                                └──→ /policy/privacy
/sign-up(자리표시자) ──→ /sign-up/complete ──→ /sign-in?type=
```

`/policy`의 유일한 인바운드는 학생·트레이너 **마이페이지**이고 둘 다 미구현이다.
`/sign-up/complete`의 유일한 인바운드는 `/sign-up`(자리표시자)이다.
즉 지금 옮기면 **선행 작업으로만 의미가 있고, 확인은
`--dart-define=INITIAL_LOCATION=/policy`로 한다.**

덤: `frontend/src/page/public/ui/InvitedPage.tsx` L61·L65의 "개인정보 처리방침"·
"서비스 이용약관" 링크가 `href='#'`로 **죽어 있다.** Flutter에서는 실제 경로로
연결하는 것이 맞다(법적으로도).

## 새로 필요한 자산 2개

- `arrow_right_small.svg` (208B) — `/policy` 리스트 행.
  웹이 `stroke={'var(--gray-400)'}`로 색을 넘기지만 **실측 결과 no-op다** —
  자산 자체가 이미 `stroke="#A7A9AE"`이고 `--gray-400: #a7a9ae`로 같은 값이다.
  Flutter에서는 `back.svg`·`close.svg`처럼 색을 덮지 않고 그대로 쓴다.
- `signUpComplete.png` (8.7KB, 100×100) → `assets/images/sign_up_complete.png`
  (레포 관례대로 snake_case로 옮겼다)

`back.svg`는 이미 있다. 자산을 추가하면 `test/shared/assets_test.dart` 목록에도
넣어야 한다(규율 #8).
