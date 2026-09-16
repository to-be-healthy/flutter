# `/trainer` 홈 이관 brief — Phase A (2026-09-15)

웹 `src/page/home/ui/TrainerHomePage.tsx`(354줄) → Flutter.
로그인이 착지하던 자리표시자 셋 중 **마지막 하나**를 뚫는다(`/select-gym` →
`/student` → 여기). 이관 후 트레이너 계정도 실제 홈을 본다.

---

## Phase A / B 경계 (`/student` 홈 선례를 그대로 적용)

| | Phase A (이번) | Phase B |
|---|---|---|
| 화면 | 진입 렌더 전부 + 하단 네비 | — |
| 요청 | **GET 3건** = 골든 `home-trainer` | `POST /push`(FCM) · `PATCH /course/{id}`(수강권 지급) |
| 다이얼로그 | 탭하면 "준비 중" | 회원 추가 · 수강권 지급 확인 모달 |

식단 타일을 렌더만 하고 시트를 미뤘던 것과 같은 경계다. 다이얼로그 너머는
**공유 체험 계정의 실제 데이터를 바꾸는 뮤테이션**(`PATCH /api/v1/course/{courseId}`
— 회원 수강권 +1)이라 골든도 만들 수 없다.

---

## 골든 `home-trainer` — 학생 홈과 모양이 다르다

`har/home-trainer.har` → `test/fixtures/requests/home-trainer.json`. 2026-09-15 캡처.

| # | 요청 | 쏘는 주체 | 응답 |
|---|---|---|---|
| 1 | `GET /api/v1/members/me` | 페이지 (`useMyInfoQuery`) | `MemberInfoResult` |
| 2 | `GET /api/v1/home/trainer` | 페이지 (`useTrainerHomeQuery`) | `TrainerHomeResult` |
| 3 | `GET /api/v1/notification/red-dot` | 페이지 (`useHomeAlarmQuery`) | `bool` |

**세 건 전부 페이지가 쏜다.** 학생 홈의 1번(`members/trainer-mapping`)은 하단
네비가 쐈지만 `TrainerNavigation`에는 react-query 훅이 **하나도 없다**(가드가
없어서 탭 넷이 전부 `<Link>`다). 그래서:

> **학생 홈의 `addPostFrameCallback` 순서 맞추기가 여기서는 필요 없다.**
> 세 요청을 `initState`에서 선언 순서대로 개시하면 골든과 같아진다.

`members/me`는 **헤더의 헬스장 이름 하나** 때문에 붙는 왕복이다(학생 홈은
`home/student` 응답의 `gym` 필드로 해결한다). 백엔드 `TrainerHomeResult`에도
`gym`이 있지만 웹은 쓰지 않는다 — **요청을 줄이면 골든이 깨진다.**

`redDotStatus`가 홈 응답 안에 또 있는 것도 학생 홈과 같다. 그대로 3건을 쏜다.

---

## 응답 계약

### `GET /api/v1/home/trainer` → `TrainerHomeResult`

백엔드는 5필드(`studentCount` · `bestStudents` · `todaySchedule` · `gym` ·
`redDotStatus`)인데 **웹 타입 `TrainerHomeInfo`는 앞의 셋만 선언한다.**
뒤의 둘은 웹이 쓰지 않으므로 Flutter 모델도 셋만 담는다.

| 필드 | 타입 | 화면이 쓰는가 |
|---|---|---|
| `studentCount` | `int` | O — "회원 N" |
| `bestStudents` | `List<BestStudent>?` | O — **웹 타입도 `\| null`이다**(유일하게 정직한 필드) |
| `todaySchedule` | `{trainerName, scheduleTotalCount, schedule[]}` | `schedule`만 |

`BestStudent` 11필드 중 화면이 쓰는 것은 **`memberId` · `name` · `courseId`
셋뿐**이다. `ranking`은 있는데 **안 쓴다**(아래 BUG-2).

`TrainerLesson`(백엔드 `LessonDetailResult`) 9필드 중 쓰는 것은
`scheduleId` · `lessonStartTime` · `applicantId` · `applicantName` 넷.
`reservationStatus`가 있는데 **필터에 쓰지 않는다**(아래 BUG-3).

