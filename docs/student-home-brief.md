# `/student` 홈 이관 brief — Phase A (2026-09-15)

웹 `src/app/(login-required)/student/page.tsx` → Flutter. 로그인이 착지하던
자리표시자 셋 중 두 번째를 뚫는 작업이고, **회원 화면 25개의 기반**이 된다.

---

## Phase A / B 경계 (사용자 결정, 2026-09-15)

| | Phase A (이번) | Phase B (다음) |
|---|---|---|
| 화면 | 진입 렌더 전부 (카드 5종 + 헤더 + 하단 네비) | — |
| 요청 | **GET 3건** = 골든 `home-student` | `POST /push`(FCM) · `POST /file` · `PUT {presigned}` · `POST /diets/home` |
| 식단 | 타일 3분기 **렌더만** | 바텀시트 · S3 업로드 · 단식 토글 |
| 인프라 | `intl`(ko 날짜 포맷) | FCM · S3 · 401 리프레시 |

**Phase A의 완료 정의:** `expectParity('home-student', ...)`가 통과한다.
`next-steps.md` §6의 부채 "`home-student.json` 골든이 소비되지 않는다"가 여기서 닫힌다.

---

## 하단 네비는 Phase A 필수다 (실측이 뒤집은 것)

골든 3건 중 `GET /api/v1/members/trainer-mapping`은 **홈 페이지가 아니라
하단 네비가 쏜다.** `useCheckTrainerMemberMappingQuery`
(`feature/schedule/api/queries.ts:18-28`)에 `enabled` 옵션이 없어
`StudentNavigation`이 마운트되는 순간 자동 실행된다.

네비 없이 화면만 만들면 요청이 2건이고 `expectParity`가
`요청 개수 불일치: 기대 3건, 실제 2건`으로 떨어진다. **골든이 이 선택을 이미 닫아놨다.**

### 요청 순서

골든 순서는 `trainer-mapping` → `home/student` → `red-dot`이다.
웹에서 이 순서가 나오는 이유는 React의 effect가 자식부터 실행되기 때문이지만
(네비가 자식), **Flutter에서 그 메커니즘을 재현하려 하지 않는다.**
`parity_matcher`가 인덱스 순서로 비교하므로 **골든 순서를 요구사항으로 받아
그 순서대로 호출을 개시한다.**

---

## 웹 원본

| 파일 | 줄 | 역할 |
|---|---:|---|
| `page/home/ui/StudentHomePage.tsx` | 469 | 화면 본체. 카드 5종 + FCM 등록 |
| `widget/navigation.tsx` | 206 | `StudentNavigation`(탭 4개) / `TrainerNavigation` |
| `widget/layout.tsx` | 76 | `type`별 하단 슬롯 분기 |
| `feature/course/ui/CourseCard.tsx` | 97 | 수강권 카드 헤더/본문 + 진행률 |
| `feature/log-diet/ui/TodayDiet.tsx` | 285 | 타일 3분기 + 시트 + S3 (**타일만 이관**) |
| `feature/home/api/queries.ts` | 65 | `useStudentHomeDataQuery` + `HomeDataResponse` |
| `entity/alarm/api/queries.ts` | 51 | `useHomeAlarmQuery` |
| `shared/ui/card.tsx` · `progress.tsx` · `collapsible.tsx` | 63·31·16 | 프리미티브 |

---

## API 3건 (골든 `home-student`)

| # | 요청 | 쏘는 주체 | 응답 |
|---|---|---|---|
| 1 | `GET /api/v1/members/trainer-mapping` | 하단 네비 마운트 | `{ mapped: bool }` |
| 2 | `GET /api/v1/home/student` | 페이지 | `StudentHomeResult` (8필드) |
| 3 | `GET /api/v1/notification/red-dot` | 페이지 | `bool` |

셋 다 `authApi`(토큰 주입). 본문 없는 GET이라 `content-type`이 붙지 않는다 —
`/select-gym`과 같다.

### `redDotStatus`가 두 번 온다 — 그대로 둔다

