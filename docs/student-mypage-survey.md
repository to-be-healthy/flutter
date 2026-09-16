# 회원(student) 마이페이지 9개 화면 — 웹 원본 실측

> 조사: 2026-09-15. 웹 루트 `frontend/`, 백엔드 루트 `backend/`.
> 모든 주장에 `파일:줄` 근거를 달았다. 확인 못 한 것은 **미확인**으로 남겼다.

## 0. 이 문서를 읽기 전에 — 실측으로 해소·정정된 것

> **이 문서는 브라우저를 띄우지 않은 정적 분석으로 시작했고, 9개 화면을
> 실제로 옮기며 여러 항목이 정정됐다.** 정정은 해당 항목 안에 인용문으로
> 붙여 두었다(BUG-6·BUG-16·BUG-17). 아래 ①~③도 같은 성격이다.
>
> **이관하며 확정된 사실은 `docs/progress.md`와 `docs/deferred-minors.md`가
> 정본이다.** 이 문서는 조사 시점의 기록이다.

조사는 **브라우저를 띄우지 않은 정적 분석**이다. 같은 날 playwright로
직접 캡처한 결과가 세 가지를 바꾼다.

### ① 허브의 요청 순서 — 조사의 "미확인"이 해소됐다

조사는 두 요청의 와이어 순서를 측정하지 못했고 "병렬로 보고 순서에 의존하지
말라"고 적었다. **실측 결과 순서가 있고, 그 순서가 골든의 계약이다.**

```
1. GET /api/v1/members/trainer-mapping   ← 하단 네비가 쏜다
2. GET /api/v1/members/me                ← 화면이 쏜다
```

`home-student` 골든과 **같은 모양·같은 이유**다(React passive effect가
자식부터 실행된다). Flutter는 `initState`가 부모부터라 반대가 되므로,
학생 홈과 똑같이 화면 요청을 `addPostFrameCallback`으로 한 프레임 미뤄야
한다. 골든 `mypage-student`가 이것을 고정한다.

`/student/mypage/info`는 하단 네비가 없어 `members/me` **1건**이다
(골든 `mypage-student-info`).

**두 화면 다 `notification/red-dot`을 부르지 않는다** — 헤더에 알림 종이
없다. 홈 두 화면과 다른 점이라 골든을 복사하면 틀린다.

### ② BUG-17(gym DTO 불일치)은 앱에서 이미 터졌고 고쳤다

조사는 이것을 "웹에서는 `.name`만 써서 표면화되지 않는다"고 분류했다.
**앱에서는 표면화됐다.** `Gym.fromJson`이 `json['gymId'] as int`로
비-null 캐스트를 하고 있어서, `GymDto` 모양(`{id, name}`)이 오면 던졌고
호출부의 `catch (_)`가 그 예외를 삼켰다. 학생 홈은 `Gym.fromJson`이
`StudentHome.fromJson` 안에서 불리므로 **응답 전체의 파싱이 죽어** 모든
섹션이 빈 상태로 그려졌다.

경위와 해법은 `docs/progress.md`의 "헬스장 DTO가 둘이었다" 항목.
결론만: **`Gym`을 넓히지 않고 두 DTO를 분리했다.** `Gym`은 목록
(`GymResult`) 전용, `GymDto`를 받는 쪽은 이름만 담는다.

### ③ 권장 순서를 조정한다 — 하단 네비는 이미 있다

조사는 허브를 7번째로 미루면서 "하단 네비를 먼저 만들어야 하는 셸 작업"을
이유로 들었다. **그 셸은 이미 있다.** `/student` 홈을 옮기며
`AppBottomNavigation`을 만들었고, `trainer-mapping` 요청과 수업예약 탭
가드까지 들어 있다(`lib/widget/app_bottom_navigation.dart`).

그래서 허브가 조사의 판단보다 훨씬 싸다. 게다가 **허브의 골든은 이미
떠 있다.** 순서는 §7에 다시 적는다.

---

## 1. 화면 9개 요약

`app/(login-required)/student/mypage/**/page.tsx` 9개는 전부 `@/page/mypage`
배럴의 재수출이고 실제 구현은 `src/page/mypage/ui/*.tsx`에 있다.

| 웹 라우트 | 실제 구현 파일 |
|---|---|
| `mypage/page.tsx` | `StudentMyPage.tsx` |
| `mypage/info/page.tsx` | `EditMyInfoPage.tsx` |
| `mypage/alarm/page.tsx` | `EditAlarmPage.tsx` |
| `mypage/trainer-info/page.tsx` | `TrainerInfoPage.tsx` |
| `mypage/last-reservation/page.tsx` | `StudentLastReservationPage.tsx` |
| `mypage/leave/page.tsx` | `LeavePage.tsx` |
| `mypage/edit/name/page.tsx` | `EditNamePage.tsx` |
| `mypage/edit/email/page.tsx` | `EditEmailPage.tsx` |
| `mypage/edit/password/page.tsx` | `EditPasswordPage.tsx` |

| # | 라우트 | 마운트 요청 | 난이도 | 설명 |
|---|---|---|---|---|
| 1 | `/student/mypage` | **2건** (실측) | 중 | 프로필 카드 + 3분할 바로가기 + 5행 메뉴 + 앱버전/푸터. **하단 네비가 있는 유일한 화면** |
| 2 | `/student/mypage/info` | 1건 | **상** | 사진 업로드/삭제(multipart), 소셜/일반 분기, **로그아웃·탈퇴 진입점** |
| 3 | `/student/mypage/alarm` | 1건 | 하 | 알림 3종 스위치. 토글 시 PATCH + refetch |
| 4 | `/student/mypage/trainer-info` | 1건 | 하 | 내 트레이너 정보. 없으면 빈 상태 |
| 5 | `/student/mypage/last-reservation` | 1건 | **상** | MonthPicker 바텀시트 + 카드 리스트 + 상세 시트 |
| 6 | `/student/mypage/leave` | **0건** | 중 | 유의사항 + 동의 체크 + 확인 다이얼로그 |
| 7 | `/student/mypage/edit/name` | 1건 | 하 | 1필드 폼 |
| 8 | `/student/mypage/edit/email` | 1건 | 중 | 2스텝(인증요청 → 인증번호) |
| 9 | `/student/mypage/edit/password` | **0건** | 중 | 2스텝(현재 비번 검증 → 새 비번) |

---

## 2. 허브 상세 (`StudentMyPage.tsx`)

### 2-1. 구조

```
Layout(type='student')                          // :25
├─ Layout.Header className='bg-white'           // :26  자식 없음(빈 흰 바 56px)
├─ Layout.Contents                              // :27
│   ├─ [data && ] 프로필 카드 → /student/mypage/info   // :28~57
│   ├─ 3분할 바로가기 (수업일지/식단/운동기록)          // :59~82
│   ├─ <ul> 메뉴 5행                                   // :84~125
│   ├─ 앱 버전 행 (링크 아님)                          // :127~130
│   └─ <footer> 앱 버전 0.0 / 오픈 소스 라이선스 보기   // :132~139
└─ StudentNavigation  ← Layout이 type='student'일 때 자동   // layout.tsx:36
```

`Layout.BottomArea`는 `type === undefined`일 때만 렌더된다(`layout.tsx:37`).
허브는 `type='student'`이므로 BottomArea 대신 **하단 네비**가 붙는다.