### `GET /api/v1/members/me` → `MemberInfoResult`

12필드지만 화면이 쓰는 것은 **`gym.name` 하나**다. Flutter 모델도 그만 담는다 —
마이페이지를 옮길 때 그쪽이 나머지를 받는다.

### 웹 타입이 계약과 다른 곳 3군데 (학생 홈과 같은 습관)

`todaySchedule`·`schedule`·`gym`이 TS에서 non-optional인데 소비 측은
`homeInfo?.todaySchedule.schedule`처럼 **첫 단계만** 옵셔널 체이닝한다.
서버가 null을 주면 TypeError다. **전부 nullable로 받고 빈 리스트·빈
문자열로 흡수한다.**

---

## 이관하는 웹 버그 (선례: `/student` 홈 — 버그째 이관 + 기록)

### BUG-1 — "가장 가까운 수업" 하이라이트가 **항상 첫 번째**다 (확정)

`findClosestSchedule`(`TrainerHomePage.tsx:69-93`)이
`dayjs(schedule.lessonStartTime)`에 파싱 포맷을 주지 않는다.
**`lessonStartTime`은 시각 전용 문자열이다** — 백엔드
`LessonDetailResult.lessonStartTime`이 `LocalTime`이고 Spring Boot 기본
Jackson 설정에서 `"09:00:00"`으로 직렬화된다(서베이는 이 점을 "미확인"으로
남겼으나 백엔드 소스로 확정했다).

dayjs의 `REGEX_PARSE`는 4자리 연도로 시작해야 매치되므로 `"09:00:00"`은
네이티브 `Date`로 폴백해 **Invalid Date**가 된다. 그 결과:

- `lessonStartTime.isBefore(now)` → `false` → **지난 수업이 걸러지지 않는다**
- `!closestSchedule || lessonStartTime.isBefore(...)` → 첫 항목에서만 참
- ⇒ `closestSchedule`은 **언제나 배열의 첫 원소**

Flutter는 "첫 원소를 하이라이트"로 직역하고 그 사실을 테스트로 고정한다.
`intl`로 파싱해 "진짜 가장 가까운 수업"을 구현하면 **웹과 다른 화면이 된다.**

### BUG-2 — 우수 회원이 2명 이상이면 헤더와 메달이 N번 반복된다

`bestStudents.map()` **안쪽**에 섹션 헤더(`{month}월의 우수 회원`)와
메달 숫자가 들어 있고, 메달 숫자는 `item.ranking`이 아니라 **하드코딩 `'1'`**
이다(`:293`, `:298`). 3명이면 "1월의 우수 회원 / 1" 블록이 3번 나온다.
학생 홈의 "포인트·랭킹 중첩" 버그와 같은 계열이다.

### BUG-3 — `/trainer/manage/null`로 이동할 수 있다

`:194`의 `href={\`/trainer/manage/${item.applicantId}\`}`에 가드가 없다.
`applicantId`는 `number | null | undefined`이고, `reservationStatus`가
있는데도 필터에 쓰지 않는다(서버가 예약된 것만 준다는 암묵적 가정).

### BUG-4 — 로딩 중 **내용 없는 빈 카드**가 뜬다

트레이너 홈에는 `isPending` 분기가 **아예 없다**(학생 홈은 `h-[500px]`
스피너로 가린다). `!hasTodaySchedule`은 로딩 중에도 참이고, 그 안의
`homeInfo?.todaySchedule.schedule.length === 0`은 `undefined === 0` →
거짓이라, **자식이 하나도 없는 100px 흰 카드**가 그려진다.

> 앱은 웹보다 이 순간이 길다(콜드 네트워크). 웹 패리티로 그대로 옮기되
> `deferred-minors.md`에 적는다 — 같은 앱 안에서 학생 홈만 스피너가 있는
> 비대칭이 남는다.

### BUG-5 (경미) — `shaodw-none` 오타