백엔드 `StudentHomeResult`에 `redDotStatus` 필드가 **이미 있는데**
웹은 `/notification/red-dot`을 따로 한 번 더 부르고, 헤더 빨간 점은
**따로 부른 쪽**을 쓴다(`homeAlarmData`). 중복 조회지만 골든이 3건이므로
**앱도 3건을 그대로 쏴야 한다.** "고치면" 패리티가 깨진다.

---

## 모델 — 웹 TS 타입을 믿으면 안 된다

`HomeDataResponse`(`queries.ts:24-54`)는 7필드를 **전부 non-optional**로
선언하는데, 소비 측은 네 필드를 전부 런타임 가드한다
(`{data?.course && ...}`, `data?.myReservation ? ... : ''`,
`{data?.lessonHistory && ...}`, `{data?.diet && ...}`).
**선언된 타입이 실제 계약과 다르다** — 그대로 Dart로 옮기면 null 역참조가 난다.

백엔드 `StudentHomeResult`(record)도 null 여부를 보장하지 않으므로
**8필드 전부 nullable로 받고 화면에서 가드한다.** 웹이 `point`·`rank`·`gym`을
가드 없이 접근하는 것은 웹의 운이지 계약이 아니다.

| 필드 | Dart | 근거 |
|---|---|---|
| `course` | `Course?` | `courseId, totalLessonCnt, remainLessonCnt, completedLessonCnt, createdAt` |
| `point` | `StudentPoint?` | `searchDate("YYYY-MM"), monthPoint, totalPoint` |
| `rank` | `StudentRank?` | `ranking, lastMonthRanking, totalMemberCnt` |
| `myReservation` | `MyReservation?` | `scheduleId, lessonDt, lessonStartTime, lessonEndTime, trainerName, reservationStatus` |
| `lessonHistory` | `LessonHistory?` | `id, content, trainerProfile, feedbackChecked('READ'\|'UNREAD')` 등 |
| `diet` | `HomeDiet?` | `breakfast/lunch/dinner: { fast, type, dietFile: {fileUrl}? }` |
| `gym` | `Gym?` | 기존 `entity/gym/model/gym.dart` 재사용 |
| `redDotStatus` | `bool?` | **쓰지 않는다** (위 참고) |

`lessonHistory.files`는 웹이 단수 객체로 선언했지만 백엔드는
`List<LessonHistoryFileResults>`다 — **웹 타입이 틀렸다.** 홈은 `files`를
쓰지 않으므로 Phase A 모델에서 생략한다.

### 서버가 이미 포맷해 주는 것과 아닌 것을 섞지 말 것

- `lessonHistory.lessonDt`·`lessonTime` → 서버가 `MM월 dd일 E요일` /
  `HH:mm - HH:mm`로 **포맷한 문자열**(`LessonTimeFormatter`, `Locale.KOREAN`).
  문자열 그대로 쓴다. 홈은 둘 다 렌더하지 않는다.
- `myReservation.lessonDt`·`lessonStartTime` → **원시** `LocalDate`/`LocalTime`.
  화면이 포맷한다. 여기가 `intl`이 필요한 유일한 자리다.

---

## `intl` 도입 (Phase A 크리티컬 패스)

분기 12(`myReservation` 카드)가 ko 로케일 날짜를 쓴다:

| 웹 | Flutter | 결과 |
|---|---|---|
| `dayjs(lessonDt).format('MM.DD (ddd)')` | `DateFormat('MM.dd (E)', 'ko')` | `09.15 (월)` |
| `dayjs(lessonStartTime,'HH:mm:ss').format('A hh:mm')` | `DateFormat('a hh:mm', 'ko')` | `오후 02:30` |

- `pubspec.yaml`에 `intl` 추가, 앱 진입점에서 `initializeDateFormatting('ko')`.
- 포맷 결과를 **전용 테스트로 고정**한다(`app_test.dart`가 아니라).
  `ddd`(dayjs 3글자 약어)가 ko 로케일에서 한 글자 요일(`월`)이라는 것과,
  `A`가 `오전/오후`라는 것이 단언 대상이다.