### 2-2. 프로필 카드 — `:29~56`

- 전체가 `<Link href={'/student/mypage/info'}>` (`:29`)
- 좌: 프로필 이미지 80×80 (`:33~42`) 또는 `IconAvatar width={80} height={80}` (`:44`)
- 이름: `data?.name ?? ''` / `HEADING_3` (`:48`)
- 부제: `data?.socialType === 'NONE' ? data.userId : data?.email` (`:50`)
  → **일반 계정은 아이디, 소셜 계정은 이메일**
- 우: `IconArrowRightSmall stroke={'var(--gray-400)'}` (`:54`)
- **조건부**: `{data && ( ... )}` (`:28`) — 로딩 중에는 카드 자체가 없다(스켈레톤 없음)

### 2-3. 3분할 바로가기 — `:59~82`

| 라벨(원문) | 이동 | 아이콘 | 근거 |
|---|---|---|---|
| `수업일지` | `/student/log` | `IconClassLog` | `:61,63,64` |
| `식단` | `/student/diet?month=${month}` | `IconDiet` | `:68,70,71` |
| `운동기록` | `/student/workout` | `IconExerciseLog` | `:75,77,78` |

`month = dayjs(new Date()).format('YYYY-MM')` (`:21~22`).
사이 구분선 `<span className='h-11 w-[1px] border border-gray-200' />` ×2 (`:67`, `:74`).

### 2-4. 메뉴 리스트 — `:84~125`

| 순서 | 라벨(원문) | 이동 | 근거 |
|---|---|---|---|
| 1 | `지난 예약` | `/student/mypage/last-reservation?month=${month}` | `:87, :89` |
| 2 | `트레이너 정보` | `/student/mypage/trainer-info` | `:95, :97` |
| 3 | `알림 설정` | `/student/mypage/alarm` | `:103, :105` |
| 4 | `약관 및 정책` | `/policy` | `:111, :113` |
| 5 | `고객센터` | `/cs` | `:119, :121` |

각 행 우측은 모두 `IconArrowRightSmall stroke={'var(--gray-400)'}`.

### 2-5. 앱 버전 행과 푸터

- 앱 버전 행 `:127~130`: 좌 `앱 버전` / 우 `최신 버전` (하드코딩).
  `<div>`이고 링크가 아니다. `<ul>` 행들과 달리 **`items-center`가 빠져 있다**(`:127` vs `:88`).
- 푸터 `:132~139`: `앱 버전 0.0` (하드코딩) + `오픈 소스 라이선스 보기`
  → `href={'#'}` (**동작 없음**), 밑줄 `border-b border-gray-300`.

### 2-6. 조건부 렌더 — 하나뿐이다

허브에 **트레이너 연결 여부에 따른 행 숨김은 없다.** `트레이너 정보` 행은
매핑 유무와 무관하게 항상 렌더되고, 빈 상태는 이동한 화면
(`TrainerInfoPage.tsx:43`)이 처리한다. 허브의 유일한 조건부 렌더는
`{data && ...}`(프로필 카드, `:28`) 하나다.

### 2-7. 로그아웃·탈퇴는 허브에 없다

둘 다 `/student/mypage/info`(`EditMyInfoPage.tsx:237~247`) 최하단에 있다.

```
section  mb-[60px] mt-auto flex w-full items-center justify-center gap-3   // :237
├─ <button> 로그아웃                              // :238~242
├─ <div className='h-4 w-[1px] bg-gray-300' />    // :243  10px × 1px
└─ <Link href={'./leave'}> 탈퇴하기               // :244~246
```

**로그아웃**(`EditMyInfoPage.tsx:83~101`) — 확인 모달 없이 **즉시 실행**:

1. `POST /api/v1/members/logout` (`authApi`)
2. onSuccess:
   - `deleteUserInfo()` — zustand 스토어를 `DEFAULT_AUTH_STATE`로 리셋
     (`entity/auth/model/store.ts:48~50`). persist가 `auth-storage`를 빈 상태로 덮어쓴다
   - `localStorage.clear()` (`:87`) — **전체 삭제**
   - 서비스워커 전부 `unregister()` (`:88~93`)
   - `router.push('/')` (`:94`)
3. 쿠키는 건드리지 않는다. 토큰은 localStorage(`auth-storage`)에만 있다.

**회원탈퇴**(`LeavePage.tsx`) — 확인 다이얼로그 있음:
동의 체크가 켜져야 `계정 삭제하기` 활성(`:88~92`) → 모달 제목
`정말로 탈퇴하시겠어요?`(`:94`), 버튼 `취소`/`탈퇴하기` →
`POST /api/v1/members/delete` → `deleteUserInfo()` + `router.replace('/')`.
**`localStorage.clear()`를 하지 않는다**(BUG-13).

---

## 3. 화면별 요청

### 3-0. 공통 전제

- **axios 2종**
  - `api` — 토큰 없음(`shared/api/baseApi.ts:19`). `baseURL` 주석 처리(`:8`)라
    상대경로로 나가고 `next.config.js:12~15` rewrite가 프록시한다
  - `authApi` — 토큰 주입(`entity/auth/api/authApi.ts:11`). 401이면
    `POST /api/v1/auth/refresh-token`(이건 `api`) 재시도 후 실패 시
    `localStorage.clear()` + `window.location.href='/'` (`:46~47`)
- **QueryClient에 기본 옵션이 없다** — `new QueryClient()`
  (`app/_providers/QueryProvider.tsx:7`). 즉 `staleTime: 0`,
  `refetchOnWindowFocus: true`, `retry: 3`. **재진입·포커스마다 재요청**된다.
- `(login-required)` 가드(`UserRoleMiddleware`)는 **네트워크 요청이 없다**.
  localStorage만 읽는다(`:19`). 단 첫 렌더에서 `null`을 반환(`:43`)하고
  `useEffect` 후 두 번째 렌더에 children을 그리므로, **모든 쿼리는 첫
  effect flush 이후에 시작**된다.
- **`enabled` 옵션은 9개 화면의 어느 쿼리에도 없다.** 전부 마운트 즉시.
- **`useEffect` 안에서 직접 API를 부르는 코드는 없다.**

### 3-1. 하단 네비 — 허브에서만 마운트된다

웹 컴포넌트 `src/widget/navigation.tsx`의 `StudentNavigation`(`:106~204`).

`Layout`은 `type` prop이 있을 때만 네비를 넣는데(`layout.tsx:35~36`),
`type='student'`를 주는 것은 `StudentMyPage.tsx:25` 뿐이다. **나머지 8개
화면은 네비가 없고, 따라서 네비 요청도 없다.**

네비가 쏘는 요청: `useCheckTrainerMemberMappingQuery()` (`navigation.tsx:111`)
= `GET /api/v1/members/trainer-mapping`, `authApi`,
`queryKey: ['checkTrainerMemberMapping']`, **`enabled` 없음**.
코드는 `const { refetch } = ...`로 refetch만 꺼내 쓰지만 `enabled: false`가
아니므로 **마운트 즉시 한 번 자동 발사**된다. 클릭 시(`:115`) 한 번 더.

`수업예약` 탭만 `<Link>`가 아니라 `<Button onClick>`(`:146~163`)이고,
매핑되어 있으면 `router.replace('/student/schedule')`, 아니면 토스트
`트레이너가 지정된 후에 예약 가능합니다`(`:119`).