`:280`. Tailwind가 인식하지 못해 무시된다(`Card` 기본에 그림자가 없어 시각
영향 없음). **의도는 "그림자 없음"이었다** — Flutter도 그림자를 주지 않는다.

### BUG-6 (경미) — 우수 회원 월이 기기 시계 기준

`new Date().getMonth() + 1`. 서버 응답에 기준 월 필드가 아예 없다.
학생 홈의 문자열 파싱 버그(`split('')[1]`)와는 **다른 부류이고, 10~12월
표시는 정상이다.** 그대로 옮긴다.

---

## 화면 구조

```
Layout (relative)
├ 파란 배너  absolute top-0 h-[170px] w-full bg-primary   ← z-0
├ Header (z-10)   헬스장명(TITLE_2 흰색)  |  알림(alarm_white) + 빨간 점
└ Contents
  ├ 오늘의 수업  (gap-y-5, pt-8 pb-10)
  │  ├ h3 "오늘의 수업"  HEADING_4_BOLD 흰색, px-7
  │  ├ 수업 있음 → 가로 스크롤. 카드 100×100, rounded-md, border gray200,
  │  │             mr-4(10), 첫 카드만 border-[#00D1FF]  ← BUG-1
  │  │             시각(BODY_2 gray500) + 이름(TITLE_1_BOLD)
  │  └ 수업 없음 → px-7 안에 100px 흰 카드
  │                 (데이터 도착 후에만 calendar_x 42px + "예약된 수업이 없습니다.")
  ├ 숏컷 2열 그리드  mt-[19px], px-7, gap-2(6), 카드 h-[140px]
  │  ├ "회원 N"   → /trainer/manage      + 우상단 plus 버튼(회원 추가 모달)
  │  │              본문 "간편한 회원 관리와\n운동 일지 공유"
  │  │              우하단 60×60 icon_profile_coin_shadow.png
  │  └ "피드백 작성" → /trainer/manage/feedback
  │                 본문 "수업 내역 관리와\n피드백 작성"
  │                 우하단 60×60 icon_calendar_shadow.png
  └ 우수 회원  mt-6, 카드 하나에 gap-6(16)으로 회원 N명
     메달(medal_gold) + 가운데 "1" | "{월}월의 우수 회원" + 이름 | [수강권 지급]
└ BottomArea(p-0) → TrainerNavigation
```

### 배너와 Layout 사용법이 학생 홈과 다르다

학생 홈은 `<Layout type='student'>`로 네비가 **자동 주입**되지만, 트레이너 홈은
`type`을 넘기지 않고 `<Layout.BottomArea className='p-0'>` **안에**
`<TrainerNavigation />`을 직접 넣는다. 결과는 같은 자리에 같은 네비이므로
Flutter는 `AppLayout.bottomNavigation` 슬롯 하나로 통일한다(그 슬롯이 이미
패딩을 주지 않는다 — 웹의 `p-0` 오버라이드와 같은 상태다).

**파란 배너는 `Stack`으로 옮긴다.** 헤더와 "오늘의 수업" 제목이 그 위에 얹혀
흰 글씨가 된다. 웹은 z-index가 일부 요소에만 붙어 있어(BUG-8) 렌더 순서에
의존하는데, Flutter `Stack`은 순서가 곧 z라 명시적으로 잡는다.

---

## 하단 네비 — 학생과 다른 점

| | 트레이너 | 학생 |
|---|---|---|
| 탭 2 | **스케줄** → `/trainer/schedule` (`<Link>`) | 수업예약 (Button + 가드) |
| 마운트 시 요청 | **없음** | `trainer-mapping` |
| 홈 탭 아이콘 활성 | `/trainer` **또는** `/trainer/manage` | `/student` |
| 홈 탭 **라벨** 활성 | `/trainer` 만 | `/student` |

> 아이콘과 라벨의 활성 조건이 갈린다 — `/trainer/manage`에서는 **아이콘은
> 켜지고 라벨은 꺼진다.** 웹 실측이고 그대로 옮긴다.