- `dayjs(new Date()).format('YYYY-MM')`(식단전체 링크 쿼리)도 여기서 쓴다.

---

## 필요한 신규 프리미티브

| Flutter | 웹 | 메모 |
|---|---|---|
| `AppCard` | `shared/ui/card.tsx` | `rounded-lg`(12) · `bg-white` · `p-6`(16) · `gap-y-2`(6) 기본값. 홈은 거의 전부 override |
| `AppProgress` | `shared/ui/progress.tsx` | 트랙 `bg-blue-600/20`, 바 `bg-white`(만료 시 `gray400`), `h-[2px]` |
| `AppCollapsible` | `shared/ui/collapsible.tsx` | Radix 재export. 트리거 + 애니메이션 펼침 |
| `AppBottomNavigation` | `widget/navigation.tsx` | 탭 4개. `AppLayout`에 슬롯 신설 |

`AppLayout`에 **`bottomNavigation` 슬롯을 추가**한다. 기존 `bottomArea`는
`p-7` 패딩이 붙지만 네비는 패딩이 다르다(`px-11 py-[18px]` = 36/18). 웹
`layout.tsx:35-37`도 `type === undefined && footer`로 **배타 분기**다 —
같은 규칙을 옮긴다.

---

## 하단 네비 상세

`px-11 py-[18px]`(36/18) · `bg-white` · `rounded-t-md`(8) ·
`shadow-nav` = `0px -2px 8px 0px rgba(0,0,0,0.06)`.

> `tailwind.config.js:149`가 `nav: 'shadow-nav'`라는 **무효 CSS 값**을 만들고,
> 실제 값은 `global.css:219`의 `.shadow-nav`에 있다. 무효 선언은 파서가
> 버리므로 순서와 무관하게 후자가 적용된다.

| 탭 | 라우트 | 요소 | 아이콘 |
|---|---|---|---|
| 홈 | `/student` | Link | `home_filled` / `home_outlined` |
| 수업예약 | `/student/schedule` | **Button — 가드 있음** | `calendar_*` |
| 커뮤니티 | `/student/community` | Link | `community_*` |
| 마이 | `/student/mypage` | Link | `profile_*` |

라벨 `Typography.NAV_TEXT`(10px medium), 활성 `text-black` / 비활성 `text-gray-700`.
아이콘·라벨 사이 `gap-y-2`(6).

### 수업예약 탭 가드 (`navigation.tsx:113-124`)

```
refetch() → GET /api/v1/members/trainer-mapping (두 번째 요청)
  mapped truthy → router.replace('/student/schedule')   ← push 아님
  falsy 또는 throw → errorToast('트레이너가 지정된 후에 예약 가능합니다')
```

두 실패 경로가 **같은 토스트**다. `replace`이므로 뒤로가기로 홈에 못 돌아온다 —
웹 그대로 옮긴다.

**이 두 번째 요청은 골든에 없다**(골든은 진입 시점 캡처). 계약 테스트로 고정한다.

### 라우트 10개 추가 (설계 시 3개로 잡았으나 실제로는 10개였다)

하단 네비 3개만 생각했는데, 헤더와 카드에서 나가는 경로가 7개 더 있다.
go_router는 등록되지 않은 경로로 `go`하면 에러 화면을 띄우므로 **빠뜨리면
그 카드를 누르는 순간 앱이 에러 화면으로 빠진다.**

`/student/alarm`(헤더) · `/student/schedule` · `/student/community` ·
`/student/mypage`(네비) · `/student/course-history` ·
`/student/point-history` · `/student/log` · `/student/log/:id` ·
`/student/diet` · `/student/workout`

전부 `NotImplementedPage`. 기존 관행(`/sign-up`·`/cs`·`/policy/terms`)과 같다.

---

## 화면 분기 (웹 실측 17건)