탭 라벨: `홈`·`수업예약`·`커뮤니티`·`마이` (`:142, 161, 178, 197`).

### 3-2. 화면별 표

| 화면 | # | 메서드 + 경로 | 인스턴스 | 훅 | 주체 |
|---|---|---|---|---|---|
| **허브** | 1 | `GET /api/v1/members/trainer-mapping` | `authApi` | `useCheckTrainerMemberMappingQuery` | **하단 네비** (`navigation.tsx:111`) |
| | 2 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` (`feature/mypage/api/queries.ts:8~16`) | 화면 (`StudentMyPage.tsx:20`) |
| **info** | 1 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` | 화면 (`:42`) |
| **alarm** | 1 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` | 화면 (`:17`) |
| **trainer-info** | 1 | `GET /api/v1/members/trainer-mapping/info` | `authApi` | `useStudentMypageTrainerInfoQuery` (`queries.ts:32~42`) | 화면 (`:33`) |
| **last-reservation** | 1 | `GET /api/v1/schedule/student/my-reservation/old?searchDate={YYYY-MM}` | `authApi` | `useStudentMyLastReservationListQuery` (`feature/schedule/api/queries.ts:85~95`) | 화면 (`:51`) |
| **leave** | — | **없음** | — | — | — |
| **edit/name** | 1 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` | 화면 (`:16`) |
| **edit/email** | 1 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` | 화면 (`:17`) |
| **edit/password** | — | **없음** | — | — | — |

> 위 표의 허브 순서는 **조사가 아니라 실측**이다(§0 ①).

### 3-3. 상호작용으로 발생하는 요청

| 화면 | 트리거 | 메서드 + 경로 | 인스턴스 | 근거 |
|---|---|---|---|---|
| alarm | 스위치 토글 | `PATCH /api/v1/members/alarm/{PUSH\|COMMUNITY\|FEEDBACK\|SCHEDULENOTICE}/{ENABLED\|DISABLE}` | `authApi` | `EditAlarmPage.tsx:26` |
| alarm | 성공 후 | `GET /api/v1/members/me` refetch | `authApi` | `:30` |
| info | 앨범에서 선택 | `PUT /api/v1/members/profile` (multipart, field `file`) | `authApi` | `:50` |
| info | 사진 삭제 | `DELETE /api/v1/members/profile` | `authApi` | `:68` |
| info | 위 둘 성공 후 | `GET members/me` refetch | | `:54`, `:70` |
| info | 로그아웃 | `POST /api/v1/members/logout` | `authApi` | `:84` |
| leave | 탈퇴하기 | `POST /api/v1/members/delete` | `authApi` | `LeavePage.tsx:33` |
| edit/name | 변경 완료 | `PATCH /api/v1/members/name` body `{name}` | `authApi` | `:27` |
| edit/name | 성공 후 | refetch → `router.replace('../info')` | | `:29~32` |
| edit/email | 인증 요청/재전송 | `POST /api/v1/auth/validation/send-email` body `{email}` | **`api` (토큰 없음)** | `:28`, `:76` |
| edit/email | 인증 완료 | `PATCH /api/v1/members/email` body `{email, emailKey}` | `authApi` | `:40` |
| edit/password | 비밀번호 확인 | `POST /api/v1/members/password` body `{password}` | `authApi` | `:25` |
| edit/password | 변경하기 | `PATCH /api/v1/members/password` body `{changePassword1, changePassword2}` | `authApi` | `:40` |
| last-reservation | 월 변경 | 동일 GET, `searchDate` 변경 + `router.push(?month=...)` | `authApi` | `:55~59` |

> `POST /api/v1/auth/validation/send-email`이 **9개 화면 통틀어 유일하게
> `api`(토큰 미주입) 인스턴스를 쓰는 요청**이다.

---

## 4. 백엔드 계약 대조

### 4-0. 봉투

| 항목 | 백엔드 | 웹 TS | 차이 |
|---|---|---|---|
| 성공 | `ApiResult<T>` = `{status, message, data}` (`ApiResult.java:10~12`) | `BaseResponse<T>` = `{message, data}` (`shared/api/types.ts:3~6`) | **`status`(항상 `"OK"`)가 웹 타입에 없고 아무데서도 안 쓴다** |
| 실패 | `ErrorResponse` = `{message, code, timestamp}` | `AxiosError<{code, message, timestamp}>` | 일치 |

- `@Valid` 실패는 DTO 메시지를 버리고 `"서버에서 에러가 발생하였습니다."`를
  반환한다(`GlobalExceptionHandler.java:51`). **DTO에 적힌 한글 검증 메시지는
  클라이언트에 절대 도달하지 않는다**(BUG-24).
- **날짜 직렬화**: `application.yml`·`config/` 어디에도 Jackson 설정이나
  `ObjectMapper` 빈이 없다(grep 0건). 즉 **Spring Boot 기본값
  (`WRITE_DATES_AS_TIMESTAMPS=false`)에 의존**한다 — 명시 설정이 아니다.
  `LocalDate` → `"2025-09-15"`, `LocalTime` → `"14:30:00"`(초 포함),
  `LocalDateTime` → `"2025-09-15T14:30:00"`.

### 4-1. `GET /api/v1/members/me` → `MemberInfoResult`

`MemberController.java:48~51` / `MemberInfoResult.java:10~23`.

| 백엔드 | 타입 | 웹 `Member` (`feature/manage/model/types.ts:25~49`) | 판정 |
|---|---|---|---|
| `id` | `Long` | `id: number` | OK |
| `userId` | `String` | `userId: string` | OK |
| `email` | `String` | `email: string` | OK |
| `name` | `String` | `name: string` | OK |
| `profile` | `ProfileDto` = `{id, fileUrl}`, **null 가능** | `{id; fileName; originalName; extension; fileSize; fileUrl}` **비-옵셔널** | **X** 필드 4개가 응답에 없고, null 가능한데 non-nullable 선언 |
| `gym` | `GymDto` = `{id, name}` (`GymDto.java:5~8`), null 가능 | `Gym` = `{gymId, name}` | **X** 이름 불일치 → `member.gym.gymId`는 항상 `undefined` |
| `memberType` | `MemberType` enum | `'STUDENT' \| 'TRAINER'` | OK (**미확인**: enum 값 목록 미열람) |
| `pushAlarmStatus` 외 3종 | `AlarmStatus` = `ENABLED \| DISABLE` | 동일 | OK |
| `socialType` | `NONE\|KAKAO\|NAVER\|GOOGLE\|APPLE` | 동일 | OK |
| — | 없음 | `age` / `height` / `weight` / `delYn` | **X** 응답에 없는 필드 |

**실측 응답(2026-09-15, `healthy-student0`)**

```json
{"id":6,"userId":"healthy-student0","email":"...","name":"차은우",
 "profile":null,"gym":{"id":1,"name":"건강해짐 홍대점"},"memberType":"STUDENT",
 "pushAlarmStatus":"DISABLE","communityAlarmStatus":"DISABLE",
 "feedbackAlarmStatus":"DISABLE","scheduleNoticeStatus":"DISABLE",
 "socialType":"NONE"}