스타일(`px-11 py-[18px]`·`rounded-t-md`·`shadow-nav`)과 아이콘 8종은
**학생 네비와 문자열까지 동일**하다 → 표현 부분을 `AppNavigationBar`로
빼고 두 네비가 공유한다.

---

## 파일

**신규**

```
lib/entity/home/model/trainer_home.dart        TrainerHome·BestStudent·TrainerLesson
lib/entity/member/model/member_info.dart       MemberInfo(gym.name 만)
lib/widget/app_navigation_bar.dart             표현 전용 네비 셸 + AppNavigationTab
lib/page/protected/trainer_home_page.dart
```

**수정**

- `lib/entity/home/api/home_api.dart` — `trainerHome()`
- `lib/entity/member/api/member_api.dart` — `me()`
- `lib/widget/app_bottom_navigation.dart` — 학생 네비를 `AppNavigationBar` 위로
  옮기고 `AppTrainerBottomNavigation` 추가
- `lib/core/router/app_router.dart` — `/trainer` 실제 화면 + 자리표시자 7개
- `test/shared/assets_test.dart` — SVG 3개

**신규 자산 5개** — `alarm_white.svg` · `calendar_x.svg` · `medal_gold.svg` ·
`icon_profile_coin_shadow.png` · `icon_calendar_shadow.png`
(셋 다 `fill="current"` 문제 없음 — 규율 #13 확인)

---

## 라우트 7개 추가

`/trainer/alarm` · `/trainer/schedule` · `/trainer/community` ·
`/trainer/mypage` · `/trainer/manage` · `/trainer/manage/:memberId` ·
`/trainer/manage/feedback`

`/trainer/class-time-setting`은 이미 있다. 학생 홈에서 배운 대로 **빠뜨리면
카드를 누르는 순간 go_router 에러 화면**이다.

---

## 틀리기 쉬운 지점

1. **`calendar_x.svg`는 자산 고유 크기와 렌더 크기가 다르다.**
   자산은 `width=28 height=28`인데 `viewBox`는 `0 0 42 42`이고, 웹은
   `<IconCalendarX width={42} />`로 **42px**에 그린다.
2. **숏컷 카드 본문의 `\n`은 실제 줄바꿈이다.** 웹이 템플릿 리터럴로
   `{`간편한 회원 관리와\n운동 일지 공유`}`를 넣고 `CardContent`가
   `whitespace-pre-wrap`이라 두 줄로 보인다.
3. **`gap-2`는 6px이다**(커스텀 스케일). Tailwind 기본 8이 아니다.
   `gap-4`=10, `gap-6`=16, `gap-y-5`=12, `mt-6`=16, `pt-8`=24, `pb-10`=32.
4. **`mt-[19px]`·`h-[140px]`·`h-[100px]`·`h-[170px]`·`-right-[2px]`는 임의값**
   이라 상수로 옮긴다(규율 #4).
5. **로딩 스피너를 발명하지 마라.** 웹에 `isPending` 분기가 없다(BUG-4).
   넣으면 웹에 없는 화면이 된다.
6. **배너 높이 170은 헤더(56)를 포함한 값이다.** 웹은 `<Layout className=
   'relative'>` 안쪽(헤더 + 본문을 함께 담는 div)을 기준으로 `top-0`이라
   화면 맨 위부터 170px가 파랗고, 그중 56px가 헤더 자리다.

   **Flutter에서는 `Stack` 하나로 안 된다.** `AppBar`는 `Scaffold`가 본문과
   별개 레이어로 그려서 본문 `Stack`이 그 뒤를 칠할 수 없다. 그래서
   **헤더를 `primary500`으로 직접 칠하고 본문에는 `170 - 56 = 114`만**
   그린다. 본문에 170을 그대로 그리면 합이 **226px**가 되어 웹보다 56px 더
   파래진다 — 처음 구현에서 실제로 이렇게 틀렸고, 800×600 테스트 43개가
   전부 통과한 채로 넘어갔다(높이를 재는 단언이 없었다).
   `TrainerHomePage.bannerBodyHeight`와 "헤더와 배너를 합친 파란 영역이
   웹과 같은 170이다" 테스트가 이 합을 고정한다.