| # | 조건 | 결과 |
|---|---|---|
| 1 | `isPending` | `h-[500px]` 중앙 로딩 (본문 전체 대체) |
| 2 | `homeAlarmData` truthy | 헤더 알림 아이콘 우상단 4×4 빨간 점(`bg-point`) |
| 3/4 | `course` 있음 / 없음 | `CourseCard` / `h-[127px]` gray500 박스 "현재 등록된 수강권이 없습니다." |
| 5 | `completed == total` | 카드 `bg-gray-500`, `"N회 PT수강 만료"`, 진행바 `gray400`, 하단 **gray400 고정 바(접기 불가)** |
| 6 | `completed != total` | `"N회 예약할 수 있어요!"`, 하단 `primary600` Collapsible |
| 7 | `isOpen` | 닫힘: 포인트 아이콘+월포인트+↓ / 열림: ↑(180° 회전)만 |
| 8 | `rank.ranking == 999` | `-` / 아니면 `N위` |
| 9/10/11 | `==` / `>` / `<` lastMonthRanking | 화살표 없음 / `arrow_filled_down`(primary500) / `arrow_filled_up`(point) |
| 12 | `myReservation` 있음 | "다음 PT예정일" 카드 |
| 13 | `lessonHistory` 있음 | "수업 일지" 카드 |
| 14 | `feedbackChecked == 'UNREAD'` | 제목 옆 20×20 원형 배지 `1`(primary500) |
| 15 | `trainerProfile` 있음 | 28×28 원형 사진 / 없으면 `avatar.svg` |
| 16 | `diet` 있음 | 타일 3개 / 없으면 카드는 남고 내용만 빈칸 |
| 17 | (무조건) | "개인 운동 기록" 카드 |

### 식단 타일 3분기 (`TodayDiet.tsx:185-250`)

타일은 `w-[calc((100%-12px)/3)]` · `h-[88px]` · `bg-gray-100` · `rounded-md`(8).

| 조건 | 렌더 |
|---|---|
| `fast == true` | `check.svg`(17×17, primary500) + "단식", `TITLE_2` gray400, 세로 배치 `mb-1` |
| `fast == false` && `dietFile.fileUrl` | 사진(`?w=400&h=400&q=90`), `rounded-md`, cover |
| `fast == false` && 없음 | `plus.svg` 20×20 gray500 |

---

## 이관하는 웹 버그 2건 (사용자 결정: 버그째 이관 + 기록)

**① 월 표시** — `point.searchDate.split('-')[1].split('')[1]`
(`StudentHomePage.tsx:179`·`:314`, 같은 식이 두 곳).
`"2026-09"` → `"09"` → `[1]` = `"9"`. 01~09월에만 우연히 맞고
**10월 → "0월", 11월 → "1월", 12월 → "2월"**이 된다.
Dart로도 같은 문자열 연산으로 옮기고, 그 성질을 **테스트로 고정**한다
(우연히 "고쳐지는" 것을 막는다).

**② 포인트·랭킹이 수강권에 종속** — 포인트/랭킹 UI가
`{data?.course && (...)}` 블록(151-338행) **안쪽**에 중첩돼 있어,
응답에 `point`·`rank`가 있어도 `course`가 null이면 통째로 사라진다.
Flutter도 같은 중첩 구조로 옮긴다.

둘 다 `deferred-minors.md`에 "웹과 함께 고쳐야 할 것"으로 기록한다.
선례: `/policy` 작업의 웹 빈 `<h3>`(제24조 누락) — 발견·미수정으로 기록만 했다.

---

## 명시적 이탈