```

### 4-2. `GET /api/v1/members/trainer-mapping/info` → `RetrieveTrainerInfo`

`MemberController.java:155~158` (`@PreAuthorize ROLE_STUDENT`).

| 백엔드 | 웹 (`feature/mypage/api/queries.ts:18~30`) | 판정 |
|---|---|---|
| `mappingId: Long` | `number` | OK (**화면에서 안 씀**) |
| `trainer.id: Long` | `number` | OK (**안 씀**) |
| `trainer.email: String` | `string` | OK |
| `trainer.name: String` | `string` | OK |
| `trainer.profile: ProfileDto`(null 가능) | `{id; fileUrl} \| null` | OK |
| `trainer.gym: GymDto{id,name}` | `Gym{gymId,name}` | **X** `gymId` 항상 undefined (`.name`만 쓰므로 화면은 무사) |
| 매핑 없으면 `data: null` (`MemberService.java:56~60`) | `... \| null` | OK |

### 4-3. `GET /api/v1/members/trainer-mapping`

`TrainerMappingResult` = `{mapped: Boolean}` ↔ 웹 `{mapped: boolean}`. 일치.

### 4-4. `GET /api/v1/schedule/student/my-reservation/old?searchDate=`

`StudentScheduleController.java:65~71`, `MyReservationResponse.java:9~12`,
`MyReservation.java:8~15`.

| 백엔드 | 타입 | 웹 (`feature/schedule/model/type.ts:29~32, 13~20`) | 판정 |
|---|---|---|---|
| `course` | **항상 `null`** (`StudentScheduleService.java:129`) | `CourseData` **비-옵셔널** | **X** 선언은 필수인데 런타임 항상 null (화면에선 안 씀) |
| `reservations` | `List`, 비면 **`null`** (`MyReservationResponse.java:16`) | `ScheduleData[] \| null` | OK |
| `.scheduleId` | `Long` | `number` | OK |
| `.lessonDt` | `LocalDate` → `"2025-09-15"` | `string` | OK |
| `.lessonStartTime` | `LocalTime` → **`"14:30:00"`** | `string` | OK |
| `.lessonEndTime` | `LocalTime` | `string` | OK |
| `.trainerName` | `String`, `"홍길동 트레이너"` (`MyReservation.java:22`에서 접미) | `string` | OK (**안 씀**) |
| `.reservationStatus` | `String` (enum name) | `string` | OK |

> `convertTo12HourFormat`(`shared/utils/date.ts:64~72`)은 `split(':')`의 앞
> 2개만 쓰므로 `"14:30:00"`에서도 안전하다. Flutter도 `HH:mm:ss` 전제로 짠다.

### 4-5. 뮤테이션 계약

| 웹 호출 | 웹 선언 | 백엔드 실제 | 판정 |
|---|---|---|---|
| `POST members/logout` | `BaseResponse<boolean>` | **`void`** — 봉투 없음, 빈 본문 (`MemberCommandController.java:51~54`) | **X** `result.data`는 `""`. onSuccess가 값을 안 봐서 무해 |
| `POST members/delete` | `BaseResponse<boolean>` | `ApiResult<String>` | **X** (미사용) |
| `PATCH members/name` `{name}` | 응답 `BaseResponse<string>` | `ApiResult<CommandChangeNameResult{memberId,name}>` | **X** 응답이 객체 (미사용) |
| `PATCH members/email` `{email, emailKey}` | `BaseResponse<boolean>` | `ApiResult<Boolean>` | OK |
| `PATCH members/password` `{changePassword1, changePassword2}` | `BaseResponse<boolean>` | `ApiResult<Boolean>` | OK |
| `POST members/password` `{password}` | `BaseResponse<boolean>` | `ApiResult<Boolean>`. 불일치 시 400 + `"비밀번호가 일치하지 않습니다."` (`MemberService.java:48`) | OK |
| `PATCH members/alarm/{type}/{status}` | `BaseResponse<boolean>` | `ApiResult<MemberChangeAlarmResult{type,status}>`. **`type`이 enum name이 아니라 한글**(`푸시/커뮤니티/피드백/일정알림`, `MemberChangeAlarmResult.java:13`) | **X** (미사용) |
| `PUT members/profile` multipart `file` | `{fileUrl, fileName}` | `ApiResult<RegisterMemberProfileResult{fileUrl,fileName}>` | OK (미사용 — refetch로 대체) |
| `DELETE members/profile` | `BaseResponse<undefined>` | `ApiResult<DeleteMemberProfileResult{fileUrl,fileName}>` | **X** 실제로는 객체 (미사용) |
| `POST auth/validation/send-email` `{email}` | `BaseResponse<string>` | `ApiResult<String>` | OK |

---

## 5. 웹 버그 목록

> 정책상 **고치지 않고 그대로 이관**한다.

### BUG-1 · 알림: 커뮤니티 스위치를 엉뚱한 필드로 게이팅
`EditAlarmPage.tsx:66`
```tsx
{data?.scheduleNoticeStatus && (          // 게이트는 scheduleNoticeStatus
  <Switch id='COMMUNITY'
    checked={data.communityAlarmStatus === 'ENABLED'}   // :69  값은 communityAlarmStatus
```
`scheduleNoticeStatus`가 falsy면 **커뮤니티 스위치가 통째로 사라진다.**
앱푸쉬(`:51`)와 피드백(`:81`)은 정상.

### BUG-2 · 알림: `SCHEDULENOTICE` 토글 UI가 없다
`EditAlarmPage.tsx:23`의 타입 유니온에 있고 백엔드도 지원(`AlarmType.java:14`)하지만
화면에는 PUSH/COMMUNITY/FEEDBACK 3개뿐이다. 도달 불가능한 분기.

### BUG-3 · 알림: 로딩/에러 분기 없음
`:17` `const { data } = useMyInfoQuery();` — 로딩 중엔 라벨만 보이고 스위치 3개가 안 보인다.

### BUG-4 · info: 이미지 URL 오타 `&=q=90`
`EditMyInfoPage.tsx:116` `?w=300&h=300&=q=90`. 허브(`StudentMyPage.tsx:35`)는 `&q=90`으로 정상.
같은 오타가 `TrainerMyPage.tsx:24`에도 있다.
**미확인**: `next.config.js:52~53`의 커스텀 로더가 재조립하므로 실효 영향은 판단 불가.

### BUG-5 · info: `isSocialAccount`가 데이터 없을 때 `true`
`:81` `data?.socialType !== 'NONE'` — `data`가 `undefined`면 `true`.
지금은 `:110`의 `{data && ...}`가 가려주지만, **로딩 UI를 넣는 순간 드러난다.**

### BUG-6 · edit/name: 에러 토스트 폴백 누락 — **정정: 무해하다**
`EditNamePage.tsx:35~36` `errorToast(error?.response?.data.message)` — `?? '문제가 발생했습니다.'`가 없다.
다른 8곳은 전부 폴백이 있다.

> **2026-09-15 정정.** 호출부에 폴백이 없는 것은 맞지만 **웹 `errorToast`가
> 자체 폴백을 갖고 있다** — `use-toast.tsx:213`의
> `{message ?? '문제가 발생했습니다.'}`. 따라서 사용자에게 보이는 결과는
> 다른 8곳과 같고, **고칠 것도 이관 시 재현할 것도 없다.**
> `AppToastController.showError`도 같은 자리에서 폴백한다.

### BUG-7 · leave: 존재하지 않는 CSS 클래스 `diabled:`
`LeavePage.tsx:90`. 오타라 no-op이고, 뒤에 `disabled:text-gray-400`이 중복으로 있어 결과는 정상.

### BUG-8 · last-reservation: `month` 없으면 `searchDate=Invalid Date`
`:45~53` `dayjs(null)` → Invalid Date → `.format('YYYY-MM')` → 문자열 `"Invalid Date"`.
허브는 항상 `?month=`를 붙이므로(`StudentMyPage.tsx:87`) 정상 경로에선 안 터지지만
**직접 URL 진입·히스토리 조작 시 발생**한다. 이 파일만 `customParseFormat`을 확장하지 않는다.

### BUG-9 · last-reservation: 로딩 분기 없음 + `=== null` 엄격 비교
`:83` `{data?.reservations === null && <NoReservation />}` — 로딩 중엔 `undefined === null`이 false라
**빈 상태도 로딩도 없는 완전 공백**. 백엔드가 `[]`가 아니라 `null`을 준다는 데 의존한다.

### BUG-10 · trainer-info: 로딩 중 "등록된 트레이너가 없습니다."가 깜빡인다
`:43` `{!data && <NoTrainer />}` — `isLoading` 분기가 없다.

### BUG-11 · 허브: 하드코딩 3종
`:129` `최신 버전` / `:133` `앱 버전 0.0` / `:135` `href={'#'}`. 셋 다 API에서 오지 않는다.

### BUG-12 · edit/password: 성공 토스트 미구현 (`//TODO: SUCCESS TOAST`, `:46~48`)

### BUG-13 · 탈퇴는 `localStorage.clear()`를 하지 않는다 (로그아웃과 비대칭)
로그아웃은 스토어 리셋 + `localStorage.clear()` + 서비스워커 해제,
탈퇴는 스토어 리셋만. `deleteUserInfo()`는 `auth-storage`를 빈 상태로 덮어쓸 뿐 키는 남긴다.

### BUG-14 · edit/email: `재전송`에 성공/실패 콜백이 없다
`:76` `onClick={() => sendCode(email)}` — 실패해도 피드백이 없다.

### BUG-15 · edit/email: 2단계에서 인증번호 입력란이 이메일 입력란보다 **위**에 온다
`:67~81`(step 2)이 `:82~92`(이메일)보다 앞에 있다. 두 섹션 모두 `pt-8`(24px).

### BUG-16 · edit/email·edit/name: `defaultValue` — **정정: 첫 로딩에서는 정상이다**
`EditEmailPage.tsx:86` / `EditNamePage.tsx:55`.

> **2026-09-15 정정 (브라우저 실측).** "쿼리가 늦으면 빈 입력창이 남는다"는
> 틀렸다. 실제로 열어 보니 입력창에 현재 값(`차은우`)이 **정상으로 채워졌다.**
> React가 `defaultValue` prop 변경을 DOM의 `value` **속성**에 반영하고,
> 사용자가 손대지 않은 입력은 그 속성을 따라가기 때문이다.
>
> 갱신이 막히는 것은 **사용자가 한 번 입력해 입력이 더러워진 뒤**부터다.
> 두 화면 모두 그 뒤에 refetch가 없어 실제로는 드러나지 않는다.
>
> 다만 **상태와 화면이 어긋나는 것은 사실이다** — `useState('')`라
> 입력창에 값이 보이는데도 제출 버튼은 비활성으로 시작한다. 그쪽이 진짜
> 관찰 가능한 동작이고, 앱도 그대로 옮겼다.

### BUG-17 · 계약: `Gym.gymId`가 `members/me`·`trainer-mapping/info` 응답에 없다
웹 `Gym = {gymId, name}` ↔ 백엔드 `GymDto = {id, name}`. 웹이 하나의 타입을 두 API에
공용해서 생긴 불일치. 웹은 `.name`만 써서 표면화되지 않는다.

> **2026-09-15 정정 — 이 계열에서 가장 값비쌌던 항목이다.** 웹에서
> 표면화되지 않는다는 것은 맞지만 **앱에서는 앱을 죽였다.**
> `Gym.fromJson`이 `json['gymId'] as int`로 비-null 캐스트를 했고,
> `GymDto` 모양이 오자 던졌다. 그 예외를 호출부의 `catch (_)`가 삼켜
> **학생 홈의 응답 전체 파싱이 죽고 모든 섹션이 빈 상태로 그려졌다.**
>
> 테스트 465개가 못 잡았다 — 픽스처를 `gymId`로 써 뒀기 때문이다.
> **골든은 요청만 대조하고 응답 본문은 보지 않는다**(규율 #16).
> 해법은 `Gym`을 넓히는 것이 아니라 두 DTO를 섞지 않는 것이었다.
> 경위: `docs/progress.md`의 "헬스장 DTO가 둘이었다".
>
> **다음 계열을 조사할 때 같은 부류를 최우선으로 찾아라** — 같은 도메인을
> 담는 백엔드 record가 둘 이상이고 필드명이 다른 경우.

### BUG-18 · 계약: `Member.profile`이 non-optional 6필드인데 실제는 nullable 2필드
소비 측은 전부 옵셔널 체이닝으로 방어한다(`StudentMyPage.tsx:32`, `EditMyInfoPage.tsx:114`).
**선언이 아니라 소비 측 가드를 보라**는 이 프로젝트 규율의 또 다른 사례.

### BUG-19 · 계약: `age`/`height`/`weight`/`delYn`는 응답에 없다
9개 화면에서 안 쓴다. **Flutter 모델에 넣으면 안 된다.**

### BUG-20 · 계약: `MyReservationResponse.course`가 항상 `null`
Flutter 모델에서 **nullable로 선언**한다.

### BUG-21 · 백엔드: 트레이너 gym이 null이면 NPE 가능 (잠재)
`RetrieveTrainerInfo.java:33~34` — `ProfileDto.from`은 null 가드가 있는데
`GymDto.from`은 없다(`GymDto.java:9~14`). `MemberInfoResult.create`는 가드하는데 여기만 빠졌다.

### BUG-22 · 허브: 3분할 구분선의 폭이 의도와 다르다
`:67, :74` `h-11 w-[1px] border border-gray-200` — `box-sizing: border-box` 때문에
`w-[1px]` 안에 좌우 1px 보더가 들어가려다 충돌한다.
Flutter에선 **1px 세로선, `#dee1e6`, 높이 36px**로 두면 시각적으로 동등하다.

### BUG-23 · 허브: 앱 버전 행만 `items-center`가 빠졌다
`:127` `flex justify-between` vs `:88` `flex items-center justify-between`.
폰트 크기가 같아 눈에 띄진 않는다.

### BUG-24 · 백엔드: `@Valid` 실패 메시지가 전부 뭉개진다
`GlobalExceptionHandler.java:48~53`. **서버 메시지에 기대는 UX를 만들면 안 된다.**

---

## 6. 스타일 실측

### 6-0. 스페이싱 스케일 — 함정

`tailwind.config.js:88~101`의 커스텀 스페이싱은 **`theme.extend.spacing`** 아래라
기본 스케일을 대체하지 않고 **병합**한다. 즉 **키 1~12만 덮어쓰고 13 이상은 Tailwind 기본(rem)** 이다.

| 키 | px | 키 | px |
|---|---|---|---|
| 1 | 4 | 7 | 20 |
| 2 | **6** (8 아님) | 8 | 24 |
| 3 | 8 | 9 | 28 |
| 4 | 10 | 10 | 32 |
| 5 | 12 | 11 | 36 |
| 6 | 16 | 12 | 48 |

**덮이지 않은 키(기본 rem 유지) — 이 9개 화면에 실제로 등장:**

| 클래스 | 실제 값 | 등장 |
|---|---|---|
| `py-28` | **112px** (7rem) | `StudentLastReservationPage.tsx:34`, `TrainerInfoPage.tsx:21` |
| `py-1.5` | 6px | `shared/ui/dropdown-menu.tsx:84` |
| `w-40` | 160px | `shared/ui/card.tsx:12` (`w-full`로 덮임) |
| `h-35` | **없는 클래스 → no-op** | `shared/ui/card.tsx:12` |

### 6-1. 공통 레이아웃 (`src/widget/layout.tsx`)

| 요소 | 클래스 | px |
|---|---|---|
| 바깥 래퍼 | `flex h-full items-center justify-center bg-black` (`:29`) | 배경 `#000` |
| 폰 프레임 | `w-[var(--max-width)] bg-gray-100` (`:31`) | **440px**, `#f2f3f5` |
| `Layout.Header` | `relative flex h-[56px] w-full flex-none items-center justify-between px-7 py-6` (`:46`) | **56px 고정**, 좌우 20, 상하 16 |
| `Layout.Contents` | `h-full w-full flex-1 flex-shrink-0 overflow-y-auto` (`:57`) | 패딩 0 |
| `Layout.BottomArea` | `w-full p-7` (`:69`) | 20px 전방향 |

### 6-2. 하단 네비 (허브에만)

| 요소 | 클래스 | px |
|---|---|---|
| `<nav>` | `rounded-tl-md rounded-tr-md bg-white shadow-nav` (`:128`) | 상단 라운드 **8px**, 그림자 `0 -2px 8px rgba(0,0,0,0.06)` |
| `<ul>` | `flex items-center justify-between px-11 py-[18px]` (`:130`) | 좌우 **36**, 상하 **18** |
| 탭 내부 | `flex flex-col items-center justify-between gap-y-2` (`:134`) | 아이콘-라벨 **6px** |
| 아이콘 | 24×24 (커뮤니티만 **22×21**) | |
| 라벨 | `NAV_TEXT` = `text-[10px] font-medium` | 10px |
| 총 높이 | 18 + 24 + 6 + ~15 + 18 ≈ **81px** | |

### 6-3. 허브 `StudentMyPage.tsx`

| 요소 | 클래스 | px |
|---|---|---|
| 헤더 | `Layout.Header className='bg-white'` (`:26`) | 56px, 흰색, **내용 없음** |
| 프로필 카드 | `flex items-center justify-between bg-white px-7 pb-7 pt-6` (`:30`) | 좌우 20, 위 16, 아래 20 → **높이 116px** |
| 프로필 이미지 | `h-[80px] w-[80px] rounded-full` (`:33`) + `border border-gray-300` (`:39`) | 80×80 원형, 1px `#cbcfd3` |
| 아바타 폴백 | `IconAvatar width={80} height={80}` (`:44`) | 80×80 |
| 이름-부제 블록 | `ml-5 flex flex-col justify-center` (`:47`) | 좌여백 **12** |
| 이름 | `HEADING_3` = 20px/130% bold | lh 26 |
| 부제 | `BODY_3` + `text-gray-500` | 13px/150%, `#86888d` |
| 우측 화살표 | `IconArrowRightSmall` **7×10**, `--gray-400` `#a7a9ae` | |
| 바로가기 래퍼 | `bg-white py-6 pb-9` (`:59`) | 위 16, 아래 **28** (pb-9가 덮음) |
| 바로가기 카드 | `mypage-box-shadow m-auto flex w-[320px] items-center rounded-lg bg-white` (`:60`) | **320px**, 라운드 **12**, 그림자 `0 4px 12px rgba(0,0,0,0.06)` |
| 수업일지 링크 | `py-5 pl-8 pr-9` (`:61`) | 상하 12, 좌 24, 우 28 |
| 식단 링크 | `px-11 py-5` (`:68`) | 좌우 36, 상하 12 |
| 운동기록 링크 | `py-5 pl-9 pr-8` (`:75`) | 상하 12, 좌 28, 우 24 |
| 링크 내부 | `flex flex-col items-center justify-center gap-y-5` (`:62`) | 아이콘-라벨 **12** |
| 바로가기 라벨 | **Typography 클래스 없음** → 브라우저 기본 **16px** | Flutter에선 16px/normal 명시 |
| 바로가기 구분선 | `h-11 w-[1px] border border-gray-200` | 높이 **36**, `#dee1e6` (BUG-22) |
| 메뉴 행 | `flex items-center justify-between bg-white px-7 py-[15px]` | 좌우 20, 상하 **15** → BODY_1(24px) 기준 **행 높이 54** |
| 메뉴 라벨 | `BODY_1` = 16px/150% normal | |
| 앱버전 행 | `flex justify-between bg-white px-7 py-[15px]` (`:127`) | 54px (단 `items-center` 없음) |
| 푸터 | `flex flex-col items-start gap-4 bg-transparent p-7` (`:132`) | 패딩 20, 간격 **10**, 배경 투명(→ `#f2f3f5` 노출) |
| 푸터 링크 | `border-b border-gray-300` | 1px 밑줄 `#cbcfd3` |
| **행 사이 구분선** | **없다.** 연속 행은 틈 없이 붙어 흰 블록이 된다 | |

### 6-4. 나머지 8개 화면 — 요약

세부 치수는 필요할 때 이 표를 근거로 웹 파일을 다시 열어 확인한다.

- **`EditMyInfoPage`(info)**: 루트 `bg-white`. 프로필 섹션 `gap-6 pt-6`,
  아바타 폴백만 **82×82**(허브는 80 — 불일치). 카메라 버튼
  `absolute -bottom-1 -right-1 ... p-2`, 아이콘 `IconCamera` 24×20.
  정보 카드 `mx-7 mt-11 rounded-lg border border-gray-100`,
  행 `px-6 py-7 border-b border-gray-100`(**행 높이 ≈62**).
  하단 액션 `mb-[60px] mt-auto ... gap-3`, 세로 구분선 `h-4 w-[1px]`(10×1).
- **`EditAlarmPage`(alarm)**: 제목 `HEADING_3 bg-white px-7 pb-7 pt-8`.
  1행 `py-[18px]`(행 64), 2행 `mt-3 ... py-6`(위 8px 회색 갭), 3행 `py-6`.
  Switch 트랙 **48×28**, thumb **24×24**, 이동 `translate-x-7`(20px),
  켜짐 `--primary-500 #1990ff` / 꺼짐 `#cbcfd3`. **행 사이 구분선 없음** — `mt-3` 갭이 대신한다.
- **`TrainerInfoPage`**: 섹션 `px-7 py-6`, 프로필 블록 `pb-11`.
  이미지 80×80인데 `object-contain`(허브·info는 `object-cover` — 불일치).
  정보 카드 `rounded-lg bg-white px-6 py-7`, 행 간격 `mb-6`.
  빈 상태 `py-28`(**112px**) + `IconAlertCircle` 35×36 + `mb-5`(12).
- **`StudentLastReservationPage`**: 본문 `bg-gray-100 px-7 pb-[52px] pt-7`.
  카드 `px-6 py-7` + 기본 `gap-y-2 rounded-lg`(내부 세로 간격 6).
  상태 배지 `w-[52px] py-[2px] rounded-sm ml-2`, COMPLETED `bg-[#e2f1ff] text-primary-500`,
  그 외 `bg-gray-100 text-gray-700`. 문구 `출석`/`미출석`.
  바텀시트 `pb-9 px-7 rounded-t-lg pt-[48px]`, 확인 버튼 높이 **48**.
  MonthPicker 월 셀 72px / 원 56px.
- **`LeavePage`**: 본문 `gap-[72px] px-7 py-8`. 유의사항 `gap-11`,
  리스트 `BODY_3 mt-3 text-gray-700`, 각 `li mt-2`. **불릿은 CSS가 아니라 문자열 `• `**.
  체크박스 **20×20** `rounded-sm`, 체크 아이콘 15×12.
  삭제 버튼 `rounded-md border border-point py-5 text-point`,
  비활성 `border-gray-300`/`text-gray-400`.
  다이얼로그 `w-[320px] rounded-md p-7`, 오버레이 `bg-black/80`,
  버튼 행 `mt-8 gap-3`, 각 `py-[13px]`.
  **`탈퇴하기`는 `variant='destructive'` = `#ef4444`로 `--point-color(#ff4668)`와 다른 빨강**이다.
- **`EditName`/`EditEmail`/`EditPassword`**: 루트 `bg-white`.
  헤더 = 뒤로가기 + 중앙 제목(`HEADING_4_SEMIBOLD`) + 우측 더미 `w-[40px]`.
  폼 `space-y-3 px-7 pt-8`. 입력 박스 `rounded-md border border-gray-200 px-6 py-[13px]`(**높이 ≈48**).
  하단 버튼은 `Layout.BottomArea`(p-7) 안 `Button size='full'` = `py-[18px] px-4 rounded-lg`.
  제목: `이름 변경` / `이메일 변경` / `비밀번호 변경`.
  버튼 라벨: `변경 완료` / `인증 요청` / `인증 완료` / `비밀번호 확인` / `비밀번호 변경하기`.

### 6-5. 임의값 목록 (9개 화면 파일)

| 값 | 파일:줄 |
|---|---|
| `py-[15px]` | `StudentMyPage.tsx:88, 96, 104, 112, 120, 127` |
| `w-[1px]` | `StudentMyPage.tsx:67, 74` / `EditMyInfoPage.tsx:243` |
| `w-[320px]` | `StudentMyPage.tsx:60` / `LeavePage.tsx:93` |
| `h-[80px] w-[80px]` | `StudentMyPage.tsx:33` / `EditMyInfoPage.tsx:120` / `TrainerInfoPage.tsx:47` |
| `bg-[#FEE500]` / `bg-[#03C75A]` | `EditMyInfoPage.tsx:182, 192` |
| `py-[13.5px]` | `EditMyInfoPage.tsx:145` |
| `mb-[60px]` | `EditMyInfoPage.tsx:237` |
| `py-[18px]` | `EditAlarmPage.tsx:49` |
| `mb-[2px]` / `w-[35px]` | `TrainerInfoPage.tsx:60, 23` |
| `bg-[#e2f1ff]` / `py-[2px]` / `w-[52px]` / `w-[35px]` / `pb-[52px]` | `StudentLastReservationPage.tsx:112, 114, 114, 36, 72` |
| `py-[13px]` | `LeavePage.tsx:100, 107` / `EditNamePage.tsx:54` / `EditEmailPage.tsx:73, 84` / `EditPasswordPage.tsx:71, 90, 98` |
| `w-[40px]` | `LeavePage.tsx:52` / `EditNamePage.tsx:50` / `EditEmailPage.tsx:64` / `EditPasswordPage.tsx:65` |
| `gap-[72px]` | `LeavePage.tsx:54` |

**공통 위젯 쪽**: `h-[56px]`(layout `:46`), `w-[var(--max-width)]`(440),
`py-[18px]`(navigation `:130`, button `:20,24`), `h-[72px]`·`h-[56px] w-[56px]`(month-picker),
`pt-[48px]`·`w-[44px]`(sheet), `w-[48px]`(switch), `bg-[#E2F1FF]`(button secondary),
그리고 **타이포 전량이 임의값**(`typography.ts:1~19`).

### 6-6. 타이포그래피 전량 (`shared/mixin/typography.ts`)

| 상수 | 값 |
|---|---|
| `HEADING_1` | 24px / 130% bold |
| `HEADING_2` | 22px / 130% bold |
| `HEADING_3` | 20px / 130% bold |
| `HEADING_4` / `_BOLD` | 18px / 130% bold |
| `HEADING_4_SEMIBOLD` | 18px / 130% semibold |
| `HEADING_5` | 13px / 150% semibold |
| `TITLE_1` / `_BOLD` | 16px / 140% bold |
| `TITLE_1_SEMIBOLD` | 16px / 140% semibold |
| `TITLE_2` | 15px / 140% semibold |
| `TITLE_3` | 14px / 150% semibold |
| `BODY_1` | 16px / 150% normal |
| `BODY_2` | 14px / 150% normal |
| `BODY_3` | 13px / 150% normal |
| `BODY_4` / `_REGULAR` | 12px / 150% normal |
| `BODY_4_MEDIUM` | 12px / 150% medium |
| `NAV_TEXT` | 10px medium, `text-gray-700`, center |

폰트 **Pretendard** (`global.css:102~162`).

### 6-7. 색 토큰 (`global.css:29~57`)

| 토큰 | 값 | 토큰 | 값 |
|---|---|---|---|
| `--radius-s/m/l` | 4 / 8 / 12 | `--max-width` | 440 |
| `--primary-50` | `#e2f1ff` | `--primary-500` | `#1990ff` |
| `--gray-100` | `#f2f3f5` | `--gray-200` | `#dee1e6` |
| `--gray-300` | `#cbcfd3` | `--gray-400` | `#a7a9ae` |
| `--gray-500` | `#86888d` | `--gray-600` | `#5f6165` |
| `--gray-700` | `#4c4e52` | `--gray-800` | `#2e3134` |
| `--point-color` | `#ff4668` | `--blue-50` | `#e2f1ff` |

> `--gray-900`은 `tailwind.config.js:49`에 매핑돼 있지만 **`global.css`에 정의가 없다**
> → `text-gray-900`은 무효. (9개 화면에서는 미사용)

**그림자**: `.mypage-box-shadow` = `0 4px 12px rgba(0,0,0,0.06)` (허브 바로가기 카드),
`.shadow-nav` = `0 -2px 8px rgba(0,0,0,0.06)` (하단 네비).

### 6-8. SVG 아이콘 — `="current"` 함정 포함

경로 접두 `frontend/src/shared/assets/images/`.

| 컴포넌트 | 파일 | 내재 크기 | 사용처 | `="current"` |
|---|---|---|---|---|
| `IconBack` | `back.svg` | 20×20 | 8개 화면 헤더 | 없음 |
| `IconArrowRightSmall` | `arrow_right_small.svg` | 7×10 | 허브 6곳, info 3곳 | 없음 |
| `IconAvatar` | `avatar.svg` | viewBox 82×82 | 허브(80), info(82), trainer-info(80) | **`width/height="current"`** — 크기 속성 무효 |
| `IconCamera` | `camera.svg` | 24×20 | info `:136` | **`fill="current"`** (렌즈 원) |
| `IconKakaoLogo`/`IconGoogleLogo`/`IconNaverLogo` | | 18/14/18 | info 소셜 뱃지 | 없음 |
| `IconClassLog` | `class_log.svg` | 20×11 | 허브 `:63` | 없음 |
| `IconDiet` | `diet.svg` | 19×15 | 허브 `:70` | 없음 |
| `IconExerciseLog` | `exercise_log.svg` | 18×16 | 허브 `:77` | 없음 |
| `IconNoSchedule` | `no_schedule.svg` | 28×28 | last-reservation 빈 상태 | 없음 |
| `IconAlertCircle` | `alert_circle.svg` | 35×36 | trainer-info 빈 상태 | 없음 |
| `NoCircleCheckIcon` | `noCircleCheck.svg` (**배럴 안 거치고 직접 import**) | viewBox 24×24, 호출 15×12 | leave `:81` | **`fill="current"` + `width/height="current"`** |
| `IconClose` | `close.svg` | 14×14 | 바텀시트 닫기 | 없음 |
| `IconTriangleDown` | `icon_triangle_down.svg` | 12×13 | MonthPicker | 없음 |
| `IconArrowLeft` | `icon_arrow_left.svg` | 16×17 | MonthPicker 연도 이전 | **`stroke="current"`** (`<svg>`에 `#1990FF` 폴백) |
| `IconArrowRight` | `icon_arrow_right.svg` | 10×17 | MonthPicker 연도 다음 | **`stroke="current"`** (`<svg>`에 `#5F6165` 폴백) |
| 네비 8종 | `home/calendar/community/profile_*.svg` | 24×24 (커뮤니티 22×21) | 허브 하단 네비 | 없음 |

#### 왜 웹에서는 멀쩡한가

`current`는 SVG `<paint>` 문법에 없는 값이다(`currentColor`의 오타로 보인다).
스펙상 **잘못된 표현 속성 값은 무시되고 부모로부터 상속**되므로, 브라우저는
루트 `<svg>`의 `fill`/`stroke`(또는 SVGR이 주입한 prop)를 물려준다.
flutter_svg는 **"칠하지 않음"으로 처리해 도형이 통째로 사라진다** —
이 프로젝트가 이미 규율 #13으로 겪은 함정이다.

**이관 체크리스트**

1. `avatar.svg` — `width/height="current"` 제거. Flutter 쪽도 크기를 명시한다.
2. `camera.svg` — `fill="current"` → `currentColor`, 사용처에서 `--gray-500` 주입.
3. `noCircleCheck.svg` — `fill="current"` → `currentColor`(흰색 주입), 크기 속성 제거.
4. `icon_arrow_left/right.svg` — `stroke="current"` → `currentColor`.
   MonthPicker가 활성/비활성에 따라 색을 **동적으로** 넘기므로(`month-picker.tsx:45, 57`)
   런타임 색 주입이 필요하다.

> 9개 화면 **밖**에도 `="current"` 파일이 많다: `alert.svg`, `album.svg`,
> `arrow_down.svg`, `arrow_filled_down/up.svg`, `arrow_top.svg`,
> `camera_upload.svg`, `chat.svg`, `check.svg`, `close_black.svg`, `delete.svg`,
> `icon_camera.svg`, `icon_left.svg`, `like.svg`, `logo.svg`, `notification.svg`,
> `plus.svg`, `profile_default.svg`, `trash.svg`, `white_close.svg`.

---

## 7. 이관 순서

난이도의 실제 변별 요인은 요청 건수가 아니라 **(a) 뮤테이션 개수,
(b) 새로 만들어야 하는 공용 위젯, (c) 다단계 상태**다.

조사의 원안은 허브를 7번째로 미뤘지만, **그 근거였던 하단 네비가 이미
있으므로**(§0 ③) 순서를 바꾼다.

| 순 | 화면 | 이유 |
|---|---|---|
| 1 | **허브** | **골든이 이미 떠 있고**(`mypage-student`) 하단 네비도 있다. 새 공용 위젯이 필요 없다. 여기서 `MemberInfo` 모델을 확정하면 3·4·8·9번이 그대로 재사용한다. 링크 대상이 전부 자리표시자라 이동 검증도 즉시 된다 |
| 2 | **info** | 골든이 이미 떠 있다(`mypage-student-info`). **로그아웃이 여기 있어 `AuthState.signOut()` 호출자 0건 부채가 풀린다.** 단 사진 업로드(multipart)·소셜 분기는 Phase B로 밀 수 있다 |
| 3 | `leave` | 요청 0건. **확인 다이얼로그 위젯의 첫 레퍼런스**가 된다. `noCircleCheck.svg` 함정을 여기서 먼저 밟는다 |
| 4 | `edit/password` | 요청 0건, 2스텝. 폼 + `BottomArea` 버튼 패턴을 확립해 5·6번이 재사용한다 |
| 5 | `edit/name` | `me` 모델 재사용 + 뮤테이션 1개. `pushReplacement` 규칙 확립 |
| 6 | `alarm` | 같은 모델. 스위치 + PATCH + 재조회. **BUG-1을 그대로 이식**해야 한다 |
| 7 | `trainer-info` | 새 모델 1개, 뮤테이션 0개. **빈 상태 위젯**(`py-28`=112px)을 만든다 |
| 8 | `edit/email` | 2스텝 + **토큰 없는 인스턴스가 섞인 유일한 화면**. Dio 인스턴스 2벌 분리가 여기서 검증된다 |
| 9 | `last-reservation` | 가장 무겁다. **MonthPicker + 상세 시트** 두 위젯을 새로 만들고 한국어 날짜 포맷을 `intl`로 재현해야 한다 |

허브를 옮길 때 링크 대상 중 **`/student/log`·`/student/diet`·`/student/workout`·
`/student/community`·`/policy`·`/cs`는 이 범위 밖**이다 — 자리표시자로 남긴다.

---

## 부록. 미확인 항목

| 항목 | 이유 |
|---|---|
| `shared/utils/file-url.ts`의 `normalizeDisplayFileUrl`/`buildDisplayImageUrl` | 미열람. BUG-4의 실효 영향 판단 불가 |
| `member/domain/MemberType.java` enum 값 목록 | 미열람 (웹은 `'STUDENT' \| 'TRAINER'` 가정) |
| `shared/ui/toast`의 스타일·노출 시간 | 미열람 |
| `shared/ui/dropdown-menu.tsx`의 Radix 포지셔닝 | info 카메라 메뉴 위치는 눈으로 맞춰야 한다 |
| MSW 모킹이 개발 환경 응답을 가로채는지 | `app/_providers/MSWComponent.tsx` 미열람. **단 §4-1의 실측 응답은 운영 도메인(`geonganghaejim.site`)에서 받은 것이라 MSW와 무관하다** |