1. **로딩 표시** — 웹 `/images/loading.gif` 20×20.
   `CircularProgressIndicator`로 대체한다(`/select-gym` 선례, 규율 #8).
2. **식단 타일 탭** — 웹은 바텀시트가 열린다. Phase A는 타일만 그리므로
   탭했을 때 **Phase B 미구현임이 드러나는 처리**를 한다. 아무 일도 안
   일어나게 두면 죽은 UI가 된다.
3. **`isError` 미처리** — 웹은 요청 실패 시 `isPending`이 false가 되고
   `data`가 `undefined`라, **네트워크 에러 화면이 "수강권 없음"과 시각적으로
   동일하다**. 웹 패리티로 그대로 두고 `deferred-minors.md`에 기록한다.
   `/select-gym`의 "빠져나갈 길이 없다" 이월 항목과 같은 부류지만, 홈은
   헤더·네비가 있어 막다른 길은 아니다.
4. **포커스 복귀 재요청 없음** — 웹 `QueryProvider`가 `new QueryClient()`
   (옵션 전무)라 TanStack v5 기본값 `refetchOnWindowFocus: true`가 살아 있어
   **탭 복귀마다 3건이 전부 재요청된다.** 앱에는 그 개념이 없고, 옮기면
   골든이 잡지 못하는 요청이 생긴다. 이관하지 않는다.

---

## 신규 자산 (웹에서 그대로 복사)

**SVG 15개** — `alarm` · `arrow_down` · `arrow_filled_down` ·
`arrow_filled_up` · `avatar` · `check` · `plus` ·
`home_filled` · `home_outlined` · `calendar_filled` · `calendar_outlined` ·
`community_filled` · `community_outlined` · `profile_filled` · `profile_outlined`

**PNG 1개** — `point.png`(21×21로 렌더)

전부 `test/shared/assets_test.dart`의 `_svgAssets` 목록에 추가한다(규율 #8).
`logo.svg`·`arrow_right_small.svg`는 이미 있다.

---

## 파일

**신규**

```
lib/entity/home/model/student_home.dart      Course·StudentPoint·StudentRank·
                                             MyReservation·LessonHistory·HomeDiet
lib/entity/home/api/home_api.dart            studentHome()
lib/entity/notification/api/notification_api.dart  redDot()
lib/entity/member/api/member_api.dart        trainerMapping()
lib/shared/ui/app_card.dart
lib/shared/ui/app_progress.dart
lib/shared/ui/app_collapsible.dart
lib/widget/app_bottom_navigation.dart
lib/feature/course/ui/course_card.dart
lib/feature/diet/ui/today_diet_tile.dart
lib/page/protected/student_home_page.dart
lib/core/date/korean_date_format.dart        intl 초기화 + 포맷 헬퍼
```

**수정**

- `lib/widget/app_layout.dart` — `bottomNavigation` 슬롯 신설(배타)
- `lib/core/router/app_router.dart` — `/student` 실제 페이지 + 라우트 3개 추가
- `lib/main.dart` — `initializeDateFormatting('ko')`
- `pubspec.yaml` — `intl`
- `test/shared/assets_test.dart` — 자산 16개

---

## 틀리기 쉬운 지점

1. **요청 3건의 순서**가 골든에 고정돼 있다. 네비를 페이지보다 먼저 마운트하는
   구조로 만들거나, 호출 개시 순서를 명시적으로 제어한다.
2. **규율 #12** — `AppLayout.contents` 안에서 `Expanded` 금지. 로딩 자리
   (`h-[500px]` 중앙 정렬)가 정확히 걸린다. 고정 높이 박스로 간다.
3. **`h-7 w-7`은 20×20이다**(스케일). 28이 아니다. `h-9 w-9`는 28.
   배지·프로필 크기를 여기서 틀리기 쉽다.
4. **`text-[#8EC7FF]`는 `primary200`이다.** 리터럴로 두지 말 것.
5. **웹 `Link href='./student/course-history'`는 상대 경로**다 —
   `/student`에서 `/student/course-history`로 해석된다. 파일 안의 다른
   링크는 전부 절대 경로라 이 둘(`course-history`·`point-history`)만 다르다.
6. **`isOpen`과 Collapsible 내부 상태가 웹에서 이중 관리**된다
   (Radix는 uncontrolled, `onClick`이 `toggleArrow`도 부름). 같은 클릭으로
   함께 움직이므로 Flutter에서는 **bool 하나로 합친다.**
7. **`rank.ranking == 999`가 "없음" 표식**이다. 실제 999위가 아니다.
