# 트레이너 회원관리(`/trainer/manage`) 19개 화면 — 웹 실측 조사

조사 대상 웹 소스: `/Users/seonwoo_jung/workspace/personal/tobehealthy/frontend`
백엔드: `/Users/seonwoo_jung/workspace/personal/tobehealthy/backend`
Flutter: `/Users/seonwoo_jung/workspace/personal/tobehealthy/flutter`

**조사 방법**: 브라우저를 띄우지 않은 정적 분석이다. 소스에 적힌 사실은 `파일:줄`로 근거를 달았고, 렌더 결과·요청 순서처럼 실행해야 확정되는 것은 **(추론)** 으로 표시했다. 확인하지 못한 것은 §9에 모았다.

아래 경로는 모두 `frontend/src/` 기준 상대 경로다(백엔드·Flutter 경로는 별도 표기).

---

## TL;DR — 이관 전에 반드시 알아야 할 7가지

1. 🔴 **`Gym` 모델은 `id`로 만들어라. `gymId`가 아니다.** 웹 TS가 `{gymId}`로 잘못 선언해 뒀지만 이 19개 화면이 실제로 받는 건 `GymDto {id, name}`이다. `gymId`를 가진 `GymResult`는 헬스장 목록 API 전용. → §4.0 / BUG-43
2. 🔴 **이미지 업로드 계약이 웹과 백엔드에서 어긋나 있다.** 웹은 presigned URL(JSON `{fileNames}` → `PUT`), 현재 백엔드는 multipart(`@RequestPart("files")`) 하나뿐이다. 웹 코드를 그대로 옮기면 S9·S10·S11 업로드가 전부 실패한다. → BUG-45
3. 🔴 **`isNonmember` vs `nonmember`** — 웹이 필드명을 틀려 회원 목록의 `가입` 뱃지가 전원에게 붙는다. → BUG-41
4. ⚠️ **`api`(토큰 없음)로 나가는 요청은 마운트 시엔 없다.** 대신 ① 401이면 `api.post('/api/v1/auth/refresh-token')`, ② 이미지 업로드 시 **맨 axios**로 `PUT {presignedUrl}`. 이 둘을 빠뜨리지 말 것. → §0.1
5. ⚠️ **S4(포인트 내역)는 트레이너 화면인데 `<Layout type='student'>`를 써서 학생 하단바가 붙고, 그 안의 훅이 `GET /api/v1/members/trainer-mapping`을 마운트 즉시 1건 더 쏜다.** → BUG-1
6. ⚠️ **노쇼 API는 동사가 직관과 반대다.** `DELETE /schedule/no-show/{id}` = 노쇼 **처리**, `POST` = 노쇼 **해제**. 웹은 올바르게 쓰고 있다. → §4.3⑱
7. ⚠️ **커스텀 스페이싱 스케일은 `w-*`/`h-*`에도 적용된다.** `h-10 w-10`(Button icon)은 40px이 아니라 **32px**, `h-11`은 36px. 반면 `py-28`은 Tailwind 기본이라 **112px**. → §0.4

`="current"` 가 붙어 flutter_svg에서 안 그려지는 SVG 14종은 §6.4에 표로 정리했다.

---

## 0. 먼저 알아야 할 전역 사실

### 0.1 axios 인스턴스는 3종류다

| 인스턴스 | 정의 | 토큰 | 이 19개 화면에서 쓰이는 곳 |
|---|---|---|---|
| `authApi` | `entity/auth/api/authApi.ts:11` | 요청 인터셉터가 `Authorization: Bearer {accessToken}` 주입 (`authApi.ts:13-24`) | **19개 화면의 모든 쿼리·뮤테이션이 전부 이것** |
| `api` | `shared/api/baseApi.ts:19` | 없음 | 이 19개 화면이 직접 부르는 곳은 **없다**. 단 `authApi`의 401 응답 인터셉터가 `POST /api/v1/auth/refresh-token`을 `api`로 쏜다 (`authApi.ts:56`) → **19개 화면 어디서든 401이 나면 토큰 없는 요청이 1건 발생한다** |
| 맨 `axios` | `entity/image/api/mutations.ts:2,36` | 없음 | **S3 presigned URL에 파일 PUT**. `axios.put(url, file)` (`entity/image/api/mutations.ts:36`). 이미지 업로드가 있는 화면(S9·S10·S11)에서 발생 |

> 직전 계열에서 놓쳤던 "토큰 없는 요청"에 해당하는 것은 이 계열에서는 **① refresh-token(401 시 자동), ② S3 presigned PUT(업로드 시)** 두 가지다. 화면이 마운트될 때 `api`로 나가는 요청은 하나도 없다.

401 인터셉터 흐름 (`authApi.ts:26-53`): 401 → `api.post('/api/v1/auth/refresh-token', {userId, refreshToken})` → 성공 시 스토어 갱신, 실패 시 `localStorage.clear()` + `window.location.href = '/'`. **원 요청을 재시도하지는 않는다** — 그냥 reject한다(`authApi.ts:51`).

### 0.2 라우트 그룹 레이아웃은 네트워크 요청을 하지 않는다

`app/(login-required)/trainer/layout.tsx:1-5` → `UserRoleMiddleware`(`app/_providers/UserRoleMiddleware.tsx`)는 `localStorage`만 읽는다(`entity/auth/model/store.ts:56`의 `auth()`). 루트 레이아웃(`app/layout.tsx`)도 QueryProvider·Toast·Kakao 스크립트뿐이다. **따라서 화면별 마운트 요청 = 그 화면 컴포넌트 트리가 만든 요청 전부**다.

### 0.3 하단 네비게이션이 요청을 쏘는 경우

`widget/layout.tsx:35-36` — `<Layout type='trainer'>` → `TrainerNavigation`, `<Layout type='student'>` → `StudentNavigation`.

- `TrainerNavigation`(`widget/navigation.tsx:22-104`): **네트워크 요청 없음**. 순수 Link 4개.
- `StudentNavigation`(`widget/navigation.tsx:106-204`): `useCheckTrainerMemberMappingQuery()`를 호출한다(`navigation.tsx:111`). 이 훅은 `enabled` 옵션이 **없다**(`feature/schedule/api/queries.ts:18-28`) → **마운트 즉시 `GET /api/v1/members/trainer-mapping`이 나간다.** 코드 의도는 "예약 탭을 눌렀을 때 refetch"인데, 훅 자체가 즉시 1회 발사된다.
- **S4(포인트 내역)가 트레이너 화면인데 `type='student'`를 쓴다**(`page/manage/ui/StudentPointDetailPage.tsx:67`) → 트레이너 화면에 학생용 하단바가 뜨고, 위 요청이 추가로 나간다. → BUG-1.

### 0.4 커스텀 스페이싱 스케일 (Tailwind)

`tailwind.config.js:80-93`이 `spacing` 키 **1~12만** 덮어쓴다:

```
1:4px  2:6px  3:8px  4:10px  5:12px  6:16px
7:20px 8:24px 9:28px 10:32px 11:36px 12:48px
```

**13 이상은 Tailwind 기본(rem)** → `py-28` = `7rem` = **112px**, `p-14` = `3.5rem` = 56px.

**중요 — 이 스케일은 padding/margin뿐 아니라 `w-*`, `h-*`, `gap-*`, `space-*`, `inset-*`에도 전부 적용된다** (Tailwind v3에서 `width`/`height`는 `theme.spacing`을 확장한다). 즉:

| 클래스 | 실제 px | 흔히 오해하는 값 |
|---|---|---|
| `h-6 w-6` | 16×16 | 24×24 |
| `h-7 w-7` | 20×20 | 28×28 |
| `h-8` | 24 | 32 |
| `h-10 w-10` (Button `size='icon'`) | 32×32 | 40×40 |
| `h-11` (Button `size='default'`) | 36 | 44 |
| `h-12` (다이얼로그 버튼) | 48 | 48 (우연히 일치) |
| `py-28` (빈 상태 리스트) | 112 상하 | 112 (Tailwind 기본) |
| `w-40` (Card 기본) | 160 (10rem, 기본 스케일) | — |
| `gap-y-11` | 36 | 44 |

이 변환을 Flutter로 옮길 때 `AppSpacing`(`flutter/lib/core/theme/app_spacing.dart:25-38`)이 이미 1:1로 같은 값을 갖고 있다 — `s1:4 … s12:48`.

### 0.5 Typography 매핑 (`shared/mixin/typography.ts`)

| 상수 | 값 |
|---|---|
| `HEADING_1` | 24px / 130% / bold |
| `HEADING_2` | 22px / 130% / bold |
| `HEADING_3` | 20px / 130% / bold |
| `HEADING_4`, `HEADING_4_BOLD` | 18px / 130% / bold |
| `HEADING_4_SEMIBOLD` | 18px / 130% / semibold |
| `HEADING_5` | 13px / 150% / semibold |
| `TITLE_1`, `TITLE_1_BOLD` | 16px / 140% / bold |
| `TITLE_1_SEMIBOLD` | 16px / 140% / semibold |
| `TITLE_2` | 15px / 140% / semibold |
| `TITLE_3` | 14px / 150% / semibold |
| `BODY_1` | 16px / 150% / normal |
| `BODY_2` | 14px / 150% / normal |
| `BODY_3` | 13px / 150% / normal |
| `BODY_4`, `BODY_4_REGULAR` | 12px / 150% / normal |
| `BODY_4_MEDIUM` | 12px / 150% / medium |
| `NAV_TEXT` | 10px / medium / gray-700 |

컨테이너 폭 `--max-width: 440px` (`app/_styles/global.css:57`). 헤더 높이 56px (`widget/layout.tsx:46`).

### 0.6 공통 레이아웃 구조 (`widget/layout.tsx`)

```
<div class="flex h-full items-center justify-center bg-black">      // 바깥 (데스크톱 레터박스)
  <div class="flex h-full w-[440px] flex-col bg-gray-100">
    {Layout.Header}      // header, h-56px, px-20 py-16, flex justify-between
    {contents}           // main, flex-1, overflow-y-auto
    {type==='trainer' && <TrainerNavigation/>}
    {type==='student'  && <StudentNavigation/>}
    {type===undefined  && Layout.BottomArea}   // footer, p-20
  </div>
</div>
```

**주의**: `type`이 지정되면 `Layout.BottomArea`는 아예 렌더되지 않는다(`layout.tsx:37`). 즉 하단 네비와 하단 버튼 영역은 **동시에 못 쓴다**. Flutter의 `AppLayout`도 `bottomArea`/`bottomNavigation` 동시 지정을 assert로 막아 이미 동일하다(`flutter/lib/widget/app_layout.dart:37-42`).

`Layout.Header`는 자식을 `justify-between`으로 배치하므로, 가운데 정렬 타이틀은 `layout-header-title`(= `absolute left-1/2 -translate-x-1/2`, `global.css:196-198`) 클래스를 별도로 붙인다. 오른쪽에 아이콘이 없는 화면은 `<div class='w-[40px]'/>` 더미를 넣어 균형을 맞춘다.

---

## 1. 19개 화면 요약표

`req` = 마운트 시 발사되는 HTTP 요청 수(§0.2 기준). 전부 `authApi`.

| # | 라우트 | 실제 구현 파일 | req | 난이도 | 한 줄 설명 |
|---|---|---|---|---|---|
| S1 | `/trainer/manage` | `page/manage/ui/StudentListPage.tsx` + `feature/manage/ui/StudentList.tsx` | 1 | 하 | 내 회원 목록. 검색·정렬 드롭다운·회원 추가 다이얼로그 |
| S2 | `/trainer/manage/[memberId]` | `page/manage/ui/TrainerStudentDetailPage/index.tsx` + `Header.tsx` | 1 | 상 | 회원 상세 허브. 수강권 카드·포인트 접이식·오늘 식단·운동기록 진입 + 회원 삭제/환불삭제 |
| S3 | `.../[memberId]/course-history` | `page/manage/ui/StudentCourseDetailPage.tsx` | 1 | 상 | 수강권 내역(무한스크롤) + 등록/연장/삭제 |
| S4 | `.../[memberId]/point-history` | `page/manage/ui/StudentPointDetailPage.tsx` | **3** | 중 | 포인트 내역(무한스크롤). 하단바가 student라 요청 1건 추가 |
| S5 | `.../[memberId]/reservation` | `page/manage/ui/TrainerStudentReservationPage.tsx` | 2 | 중 | 다가오는/지난 예약 탭 + 출석·미출석 토글 |
| S6 | `.../[memberId]/edit/memo` | `page/manage/ui/StudentEditMemo.tsx` | 1 | 하 | 회원 메모 textarea 1개 |
| S7 | `.../[memberId]/edit/nickname` | `page/manage/ui/StudentEditNickname.tsx` | 1 | 하 | 별칭 설정 + 확인 알럿 |
| S8 | `.../[memberId]/log` | `page/feedback/ui/TrainerLogPage.tsx` | 2 | 중 | 수업일지 목록(월 단위, 페이징 없음) |
| S9 | `.../[memberId]/log/write` | `page/feedback/ui/TrainerCreateLogPage.tsx` | 1 | 상 | 수업일지 작성. 수업 선택 모드 전환 + 이미지 3장 업로드 |
| S10 | `.../[memberId]/log/[logId]` | `page/feedback/ui/TrainerLogDetailPage/index.tsx` + `Header.tsx` | 1 | 최상 | 수업일지 상세 + 댓글/대댓글(이미지 첨부) + 수정/삭제 |
| S11 | `.../[memberId]/log/[logId]/edit` | `page/feedback/ui/TrainerEditLogPage.tsx` | 1 | 상 | 수업일지 수정 + 이미지 업로드 |
| S12 | `/trainer/manage/feedback` | `page/feedback/ui/TrainerFeedbackPage/index.tsx` (+2) | 1 | 상 | 주간 캘린더 + 수업/식단 탭. 피드백 작성 진입점 |
| S13 | `/trainer/manage/invite` | `page/manage/ui/TrainerInvitePage.tsx` | 1 | 상 | 미가입 회원 초대. 초대링크 복사 / 카카오 공유 |
| S14 | `/trainer/manage/append` | `page/manage/ui/NotRegisteredStudentListPage.tsx` | 2 | 하 | 미배정 가입회원 검색 목록 |
| S15 | `/trainer/manage/append/[memberId]` | `page/manage/ui/TrainerAppendStudentPage.tsx` | **0** | 하 | 가입회원 추가(PT 횟수 입력) |
| S16 | `.../[memberId]/diet` | `page/feedback/ui/TrainerStudentDietListPage.tsx` | 2 | 중 | 회원 식단 목록(무한스크롤) |
| S17 | `.../[memberId]/diet/[dietId]` | `page/feedback/ui/TrainerStudentDietDetailPage.tsx` | 2 | 상 | 식단 상세 + 좋아요 + 댓글/대댓글 + 이미지 확대 |
| S18 | `.../[memberId]/workout` | `page/workout/ui/TrainerWorkoutPage.tsx` | 1 | 중 | 회원 개인 운동기록 목록(무한스크롤) |
| S19 | `.../[memberId]/workout/[workoutHistoryId]` | `page/workout/ui/TrainerWorkoutDetailPage.tsx` | 2 | 상 | 운동기록 상세 + 좋아요 + 댓글 |

배럴 매핑: `page/manage/index.ts`, `page/feedback/index.ts`, `page/workout/index.ts` 참고. S12/S16/S17은 `@/page/feedback`, S18/S19는 `@/page/workout`에서 재수출된다 — **manage 계열인데 구현이 feedback/workout 디렉터리에 있다.**

---

## 2. ⚠️ 공유 데이터를 바꾸는 요청 — 캡처 전에 읽을 것

공개 체험 계정으로 브라우저 캡처를 할 때 **절대 누르면 안 되는 것들**이다.

### 2.1 치명 — 복구 불가

| 화면 | UI 문구 | 요청 | 무엇이 바뀌나 |
|---|---|---|---|
| S2 | 케밥 → `회원 삭제` → 알럿 `예` | `DELETE /api/v1/trainers/members/{memberId}` | 회원-트레이너 매핑이 끊긴다. 목록에서 사라진다 |
| S2 | 케밥 → `환불 회원 삭제` → 체크 → `회원 삭제` | `DELETE /api/v1/trainers/members/{memberId}/refund` | **시트 문구 그대로: "회원 정보, 운동 기록, 예약 내역, 수강권 등은 복구되지 않습니다."** |
| S3 | `수강권 삭제` → 알럿 `예` | `DELETE /api/v1/course/{courseId}` | 그 회원 수강권이 통째로 삭제된다 |
| S10 | 케밥 → `삭제` → 알럿 `삭제` | `DELETE /api/v1/lessonhistory/{logId}` | 수업일지 1건 영구 삭제 |
| S10/S17/S19 | 댓글 케밥 → `댓글 삭제` | `DELETE /api/v1/lessonhistory/comment/{id}` / `DELETE /api/v1/diets/{dietId}/comments/{commentId}` / `DELETE /api/v1/workout-histories/{id}/comments/{commentId}` | 댓글 삭제(확인 다이얼로그 **없이 바로 나간다**) |

### 2.2 데이터 생성/증감

| 화면 | UI 문구 | 요청 | 무엇이 바뀌나 |
|---|---|---|---|
| S15 | `추가하기` | `POST /api/v1/trainers/members/{memberId}` body `{lessonCnt}` | 회원이 내 회원으로 편입 + 수강권 N회 지급 |
| S13 | `완료` | `POST /api/v1/trainers/nonmember` body `{name, lessonCnt}` | 비회원 초대 레코드 생성 + 초대 URL 발급 |
| S3 | `수강권 등록` | `POST /api/v1/course` body `{memberId, lessonCnt}` | 수강권 신규 생성 |
| S3 | `수업 횟수 추가` | `PATCH /api/v1/course/{courseId}` body `{memberId, calculation:'PLUS', type:'PLUS_CNT', updateCnt}` | 수강 횟수 증가(+내역 기록) |
| S9 | `작성 완료` | `POST /api/v1/lessonhistory` | 수업일지 생성. `title`은 `'무제'` 하드코딩(`TrainerCreateLogPage.tsx:64`) |
| S11 | `작성 완료` | `PATCH /api/v1/lessonhistory/{logId}` | 수업일지 내용·이미지 덮어쓰기 |
| S6 | 헤더 `완료` | `PUT /api/v1/members/{studentId}/memo` | 회원 메모 덮어쓰기 |
| S7 | 헤더 `완료` → `예` | `POST /api/v1/members/nickname/{studentId}` | 회원 별칭 변경 |
| S5 | 시트에서 `출석`/`미출석` | `DELETE` 또는 `POST /api/v1/schedule/no-show/{scheduleId}` | 출석 상태 토글. **노쇼 처리 시 회원 포인트가 깎인다**(포인트 타입 `NO_SHOW`) |
| S17 | 하트 아이콘 | `POST`/`DELETE /api/v1/diets/{dietId}/like` | 식단 좋아요 토글 |
| S19 | 하트 아이콘 | `POST`/`DELETE /api/v1/workout-histories/{id}/like` | 운동기록 좋아요 토글. **300ms 디바운스 후 자동 전송**(`feature/workout/ui/PostMetrics.tsx:41,104-108`) — 두 번 눌러 되돌리면 요청이 아예 안 나갈 수도 있다 |
| S10/S17/S19 | 입력창 ↑ 버튼 | 댓글/대댓글 생성·수정 POST/PATCH | 공개 댓글이 실제로 달린다 |
| S9/S10/S11 | 카메라/사진 아이콘으로 파일 선택 | `POST /api/v1/file` → `PUT {presignedUrl}`(맨 axios) | **파일 선택 즉시 업로드가 시도된다.** 글을 저장하지 않아도 요청 자체는 발생. 단 **현재 백엔드는 이 계약을 지원하지 않는다**(§5.1 BUG-45) → 실제로는 에러 토스트가 뜰 가능성이 높다 |

### 2.3 메일/외부 발송

| 화면 | UI | 무엇이 나가나 |
|---|---|---|
| S13 | 완료 후 다이얼로그 `공유하기` | `window.Kakao.Share.sendDefault(...)` — 카카오톡 공유창이 뜬다(`TrainerInvitePage.tsx:62-82`). 서버 메일은 아님 |
| S13 | 완료 후 다이얼로그 `링크 복사하기` | 클립보드 복사만. 서버 요청 없음 |

> **이 19개 화면에 이메일을 발송하는 엔드포인트는 없다.** 초대는 링크/카카오 공유 방식이다. `POST /api/v1/trainers/nonmember` 응답이 `{uuid, invitationLink}`(`feature/manage/api/mutations.ts:105-108`).

### 2.4 캡처 시 안전한 화면

S1, S4, S8, S12, S14, S16, S18 — 마운트만으로는 GET만 나간다. S2/S3/S5/S17/S19도 **버튼을 안 누르면** 안전하다(S19는 하트에 스치기만 해도 위험).

---

## 3. 화면별 상세

표기: `[a] → [b]`는 화면 이동. 문구는 원문 그대로.

---

### S1 — `/trainer/manage` · 나의 회원

구현: `page/manage/ui/StudentListPage.tsx`(29줄) + `feature/manage/ui/StudentList.tsx`(237줄) + `feature/manage/ui/AddStudentDialog.tsx`

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/members` | `authApi` | `useRegisteredStudentsQuery` (`feature/manage/api/queries.ts:23`) | 없음 → 즉시 | **하위 컴포넌트** `StudentList` (`StudentList.tsx:65`) |

`<Layout type='trainer'>`(`StudentListPage.tsx:14`) → `TrainerNavigation` 렌더되지만 요청 없음.
`useEffect` 안에서 직접 호출하는 요청 없음. 무한스크롤 아님(전체 배열 1회 수신).

#### 구조 (위 → 아래)

1. **헤더** (`bg-transparent`)
   - 왼쪽: `IconBack` → `/trainer`
   - 가운데: `나의 회원` (HEADING_4)
   - 오른쪽: `AddStudentDialog` 트리거 = `IconPlus fill='black' width=17 height=16` 를 담은 `h-7 w-7`(=20×20px) ghost 버튼
2. **검색바** — `px-7 py-6`(20/16px), 안쪽 `bg-gray-200 rounded-md px-6 py-4`(16/10px). 좌측 `IconSearch`(`h-7 w-7`=20px), placeholder `이름 검색`
3. **카운트 + 정렬** — `총 {n}명` (BODY_2, 숫자만 TITLE_3 + primary-500) / 우측 정렬 드롭다운 트리거 `IconArrowDownUp` + 현재 라벨
   - 드롭다운(`w-[96px]`, `absolute -right-9 top-1`): `기본 순` / `랭킹 순` — 선택된 것은 `text-black`, 나머지 `text-gray-500`
   - `기본 순` = `memberId` 오름차순, `랭킹 순` = `ranking` 오름차순 (`StudentList.tsx:34-43`)
4. **분기**
   - `studentList === null` → `IconAlertCircle` + `등록된 회원이 없습니다.` + 버튼 `회원 등록하기`(`IconPlus fill='white'`, `h-12 w-[146px]`, AddStudentDialog 트리거)
   - `studentList !== null && 검색결과 0건` → `IconAlertCircle` + `검색 결과가 없습니다.`
   - 그 외 → 회원 카드 리스트
5. **회원 카드** (`h-[72px] rounded-lg bg-white px-6 py-7`)
   - 프로필: `fileUrl` 있으면 `<Image src={fileUrl + '?w=300&h=300&q=90'} className='h-10 w-10 ...'>`(=32×32px), 없으면 `IconProfileDefault width=32 height=32`
   - 랭킹 1/2/3위는 테두리 색이 다르다 (`page/manage/utils.ts:1-7`): 1위 `#FFB950`, 2위 `#C4C5CD`, 3위 `#FFB58B`, 그 외 없음 (모두 `border-[2px]`)
   - 이름(TITLE_1_BOLD) + `nonmember === false`일 때 뱃지 `가입` (`bg-blue-50 text-[10px] text-primary px-3 py-[1.5px]`)
     - ⚠️ **서버가 보내는 필드는 `isNonmember`라 `item.nonmember`는 항상 `undefined` → 실제로는 전 회원에게 뱃지가 붙는다** → BUG-41
   - 그 아래 `nickName`(BODY_4_REGULAR, gray-500) — **타입상 항상 `null`이라 표시될 수 없다 → BUG-4**
   - 우측: `잔여`(BODY_3 primary-500) + `remainLessonCnt`(TITLE_3 primary-500) + `/{lessonCnt}`(BODY_2 gray-400)
   - 클릭 → `/trainer/manage/{memberId}`

#### `AddStudentDialog` (`feature/manage/ui/AddStudentDialog.tsx`)

전체화면 다이얼로그(`top-0 max-w-[440px] translate-y-0 p-0`).
- 헤더(`flex-row-reverse`): 닫기(`CloseIcon 20×20`) / 제목 `회원 추가` / 더미 `w-[40px]`
- 본문(`flex-row justify-evenly py-6`): 2열
  - `IconPeoplePlus` + `회원 직접 추가` → `/trainer/manage/invite`
  - `IconPeoples` + `가입된 회원 추가` → `/trainer/manage/append`

---

### S2 — `/trainer/manage/[memberId]` · 회원 정보

구현: `page/manage/ui/TrainerStudentDetailPage/index.tsx`(418줄) + `Header.tsx`(188줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/members/{memberId}` | `authApi` | `useStudentDetailQuery` (`feature/manage/api/queries.ts:35`) ← `useStudentInfo`(`page/manage/hooks/useStudentInfo.tsx:3`) | 없음 → 즉시 | 화면 본체 (`index.tsx:45`) |

`<Layout>`에 `type` 없음 → 하단 네비 없음. `useEffect` 직접 호출 없음.

#### 구조

**헤더** (`Header.tsx:78-184`)
- 왼쪽 `IconBack` → `router.back()`
- 가운데 `회원 정보` (HEADING_4_SEMIBOLD + `layout-header-title`)
- 오른쪽 `IconDotsVertical` 케밥 → 드롭다운(`w-[130px]`, `absolute -right-5 top-0`)
  - `별칭 설정` → `/trainer/manage/{memberId}/edit/nickname`
  - `회원 삭제` → AlertDialog 열기
  - `환불 회원 삭제` (`text-point` = `#FF4668`) → Sheet 열기

**AlertDialog — 회원 삭제** (`Header.tsx:109-136`)
- 제목: `{name}님을 삭제하시겠습니까?` (TITLE_1, 가운데)
- 버튼 2개(`flex-row gap-3`, 각 `h-12 w-full`): `아니요`(`bg-gray-100 text-gray-600`) / `예`(`bg-point text-white`) → `DELETE /api/v1/trainers/members/{memberId}` → 성공 시 `router.replace('/trainer/manage')`

**Sheet — 환불 회원 삭제** (`Header.tsx:137-183`, `p-7 pb-9`)
- 제목: `환불 회원 삭제하기` (HEADING_4_BOLD, 좌측)
- 설명: `회원 삭제시 회원 정보, 운동 기록, 예약 내역, 수강권 등은 복구되지 않습니다.` (BODY_1, gray-600)
- 체크박스(커스텀, `h-7 w-7`=20×20, 체크 시 `bg-primary-500` + `IconNoCircleCheck width=15 height=12 fill='white'`) + 문구 `위 내용을 확인하였으며, 회원을 삭제합니다.` (BODY_2)
- 하단: `취소`(SheetClose, `bg-gray-100 text-gray-600`) / `회원 삭제`(체크 전 `bg-gray-300` + disabled, 체크 후 `bg-point`) → `DELETE /api/v1/trainers/members/{memberId}/refund` → 성공 토스트(서버 message) + `router.replace('/trainer/manage')`

**본문** (`index.tsx:58` `Layout.Contents` = `hide-scrollbar p-7 pt-8`)

1. **프로필 행** (`mb-6 gap-x-8`)
   - 사진 80×80 원형(`border-gray-300` + 랭킹 테두리) 또는 `IconDefaultProfile`
   - 이름 (HEADING_2)
   - 그 아래 (BODY_3 gray-500): `nickName` / 구분선(`h-[11px] w-[1px] bg-gray-300`) / `랭킹 {ranking}` — **`ranking === 999`면 랭킹 표시를 숨긴다**(`index.tsx:84,87`)
2. **바로가기 카드** (`Card mb-6 px-8 py-5 shadow-sm`, 3열 + 세로 구분선 `h-11 w-[1px] bg-gray-100`)
   | 아이콘 | 문구 (HEADING_5) | 이동 |
   |---|---|---|
   | `IconCalendar`(icon_calendar_blue.svg) | `예약 내역` | `/trainer/manage/{id}/reservation?name={name}` |
   | `IconEdit`(icon_edit.svg) | `회원 메모` | `/trainer/manage/{id}/edit/memo` |
   | `IconDumbel` | `수업 일지` | `/trainer/manage/{id}/log` |
3. **수강권 카드** — `memberInfo.course`가 있을 때만 (`index.tsx:127`)
   - `CourseCard`(`feature/course/ui/CourseCard.tsx`): 만료(`completedLessonCnt === totalLessonCnt`)면 `bg-gray-500`, 아니면 `bg-primary-500`
     - 헤더: 좌 `{gymName}`, 우 `PT {totalLessonCnt}회 수강권` (둘 다 BODY_3 gray-100)
     - 큰 글씨(HEADING_3): 만료 시 `{total}회 PT수강 만료`, 아니면 `{remain}회 예약할 수 있어요!`
     - 본문: `PT 진행 횟수 {completed}` + `/{total}`(만료 시 gray-300, 아니면 `#8EC7FF`) + `Progress h-[2px]`
     - 카드 전체가 `/trainer/manage/{id}/course-history?name={name}`로 링크
   - **만료가 아닐 때** → `Collapsible`(`bg-primary-600`, 하단 라운드)
     - 트리거(`p-6`): 좌 `{M}월 활동 포인트`(HEADING_5) / 우 — 닫힘: point.png(21×21) + `{monthPoint}` + `IconArrowDown`, 열림: `IconArrowDown` 180도 회전만
     - 내용(`p-6 pt-3`): 카드 2장(각 `w-[130px] p-6 gap-y-7`)
       - ① point.png + `이번달 포인트` / 큰 숫자 `{monthPoint}` + `점` / `누적 {totalPoint}` → `/trainer/manage/{id}/point-history?name={name}`
       - ② `랭킹` / `{rank.ranking}` + `위` (999면 `-`) + 화살표(랭킹이 지난달보다 나빠졌으면 `IconArrowFilledDown fill='var(--primary-500)'`, 좋아졌으면 `IconArrowFilledUp fill='var(--point-color)'`, 같으면 없음) / `총 {rank.totalMemberCnt}명`
   - **만료일 때** → 접이식 없이 `bg-gray-400` 고정 바: `{M}월 활동 포인트` + point.png + `{monthPoint}`
4. **수강권 없을 때** (`index.tsx:329`) — `Card h-[127px] bg-gray-500 text-white` 가운데 `현재 등록된 수강권이 없습니다.` (TITLE_3)
5. **오늘 식단 카드** — `memberInfo.diet.dietId`가 truthy일 때
   - 헤더: `오늘 식단`(TITLE_2 gray-800) / 우 `식단전체`(BODY_3 gray-500) → `/trainer/manage/{id}/diet?month={YYYY-MM}`
   - 본문: 아침·점심·저녁 3칸(각 `h-[88px]`)
     - `fast === true` → `bg-gray-100` + `IconCheck fill='var(--primary-500)' 17×17` + 글자 `단식`
     - 사진 있음 → `<img class='custom-image rounded-md'>` (`buildDisplayImageUrl`)
     - 둘 다 없음 → `bg-gray-100` 빈 박스
6. **등록 식단 카드** — `memberInfo.diet.dietId === null`일 때 (`index.tsx:391`)
   - `등록 식단`(TITLE_2) + `IconArrowRight` → `/trainer/manage/{id}/diet?month={YYYY-MM}`
7. **개인 운동 기록 카드** — 항상
   - `개인 운동 기록`(TITLE_2 gray-800) + `IconArrowRight` → `/trainer/manage/{id}/workout`

#### 상호작용 요청

| 트리거 | 메서드·경로 | 인스턴스 |
|---|---|---|
| `회원 삭제` → `예` | `DELETE /api/v1/trainers/members/{memberId}` | authApi |
| `환불 회원 삭제` → `회원 삭제` | `DELETE /api/v1/trainers/members/{memberId}/refund` | authApi |

---

### S3 — `.../[memberId]/course-history` · {name}님 수강권

구현: `page/manage/ui/StudentCourseDetailPage.tsx`(391줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/members/{memberId}/course?page=0&size=20&searchDate={YYYY-MM}` | `authApi` | `useStudentCourseDetailQuery` — **`useInfiniteQuery`** (`feature/course/api/queries.ts:35-54`) | 없음 → 즉시 | 화면 본체 (`:74`) |

- 페이지 파라미터 이름 **`page`**, `initialPageParam: 0`, 다음 페이지 = `allPages.length` (`queries.ts:48-52`), 종료 조건 `lastPage.isLast`
- `size`는 화면 상수 `ITEMS_PER_PAGE = 20` (`StudentCourseDetailPage.tsx:49`)
- `searchDate`는 `dayjs(searchMonth).format('YYYY-MM')` — **월 변경 시 queryKey가 바뀌어 새 요청**
- `<Layout type='trainer'>` → TrainerNavigation (요청 없음)
- `useEffect` 2개: ① 무한스크롤 트리거(`:148-154`, `useInView` 기반 `fetchNextPage`) ② 언마운트 시 `queryClient.removeQueries(['studentCourseHistory'])` (`:156-160`)

#### 구조

**헤더** (`justify-start bg-white`)
- `IconBack` → `router.back()`
- `{name}님 수강권` (HEADING_4_SEMIBOLD + `layout-header-title`) — `name`은 쿼리스트링에서 읽음(`:55`)
- 우측 `+`(`IconPlus 20×20 fill='black'`, `absolute right-7`) — **`totalLessonCnt === completedLessonCnt`(만료)일 때만 렌더**(`:172`). 누르면 수강권 등록 시트

**로딩** — `isPending`이면 화면 전체에 `/images/loading.gif` 30×30 (`:196-198`)

**수강권 있을 때** (`bg-white p-7 pb-0`)
1. `CourseCard` (S2와 동일 구조)
2. 액션 바 (`rounded-lg bg-gray-100`, 2열 + 세로선 `h-[30px] w-[1px] bg-gray-200`)
   - `수업 횟수 추가` (`h-[46px] w-[160px]`, HEADING_5) — 만료 시 `disabled` + `text-gray-400`
   - `수강권 삭제` (`h-[46px] w-[160px]`, ghost) → AlertDialog
3. 우측 정렬 `MonthPicker`

**수강권 없을 때** (`:303`, `bg-white py-[88px]`)
- `등록된 수강권이 없습니다.` (TITLE_3 gray-500)
- 버튼 `수강권 등록` (`h-[37px] w-[112px] rounded-full border border-primary-500 text-primary-500`) → 등록 시트

**내역 리스트** (`bg-gray-100`)
- 빈 페이지(`content === null || length === 0`) → `py-28`(=112px 상하) 가운데: `IconNotification 33×33 stroke='var(--gray-300)'` + `수강권 내역이 없습니다.` (TITLE_1_BOLD gray-700)
- 항목(`px-7 py-8` = 20/24px): 날짜 `YY.MM.DD`(BODY_4_MEDIUM gray-500) / 좌 타입 라벨(TITLE_3 gray-700) / 우 `+{cnt}` 또는 `-{cnt}`(TITLE_3 black)
- 타입 라벨 매핑 (`feature/course/const.ts`):
  | 코드 | 문구 |
  |---|---|
  | `COURSE_CREATE` | `수강권 생성` |
  | `PLUS_CNT` | `수강권 연장` |
  | `MINUS_CNT` | `수강권 차감` |
  | `ONE_LESSON` | `1회권 지급` |
  | `RESERVATION` | `수업 예약` |
  | `RESERVATION_CANCEL` | `수업 예약 취소` |
- 하단 감지 영역: `!마지막페이지.isLast && hasNextPage`이면 `loading.gif` 20×20 (`:381`)

**공통 시트 — `CourseSheet`** (`feature/manage/ui/CourseBottomSheet.tsx`)
- 컨테이너: `m-auto mb-7 w-[calc(100%-20px)] rounded-lg px-7 pb-9 pt-8`, `side='bottom'`
- 제목: 등록 시 `등록할 수업횟수`, 추가 시 `추가할 수업횟수` (HEADING_4, 좌측)
- 입력: `type='number'`, `w-[100px] text-[40px] font-bold leading-[130%]` 가운데, 밑줄만(`border-b`), 포커스 시 `border-y-primary-500`
  - 3자 초과 입력은 잘라냄(`:78-80`), 500 초과 시 에러 문구 `500회 이하로 입력해주세요.`(`text-point`, BODY_4)
  - 시트가 닫히면 입력·에러 초기화 (`:90-95`)
- 버튼(`h-[52px] w-full`, TITLE_1): 등록 시 `수강권 등록`, 추가 시 `수업 횟수 추가`. `입력 === '' || Number > 500`이면 disabled

**AlertDialog — 수강권 삭제** (`:271-289`, `py-11`)
- 제목 `수강권을 삭제하시겠습니까?` (TITLE_1)
- 버튼(2열 grid, 각 `h-[48px]`): `아니요`(gray-100/gray-600) / `예`(bg-point/white)

#### 상호작용 요청

| 트리거 | 메서드·경로 | body | 성공 토스트 |
|---|---|---|---|
| `수강권 등록` | `POST /api/v1/course` | `{memberId, lessonCnt}` | 서버 `message` |
| `수업 횟수 추가` | `PATCH /api/v1/course/{courseId}` | `{memberId, calculation:'PLUS', type:'PLUS_CNT', updateCnt}` | `{입력값}회가 연장되었습니다.` |
| `수강권 삭제` → `예` | `DELETE /api/v1/course/{courseId}` | — | 서버 `message` |

`courseId`는 `historyData.pages[0].mainData.course.courseId`를 `Number()`로 변환해 쓴다(`:84`) — 수강권이 없으면 `Number(undefined) = NaN` → **BUG-9**.

---

### S4 — `.../[memberId]/point-history` · {name}님 포인트

구현: `page/manage/ui/StudentPointDetailPage.tsx`(179줄)

#### 마운트 요청 — **3건. 트레이너 화면인데 학생 하단바가 요청을 1건 더 쏜다.**

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/members/{memberId}` | `authApi` | `useStudentDetailQuery` ← `useStudentInfo` (`:30`) | 없음 | 화면 본체 |
| 2 | `GET /api/v1/members/{memberId}/point?page=0&size=20&searchDate={YYYY-MM}` | `authApi` | `useStudentPointHistoryQuery` — **`useInfiniteQuery`** (`feature/point/api/queries.ts:34`) | 없음 | 화면 본체 (`:42`) |
| 3 | `GET /api/v1/members/trainer-mapping` | `authApi` | `useCheckTrainerMemberMappingQuery` (`feature/schedule/api/queries.ts:18`) | 없음 | **하위 컴포넌트 `StudentNavigation`** (`widget/navigation.tsx:111`) — `<Layout type='student'>`(`:67`) 때문 |

페이지 파라미터 `page`, `initialPageParam: 0`, `ITEMS_PER_PAGE = 20`.
발사 순서는 선언 순서로 ①→②이고 ③은 트리 하단이라 마지막일 것으로 보이나, **TanStack Query가 effect 시점에 fetch하므로 실제 네트워크 순서는 실행해야 확정된다 (추론)**.

`useEffect` 2개: 무한스크롤(`:48-54`), 언마운트 시 `removeQueries(['myPointHistory'])`(`:56-60`) — **키가 틀렸다 → BUG-6**.

#### 구조

**헤더** (`justify-start bg-white`)
- 좌측 `IconClose width=14 height=14` 를 감싼 `<Link href='./' className='h-full w-full'>` — **뒤로가기가 아니라 상대경로 `./`** (현재 URL 기준). `layout-header-title`이 붙은 제목과 겹칠 수 있다 (추론)
- 제목 `{memberInfo?.name}님 포인트`

**로딩** — `isPending`이면 `<div className='loading'>Loading..</div>` — **스타일 없는 raw 텍스트**(`:78`) → BUG-13

**상단 블록** (`bg-white p-7 pb-11 pt-6`)
1. `MonthPicker`
2. 포인트 카드 (`bg-primary-500 px-6 py-7 gap-y-1`)
   - 헤더: `{M}월 활동 포인트`(HEADING_5 white) / 우측 point.png 21×21 + `{monthPoint}`(HEADING_4 white)
   - 본문: `누적`(BODY_4_MEDIUM, `text-blue-100`) ↔ `{totalPoint}`(BODY_3 white)
     - **`text-blue-100`은 tailwind config에 없다**(blue는 10·50만 정의, `tailwind.config.js:48-51`) → 클래스가 생성되지 않는다 → BUG-14
3. 안내문: `IconNotification 12×12 stroke='black'` + `활동 포인트는 매월 1일 자정 초기화됩니다.` (BODY_4)

**내역 리스트** (`bg-gray-100`) — S3와 동일 형태
- 빈 상태: `py-28` + `IconNotification 33×33 stroke='var(--gray-300)'` + `포인트 내역이 없습니다.`
- 항목: `YY.MM.DD` / 타입 라벨 / `+{point}` 또는 `-{point}`
- 타입 라벨 (`feature/point/const.ts`): `NO_SHOW`→`노쇼`, `NO_SHOW_CANCEL`→`노쇼취소`, `WORKOUT`→`개인운동`, `DIET`→`식단등록`

#### 상호작용 요청
없음(읽기 전용). 월 변경 시 ②가 새 `searchDate`로 재요청.

---

### S5 — `.../[memberId]/reservation` · {name}님 예약 내역

구현: `page/manage/ui/TrainerStudentReservationPage.tsx`(126줄) + `feature/schedule/ui/TrainerStudentReservationSchedule.tsx` + `TrainerStudentLastReservationSchedule.tsx`

#### 마운트 요청 — 2건. **탭이 안 열려 있어도 둘 다 나간다.**

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/reservation/new?memberId={id}` | `authApi` | `useTrainerStudentReservationListQuery` (`feature/schedule/api/queries.ts:175`) | 없음 | 화면 본체 (`:32`) |
| 2 | `GET /api/v1/trainers/reservation/old?searchDate={YYYY-MM}&memberId={id}` | `authApi` | `useTrainerStudentLastReservationListQuery` (`feature/schedule/api/queries.ts:160`) | 없음 | 화면 본체 (`:34`) |

둘 다 `useQuery`(무한스크롤 아님). 훅이 **페이지 컴포넌트에서** 호출되므로 Radix Tabs가 비활성 `TabsContent`를 언마운트하는 것과 무관하게 둘 다 발사된다.

#### 구조

**헤더**: `IconBack` → `router.back()` / `{name}님 예약 내역` (`name`이 없으면 제목 자체가 빈 문자열, `:51`)

**탭** (`Tabs defaultValue='upcomingReservation'`)
- `TabsList`는 기본 하단 보더를 `border-b-0 p-0`로 지우고 `gap-4`(10px) 좌측 정렬
- 트리거 2개(`rounded-full bg-white px-5 py-[5px] text-gray-500`, 활성 시 `bg-primary-500 text-white` + HEADING_5):
  - `다가오는 예약`
  - `지난 예약`

**다가오는 예약 탭**
- `reservations`가 있으면 `TrainerStudentReservationSchedule` 반복, 없으면(`null`) 같은 컴포넌트에 `data={null}` 전달 → 빈 상태
- 항목 카드(`mb-5 px-6 py-7 text-left`): 상단 `MM월 DD일 dddd`(TITLE_3 gray-600), 하단 `{오전|오후} {h:mm} - {h:mm}`(TITLE_1_BOLD) + `IconCheck fill='var(--primary-500)' 17×17`
- 빈 상태: `py-28` + `IconNoSchedule` + `예약된 수업이 없습니다.` (TITLE_1_BOLD gray-400)

**지난 예약 탭**
- 좌측 정렬 `MonthPicker`
- `isPending`이면 `h-[500px]` 가운데 `loading.gif` 20×20
- 항목 카드: 날짜 + 시간 + 상태 뱃지(`w-[52px] py-[2px] rounded-sm`) — `COMPLETED`이면 `bg-[#e2f1ff] text-primary-500` / `출석`, 아니면 `bg-gray-100 text-gray-700` / `미출석`
- 카드 전체가 Sheet 트리거
- 빈 상태: `py-28` + `IconNoSchedule` + `완료한 수업이 없습니다.`

**Sheet — 수업 정보** (`TrainerStudentLastReservationSchedule.tsx:131-173`, `pt-7`)
- 제목 `수업 정보` (HEADING_4_BOLD, 좌측)
- 본문(`rounded-md bg-gray-100 p-6 text-center`, HEADING_3): `{MM.DD (dd)} {오전|오후} {h:mm} - {h:mm}` + 상태(` 출석` black / ` 미출석` text-point)
- 하단 버튼 2개(각 `h-12 w-full`):
  - 좌: 현재 `COMPLETED`면 `미출석`(`bg-gray-100 text-point`), 아니면 `출석`(`bg-[#E2F1FF] text-primary-500`)
  - 우: `확인`(SheetClose, `bg-primary-500 text-white`)

시간 포맷은 `convertTo12HourFormat`(`shared/utils/date.ts:64-72`) — `"14:30:00"` → `["2:30", "오후"]`. 12시는 `오후 12:00`, 0시는 `오전 12:00`.

#### 상호작용 요청

| 트리거 | 조건 | 메서드·경로 |
|---|---|---|
| 시트 좌측 버튼 | 현재 `COMPLETED` → 노쇼 처리 | `DELETE /api/v1/schedule/no-show/{scheduleId}` |
| 시트 좌측 버튼 | 현재 `COMPLETED` 아님 → 출석 복구 | `POST /api/v1/schedule/no-show/{scheduleId}` |

성공 시 서버 `message` 토스트 + 시트 닫기 + `refetchQueries(['TrainerStudentLastReservationList'])`.

---

### S6 — `.../[memberId]/edit/memo` · {name}님 메모장

구현: `page/manage/ui/StudentEditMemo.tsx`(77줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/members/{memberId}` | `authApi` | `useStudentDetailQuery` ← `useStudentInfo` (`:23`) | 없음 | 화면 본체 |

#### 구조
- 배경 `bg-white`(`<Layout className='bg-white'>`)
- **`memberInfo`가 로드되기 전에는 헤더까지 포함해 아무것도 렌더되지 않는다**(`:48`) — 빈 흰 화면
- 헤더: `IconBack` → `router.back()` / `{name}님 메모장`(HEADING_4_SEMIBOLD) / 우측 `완료`(ghost, BODY_1)
- 본문: `Textarea` 하나 — `h-full resize-none px-7 py-8`(20/24px), BODY_2, placeholder `메모를 입력해주세요.`, 초기값 `memberInfo.memo ?? ''`

#### 상호작용 요청

| 트리거 | 메서드·경로 | body | 후처리 |
|---|---|---|---|
| 헤더 `완료` | `PUT /api/v1/members/{studentId}/memo` | `{memo}` | `refetchMemberInfo()` → 토스트 `메모를 저장했습니다.` → `router.back()` |

**빈 문자열이면 요청 자체를 보내지 않는다**(`:29` `if (!newMemo) return;`) → 메모를 지울 수 없다 → BUG-10.

---

### S7 — `.../[memberId]/edit/nickname` · 회원 별칭 설정

구현: `page/manage/ui/StudentEditNickname.tsx`(170줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | 주체 |
|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/members/{memberId}` | `authApi` | `useStudentDetailQuery` ← `useStudentInfo` (`:37`) | 화면 본체 |

#### 구조
- 헤더: 좌 `IconClose 20×20`(→ `router.replace('/trainer/manage/{memberId}')`) / 가운데 `회원 별칭 설정` / 우 `완료`(AlertDialog 트리거)
- 본문(`mt-11 gap-y-11 px-7`)
  1. 프로필 이미지 80×80 원형 또는 `IconDefaultProfile` (가운데, `pt-8`)
  2. `이름` 라벨(TITLE_3) + readonly 입력(`bg-gray-100 border-gray-200 rounded-md px-6 py-[13px]`, BODY_1 gray-500)
  3. `별칭` 라벨(TITLE_3) + 입력(`border-gray-200 rounded-md px-6 py-[13px]`, BODY_1 gray-800, placeholder `별칭을 입력해주세요.`)

**AlertDialog — 저장 확인** (`gap-8`)
- 제목 `별칭을 저장할까요?` (TITLE_1_SEMIBOLD, 좌측)
- 버튼(각 `h-12 w-full`): `아니요`(`bg-gray-100 text-gray-600`) / `예`(기본 `bg-primary-500`)

#### 상호작용 요청

| 트리거 | 검증 | 메서드·경로 |
|---|---|---|
| `예` | 입력이 비었으면 토스트 `별칭을 입력해주세요.` 후 중단 | — |
| `예` | 기존 별칭과 같으면 토스트 `기존 별칭과 같습니다.` 후 중단 | — |
| `예` | 통과 | `POST /api/v1/members/nickname/{studentId}` body `{nickname}` |

성공: `refetchMemberInfo()` → 서버 `message` 토스트 → `router.replace('/trainer/manage/{memberId}')`.

**주의**: 별칭 입력은 `defaultValue`(비제어) + `onChange` 조합이라(`:152-156`) 초기값이 `memberInfo` 도착 전 `''`로 굳는다 → BUG-11.

---

### S8 — `.../[memberId]/log` · {name}님 수업 일지

구현: `page/feedback/ui/TrainerLogPage.tsx`(146줄)

#### 마운트 요청 — 2건

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/lessonhistory/student/{memberId}?searchDate={YYYY-MM}` | `authApi` | `useTrainerLogListQuery` (`feature/log-class/api/queries.ts:87`) | 없음 | 화면 본체 (`:39`) |
| 2 | `GET /api/v1/lessonhistory/unwritten?studentId={memberId}` | `authApi` | `useLessonListQuery` (`feature/log-class/api/queries.ts:8`) | 없음 | 화면 본체 (`:43`) |

①은 `useQuery`(무한스크롤 아님) — 응답에 `Pageable` 필드가 있지만 **페이지네이션을 하지 않는다**. `page`/`size` 파라미터도 안 보낸다.
②는 우측 `+` 버튼의 동작 분기용.

#### 구조

**헤더**
- `IconBack` → `router.back()`
- `{studentName}님 수업 일지` — `studentName`은 ①의 응답 필드. 없으면 그냥 `수업 일지`(`:53`)
- 우측 `IconPlus fill='black' 20×20`: `lessonList`가 로드된 뒤에만 렌더
  - 미작성(`reviewStatus === '미작성'`) 수업이 **있으면** → `/trainer/manage/{memberId}/log/write` 링크
  - **없으면** → AlertDialog: 제목 `수업일지가 모두 작성 완료되었습니다.`(HEADING_4_BOLD) + 버튼 `확인`(`bg-primary-500 text-white py-[13px]`) 하나

**본문** (`overflow-y-hidden py-7`)
- `MonthPicker` (`px-7`)
- 일지 카드(`px-6 py-7 gap-0`) 반복 → `{pathname}/{log.id}` 로 이동
  - 헤더(TITLE_3): `{lessonDt} {lessonTime}` (사이에 공백 1)
  - 본문: `ImageSlide images={log.files}` (확대 모드 꺼짐) + 내용 2줄 클램프(BODY_3 black)
  - 푸터: `IconChat` + `댓글 {commentTotalCount}` (BODY_4_MEDIUM gray-500)
- 빈 상태(`contents.length === 0`): `IconCalendarX 42×42` + `수업일지 내역이 없습니다.` (HEADING_4_SEMIBOLD gray-400)
- **로딩 분기 없음** — `contents`가 `undefined`인 동안 아무것도 안 그린다

#### 상호작용 요청
없음(뮤테이션 0). 월 변경 시 ①만 재요청(②는 `searchDate`를 안 받으므로 그대로).

---

### S9 — `.../[memberId]/log/write` · {name}님 수업일지 작성

구현: `page/feedback/ui/TrainerCreateLogPage.tsx`(310줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/lessonhistory/unwritten?studentId={memberId}[&lessonDate={YYYY-MM-DD}]` | `authApi` | `useLessonListQuery` (`:47`) | 없음 | 화면 본체 |

쿼리스트링은 `URLSearchParams`로 조립되므로 `lessonDate`가 없으면 키 자체가 빠진다(`queries.ts:18-26`).
쿼리스트링 3개를 읽는다: `name`, `lessonDate`, `scheduleId` (`:44-46`).

#### 구조 — **두 개의 화면 모드**

**모드 A: 수업 선택 모드** (`selectLessonMode === true`, `:104-151`)
- 헤더: `IconBack`(→ 모드 해제) / `작성할 수업 선택`
- 본문(`flex-col gap-5 px-7 py-6`): 미작성 수업 카드 반복
  - `{lessonDt}`(TITLE_3 gray-600)
  - `{lessonTime}`(TITLE_1_BOLD) + 상태 뱃지: `출석`(`bg-blue-50 text-primary-500 px-4 py-1 rounded-sm`) 또는 `미출석`(`bg-gray-100 text-gray-700`)

**모드 B: 작성 모드** (기본)
- 헤더: 좌 `IconClose 20×20`(AlertDialog 트리거) / 가운데 `{name}님 수업일지 작성`(HEADING_4) / 우 더미 `w-[40px]`
- **AlertDialog — 작성 중단** (`py-8`)
  - 제목 `수업일지 작성을 그만둘까요?` (HEADING_4_BOLD)
  - 설명 `작성된 내용은 저장되지 않아요.` (BODY_1 gray-600)
  - 버튼 2개(둘 다 `AlertDialogCancel`): `확인`(`bg-blue-50 text-primary-500`, `onClick={router.back}`) / `취소`(`bg-primary-500 text-white`)
    - **문구·색이 뒤집혀 있다: 파란 배경(강조)이 "취소"** → BUG-16
- 본문(`p-7`)
  1. `작성할 수업`(TITLE_3) + 우측 `변경하기`(ghost, gray-500) — `selectedLesson !== null`일 때만 렌더
  2. 선택된 수업 박스(`h-[85px] rounded-lg border border-gray-200 p-6`)
     - `selectedLesson === null` → 가운데 `수업일지가 모두 작성 완료되었습니다.` (HEADING_5 gray-500)
     - 있으면 → `{lessonDt}`(TITLE_3 gray-600) / `{lessonTime}`(TITLE_1_BOLD) + `출석`/`미출석` 뱃지
  3. 이미지 영역(`mt-10 flex gap-3`)
     - 업로드 버튼: `h-[60px] w-[60px] rounded-sm border border-gray-200` 안에 `IconCamera` + `{images.length} / 3` (BODY_4_MEDIUM gray-500)
     - 업로드된 이미지 썸네일 60×60 + 우상단 `IconCloseBlack 20×20` 제거 버튼
  4. `내용`(TITLE_3) + `Textarea`(`h-[200px] resize-none rounded-lg border border-gray-200 p-6`, BODY_2, placeholder `수업 일지 내용을 작성해 주세요.`)
- 하단(`Layout.BottomArea`, `p-7`): `작성 완료` (`size='full'`, TITLE_1_BOLD). `!content || !selectedLesson`이면 disabled

#### 상호작용 요청

| 트리거 | 순서 | 메서드·경로 | 인스턴스 |
|---|---|---|---|
| 파일 선택 | 1 | `POST /api/v1/file` body `{fileNames: string[]}` | `authApi` |
| 파일 선택 | 2 | `PUT {presignedUrl}` body: 파일 바이너리 | **맨 `axios`** (`entity/image/api/mutations.ts:36`) |
| `작성 완료` | — | `POST /api/v1/lessonhistory` body `{title:'무제', content, studentId, scheduleId, uploadFiles: ImageType[]}` | `authApi` |

성공 시 `router.push('/trainer/manage/{memberId}/log')`.
`useImages`(`entity/image/hook/useImages.ts`)는 파일 개수 초과 시 **`alert()`** 를 띄운다(`:30`) — 토스트가 아니다. 문구: `이미지는 최대 {N}개까지 업로드할 수 있습니다.`

---

### S10 — `.../[memberId]/log/[logId]` · 수업일지 상세

구현: `page/feedback/ui/TrainerLogDetailPage/index.tsx`(75줄) + `Header.tsx`(107줄) + `feature/log-class/ui/TrainerCommentList.tsx` + `TrainerCommentInput.tsx`

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/lessonhistory/{logId}` | `authApi` | `useLogDetailQuery` (`feature/log-class/api/queries.ts:41`) | 없음 | 화면 본체 (`:32`) |

**댓글은 별도 요청이 없다** — 상세 응답의 `comments` 배열을 그대로 쓴다(`index.tsx:61`). S17·S19와 다른 점.

#### 구조

**헤더** (`Header.tsx`) — **제목 텍스트가 없다.** 좌측 `IconBack`, 우측 `IconDotsVertical` 케밥만.
- 드롭다운(`w-[120px]`, `absolute -right-5 top-0`)
  - `IconEdit` + `수정` → `router.replace('/trainer/manage/{memberId}/log/{logId}/edit')`
  - `IconTrash` + `삭제` (`text-point`) → AlertDialog
- **AlertDialog — 삭제 확인**
  - 제목 `게시글을 삭제하시겠습니까?` (TITLE_1_SEMIBOLD, 가운데)
  - 버튼(2열 grid, 각 `h-[48px]`): `취소`(gray-100/gray-600) / `삭제`(bg-point/white)

**본문** (`hide-scrollbar px-7 py-6`) — `Card` 하나(`gap-0 px-0 pb-0 pt-7`)
- 헤더(`px-6`, TITLE_3): `{lessonDt} {lessonTime}`
- 내용(`mt-4 px-6`): `ImageSlide images={data.files} enlargeMode` + 본문(BODY_3)
- 푸터: `IconChat` + `댓글 {commentTotalCount}` / 그 아래 `TrainerCommentList comments={data.comments}`

**댓글 트리** (`TrainerCommentList.tsx`)
- 재귀 렌더. 대댓글은 `ml-[47px]` 들여쓰기(`:79`)
- 각 항목(`px-6 py-4`): 프로필(32×32 원형 또는 `IconProfileDefault 24×24`) / 이름(HEADING_5) / 내용(BODY_3, `delYn`이면 gray-500) / 첨부 이미지 90×90 / `답글달기` 버튼(depth 0이고 `delYn` 아닐 때만, BODY_4_REGULAR gray-500)
- 내 댓글(`comment.member.memberId === 내 memberId`)이면 우측 `IconDotsVertical` 케밥 → `댓글 수정` / `댓글 삭제` (`w-[120px]`)
- 활성(케밥 열림 또는 수정/답글 대상)이면 행 배경 `bg-blue-10`(`#f4faff`)

**댓글 입력** (`TrainerCommentInput.tsx`, `Layout.BottomArea className='p-0'`)
- 상단 상태바(조건부): `{이름}님에게 답글 남기는 중` 또는 `댓글 수정 중` + 점 구분(`h-[2px] w-[2px]`) + `취소`
- 첨부 이미지 미리보기 80×80 + `IconCloseCircle`
- 좌측 `IconPicture`(파일 선택), 가운데 textarea(placeholder `댓글을 입력하세요.`, `h-8`=24px), 텍스트가 있을 때만 우측 `IconArrowTop` 전송 버튼

#### 상호작용 요청

| 트리거 | 메서드·경로 | 인스턴스 |
|---|---|---|
| 케밥 `삭제` → `삭제` | `DELETE /api/v1/lessonhistory/{logId}` | authApi |
| 신규 댓글 전송 | `POST /api/v1/lessonhistory/{logId}/comment` body `{content, uploadFiles}` | authApi |
| 대댓글 전송 | `POST /api/v1/lessonhistory/{logId}/comment/{commentId}` body `{content, uploadFiles}` | authApi |
| 댓글 수정 전송 | `PATCH /api/v1/lessonhistory/comment/{commentId}` body `{content, uploadFiles}` | authApi |
| 댓글 케밥 `댓글 삭제` | `DELETE /api/v1/lessonhistory/comment/{id}` | authApi (**확인 다이얼로그 없음**) |
| 사진 선택 | `POST /api/v1/file` → `PUT {presignedUrl}` | authApi → **맨 axios** |

일지 삭제 성공: `refetchQueries(['studentLogList', memberId])` — **이 키를 쓰는 쿼리가 없다**(S8은 `['trainerLogList', ...]`) → BUG-7. 이후 `router.replace('/trainer/manage/{memberId}/log')`.
댓글 성공 후: `refetchQueries(['logDetail', logId])`(`hooks/useTrainerComment.ts:45-49`).

---

### S11 — `.../[memberId]/log/[logId]/edit` · 수업 일지 수정

구현: `page/feedback/ui/TrainerEditLogPage.tsx`(217줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | 주체 |
|---|---|---|---|---|
| 1 | `GET /api/v1/lessonhistory/{logId}` | `authApi` | `useLogDetailQuery` (`:41`) | 화면 본체 |

`useEffect`(`:73-78`)가 응답 도착 시 `setContent(data.content)` + `updateImages(data.files)`로 폼을 채운다.

**배럴(`app/.../log/[logId]/edit/page.tsx:9`)이 `memberId`를 안 넘긴다** — 이 화면은 `memberId`를 아예 모른다. 그래서 저장 후 `router.back()`으로만 돌아간다(`:63`).

#### 구조
S9의 모드 B와 거의 동일. 차이점만:
- 헤더 제목 `수업 일지 수정` (S9는 `{name}님 수업일지 작성`)
- AlertDialog 제목 `수업일지 수정을 그만둘까요?` / 설명 `변경된 내용은 저장되지 않아요.` (버튼은 동일하게 `확인`/`취소`, 같은 색 반전 문제)
- `작성할 수업` 박스에 **`변경하기` 버튼이 없다**. 수업 정보는 `data.lessonDt`/`data.lessonTime`/`data.attendanceStatus`에서 온다
  - `attendanceStatus === '출석'` 비교 — S9는 `reservationStatus`를 본다. 필드 이름이 다르다(`feature/log-class/model/types.ts:30` vs `:55`)
- 이미지 영역 간격이 `gap-2`(6px), S9는 `gap-3`(8px)
- 하단 버튼 `작성 완료` — **`className`에 `Typography.TITLE_1_BOLD`가 빠져 있다**(`:209`, S9는 `:302`에 있음) → 폰트 크기가 다르다 → BUG-17
- disabled 조건이 `!content`뿐(S9는 `!content || !selectedLesson`)

#### 상호작용 요청

| 트리거 | 메서드·경로 |
|---|---|
| 파일 선택 | `POST /api/v1/file` → `PUT {presignedUrl}`(맨 axios) |
| `작성 완료` | `PATCH /api/v1/lessonhistory/{logId}` body `{title:'무제', content, uploadFiles}` |

성공: `refetchQueries(['logDetail', logId])` → `router.back()`.

---

### S12 — `/trainer/manage/feedback` · 피드백 작성

구현: `page/feedback/ui/TrainerFeedbackPage/index.tsx`(115줄) + `LessonFeedbackList.tsx`(77줄) + `DietFeedbackList.tsx`(138줄)

#### 마운트 요청 — **1건**(기본 탭이 "수업"이라 식단 요청은 탭 전환 시 발사)

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/lessonhistory/unwritten?lessonDate={YYYY-MM-DD}` | `authApi` | `useLessonListQuery({lessonDate})` | 없음 | **하위 컴포넌트 `LessonFeedbackList`** (`:13`) |
| (탭 전환 시) | `GET /api/v1/trainers/diets?page=0&size=10&searchDate={YYYY-MM-DD}` | `authApi` | `useStudentFeedbackDietListQuery` — **`useInfiniteQuery`** (`entity/diet/api/queries.ts:85`) | 없음 | **하위 컴포넌트 `DietFeedbackList`** (`:39`) |

Radix `TabsContent`는 비활성일 때 언마운트되므로 `식단` 탭을 누르기 전까지 ②는 나가지 않는다 **(추론 — Radix Tabs 기본 동작 기준, `forceMount` 미사용 확인: `index.tsx:103-108`)**.
페이지 파라미터 `page`, `size` 10, `initialPageParam: 0`.
`searchDate`는 `YYYY-MM-DD`(일 단위)다 — 다른 화면의 `YYYY-MM`과 다르다.

#### 구조

**헤더**(`relative bg-white`): `IconBack` → `router.back()` / `피드백 작성` (HEADING_4_SEMIBOLD)

**주간 캘린더** (`calendar-shadow rounded-bl-lg rounded-br-lg bg-white`)
- `react-day-picker` `Calendar`(`shared/ui/calendar.tsx`) — `mode='single'`, `weekStartsOn={1}`(월요일 시작), `showOutsideDays`
- 해당 주(월~일)만 보이게 `modifiers.hidden`으로 나머지를 숨긴다(`:76-78`, `dayjs.isBetween`)
- 미래 날짜는 `var(--gray-400)`
- 캡션은 `dayjs(date).format('MMMM')` — **로케일 설정이 없어 영어 월 이름이 나온다**(`index.tsx:68`) → BUG-18
- 우상단(`absolute right-7 top-6 gap-8`): `IconArrowLeft stroke='#000'`(−7일) / `IconArrowRight`(+7일, 다음 주가 미래면 disabled + `stroke='var(--gray-400)'`)
- 날짜 클릭 시 `?date=YYYY-MM-DD` 쿼리스트링을 `router.replace`로 갱신(`shared/hooks/useQueryString.ts:14-18`). 미래 날짜는 무시(`:27`)
- 선택 셀 스타일은 `classNames.cell`로 `[&:has([aria-selected])]:bg-primary-500 ... rounded-full`

**탭** (`Tabs defaultValue='lesson'`) — `TabsList` 기본 스타일 사용(하단 보더 + 활성 시 `border-b-2 border-gray-800 text-black`)
- `수업` / `식단`

**수업 탭** (`LessonFeedbackList`)
- `data`가 `undefined`면 `loading.gif` 40×40
- `length === 0` → `IconAlertCircle` + `작성해야 할 피드백이 없습니다.` (TITLE_1_BOLD gray-700)
- 항목 카드(`Card`, `flex-row items-center justify-between`)
  - `reviewStatus === '작성'` → 카드 전체가 링크 `/trainer/manage/{studentId}/log/{lessonHistoryId}?scheduleId={scheduleId}`, 우측 `IconCheckCircle`
  - `미작성` → 카드는 링크 아님, 우측 버튼 `작성하기`(`variant='secondary' size='lg'`) → `/trainer/manage/{studentId}/log/write?scheduleId={scheduleId}`
  - 좌측: `{lessonTime}`(TITLE_3 gray-600) / `{studentName}`(TITLE_1_BOLD)
  - **`작성하기` 링크에 `name`·`lessonDate`를 안 넘긴다** → S9 제목이 `수업일지 작성`이 되고 `lessonDate` 필터도 안 걸린다 → BUG-19

**식단 탭** (`DietFeedbackList`)
- 빈 페이지 → `py-28` + `IconNotification 33×33 stroke='var(--gray-300)'` + `피드백을 작성할 식단이 없습니다.`
- 항목 카드(`mb-5 px-6 py-7`) → `/trainer/manage/{diet.member.id}/diet/{diet.dietId}?month={YYYY-MM}&name={회원명}`
  - 좌: 회원 이름(TITLE_1_BOLD, `w-[50px]`) + `feedbackChecked === false`이면 빨간 점(`absolute ml-[2px] h-1 w-1 rounded-full bg-point`)
  - 우: 아침·점심·저녁 썸네일 3칸(각 `h-[62px]`, `w-[calc(100%-70px)]` 안에서 균등). 단식이면 `단식`(BODY_4_MEDIUM gray-400), 없으면 빈 회색 박스
- 하단 무한스크롤 트리거 + `loading.gif` 20×20

#### 상호작용 요청
뮤테이션 없음. 날짜/주 변경 → `?date=` 갱신 → 두 쿼리의 `queryKey`가 바뀌어 재요청.

---

### S13 — `/trainer/manage/invite` · 회원 추가(직접 초대)

구현: `page/manage/ui/TrainerInvitePage.tsx`(203줄)

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | 주체 |
|---|---|---|---|---|
| 1 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` (`feature/mypage/api/queries.ts:8`) | 화면 본체 (`:29`) |

`gym.name`과 `name`을 카카오 공유 문구에 쓰려고 부른다(`:30-31`).

#### 구조
- 헤더(`flex-row-reverse`): 우측 `CloseIcon 20×20` → `router.back()` / 가운데 `회원 추가`(HEADING_4) / 좌측 더미 `w-[40px]`
- 본문(`px-7`)
  1. `회원님의 정보를 알려주세요.` (HEADING_3, `py-11`)
  2. `/images/letter_blue-heart.png` 110×110 (가운데, `py-11`)
  3. 폼(`flex justify-center gap-x-3`, TITLE_3) — 2열
     - `이름` + 입력(`rounded-md border border-gray-200 px-6 py-[11.5px]`, placeholder `실명 입력`). `required`, 에러 시 `border-point`
     - `수업 할 PT 횟수` + `type='number'` 입력 + 우측 `회`(BODY_3 gray-500). `required`, `max: 500`. 500 초과 입력 시 토스트 `수강권 횟수는 최대 500회까지 입력할 수 있습니다.` 후 값 강제 500
- 하단(`Layout.BottomArea`): `완료` (`size='full'`, TITLE_1_BOLD)
  - 검증 실패 시 토스트 `입력이 필요한 항목이 있습니다.`

**Dialog — 초대 링크** (`:176-200`) — `rounded-t-5 bottom-0 top-auto max-w-[440px] px-7 py-10`
- `회원님을 초대해주세요.` (HEADING_4_BOLD)
- `초대 링크로 가입하면 입력하신 정보로\n바로 가입할 수 있습니다.` (BODY_1 gray-600, 줄바꿈 포함)
- 버튼 2개: `링크 복사하기`(`variant='secondary'`) / `공유하기`(기본)
  - 복사 → 토스트 `초대 링크를 복사했어요.`
  - 공유 → `window.Kakao.Share.sendDefault`
    - `title: '초대장이 도착했어요!'`
    - `description: '{gymName} {trainerName} 트레이너님이 초대장을 보냈어요!'`
    - `imageUrl: '/images/invitation.png'`
    - 버튼 `초대장 확인하기`
- **`rounded-t-5`는 tailwind에 없는 클래스다**(borderRadius는 `sm/md/lg`만, `tailwind.config.js:94-98`) → 죽은 클래스 → BUG-20
- **치명: `invitationUrl`을 채우는 코드가 없다** → 이 다이얼로그는 절대 열리지 않는다 → BUG-2

#### 상호작용 요청

| 트리거 | 메서드·경로 | body | 성공 처리 |
|---|---|---|---|
| `완료` | `POST /api/v1/trainers/nonmember` | `{name, lessonCnt}` | **`router.back()`** (`:36`) — 응답의 `invitationLink`를 쓰지 않는다 |

---

### S14 — `/trainer/manage/append` · 가입된 회원 추가 목록

구현: `page/manage/ui/NotRegisteredStudentListPage.tsx`(108줄)

#### 마운트 요청 — 2건

| # | 메서드 · 경로 | 인스턴스 | 훅 | 주체 |
|---|---|---|---|---|
| 1 | `GET /api/v1/members/me` | `authApi` | `useMyInfoQuery` (`:26`) | 화면 본체 (헤더에 `gym.name` 표시용) |
| 2 | `GET /api/v1/trainers/unattached-members` | `authApi` | `useNotRegisteredStudentsQuery` (`feature/manage/api/queries.ts:9`) | 화면 본체 (`:29`) |

#### 구조
- 헤더: 좌 더미 `w-[40px]` / 가운데 `{myInfo.gym.name}`(HEADING_4_SEMIBOLD) / 우 `CloseIcon 20×20` → `/trainer/manage`
- 본문(`px-7 pb-6`)
  1. 검색바(`bg-gray-200 rounded-md px-6 py-4`, `py-6` 바깥) — `IconSearch` + placeholder `이름 검색`
  2. 빈/검색결과 없음 (`!isPending && 목록 0건`): `IconAlertCircle` + 문구
     - `data === null` → `등록된 회원이 없습니다.`
     - 그 외 → `검색 결과가 없습니다.`
     - 문구 스타일이 `text-6/[130%] font-bold text-gray-500` — **`text-6`은 fontSize가 아니라 spacing 키 6을 참조하려는 오타로 보인다** → BUG-21
  3. 회원 카드(`my-[4px] px-6 py-7 flex-row justify-between`)
     - 좌: 이름(TITLE_1_BOLD) / 이메일(BODY_4_REGULAR gray-400)
     - 우: 버튼 `추가` (`variant='secondary' px-11 py-2`) → `/trainer/manage/append/{id}?name={name}`

검색은 `student.name.includes(keyword.toLowerCase())` (`:17-18`) — 검색어만 소문자화하고 대상은 그대로라 한글엔 무해하지만 영문 이름에는 어긋난다 → BUG-22 (S1의 `StudentList.tsx:47-48`도 동일).

#### 상호작용 요청
없음.

---

### S15 — `/trainer/manage/append/[memberId]` · 회원 추가

구현: `page/manage/ui/TrainerAppendStudentPage.tsx`(129줄)

#### 마운트 요청 — **0건**

쿼리 훅이 하나도 없다. `name`은 쿼리스트링에서 읽고, `name` 또는 `memberId`가 없으면 `throw new Error()`(`:21-23`) → Next.js 에러 바운더리.

#### 구조
- 배경 `bg-white`
- 헤더: 좌 더미 `w-[40px]` / 가운데 `회원 추가` / 우 `CloseIcon 20×20` → `/trainer/manage/append`
- 본문(`px-7 py-12` = 20/48px)
  1. `{name}님의 수강 정보를\n알려주세요.` (HEADING_3, `whitespace-pre-wrap break-keep`, 줄바꿈 포함)
  2. 폼(`mt-[42px] flex justify-center gap-x-3`, TITLE_3) — 2열
     - `이름` + readonly 입력(`border-gray-200 px-6 py-[11.5px]`, TITLE_1_SEMIBOLD)
       - 클래스에 `read-only:text-`라는 **미완성 유틸리티**가 있다(`:94`) → BUG-23
     - `수업 할 PT 횟수` + 입력(`type='text' inputMode='numeric' pattern='[0-9]*'`, TITLE_1_SEMIBOLD) + 우측 `회`(BODY_1 gray-500)
       - 비숫자 제거 + 선행 0 제거(`:31`), 500 초과 시 토스트 `수강권 횟수는 최대 500회까지 입력할 수 있습니다.` 후 500으로 고정
- 하단(`Layout.BottomArea`): `추가하기` (`size='full'`, TITLE_1_BOLD). `lessonCnt`가 0이면 disabled

#### 상호작용 요청

| 트리거 | 메서드·경로 | body | 성공 처리 |
|---|---|---|---|
| `추가하기` | `POST /api/v1/trainers/members/{memberId}` | `{lessonCnt}` (`name`은 전송하지 않음, `feature/manage/api/mutations.ts:73-77`) | `refetchQueries(['notRegisteredStudents'])` → 토스트 `회원이 추가되었습니다.` → `router.replace('/trainer/manage/append')` |

---

### S16 — `.../[memberId]/diet` · {name}님 식단

구현: `page/feedback/ui/TrainerStudentDietListPage.tsx`(248줄)

#### 마운트 요청 — 2건

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/trainers/members/{memberId}` | `authApi` | `useStudentDetailQuery` ← `useStudentInfo` (`:54`) | 없음 | 화면 본체 |
| 2 | `GET /api/v1/members/{memberId}/diets?page=0&size=10&searchDate={YYYY-MM}` | `authApi` | `useTrainerStudentDietListQuery` — **`useInfiniteQuery`** (`entity/diet/api/queries.ts:118`) | 없음 | 화면 본체 (`:61`) |

페이지 파라미터 `page`, `size` 10(`ITEMS_PER_PAGE`, `:44`), `initialPageParam: 0`.
`useEffect` 3개: ① 쿼리스트링 `month` → state 동기화(`:89-93`) ② 무한스크롤(`:95-101`) ③ 언마운트 시 `removeQueries(['dietList'])`(`:103-107`) — **키가 틀렸다** → BUG-8.

#### 구조
- **`isPending`이면 `<div>로딩중...</div>` 만 렌더**(`:110`) — 레이아웃·헤더 없음 → BUG-13
- 헤더(`justify-start`): `IconBack` → `router.back()` / `{name ?? memberInfo.name}님 식단`
- 본문(`bg-gray-100`, `px-7 pb-[52px] pt-7`)
  - 좌측 정렬 `MonthPicker` — 변경 시 `router.push('/trainer/manage/{id}/diet?month={YYYY-MM}[&name={name}]')`
  - 식단 카드(`mb-5 px-6 py-7`) 반복 → 클릭 시 `/trainer/manage/{id}/diet/{dietId}?month={month}[&name={name}]`
    - 헤더: `MM월 DD일 (dd)` — 오늘이면 `오늘` (gray-600)
    - 본문: 아침·점심·저녁 3칸(각 `h-[88px]`) — 단식 / 사진(`w=400&q=90`) / 빈 회색 박스
    - 푸터: 하트(`liked`면 `IconLike stroke+fill='var(--point-color)'`, 아니면 `stroke='var(--gray-500)'`) + `{likeCnt ?? 0}` / `IconChat` + `댓글 {commentCnt ?? 0}`
  - 빈 페이지: `py-28` + `IconNotification 33×33 stroke='var(--gray-300)'` + `등록된 식단이 없습니다.`
  - 무한스크롤 트리거: `<div className='h-7 p-3 text-center'>loading...</div>` (raw 텍스트)

카드 헤더 클래스가 `{(Typography.TITLE_3, 'mb-4 text-left text-gray-600')}` — **콤마 연산자라 `TITLE_3`가 버려진다**(`:151`) → BUG-5.

#### 상호작용 요청
뮤테이션 없음.

---

### S17 — `.../[memberId]/diet/[dietId]` · 식단 상세

구현: `page/feedback/ui/TrainerStudentDietDetailPage.tsx`(270줄) + `feature/log-diet/ui/CommentList.tsx` + `CommentInput.tsx`

#### 마운트 요청 — 2건

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/diets/{dietId}` | `authApi` | `useStudentDietDetailQuery` (`entity/diet/api/queries.ts:59`) | 없음 | 화면 본체 (`:61`) |
| 2 | `GET /api/v1/diets/{dietId}/comments?page=0&size=20` | `authApi` | `useDietCommentListQuery` — **`useInfiniteQuery`** (`feature/log-diet/api/queries.ts:12`) | 없음 | 화면 본체 (`:62`) |

②의 `getNextPageParam`이 `lastPage.content ? allPages.length : undefined`(`queries.ts:23-25`) — `isLast`를 안 보고 `content` 존재만 본다 → 마지막 페이지에서도 `hasNextPage`가 true로 남을 수 있다 → BUG-12. (다만 이 화면은 무한스크롤 트리거를 안 달아서 실제로 더 불러오지는 않는다 — `commentData.pages[0].content`만 쓴다, `:252-255`.)

①은 응답에 `type`을 덧붙여 정규화한다(`queries.ts:66-71`): `breakfast.type='breakfast'` 등. **서버 응답에 `type`이 없거나 대문자라는 뜻** — Flutter 이관 시 주의.

#### 구조
- **`dietData && commentData` 둘 다 있을 때만 렌더**(`:100`) — 그전엔 빈 화면
- 헤더(`justify-start`): `IconBack` → `router.back()` / 제목 분기(`:107-111`)
  - `name` 쿼리스트링 있으면 → `{name}님 식단`
  - 없고 오늘이면 → `오늘 식단`
  - 그 외 → `{MM월} {DD일} 식단` (요일 부분을 잘라냄)
- 본문(`px-7 py-6`)
  - `name`이 있을 때만 `전체보기`(BODY_3 gray-600) → `/trainer/manage/{memberId}/diet?month={month}&name={name}`
  - `Card p-0`
    - 헤더(`mb-4 px-6 pt-7 text-left text-gray-600`): 오늘이면 `오늘`, 아니면 `MM월 DD일 (dd)` — 여기도 콤마 연산자로 TITLE_3 유실(`:129`) → BUG-5
    - 식사 3칸(`w-[calc((100%-12px)/3)]`, 각 `h-[88px]`)
      - 단식 → `IconCheck fill='var(--primary-500)' 17×17` + `단식`
      - 사진 → 누르면 전체화면 Dialog(`bg-black p-0`): 상단 `h-[56px] px-7 py-6`에 `IconWhiteClose stroke='white'`, 아래 `h-[calc(100%-56px)]`에 `w=1200&q=90` 이미지
      - 없음 → 빈 회색 박스
      - 각 칸 아래 라벨(BODY_4_MEDIUM gray-500): `아침` / `점심` / `저녁` (`dietText`, `:42-46`)
    - 좋아요/댓글 줄: 하트 버튼(토글) + `{likeCnt}` / `IconChat` + `댓글 {commentCnt}`
    - 구분선(`border-t border-gray-100`) 아래 `DietCommentList`
- 하단(`Layout.BottomArea className='p-0'`): `DietCommentInput`

**댓글 트리** (`feature/log-diet/ui/CommentList.tsx`) — S10과 거의 동일. 차이: **이미지 첨부가 없다**(식단 댓글은 텍스트만), 드롭다운 위치가 `absolute -top-11 right-4`(`:148`).
**댓글 입력** (`CommentInput.tsx`) — 사진 버튼 없음. 나머지 문구는 S10과 동일(`{이름}님에게 답글 남기는 중`, `댓글 수정 중`, `취소`, placeholder `댓글을 입력하세요.`).

#### 상호작용 요청

| 트리거 | 메서드·경로 | 후처리 |
|---|---|---|
| 하트(좋아요 안 됨) | `POST /api/v1/diets/{dietId}/like` | `refetchQueries(['studentDietDetail', dietId])` |
| 하트(좋아요 됨) | `DELETE /api/v1/diets/{dietId}/like` | `refetchQueries(['studentDietDetail'])` — **키 범위가 위와 다르다**(`:87`) → BUG-15 |
| 신규 댓글 | `POST /api/v1/diets/{dietId}/comments` body `{content}` | `refetchQueries(['dietCommentList', dietId])` |
| 대댓글 | `POST /api/v1/diets/{dietId}/comments` body `{content, parentCommentId}` | 동일 |
| 댓글 수정 | `PATCH /api/v1/diets/{dietId}/comments/{commentId}` body `{content}` | 동일 |
| 댓글 삭제 | `DELETE /api/v1/diets/{dietId}/comments/{commentId}` | 동일 (**확인 없음**) |

---

### S18 — `.../[memberId]/workout` · {name}님 운동기록

구현: `page/workout/ui/TrainerWorkoutPage.tsx`(89줄) + `feature/workout/ui/WorkoutPost.tsx` + `ExerciseInfo.tsx` + `NoWorkout.tsx`

#### 마운트 요청

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/members/{memberId}/workout-histories?page=0&size=20&searchDate={YYYY-MM}` | `authApi` | `useWorkoutQuery` — **`useInfiniteQuery`** (`feature/workout/api/queries.ts:86`) | 없음 | 화면 본체 (`:21`) |

페이지 파라미터 `page`, `size` 기본 20(`DEFAULT_WORKOUT_SIZE`, `queries.ts:17`), `initialPageParam: 0`.
제목의 회원 이름은 **이 응답의 `mainData.name`** 에서 온다(`:26`) — 별도 회원 조회를 하지 않는다.

#### 구조
- 헤더: `IconBack` → `router.back()` / `{name}님 운동기록` (name 없으면 `undefined` → 제목 미표시)
- 본문(`flex flex-col flex-wrap py-7`)
  - `MonthPicker` (`px-7`)
  - 운동기록 카드(`WorkoutPost`) 반복 → `/trainer/manage/{memberId}/workout/{workoutHistoryId}`
    - 헤더: `M월 D일 (ddd)`(TITLE_3) + 우측 `viewMySelf`면 `IconLock`, 아니면 `IconGroup`
    - 내용 2줄 클램프(BODY_3)
    - `ImageSlide images={files}` (캐러셀)
    - `ExercisePreview`(`feature/workout/ui/ExerciseInfo.tsx:12`)
      - 운동 1개: `bg-gray-100 rounded-md px-6 py-5` 안에 `{name}` ↔ `{weight}kg × {numberOfCycles}회` + `{setNum}세트`(primary-500)
      - 2개 이상: `{첫번째이름} 외 {n-1}개`
      - 0개: 아무것도 안 그림
    - 푸터: 하트(읽기 전용, liked면 point 색) + `{likeCnt}` / `IconChat` + `댓글 {commentCnt}`
  - 하단 무한스크롤 트리거 + `isFetchingNextPage`일 때만 `loading.gif` 20×20
  - **빈 상태 조건이 `data.pages[0].content === null`**(`:81`) — 빈 배열 `[]`이면 안 걸린다 → BUG-24. 문구: `IconAlertCircle 36×36` + `등록된 운동 기록이 없습니다.` (TITLE_1_BOLD gray-700)

#### 상호작용 요청
없음.

---

### S19 — `.../[memberId]/workout/[workoutHistoryId]` · 운동기록 상세

구현: `page/workout/ui/TrainerWorkoutDetailPage.tsx`(76줄) + `feature/workout/hook/useComment.ts` + `ui/CommentList.tsx` + `CommentInput.tsx` + `PostMetrics.tsx`

#### 마운트 요청 — 2건

| # | 메서드 · 경로 | 인스턴스 | 훅 | `enabled` | 주체 |
|---|---|---|---|---|---|
| 1 | `GET /api/v1/workout-histories/{workoutHistoryId}` | `authApi` | `useWorkoutDetailQuery` (`feature/workout/api/queries.ts:63`) | 없음 | 화면 본체 (`:32`) |
| 2 | `GET /api/v1/workout-histories/{workoutHistoryId}/comments?page=0&size=20` | `authApi` | `useWorkoutCommentQuery` — **`useInfiniteQuery`** (`queries.ts:41`) ← `useWorkoutComment`(`hook/useComment.ts:47`) | 없음 | 화면 본체가 부른 훅 (`:35`) |

페이지 파라미터 `page`, `size` 20.

#### 구조
- 헤더: **`IconBack` 하나뿐. 제목 없음.** `<Link href='/trainer/manage/{memberId}/workout'>`(뒤로가기가 아니라 고정 링크, `:43`)
- 본문(`hide-scrollbar px-7 py-6`) — `Card gap-0 px-0 pb-0 pt-7`
  - 헤더(`px-6`): `M월 D일 (ddd)`(TITLE_3) + `viewMySelf`면 `IconLock`, 아니면 `IconGroup`
  - 내용(BODY_3) + `ImageSlide images={files} enlargeMode` + `ExerciseDetail`(운동 전체 목록: `{name}` ↔ `{weight}kg × {numberOfCycles}회` + `{setNum}세트`)
  - `PostMetrics` — 하트 버튼(토글, 낙관적 업데이트 + 300ms 디바운스) + `{likeCnt}` / `IconChat` + `댓글` (**`commentCnt > 0`일 때만 숫자를 붙인다**, `PostMetrics.tsx:124`)
  - `WorkoutCommentsWrapper` — 댓글 0건이면 `null` 반환(`CommentList.tsx:26-28`), 빈 상태 문구 없음
- 댓글 입력(`WorkoutCommentInput`) — 자체적으로 `Layout.BottomArea className='p-0'`를 렌더한다(`CommentInput.tsx:16`). 사진 버튼 없음
- **파일 마지막 줄에 `WorkoutCommentsWrapper;` 라는 의미 없는 표현식**이 있다(`:76`) → BUG-25

#### 상호작용 요청

| 트리거 | 메서드·경로 | 비고 |
|---|---|---|
| 하트 | `POST` 또는 `DELETE /api/v1/workout-histories/{id}/like` | 300ms 디바운스 후 발사. 실패 시 로컬 상태 롤백 + 토스트 |
| 신규 댓글 | `POST /api/v1/workout-histories/{id}/comments` body `{content}` | |
| 대댓글 | `POST /api/v1/workout-histories/{id}/comments` body `{content, parentCommentId}` | |
| 댓글 수정 | `PATCH /api/v1/workout-histories/{id}/comments/{commentId}` body `{content}` | |
| 댓글 삭제 | `DELETE /api/v1/workout-histories/{id}/comments/{commentId}` | **확인 없음** |

댓글 성공 후 `refetch()`(②만 갱신). 좋아요는 `invalidateQueries(['workoutDetail', id])`.

---

## 4. 백엔드 계약 대조

백엔드 경로는 `backend/src/main/java/com/tobe/healthy/` 기준.

### 4.0 🔴 최우선 — 같은 도메인 DTO가 여럿이고 키 이름이 다르다

**직전 계열에서 앱을 죽였던 `GymResult{gymId}` vs `GymDto{id}` 문제가 이 계열에도 그대로 있다. 게다가 웹 TS 타입이 틀린 쪽을 선언하고 있다.**

| 개념 | 웹 TS 타입 | 실제로 받는 백엔드 DTO | 결과 |
|---|---|---|---|
| **Gym** | `Gym { gymId: number; name: string }`<br>`entity/gym/model/types.ts:1-4` | **`GymDto { Long id; String name }`**<br>`gym/presentation/dto/out/GymDto.java:5` | **`gym.gymId`는 항상 `undefined`.** 웹은 `.name`만 써서 살아남았다. `gymId`로 Flutter 모델을 만들면 즉시 깨진다 |

- `GymResult { gymId, name }`(`gym/presentation/dto/out/GymResult.java:5`)는 **`GET /api/v1/gyms`(헬스장 목록)에서만** 쓰인다. 이 19개 화면은 전부 `GymDto`(=`id`)를 받는다.
- 이 19개 화면에서 `gym`이 실려 오는 곳: `GET /api/v1/members/me`(`MemberInfoResult.gym`), `GET /api/v1/trainers/members/{memberId}`(`MemberDetailResult.gym`).
- 웹에서 `gym`을 쓰는 곳은 **전부 `.name`뿐**: S2(`TrainerStudentDetailPage/index.tsx:140`), S13(`TrainerInvitePage.tsx:30`), S14(`NotRegisteredStudentListPage.tsx:43`).

**→ Flutter의 `Gym` 모델은 `id`로 만들어야 한다. `gymId`로 만들면 안 된다.**

같은 도메인이 여러 DTO로 갈라진 다른 사례:

| 개념 | DTO들 | 키 차이 |
|---|---|---|
| **Member** | `MemberDto`(`id`) / `MemberInfoResult`(`id`) / `MemberInTeamResult`(**`memberId`**) / `MemberDetailResult`(**`memberId`**) / `CommentMemberDto`(`memberId`) / `LessonHistoryCommentMemberResult`(`memberId`) | **이 계열 한 화면 흐름에서 4가지가 다 나온다** — `/trainers/members`→`memberId`, `/members/me`→`id`, `/trainers/members/{id}`→`memberId`, `/trainers/unattached-members`→`id` |
| **프로필 이미지** | `MemberInTeamResult.fileUrl`(평평한 String) / `MemberDetailResult.fileUrl`(평평) vs `MemberDto.profile.fileUrl`(중첩) / `MemberInfoResult.profile.fileUrl`(중첩) | 같은 화면군에서 평평/중첩이 섞인다 |
| **파일** | `WorkoutHistoryFileDto{id, workoutHistoryId, fileUrl, fileOrder}` / `DietFileDto{id, dietId, fileUrl, type}`(**`fileOrder` 없음**) / `LessonHistoryFileResults{fileUrl, fileOrder, createdAt}` / `CommandUploadFileResult{fileUrl, fileOrder}` | 4가지. `LessonHistoryFileResults`는 **같은 이름으로 두 파일에 중복 정의**돼 있고 `int` vs `Integer`로 타입도 다르다 |
| **댓글** | `DietCommentDto` / `WorkoutHistoryCommentDto`(둘은 필드 동일) / `LessonHistoryCommentCommandResult`(`files` 추가, `orderNum`이 `Integer`) / POST 응답 `CommandRegisterCommentResult`(**`lessonHistoryCommentId`**) / POST 답글 응답 `CommandRegisterReplyResult`(**`commentId`**) | 같은 수업일지 댓글 기능의 생성 응답 2개가 id 키 이름부터 다르다 |
| **예약 상태** | `MyReservation.reservationStatus` = **영어 enum명**(`"COMPLETED"`) vs `RetrieveUnwrittenLessonHistory.reservationStatus` = **한국어 문자열**(`"출석"`) | 필드 이름이 같은데 값 어휘가 반대다 |
| **날짜** | `MyReservation.lessonDt` = `LocalDate`(`"2024-05-28"`) vs `RetrieveUnwrittenLessonHistory.lessonDt` / `RetrieveLessonHistoryByDateCondResult.lessonDt` = **서버가 포맷한 한국어 String** | 같은 이름, 다른 타입 |

### 4.1 응답 봉투

**성공**: `ApiResult`(`common/ApiResult.java:8`, Lombok POJO)
```json
{ "status": "OK", "message": "...", "data": <T|null> }
```
`status`는 `HttpStatus` enum이라 항상 문자열 `"OK"`. **웹 `BaseResponse<T>`는 `{message, data}`만 선언한다**(`shared/api/types.ts:3-6`) — `status`를 무시할 뿐 문제는 없다.

**에러**: `ErrorResponse`(`common/error/ErrorResponse.java:12`) = `{message, code, timestamp}`. 웹 `BaseError`(`shared/api/types.ts:8-12`)와 필드 일치 ✓.

**페이징**: `CustomPaging<T>`(`common/CustomPaging.java:12`)

| 백엔드 | 타입 | 웹 `Pageable` (`shared/api/types.ts:14-20`) | 일치 |
|---|---|---|---|
| `content` | `List<T>` | 각 응답 타입에서 개별 선언 | ✓ |
| `pageNumber` | `int` | `pageNumber: number` | ✓ |
| `pageSize` | `int` | `pageSize: number` | ✓ |
| `totalPages` | `int` | `totalPages: number` | ✓ |
| `totalElements` | `Long` | `totalElements: number` | ✓ |
| `isLast` | `Boolean` + **`@JsonProperty("isLast")`**(`CustomPaging.java:19`) | `isLast: boolean` | ✓ |
| `mainData` | `T` | 각 응답 타입에서 개별 선언 | ✓ |

> **`isLast`가 `last`로 나가지 않는 것이 명시적으로 보장돼 있다** — `@JsonProperty("isLast")` + 체크인된 계약 테스트 `backend/src/test/java/com/tobe/healthy/ApiContractSerializationTest.java:33`이 `json.has("isLast")` && `!json.has("last")`를 단언한다.

**`mainData`는 `@JsonInclude`가 없어 값이 없어도 `"mainData": null`이 항상 나간다.**

### 4.2 날짜 직렬화

`spring.jackson.serialization.write-dates-as-timestamps`는 **어디에도 설정돼 있지 않다**(`backend/src/main/resources/application.yml`에 `spring.jackson` 블록 자체가 없음). `Jackson2ObjectMapperBuilder`/`@Bean ObjectMapper`/`JavaTimeModule` 수동 등록도 없다. **Spring Boot 자동설정이 `WRITE_DATES_AS_TIMESTAMPS`를 끄므로 ISO-8601 문자열로 나간다.**

- `LocalDate` → `"2024-05-28"`
- `LocalDateTime` → `"2024-05-28T10:15:30"`
- `LocalTime` → `"14:30:00"`

코드베이스 전체에 `@JsonFormat`·`@JsonNaming`은 **0건**이다.

### 4.3 엔드포인트별 대조

#### ① `GET /api/v1/trainers/members` (S1)
`TrainerController.java:106` · `@PreAuthorize("hasAuthority('ROLE_TRAINER')")`
응답: **`ApiResult<List<MemberInTeamResult>>`** — 페이징 봉투가 아니라 맨 배열.

| 백엔드 `MemberInTeamResult`<br>(`member/repository/dto/MemberInTeamResult.java:5`) | 웹 `RegisteredStudent`<br>(`feature/manage/model/types.ts:7-18`) | 판정 |
|---|---|---|
| `Long memberId` | `memberId: number` | ✓ |
| `String name` | `name: string` | ✓ |
| `String userId` | `userId: string` | ✓ |
| `String email` | `email: string` | ✓ |
| `int ranking` | `ranking: number` | ✓ |
| `int lessonCnt` | `lessonCnt: number` | ✓ |
| `int remainLessonCnt` | `remainLessonCnt: number` | ✓ |
| `String nickName` | `nickName: null` | ❌ **타입 거짓말 — 서버는 실제 별칭을 보낸다** (BUG-4) |
| `String fileUrl` | `fileUrl: string \| null` | ✓ |
| `Long courseId` | — | 웹이 선언 안 함(미사용) |
| **`boolean isNonmember`** | **`nonmember: boolean`** | ❌ **이름 불일치 → BUG-41 (치명)** |

> **BUG-41**: Java record 컴포넌트명이 `isNonmember`라 Jackson이 `"isNonmember"`로 내보낸다(`@JsonValue`/`@JsonProperty` 없음). 웹은 `item.nonmember`를 읽으므로 **항상 `undefined`** → `{!item.nonmember && <span>가입</span>}`(`feature/manage/ui/StudentList.tsx:199`)가 **모든 회원에게 항상 참** → **미가입 회원에게도 `가입` 뱃지가 붙는다.**

**파라미터**: `@PageableDefault(size = 100)` (`TrainerController.java:108`). 웹은 `page`/`size`를 보내지 않는다 → **회원이 100명을 넘으면 목록이 잘린다.**
**빈 목록**: 서비스가 `members.isEmpty() ? null : members`를 반환 → **`"data": null`**. 웹 타입 `RegisteredStudent[] | null` ✓ 정확.

#### ② `GET /api/v1/trainers/unattached-members` (S14)
`TrainerController.java:119` · 트레이너 전용 · 응답 **`ApiResult<List<MemberDto>>`**(맨 배열, 빈 경우 `null`)

| 백엔드 `MemberDto`(`member/presentation/dto/MemberDto.java:11`) | 웹 `Member`(`feature/manage/model/types.ts:25-49`) | 판정 |
|---|---|---|
| `Long id` | `id: number` | ✓ |
| `String userId` / `String email` / `String name` | 동일 | ✓ |
| — | `age`, `height`, `weight` | ❌ **팬텀 필드 — 서버가 안 보낸다** |
| `boolean delYn` | `delYn: boolean` | ✓ |
| `ProfileDto profile` (`{id, fileUrl}`) — **`MemberDto.from()`이 항상 `null`을 넣는다** | `profile: {id, fileName, originalName, extension, fileSize, fileUrl}` | ❌ **항상 null인데 non-null 6필드 객체로 선언** |
| `MemberType memberType` (`STUDENT`\|`TRAINER`) | 동일 | ✓ |
| `AlarmStatus pushAlarmStatus`, `feedbackAlarmStatus` | 동일 | ✓ |
| — | `scheduleNoticeStatus`, `communityAlarmStatus` | ❌ **`MemberDto`에 없다** (있는 건 `MemberInfoResult`) |
| `GymDto gym` — **`from()`이 항상 `null`** | `gym: Gym` (=`{gymId, name}`) | ❌ 이중 오류(§4.0 + 항상 null) |
| `SocialType socialType` | `socialType: SocialType` | ✓ |

S14는 `name`/`id`/`email`만 쓰므로 런타임 사고는 없다.
**파라미터**: 맨 `Pageable` → `size=20` 기본. 웹이 파라미터를 안 보내므로 **미배정 회원이 20명을 넘으면 잘린다.** → BUG-44

#### ③ `GET /api/v1/trainers/members/{memberId}` (S2·S4·S6·S7·S16)
`TrainerController.java:97` · 트레이너 전용 · 응답 `ApiResult<MemberDetailResult>`

| 백엔드 `MemberDetailResult`(`member/repository/dto/MemberDetailResult.java:13`) | 웹 `StudentDetail`(`feature/manage/model/types.ts:51-65`) | 판정 |
|---|---|---|
| `Long memberId` / `String name` / `String nickName` / `String fileUrl` / `String memo` / `int ranking` | 동일 | ✓ |
| **`LocalDate lessonDt`** → `"2024-05-28"` | `lessonDt: string \| null` | ✓ |
| **`LocalTime lessonStartTime`** → `"14:30:00"` | `lessonStartTime: string \| null` | ✓ |
| `DietDto diet` | `diet: HomeDietData` (non-null 선언) | ⚠️ §4.3⑧ 참조. 웹은 `memberInfo.diet.dietId`를 옵셔널 체이닝 없이 읽는다(`TrainerStudentDetailPage/index.tsx:339`) |
| `CourseDto course` | `course: CourseItem \| null` | ✓ |
| `PointDto point` | `point: StudentPointItem \| null` | ✓ |
| `RankDto rank` | `rank: StudentRank` | ✓ |
| `GymDto gym` (=`{id, name}`) | `gym: Gym` (=`{gymId, name}`) | ❌ **§4.0** |
| `boolean isNonmember` | — | 웹이 선언 안 함(미사용) |

중첩 DTO 대조:

| 백엔드 | 웹 | 판정 |
|---|---|---|
| `CourseDto {Long courseId, int totalLessonCnt, int remainLessonCnt, int completedLessonCnt, LocalDateTime createdAt}` | `CourseItem {courseId, totalLessonCnt, remainLessonCnt, completedLessonCnt, createdAt: string}` | ✓ 완전 일치 |
| `PointDto {String searchDate, int monthPoint, int totalPoint}` | `StudentPointItem {monthPoint, totalPoint, searchDate}` | ✓ (순서만 다름) |
| `RankDto {int ranking, int lastMonthRanking, int totalMemberCnt}` | `StudentRank {ranking, totalMemberCnt, lastMonthRanking}` | ✓ |
| `ProfileDto {Long id, String fileUrl}` | (해당 없음 — `fileUrl`이 평평하게 옴) | ✓ |

#### ④ `GET /api/v1/members/me` (S13·S14)
`MemberController.java:48` · **`@PreAuthorize` 없음**(인증만) · 응답 `ApiResult<MemberInfoResult>`

| 백엔드 `MemberInfoResult`(`member/presentation/dto/out/MemberInfoResult.java:10`) | 웹은 `Member` 타입을 재사용(`feature/mypage/api/queries.ts:9`) | 판정 |
|---|---|---|
| `Long id`, `String userId`, `String email`, `String name` | ✓ | ✓ |
| `ProfileDto profile` (`{id, fileUrl}`, **여기선 실제로 채워짐**) | `profile: {id, fileName, originalName, extension, fileSize, fileUrl}` | ❌ 4개 팬텀 필드 |
| `GymDto gym` | `gym: Gym`(`{gymId,...}`) | ❌ **§4.0** |
| `MemberType memberType` | ✓ | ✓ |
| `AlarmStatus pushAlarmStatus`, `communityAlarmStatus`, `feedbackAlarmStatus`, `scheduleNoticeStatus` | ✓ 4개 모두 선언 | ✓ |
| `SocialType socialType` | ✓ | ✓ |
| — | `age`, `height`, `weight`, `delYn` | ❌ 팬텀 |

#### ⑤ `GET /api/v1/members/{memberId}/course?searchDate=` (S3)
`MemberController.java:123` · 트레이너 전용 · 응답 `ApiResult<CustomPaging>` (**raw type**)
서비스에서 채우는 실제 내용(`course/application/CourseService.java:155,170`):
- `content: List<CourseHistoryDto>`
- `mainData: CourseGetResult {CourseDto course, String gymName}`

| 백엔드 `CourseHistoryDto`(`course/presentation/dto/CourseHistoryDto.java:9`) | 웹 `CourseHistoryItem`(`feature/manage/model/types.ts:84-90`) | 판정 |
|---|---|---|
| `Long courseHistoryId` | `courseHistoryId: number` | ✓ |
| `int cnt` | `cnt: number` | ✓ |
| `Calculation calculation` (`PLUS`\|`MINUS`) | `calculation: string` | ✓ (느슨) |
| `CourseHistoryType type` | `type: CourseHistory` = `keyof typeof courseHistoryTypes` | ✓ **6개 상수 전부 일치**: `COURSE_CREATE`, `PLUS_CNT`, `MINUS_CNT`, `ONE_LESSON`, `RESERVATION`, `RESERVATION_CANCEL` |
| `LocalDateTime createdAt` | `createdAt: string` | ✓ |

웹 `StudentCourse extends Pageable { mainData: {course: CourseItem; gymName: string}, content: CourseHistoryItem[] \| null }` — `mainData.course`를 non-null로 선언했지만 백엔드 `CourseGetResult.course`는 null일 수 있다. 웹 코드가 `mainData.course?.`로 방어하고 있어 사고는 없다.
**파라미터**: `searchDate`(평범한 메서드 파라미터 → 쿼리 파라미터, 기본값 없음), 맨 `Pageable` → `size=20`. 웹은 `page`/`size`/`searchDate` 전부 명시 전송 ✓

#### ⑥ `GET /api/v1/members/{memberId}/point?searchDate=` (S4)
`MemberController.java:140` · 트레이너 전용 · `ApiResult<CustomPaging>` raw
실제 내용(`point/application/PointService.java:111,122`): `content: List<PointHistoryDto>`, `mainData: PointDto`

| 백엔드 `PointHistoryDto`(`point/presentation/dto/PointHistoryDto.java:9`) | 웹 `pointHistoryType`(`feature/manage/model/types.ts:100-106`) | 판정 |
|---|---|---|
| `Long pointId` | `pointId: number` | ✓ |
| `PointType type` | `type: HistoryType` | ✓ **4개 전부 일치**: `NO_SHOW`, `NO_SHOW_CANCEL`, `WORKOUT`, `DIET` |
| `Calculation calculation` | `calculation: 'MINUS' \| 'PLUS'` | ✓ |
| `int point` | `point: number` | ✓ |
| `LocalDateTime createdAt` | `createdAt: string` | ✓ |

`mainData: PointDto {searchDate, monthPoint, totalPoint}` ↔ 웹 `StudentPointItem` ✓

#### ⑦ `GET /api/v1/trainers/reservation/new?memberId=` / `old?searchDate=&memberId=` (S5)
`TrainerController.java:151` / `:161` · 둘 다 트레이너 전용 · 응답 `ApiResult<MyReservationResponse>`

| 백엔드 `MyReservationResponse`(`schedule/presentation/dto/out/MyReservationResponse.java:9`) | 웹(`feature/schedule/model/type.ts:29-32`) | 판정 |
|---|---|---|
| `CourseDto course` | `course: CourseData` | ⚠️ 웹 `CourseData`에 **`completedLessonCnt`가 없다**(`type.ts:22-27`). 또 `/reservation/old`는 **`course`가 항상 `null`**(`findOldReservation`이 null을 넘김)인데 웹은 non-null 선언 |
| `List<MyReservation> reservations` | `reservations: ScheduleData[] \| null` | ✓ **빈 목록일 때 `null`** (`create()`가 빈 리스트를 null로 바꿈) — 웹 타입 정확 |

| 백엔드 `MyReservation`(`.../MyReservation.java:8`) | 웹 `ScheduleData`(`type.ts:13-20`) | 판정 |
|---|---|---|
| `Long scheduleId` | ✓ | ✓ |
| **`LocalDate lessonDt`** → `"2024-05-28"` | `lessonDt: string` | ✓ |
| **`LocalTime lessonStartTime` / `lessonEndTime`** → `"14:30:00"` | `string` | ✓ — `convertTo12HourFormat`이 `split(':')`하므로 초까지 있어도 동작 |
| `String trainerName` (**서버가 `" 트레이너"`를 덧붙임**) | `trainerName: string` | ✓ (S5에서 미사용) |
| `String reservationStatus` = **`ReservationStatus.name()` — 영어** | `reservationStatus: string` | ✓ 웹이 `=== 'COMPLETED'`로 비교 — **맞다** |

`ReservationStatus` 상수: `COMPLETED`, `AVAILABLE`, `NO_SHOW`, `SOLD_OUT`, `LUNCH_TIME`, `DISABLED`.
**파라미터 주의**: 컨트롤러가 `@RequestParam`이 아니라 **Spring Data의 `@Param`** 을 쓴다(`TrainerController.java:7` import). Spring MVC는 이걸 무시하므로 `-parameters` 컴파일 옵션에 의한 이름 바인딩에 의존한다. 웹이 `?memberId=`/`?searchDate=`로 보내므로 동작한다. `/reservation/new`는 `StudentScheduleCond`(`lessonDt`, `lessonStartDt`, `lessonEndDt`, `courseId`)도 모델 어트리뷰트로 바인딩하는데 웹은 안 보낸다 → 전부 null.

#### ⑧ 식단 — `GET /api/v1/members/{memberId}/diets` (S16) / `GET /api/v1/trainers/diets` (S12) / `GET /api/v1/diets/{dietId}` (S17)
`MemberController.java:94`(**`@PreAuthorize` 없음**) / `TrainerController.java:141`(트레이너 전용) / `DietController.java:75`(**없음**)
응답: 앞 둘은 `ApiResult<CustomPaging<DietDto>>`(`mainData: null`), 마지막은 `ApiResult<DietDto>`

| 백엔드 `DietDto`(`diet/presentation/dto/DietDto.java:12`) | 웹 `HomeDietData`(`entity/diet/model/types.ts:5-33`) | 판정 |
|---|---|---|
| `Long dietId` | `dietId: number` | ✓ |
| `MemberDto member` (**`from()`이라 `profile`·`gym`이 항상 null**) | `member: {...}` — `profile: null \| {id, fileUrl}`, `gym: null \| Gym` | ✓ nullable로 선언해 둠. 단 `age/height/weight`는 팬텀, `socialType`은 **`['NONE','KAKAO','NAVER','GOOGLE']` 배열 타입으로 잘못 선언**(`types.ts:21`) |
| `Long likeCnt` / `Long commentCnt` | `number` | ⚠️ Java `Long`이라 null 가능. S16은 `? :`로 방어(`:213,225`), **S17은 방어 없이 렌더**(`:233,242`) |
| `LocalDateTime createdAt` / `updatedAt` | `string` | ⚠️ **목록 응답(`@QueryProjection`)에서는 항상 `null`**, 상세에서만 채워짐 |
| **`LocalDate eatDate`** → `"2024-05-28"` | `eatDate: string` | ✓ |
| `boolean liked` / `boolean feedbackChecked` | `boolean` | ✓ `feedbackChecked`는 `/trainers/diets`에서만 실제로 계산되고 `/members/{id}/diets`에서는 항상 `false` |
| `DietDetailDto breakfast` / `lunch` / `dinner` | `DietWithFasting` | ❌ 아래 |

| 백엔드 `DietDetailDto`(`diet/presentation/dto/DietDetailDto.java:3`) | 웹 `DietWithFasting`(`entity/diet/model/types.ts:35-44`) | 판정 |
|---|---|---|
| `Boolean fast` | `fast: boolean` | ✓ |
| **(없음)** | **`type: MealType`** (`'breakfast'\|'lunch'\|'dinner'`) | ❌ **BUG-42** |
| `DietFileDto dietFile` (`{Long id, Long dietId, String fileUrl, DietType type}`) | `dietFile: null \| {id, dietId, fileUrl, type: string}` | ✓ — `DietType`은 대문자 `BREAKFAST`\|`LUNCH`\|`DINNER` |

> **BUG-42**: 백엔드 `DietDetailDto`에는 `type` 필드가 없다. 그래서 `useStudentDietDetailQuery`가 클라이언트에서 주입한다(`entity/diet/api/queries.ts:66-71`). **하지만 목록 쿼리(`useTrainerStudentDietListQuery`, `useStudentFeedbackDietListQuery`)는 주입하지 않는다** → S16·S12에서 `meal.type`은 `undefined`. 영향은 `alt={\`${meal.type} image\`}` → `"undefined image"` 뿐이라 시각적으로는 안 보인다. **Flutter에서는 `type`을 서버 응답에서 기대하면 안 된다 — 키 이름(breakfast/lunch/dinner)에서 직접 만들어야 한다.**

#### ⑨ 식단 댓글 — `GET/POST /api/v1/diets/{dietId}/comments`, `PATCH/DELETE .../{commentId}` (S17)
`DietCommentController.java:38/46/55/65` · **전부 `@PreAuthorize` 없음**

| 백엔드 `DietCommentDto`(`diet/presentation/dto/DietCommentDto.java:10`) | 웹 `ContentType`(`feature/log-diet/model/types.ts:18-32`) | 판정 |
|---|---|---|
| `Long id` | `id: number` | ✓ |
| `CommentMemberDto member` = `{Long memberId, String name, String fileUrl}` | `member: {memberId, name, fileUrl: string\|null}` | ✓ |
| `String content` | `content: string` | ✓ (삭제된 댓글은 서버가 `"삭제된 댓글입니다."`로 치환) |
| `LocalDateTime createdAt` / `updatedAt` | `string` | ✓ |
| `Long parentId` | `parentId: number \| null` | ✓ |
| `Long orderNum` | `orderNum: number` | ✓ |
| `boolean delYn` | `delYn: boolean` | ✓ |
| `List<DietCommentDto> replies` | `replies: ContentType[] \| null` | ✓ (답글 항목은 `null`) |

**완전 일치.** 단 **`POST /diets/{dietId}/comments`의 응답은 `ApiResult<Void>`** — 생성된 댓글을 안 돌려준다. 웹은 `BaseResponse<boolean>`으로 선언했지만 쓰지 않고 refetch한다 ✓

#### ⑩ 수업일지 — `GET /api/v1/lessonhistory/unwritten` (S8·S9·S12)
`LessonHistoryController.java:70` · **`@PreAuthorize` 없음** · 응답 `ApiResult<List<RetrieveUnwrittenLessonHistory>>` (**빈 경우 `[]`**, null 아님)

| 백엔드(`lessonhistory/presentation/dto/out/RetrieveUnwrittenLessonHistory.java:10`) | 웹 `UnwrittenLesson`(`feature/log-class/model/types.ts:49-58`) | 판정 |
|---|---|---|
| `Long scheduleId` / `Long studentId` / `String studentName` | 동일 | ✓ |
| **`String lessonDt`** (서버가 포맷한 문자열) | `lessonDt: string` | ✓ |
| **`String lessonTime`** | `lessonTime: string` | ✓ |
| `String reservationStatus` = **한국어** | `reservationStatus: string` | ⚠️ `"출석"`/`"미출석"` 외에 `"예약가능"`, `"대기마감"`, `"점심시간"`, `"예약불가"`도 올 수 있다(`RetrieveUnwrittenLessonHistory.java:37-44`). 웹은 `=== '출석'` 아니면 전부 `미출석`으로 표시 |
| `Long lessonHistoryId` | `lessonHistoryId: number \| null` | ✓ |
| `String reviewStatus` = `"작성"` \| `"미작성"` | `reviewStatus: '작성' \| '미작성'` | ✓ |

**파라미터**: `UnwrittenLessonHistorySearchCond` 레코드를 **애노테이션 없이** 받으므로 모델 어트리뷰트 바인딩 → 쿼리 파라미터 이름 = `lessonDate`, `studentId`, `writingStatus`(`WRITTEN`\|`UNWRITTEN`). 웹은 앞 두 개만 보낸다 ✓

#### ⑪ 수업일지 목록 — `GET /api/v1/lessonhistory/student/{studentId}?searchDate=` (S8)
`LessonHistoryController.java:57` · 트레이너 전용
응답: **`ApiResult<CustomRetrieveLessonHistoryByDateCondResult>`** = `{String studentName, List<...> content}` — **`CustomPaging`이 아니다. 페이징 필드가 아예 없다.**

> 웹은 `TrainerLogListResponse extends Pageable`로 선언한다(`feature/log-class/api/queries.ts:82-85`) → `pageNumber`/`pageSize`/`totalPages`/`totalElements`/`isLast` 5개가 전부 `undefined`. 쓰지 않아 무해하지만 타입 거짓말 → BUG-28 확정.

| 백엔드 `RetrieveLessonHistoryByDateCondResult`(`.../out/RetrieveLessonHistoryByDateCondResult.java:17`) | 웹 `Log`(`feature/log-class/model/types.ts:19-32`) | 판정 |
|---|---|---|
| `Long id` / `String title` / `String content` | 동일 | ✓ |
| `Integer commentTotalCount` | `commentTotalCount: number` | ✓ |
| `LocalDateTime createdAt` | `createdAt: string` | ✓ |
| `Long studentId` | — | 웹 미선언(미사용) |
| `String student` / `String trainer` (**`" 트레이너"` 덧붙음**) | `student: string` / `trainer: string` | ✓ (S8에서 미사용) |
| `String trainerProfile` | — | 웹 미선언 |
| `Long scheduleId` | `scheduleId: number` | ✓ |
| **`String lessonDt` / `String lessonTime`** (서버 포맷 한국어) | `string` | ✓ — 웹이 그대로 출력(`TrainerLogPage.tsx:106-108`) |
| `String attendanceStatus` = `"출석"`\|`"미출석"` | `attendanceStatus: '출석' \| '미출석'` | ✓ |
| `LessonHistoryReadStatus feedbackChecked` (`READ`\|`UNREAD`) | — | 웹 미선언 |
| `List<LessonHistoryFileResults> files` = `{fileUrl, int fileOrder, LocalDateTime createdAt}` | `files: ImageFile[]` = `{fileUrl, fileOrder}` | ✓ (`createdAt` 미사용) |

#### ⑫ 수업일지 상세 — `GET /api/v1/lessonhistory/{lessonHistoryId}` (S10·S11)
`LessonHistoryController.java:46` · **`@PreAuthorize` 없음**(학생도 자기 일지를 읽어야 함)

> ⚠️ **못 찾으면 404가 아니라 HTTP 200 + `"data": null`** 이다(`findOneLessonHistory`가 null 반환). 웹은 `{data && (...)}`로 가드하므로 **영원히 빈 화면**이 된다. S10·S11 둘 다 해당.

| 백엔드 `RetrieveLessonHistoryDetailResult`(`.../out/RetrieveLessonHistoryDetailResult.java:21`) | 웹 `LogDetail extends Log`(`feature/log-class/api/queries.ts:37-39`) | 판정 |
|---|---|---|
| `Long id, String title, String content` | ✓ | ✓ |
| `List<LessonHistoryCommentCommandResult> comments` | `comments: Comment[]` | ✓ |
| `Integer commentTotalCount`, `LocalDateTime createdAt` | ✓ | ✓ |
| `String student`, `String trainer`, `Long scheduleId` | ✓ | ✓ |
| `String lessonDt`, `String lessonTime`, `String attendanceStatus` | ✓ | ✓ S11이 `attendanceStatus === '출석'`으로 비교 — **맞다** |
| `List<LessonHistoryFileResults> files` (여기선 `Integer fileOrder`) | `files: ImageFile[]` | ✓ |
| **없음**: `studentId`, `trainerProfile`, `feedbackChecked` | 웹 `Log`에도 없음 | ✓ 우연히 일치 |

| 백엔드 `LessonHistoryCommentCommandResult`(같은 파일 `:108`) | 웹 `Comment`(`feature/log-class/model/types.ts:1-16`) | 판정 |
|---|---|---|
| `Long id`, `String content` | ✓ | ✓ |
| `LessonHistoryCommentMemberResult member` = `{memberId, name, fileUrl}` | `member: {memberId, name, fileUrl: string\|null}` | ✓ |
| `Integer orderNum` | `orderNum: number` | ✓ |
| `Long parentId` | `parentId: number \| null` | ✓ |
| `List<...> replies` | `replies: Comment[] \| null` | ✓ |
| `List<LessonHistoryFileResults> files` | `files: ImageFile[]` | ✓ |
| `Boolean delYn` | `delYn: boolean` | ✓ |
| `LocalDateTime createdAt` / `updatedAt` | `string` | ✓ |

**완전 일치.**

#### ⑬ 수업일지 뮤테이션 (S9·S10·S11)
`LessonHistoryCommandController.java`

| 엔드포인트 | 줄 | 권한 | 요청 body | 응답 | 웹 선언 | 판정 |
|---|---|---|---|---|---|---|
| `POST /api/v1/lessonhistory` | `:43` | 트레이너 | `CommandRegisterLessonHistory {title, content, studentId, scheduleId, uploadFiles: List<CommandUploadFileResult{fileUrl, fileOrder}>}` | `CommandRegisterLessonHistoryResult` | `BaseResponse<boolean>` | ⚠️ 응답 타입 거짓말(미사용) |
| `PATCH /api/v1/lessonhistory/{id}` | `:68` | 트레이너 | `CommandUpdateLessonHistory {title, content, uploadFiles}` | `CommandUpdateLessonHistoryResult {lessonHistoryId, title, content, files}` | `BaseResponse<boolean>` | ⚠️ 동일 |
| `DELETE /api/v1/lessonhistory/{id}` | `:82` | 트레이너 | — | **`ApiResult<Long>`** → `"data": 123` | `BaseResponse<boolean>` | ⚠️ 동일 |
| `POST /api/v1/lessonhistory/{id}/comment` | `:93` | **없음** | `CommandRegisterComment {content, uploadFiles}` | `CommandRegisterCommentResult {lessonHistoryId, **lessonHistoryCommentId**, writerId, writerName, content, files}` | `BaseResponse<boolean>` | ⚠️ |
| `POST /api/v1/lessonhistory/{id}/comment/{lessonHistoryCommentId}` | `:105` | **없음** | 동일 | `CommandRegisterReplyResult {lessonHistoryId, **commentId**, content, files, order, delYn, parentId}` | `BaseResponse<boolean>` | ⚠️ **위 응답과 id 키·필드가 다르다** |
| `PATCH /api/v1/lessonhistory/comment/{commentId}` | `:119` | **없음** | `CommandUpdateComment {content, uploadFiles}` | `CommandUpdateCommentResult` | `BaseResponse<boolean>` | ⚠️ |
| `DELETE /api/v1/lessonhistory/comment/{commentId}` | `:131` | **없음** | — | **`ApiResult<Long>`** | `BaseResponse<boolean>` | ⚠️ |

웹은 이 응답들을 전부 버리고 refetch하므로 런타임 사고는 없다. **Flutter도 응답을 파싱하지 말고 성공 여부만 보는 게 안전하다.**

#### ⑭ 운동기록 — `GET /api/v1/members/{memberId}/workout-histories` (S18) / `GET /api/v1/workout-histories/{id}` (S19)
`MemberController.java:71`(**`@PreAuthorize` 없음**) / `WorkoutHistoryController.java:58`(**없음**)
목록 응답: `ApiResult<CustomPaging>` raw — `content: List<WorkoutHistoryDto>`, **`mainData: MemberDto`**(`workout/application/WorkoutHistoryService.java:87`)

| 백엔드 `WorkoutHistoryDto`(`workout/presentation/dto/out/WorkoutHistoryDto.java:18`) | 웹 `Workout`/`WorkoutDetail`(`feature/workout/model/types.ts:5-39`) | 판정 |
|---|---|---|
| `Long workoutHistoryId`, `String content` | ✓ | ✓ |
| `MemberDto member` | `WorkoutDetail.member: WorkoutMember` (목록 타입 `Workout`엔 없음) | ⚠️ 목록에도 실려 오지만 웹이 선언 안 함(무해) |
| `boolean liked`, `Long likeCnt`, `Long commentCnt`, `boolean viewMySelf` | ✓ | ✓ (`Long`이라 null 가능) |
| `LocalDateTime createdAt` → `"2024-05-28T10:15:30"` | `createdAt: Date` | ⚠️ **TS 타입은 `Date`인데 실제로는 문자열이다.** `dayjs(createdAt)`에 그대로 넣어 동작(`WorkoutPost.tsx:25`) |
| **`@JsonIgnore List<MultipartFile> multipartFiles`** | — | ✓ 와이어에 안 나감 |
| `List<WorkoutHistoryFileDto> files` = `{id, workoutHistoryId, fileUrl, fileOrder}` | `files: ImageType[]` = `{fileUrl, fileOrder, createdAt?}` | ✓ (`id`/`workoutHistoryId` 미사용, `createdAt`은 안 옴) |
| `List<CompletedExerciseDto> completedExercises` = `{exerciseId, name, **names**, setNum, weight, numberOfCycles, workoutHistoryId}` | `Exercise[]` = `{exerciseId, name, setNum, weight, numberOfCycles, workoutHistoryId}` | ✓ `names`는 `from()`에서 항상 `null` — 웹이 `name`을 쓰는 게 맞다 |

`mainData: MemberDto` ↔ 웹 `WorkoutMember` — **`MemberDto.from()`이라 `profile`·`gym`이 항상 `null`인데 웹은 `profile: {id, fileUrl}`을 non-null로 선언**한다(`types.ts:26-29`). S18은 `mainData.name`만 쓰므로 무해.

#### ⑮ 운동기록 댓글 (S19)
`WorkoutCommentController.java:38/46/55/65` · **전부 `@PreAuthorize` 없음**
`WorkoutHistoryCommentDto`는 `DietCommentDto`와 필드 구성이 동일 → 웹 `WorkoutComment`(`feature/workout/model/types.ts:51-65`)와 ✓ 일치(`createdAt`/`updatedAt`만 TS에서 `Date`로 선언돼 있으나 실제는 문자열).
`POST .../comments` 응답은 **`ApiResult<Void>`**.

#### ⑯ 수강권 뮤테이션 (S3)
`CourseController.java` · 3개 전부 트레이너 전용, 전부 **`ApiResult<Void>`**

| 엔드포인트 | 줄 | 백엔드 요청 DTO | 웹이 보내는 body | 판정 |
|---|---|---|---|---|
| `POST /api/v1/course` | `:36` | `CourseAddCommand {Long memberId(@NotNull), int lessonCnt(@Positive)}` | `{memberId, lessonCnt}` | ✓ |
| `PATCH /api/v1/course/{courseId}` | `:54` | `CourseUpdateCommand {Long memberId(@NotNull), Calculation calculation(@NotNull), CourseHistoryType type(@NotNull), int updateCnt}` | `{memberId, calculation:'PLUS', type:'PLUS_CNT', updateCnt}` — **`updateCnt`를 문자열로 보낸다**(`StudentCourseDetailPage.tsx:115`의 `addInput`이 `string`) | ⚠️ Jackson이 `"5"` → `int 5`로 강제변환하므로 동작. **Flutter에서는 `int`로 보낼 것** |
| `DELETE /api/v1/course/{courseId}` | `:45` | — | — | ✓ |

#### ⑰ 회원 뮤테이션 (S2·S6·S7·S15·S13)

| 엔드포인트 | 위치 | 권한 | 요청 | 백엔드 응답 | 웹 선언 | 판정 |
|---|---|---|---|---|---|---|
| `PUT /api/v1/members/{memberId}/memo` | `MemberCommandController.java:101` | 트레이너 | `CommandUpdateMemo {memo}` | `ApiResult<Void>`, message `"메모가 수정되었습니다."` | `BaseResponse<null>` | ✓ (**웹은 서버 message 대신 자체 문구 `메모를 저장했습니다.`를 띄운다**) |
| `POST /api/v1/members/nickname/{studentId}` | `MemberCommandController.java:111` | 트레이너 | `CommandAssignNickname {nickname}`(`@NotEmpty`) | `ApiResult<CommandAssignNicknameResult {memberId, nickname}>` | `BaseResponse<boolean>` | ⚠️ 타입 거짓말(웹은 `data.message`만 사용) |
| `POST /api/v1/trainers/members/{memberId}` | `TrainerController.java:77` | 트레이너 | `MemberLessonCommand {int lessonCnt}`(`@Positive`) | **`ApiResult<TrainerMemberMappingDto {mappingId, trainer, member}>`** | **`BaseResponse<{uuid: string}>`** | ❌ **완전히 다른 타입.** 웹이 응답을 안 써서 살아남음 |
| `DELETE /api/v1/trainers/members/{memberId}` | `TrainerController.java:87` | 트레이너 | — | `ApiResult<Void>` | `BaseResponse<null>` | ✓ |
| `DELETE /api/v1/trainers/members/{memberId}/refund` | `TrainerController.java:171` | 트레이너 | — | `ApiResult<Void>` | `BaseResponse<null>` | ✓ (웹이 서버 message를 토스트) |
| `POST /api/v1/trainers/nonmember` | `TrainerController.java:68` | 트레이너 | `MemberInviteCommand {name(@NotEmpty), int lessonCnt(@Positive)}` | `ApiResult<MemberInviteResultCommand {uuid, invitationLink}>` | `BaseResponse<{uuid, invitationLink}>` | ✓ **타입은 맞는데 웹이 안 쓴다 → BUG-2** |

#### ⑱ 노쇼 토글 (S5) — ⚠️ 동사가 직관과 반대다

`TrainerScheduleCommandController.java` · 둘 다 트레이너 전용 · 응답 `ApiResult<ScheduleIdInfo>`

| 엔드포인트 | 줄 | 메서드명 | 실제 동작 | 서버 message |
|---|---|---|---|---|
| **`DELETE`** `/api/v1/schedule/no-show/{scheduleId}` | `:114` | `updateReservationStatusToNoShow` | **노쇼로 표시** | `"노쇼 처리되었습니다."` |
| **`POST`** `/api/v1/schedule/no-show/{scheduleId}` | `:129` | `revertReservationStatusToNoShow` | **노쇼 해제** | `"노쇼 처리가 취소되었습니다."` |

**웹은 이걸 올바르게 쓰고 있다**: `reservationStatus === 'COMPLETED'`(출석 상태)일 때 `DELETE`(노쇼 처리), 아니면 `POST`(노쇼 해제) — `feature/schedule/ui/TrainerStudentLastReservationSchedule.tsx:67-94`. **Flutter로 옮길 때 "DELETE=삭제"라고 짐작하면 반대로 동작한다.**
`ScheduleIdInfo {studentId, trainerId, scheduleId, scheduleTime}` — `from()`을 쓰므로 `scheduleTime`은 `null`. 웹은 `message`만 사용.

#### ⑲ 이미지 업로드 (S9·S10·S11)
`POST /api/v1/file` — 웹 `useCreateS3PresignedUrlMutation`(`entity/image/api/mutations.ts:13`)이 `{fileNames: string[]}`을 보내고 `PresignedUrlResponse[] {fileUrl, fileOrder}`를 받는다. **이 엔드포인트는 이번 백엔드 조사 대상 목록에 없어 컨트롤러를 확인하지 못했다 → §9 U12.**
이후 `PUT {fileUrl}`(맨 axios)로 S3 직업로드. 저장 시 `uploadFiles: [{fileUrl(쿼리스트링 제거), fileOrder}]`를 본문에 실어 보낸다 — 백엔드 `CommandUploadFileResult {fileUrl, fileOrder}`와 ✓ 일치.

### 4.4 enum 상수 (전부 이름 그대로 직렬화 — `@JsonValue` 0건)

| enum | 상수 | 웹 대응 |
|---|---|---|
| `CourseHistoryType` | `COURSE_CREATE`, `PLUS_CNT`, `MINUS_CNT`, `ONE_LESSON`, `RESERVATION`, `RESERVATION_CANCEL` | `feature/course/const.ts` ✓ 6개 모두 |
| `PointType` | `NO_SHOW`, `NO_SHOW_CANCEL`, `WORKOUT`, `DIET` | `feature/point/const.ts` ✓ 4개 모두 |
| `Calculation` | `PLUS`, `MINUS` | ✓ |
| `ReservationStatus` | `COMPLETED`, `AVAILABLE`, `NO_SHOW`, `SOLD_OUT`, `LUNCH_TIME`, `DISABLED` | `feature/schedule/model/type.ts:69-75` ✓ |
| `MemberType` | `STUDENT`, `TRAINER` | ✓ |
| **`AlarmStatus`** | `ENABLED`, **`DISABLE`** (`DISABLED`가 아니다) | 웹 `'ENABLED' \| 'DISABLE'` ✓ |
| `SocialType` | `NONE`, `KAKAO`, `NAVER`, `GOOGLE`, **`APPLE`** | 웹 `entity/auth`의 `SocialType` — `APPLE` 포함 여부 미확인(§9 U13) |
| `DietType` | `BREAKFAST`, `LUNCH`, `DINNER` | 웹은 `dietFile.type: string` (느슨) |
| `LessonHistoryReadStatus` | `READ`, `UNREAD` | 웹 미선언 |
| `WritingStatus` | `WRITTEN`, `UNWRITTEN` (요청 파라미터 전용) | 웹 미사용 |

**enum이 아니라 한국어 문자열인 것** — enum으로 모델링하면 안 된다:
- `RetrieveUnwrittenLessonHistory.reviewStatus` → `"작성"` / `"미작성"`
- `RetrieveUnwrittenLessonHistory.reservationStatus` → `"출석"` / `"미출석"` / `"예약가능"` / `"대기마감"` / `"점심시간"` / `"예약불가"`
- `RetrieveLessonHistoryByDateCondResult.attendanceStatus`, `RetrieveLessonHistoryDetailResult.attendanceStatus` → `"출석"` / `"미출석"`
- **반면 `MyReservation.reservationStatus`는 영어 enum명이다.** 이름이 같은데 어휘가 반대다.

### 4.5 권한 (`config/security/SecurityConfig.java:52-64` + 메서드 `@PreAuthorize`)

`permitAll`은 `/api/v1/auth/**`, `/actuator/**`, swagger, `/files/**` 등뿐이고 나머지는 `.anyRequest().authenticated()`. 역할 제한은 전부 메서드 애노테이션이다.

**트레이너 전용(`ROLE_TRAINER`)**: `/api/v1/trainers/**` 전부, `GET /members/{id}/course`, `GET /members/{id}/point`, `PUT /members/{id}/memo`, `POST /members/nickname/{id}`, `/api/v1/course` 3종, `POST|PATCH|DELETE /lessonhistory`·`/lessonhistory/{id}`, `GET /lessonhistory/student/{id}`, `POST|DELETE /schedule/no-show/{id}`

**인증만 하면 학생도 호출 가능** (이 19개 화면이 쓰는 것 중):
`GET /members/me`, `GET /members/{id}/diets`, `GET /members/{id}/workout-histories`, `GET /members/trainer-mapping`, `/api/v1/diets/**` 전부(상세·좋아요·댓글 4종), `/api/v1/workout-histories/**` 전부, `GET /lessonhistory/{id}`, `GET /lessonhistory/unwritten`, `/lessonhistory/{id}/comment` 계열 전부

> 소유권 검증은 서비스/리포지토리 레이어에서 `memberId`+`memberType`으로 거르는 방식이라 애노테이션만으로는 판단할 수 없다.

### 4.6 Flutter 모델링 시 nullable 주의 (백엔드 확인 결과)

1. **`[]`가 아니라 `null`이 온다**
   - `GET /trainers/members` → 회원 0명이면 `"data": null`
   - `GET /trainers/unattached-members` → 동일
   - `MyReservationResponse.reservations` → 빈 목록이면 `null` (S5의 두 요청 모두)
   - `DietCommentDto.replies` / `WorkoutHistoryCommentDto.replies` → 답글 항목·답글 없는 부모는 `null`
2. **`"mainData": null`이 항상 키로 존재** — `/diets`, 두 `/comments` 페이징 응답
3. **`GET /lessonhistory/{id}`는 못 찾아도 HTTP 200 + `data: null`** (404 아님)
4. `ApiResult<Void>` 응답은 `"data": null` — 좋아요/삭제/수강권 뮤테이션/메모/댓글 생성
5. `DELETE /lessonhistory/{id}`와 `DELETE /lessonhistory/comment/{id}`는 **`data`에 숫자가 그냥 들어온다** (객체 아님)
6. `MemberDto.profile` / `MemberDto.gym`은 이 계열의 모든 사용처(`/trainers/unattached-members`, `DietDto.member`, 운동기록 `mainData`)에서 **항상 `null`**
7. `DietDto.createdAt` / `updatedAt`은 **목록에서만 `null`**, 상세에서는 채워짐
8. `CourseGetResult.course`, `MyReservationResponse.course`(특히 `/reservation/old`는 항상)는 `null` 가능
9. `Long likeCnt` / `Long commentCnt`는 박싱 타입이라 `null` 가능

---

## 5. 웹 버그 목록

**이 프로젝트는 웹 버그를 고치지 않고 그대로 이관한다.** 아래는 "그대로 옮겨야 하는 동작"과 "옮기면 안 되는 사고"를 구분하기 위한 목록이다. 마지막 열에 이관 판단을 달았다.

| # | 내용 | 근거 | 이관? |
|---|---|---|---|
| **BUG-1** | **트레이너 화면인데 학생용 하단바를 쓴다.** S4가 `<Layout type='student'>` → 학생 네비(홈/수업예약/커뮤니티/마이)가 뜨고, 그 안의 `useCheckTrainerMemberMappingQuery`가 `GET /api/v1/members/trainer-mapping`을 **마운트 즉시** 쏜다. 트레이너 계정에선 의미 없는 요청 | `page/manage/ui/StudentPointDetailPage.tsx:67` / `widget/navigation.tsx:111` / `feature/schedule/api/queries.ts:18-28` | 화면 그대로면 재현. **단 이 요청 1건은 Flutter에서 반드시 재현할 것** — 직전 계열에서 누락된 유형 |
| **BUG-2** | **초대 링크 다이얼로그가 절대 안 열린다.** `invitationUrl` state에 값을 넣는 코드가 없다. `onSuccess`는 `router.back()`만 하고 응답의 `invitationLink`/`uuid`를 버린다. `dialogOpen = !!invitationUrl`이므로 항상 false | `page/manage/ui/TrainerInvitePage.tsx:25-26,34-37` / 응답 타입 `feature/manage/api/mutations.ts:105-108` | 그대로 이관하면 다이얼로그 코드가 통째로 죽은 코드가 된다. **이관 전 사용자 확인 필요** |
| **BUG-3** | **12월이 "2월"로 표시된다.** `searchDate.split('-')[1].split('')[1]` = `"12"`의 **두 번째 글자**만 취함. `09`→`9`는 맞지만 `10/11/12`→`0/1/2` | `page/manage/ui/TrainerStudentDetailPage/index.tsx:162`, `:300` / 동일 패턴 `page/manage/ui/StudentPointDetailPage.tsx:62-64` | 그대로 이관하면 12월에 오작동. **확인 필요** |
| **BUG-4** | **TS 타입과 런타임이 어긋난다.** `RegisteredStudent.nickName: null`(리터럴 타입)인데 UI는 `{item.nickName && ...}`로 렌더한다. 타입상 이 분기는 죽은 코드지만 서버는 실제 별칭을 보낼 수 있다 | 타입 `feature/manage/model/types.ts:10` / 사용 `feature/manage/ui/StudentList.tsx:205` | Flutter에선 `String?`로 받고 렌더한다(런타임 쪽이 옳다) |
| **BUG-5** | **콤마 연산자 때문에 Typography가 버려진다.** `className={(Typography.TITLE_3, 'mb-4 ...')}` → 앞 항목이 평가만 되고 버려져 TITLE_3(14px semibold)이 적용 안 된다. 실제로는 `Card`의 `CardHeader` 기본값 TITLE_1_BOLD(16px bold)가 남는다 **(추론 — 렌더 확인 필요)** | `page/feedback/ui/TrainerStudentDietListPage.tsx:151` / `page/feedback/ui/TrainerStudentDietDetailPage.tsx:129` | 렌더 결과(16px bold)를 이관 |
| **BUG-6** | **언마운트 정리가 엉뚱한 쿼리 키를 지운다.** S4가 `removeQueries(['myPointHistory'])`를 부르는데, 이 화면의 실제 키는 `['studentPointHistory', {searchDate}]`. 학생 본인 포인트 캐시만 날아가고 이 화면 캐시는 남는다 | `page/manage/ui/StudentPointDetailPage.tsx:58` vs `feature/point/api/queries.ts:40` | Flutter엔 해당 코드가 없으므로 무시 |
| **BUG-7** | **일지 삭제 후 존재하지 않는 키를 refetch한다.** `['studentLogList', memberId]` — S8이 쓰는 키는 `['trainerLogList', studentId, searchDate]` | `page/feedback/ui/TrainerLogDetailPage/Header.tsx:39` vs `feature/log-class/api/queries.ts:92` | 무시. Flutter에선 목록을 실제로 갱신할 것 |
| **BUG-8** | **식단 목록 언마운트 정리도 키가 틀렸다.** `removeQueries(['dietList'])` ← 학생 본인 식단 키. 이 화면 키는 `['trainerStudentdietList', {searchDate}]` | `page/feedback/ui/TrainerStudentDietListPage.tsx:105` vs `entity/diet/api/queries.ts:124` | 무시 |
| **BUG-9** | **`courseId`가 `NaN`이 될 수 있다.** `Number(historyData?.pages[0]?.mainData.course?.courseId)` — 수강권이 없으면 `NaN`. 그 상태에서 `수업 횟수 추가`/`수강권 삭제`를 누르면 `/api/v1/course/NaN` 으로 나간다. (수강권이 없을 땐 두 버튼이 렌더되지 않아 실제로는 도달하기 어렵다) | `page/manage/ui/StudentCourseDetailPage.tsx:84` | Flutter에선 nullable로 받고 버튼을 비활성화 |
| **BUG-10** | **메모를 빈 문자열로 저장할 수 없다.** `if (!newMemo) return;` 때문에 전부 지우고 `완료`를 눌러도 아무 일도 안 일어난다(토스트도 없다) | `page/manage/ui/StudentEditMemo.tsx:28-29` | 그대로 이관 가능(사용자 확인 권장) |
| **BUG-11** | **별칭 입력이 초기값을 놓친다.** `useState(memberInfo?.nickName ?? '')`는 첫 렌더 시점(응답 전)에 `''`로 굳는다. 게다가 `<Input defaultValue={newNickName}>`(비제어)이라 이후 state가 바뀌어도 DOM에 반영되지 않는다 → 기존 별칭이 입력창에 안 보인다 **(추론 — 렌더 확인 필요)** | `page/manage/ui/StudentEditNickname.tsx:38,152-153` | 웹 동작(빈 입력창)을 이관할지 확인 필요 |
| **BUG-12** | **댓글 무한스크롤 종료 조건이 `isLast`가 아니다.** `lastPage.content ? allPages.length : undefined` — `content`가 빈 배열이어도 truthy라 `hasNextPage`가 계속 true | `feature/log-diet/api/queries.ts:23-25` | Flutter에선 `isLast`를 쓴다 |
| **BUG-13** | **로딩/에러 분기가 스타일 없는 raw 텍스트다.** S4는 `<div className='loading'>Loading..</div>`(`loading` 클래스는 CSS에 정의돼 있지 않다), S16은 `<div>로딩중...</div>` — 레이아웃·헤더 없이 이것만 뜬다. **에러 분기는 19개 화면 전부에 없다**(`isError` 사용처 0건) | `page/manage/ui/StudentPointDetailPage.tsx:78` / `page/feedback/ui/TrainerStudentDietListPage.tsx:110` / `app/_styles/global.css` 전체에 `.loading` 없음 | Flutter에선 제대로 된 로딩·에러를 넣을 것 |
| **BUG-14** | **정의되지 않은 색 클래스.** `text-blue-100` — tailwind config의 `blue`는 `10`, `50`만 있다. 클래스가 생성되지 않아 색이 안 먹는다 | `page/manage/ui/StudentPointDetailPage.tsx:108` vs `tailwind.config.js:48-51` | 렌더 결과(상속색)를 이관 |
| **BUG-15** | **좋아요 취소만 invalidate 범위가 다르다.** 좋아요는 `['studentDietDetail', dietId]`, 취소는 `['studentDietDetail']`(전체) | `page/feedback/ui/TrainerStudentDietDetailPage.tsx:75` vs `:87` | 무시 |
| **BUG-16** | **작성 중단 다이얼로그의 버튼 문구/색이 뒤집혀 있다.** 파란 배경(`bg-blue-50 text-primary-500`) 쪽이 `확인`이고 실제로 나가기(`router.back()`)를 수행하며, 강조색(`bg-primary-500 text-white`) 쪽이 `취소`다. 둘 다 `AlertDialogCancel`이라 **어느 쪽을 눌러도 다이얼로그는 닫힌다** | `page/feedback/ui/TrainerCreateLogPage.tsx:170-186` / `page/feedback/ui/TrainerEditLogPage.tsx:99-115` | 문구·동작 그대로 이관(색 배치도 그대로) |
| **BUG-17** | **S11의 `작성 완료` 버튼만 폰트 지정이 빠졌다.** S9는 `TITLE_1_BOLD`, S11은 없음 → Button 기본 `text-sm font-medium`(14px) | `page/feedback/ui/TrainerEditLogPage.tsx:209` vs `page/feedback/ui/TrainerCreateLogPage.tsx:302` | 그대로 이관(차이를 재현) |
| **BUG-18** | **캘린더 캡션이 영어다.** `dayjs(date).format('MMMM')` — 이 파일엔 `dayjs/locale/ko` import가 없다. 단 SPA 내에서 다른 화면(예: `StudentPointDetailPage.tsx:3`)이 먼저 로드되면 전역 locale이 `ko`로 바뀌어 한국어가 될 수 있다 → **어떤 경로로 들어오냐에 따라 표시가 달라진다 (추론)** | `page/feedback/ui/TrainerFeedbackPage/index.tsx:68` / locale import 위치 `page/manage/ui/StudentPointDetailPage.tsx:3-6` | Flutter에선 한국어로 고정 권장(사용자 확인) |
| **BUG-19** | **`작성하기` 링크가 `name`·`lessonDate`를 안 넘긴다.** S12 → S9로 갈 때 `?scheduleId=`만 붙인다. 그 결과 S9 제목이 `수업일지 작성`(이름 없음)이 되고, `useLessonListQuery`에 `lessonDate` 필터가 안 걸려 **선택한 날짜와 무관한 미작성 수업 전체**를 받는다 | `page/feedback/ui/TrainerFeedbackPage/LessonFeedbackList.tsx:65` / S9의 파라미터 사용 `TrainerCreateLogPage.tsx:44-47` | 그대로 이관 |
| **BUG-20** | **존재하지 않는 border-radius 클래스.** `rounded-t-5` — config의 borderRadius는 `sm/md/lg`뿐 | `page/manage/ui/TrainerInvitePage.tsx:177` vs `tailwind.config.js:94-98` | 무시(어차피 BUG-2로 안 열림) |
| **BUG-21** | **`text-6/[130%]`.** `text-6`은 fontSize 스케일에 없는 키(spacing 키 6을 잘못 쓴 것으로 보인다) → 폰트 크기가 안 먹고 `font-bold text-gray-500`만 적용된다 **(추론)** | `page/manage/ui/NotRegisteredStudentListPage.tsx:74` | 렌더 결과를 이관 |
| **BUG-22** | **검색이 반쪽 대소문자 무시.** `student.name.includes(keyword.toLowerCase())` — 검색어만 소문자화하고 대상 이름은 안 한다. 영문 이름 `Kim`을 `kim`으로 검색하면 안 걸린다 | `page/manage/ui/NotRegisteredStudentListPage.tsx:17-18` / `feature/manage/ui/StudentList.tsx:47-48` | 그대로 이관 |
| **BUG-23** | **미완성 유틸리티 클래스 `read-only:text-`.** 값이 없어 CSS가 생성되지 않는다 | `page/manage/ui/TrainerAppendStudentPage.tsx:94` | 무시 |
| **BUG-24** | **빈 상태 조건이 `null`만 본다.** S18은 `data.pages[0].content === null`일 때만 `NoWorkout`을 그린다. 서버가 `[]`를 주면 빈 화면이 된다 | `page/workout/ui/TrainerWorkoutPage.tsx:81` | Flutter에선 `null || isEmpty` 둘 다 처리 권장(사용자 확인) |
| **BUG-25** | **죽은 표현식.** 파일 마지막 줄 `WorkoutCommentsWrapper;` — 아무 동작도 없는 statement | `page/workout/ui/TrainerWorkoutDetailPage.tsx:76` | 무시 |
| **BUG-26** | **`widht` 오타 prop.** `<IconArrowDown widht={14} height={14}/>` — `width`가 아니므로 SVG는 자기 기본 크기로 렌더된다 | `page/manage/ui/TrainerStudentDetailPage/index.tsx:172,191` | 렌더 결과(SVG 원본 크기)를 이관 |
| **BUG-27** | **이미지 다중 업로드 시 항목이 제곱으로 늘어난다.** `data.map(file => s3UploadMutate(..., {onSuccess: () => setImages(prev => [...prev, ...res])}))` — 파일 N개를 고르면 onSuccess가 N번 호출되고 매번 `res`(N개 전부)를 append → **N² 개**가 목록에 들어간다 | `entity/image/hook/useImages.ts:44-53` | **버그다. 재현하면 안 된다.** S9·S10·S11에 영향 |
| **BUG-28** | **응답에 있는데 안 쓰는 필드.** S8의 응답은 `Pageable`(`pageNumber/pageSize/totalPages/totalElements/isLast`)을 담지만 `useQuery`로 받아 페이지네이션을 하지 않는다. 또 `feature/log-class/model/types.ts`의 `Lesson` 인터페이스는 export만 되고 아무도 쓰지 않는다 | `feature/log-class/api/queries.ts:82-85` / `types.ts:39-47` | 무시 |
| **BUG-29** | **죽은 파일.** `feature/manage/model/studentDetailContext.ts`(37줄, `StudentDetailContext`/`useStudentDetail`/`useStudentDetailContext`)를 import하는 곳이 **0곳**이다. 화면들은 `page/manage/hooks/useStudentInfo.tsx`를 쓴다 | `feature/manage/model/studentDetailContext.ts` 전체 / grep 결과 자기 파일 외 참조 없음 | 이관 대상 아님 |
| **BUG-30** | **`useEffect` 의존성이 매 렌더 새 배열이다.** S9의 `useEffect(..., [unwrittenLessonList])` — `unwrittenLessonList`는 `data.filter(...)` 결과라 매 렌더 새 참조 → effect가 매 렌더 실행된다. `if (selectedLesson) return` 가드로 무한루프는 면한다 | `page/feedback/ui/TrainerCreateLogPage.tsx:48-50, 89-102` | Flutter에선 1회 초기화로 대체 |
| **BUG-31** | **`'use cilent'` 오타.** `PostMetrics.tsx` 첫 줄. 클라이언트 컴포넌트 지시자가 아니라 그냥 문자열. (부모가 client라 실제 문제는 없다) | `feature/workout/ui/PostMetrics.tsx:1` | 무시 |
| **BUG-32** | **`Card` 기본 클래스에 존재하지 않는 `h-35`.** Tailwind height 스케일에 35는 없고 커스텀 spacing도 1~12뿐 → CSS 미생성. 같은 줄 `w-40`(160px)은 유효하지만 거의 모든 사용처가 `w-full`로 덮는다 **(추론 — tailwind-merge가 `w-40`을 제거)** | `shared/ui/card.tsx:12` / `tailwind.config.js:80-93` | 무시 |
| **BUG-33** | **`gray-50`/`gray-900`/`--gray`가 CSS에 정의돼 있지 않다.** tailwind config는 `var(--gray-50)`, `var(--gray-900)`, `hsl(var(--gray))`를 참조하지만 `global.css`의 `:root`에는 `--gray-100`~`--gray-800`만 있다 | `tailwind.config.js:35-47` vs `app/_styles/global.css:43-50` | Flutter `AppColors`도 `gray900`이 없다 — 일치 |
| **BUG-34** | **`MonthPicker`가 `dayjs(year+month, 'YYYYM')`로 파싱한다.** `customParseFormat` 플러그인이 이 화면 경로 어디에서도 로드되지 않는다(로드하는 곳: StudentHomePage / ClassTimeSettingPage / TrainerScheduleSettingPage / feature/schedule/ui/ClassTimeSetting). 플러그인이 없으면 포맷 인자는 무시되고 dayjs 코어의 `REGEX_PARSE`가 `"20259"`를 해석한다. **결과가 같은지는 node_modules가 없어 실증하지 못했다** | `widget/month-picker.tsx:27` / plugin import 위치 grep 결과 | **§9 미확인 항목.** Flutter에선 `DateTime(year, month)`로 명시 생성 |
| **BUG-35** | **`MonthlyCalendar`의 초기 state가 갱신되지 않는다.** `useState(dayjs(date).format('YYYY'))` — 시트를 닫았다 다시 열어도 컴포넌트가 언마운트되지 않으면 이전 선택이 남는다 **(추론 — Radix Sheet의 unmount 동작 확인 필요)** | `widget/month-picker.tsx:23-24` | 확인 후 판단 |
| **BUG-36** | **댓글 삭제에 확인 절차가 없다.** S10/S17/S19 모두 드롭다운의 `댓글 삭제`를 누르면 즉시 DELETE가 나간다 | `feature/log-class/ui/TrainerCommentList.tsx:164-166` / `feature/log-diet/ui/CommentList.tsx:164-166` / `feature/workout/ui/CommentList.tsx:147-149` | 그대로 이관(캡처 시 위험) |
| **BUG-37** | **쿼리 키에 `memberId`가 빠져 회원 간 캐시가 섞인다.** `useStudentPointHistoryQuery` 키 `['studentPointHistory', {searchDate}]`, `useTrainerStudentDietListQuery` 키 `['trainerStudentdietList', {searchDate}]` — 둘 다 `memberId`가 없다. 회원 A→B로 이동하면 같은 달에 대해 A의 캐시가 먼저 보인다 | `feature/point/api/queries.ts:40` / `entity/diet/api/queries.ts:124` | Flutter엔 전역 쿼리 캐시가 없으므로 자연히 해소 |
| **BUG-38** | **`workoutList` 키를 3개 쿼리가 공유한다.** `useWorkoutQuery`(`{memberId, searchDate}`), `useWorkoutTypeListQuery`(`{searchValue, exerciseCategory}`), `useCommunityQuery`(`{memberId}`) — 전체 키는 다르지만 prefix invalidate 시 서로를 건드린다 | `feature/workout/api/queries.ts:92, 122, 165` | 무시 |
| **BUG-39** | **`auth()`의 빈 스토어 분기가 `gymId`를 안 돌려준다.** `{tokens:null, memberType:null, userId:null}` — `gymId`가 `undefined`라 `UserRoleMiddleware`의 `gymId === null` 리다이렉트가 안 걸린다 | `entity/auth/model/store.ts:57-59` vs `app/_providers/UserRoleMiddleware.tsx:35` | 무시 |
| **BUG-40** | **401 후 원 요청을 재시도하지 않는다.** refresh 성공해도 `Promise.reject(error)` → 화면은 실패 상태로 남는다 | `entity/auth/api/authApi.ts:41-51` | Flutter에는 401 refresh 자체가 미구현(`flutter/lib/core/network/auth_interceptor.dart:7`) |

### 5.1 백엔드 대조로 새로 드러난 버그 (BUG-41 ~ BUG-45)

| # | 내용 | 근거 | 이관? |
|---|---|---|---|
| **BUG-41** 🔴 | **회원 목록의 `가입` 뱃지가 항상 붙는다.** 백엔드 `MemberInTeamResult`의 필드는 **`isNonmember`**(Java record 컴포넌트명 그대로 직렬화)인데 웹 타입·코드는 **`nonmember`** 를 읽는다. `item.nonmember`는 언제나 `undefined` → `!undefined === true` → **미가입 회원에게도 파란 `가입` 뱃지가 붙는다** | 백엔드 `backend/.../member/repository/dto/MemberInTeamResult.java:5` vs 웹 타입 `feature/manage/model/types.ts:17`, 사용 `feature/manage/ui/StudentList.tsx:199` | **필드명 버그다. Flutter에선 `isNonmember`로 받고 뱃지 조건을 제대로 구현할지 사용자 확인 필요** |
| **BUG-42** | **식단 목록에서 `meal.type`이 `undefined`.** 백엔드 `DietDetailDto`에는 `type` 필드가 없다. `useStudentDietDetailQuery`만 클라이언트에서 `type`을 주입하고(`queries.ts:66-71`) 목록 쿼리 2개는 주입하지 않는다. 영향은 `alt="undefined image"` 뿐 | 백엔드 `backend/.../diet/presentation/dto/DietDetailDto.java:3` vs 웹 `entity/diet/model/types.ts:37`, 주입 위치 `entity/diet/api/queries.ts:66-71`, 사용 `TrainerStudentDietListPage.tsx:189` | Flutter에선 키 이름(breakfast/lunch/dinner)에서 직접 만든다 |
| **BUG-43** 🔴 | **`Gym` 타입이 틀린 DTO를 선언하고 있다.** 웹 `Gym { gymId, name }`인데 이 19개 화면이 받는 건 `GymDto { id, name }`. `gymId`는 항상 `undefined`. 웹은 `.name`만 써서 살아남았다 | 웹 `entity/gym/model/types.ts:1-4` vs 백엔드 `backend/.../gym/presentation/dto/out/GymDto.java:5`. `gymId`를 가진 `GymResult`(`.../GymResult.java:5`)는 `GET /api/v1/gyms` 전용 | **Flutter의 `Gym` 모델은 반드시 `id`로 만들 것.** 직전 계열에서 앱을 죽인 바로 그 패턴 |
| **BUG-44** | **목록 페이지 크기 기본값 때문에 잘린다.** 웹이 `page`/`size`를 안 보내므로 서버 기본값이 적용된다: `GET /trainers/members`는 `@PageableDefault(size=100)` → **회원 100명 초과 시 잘림**, `GET /trainers/unattached-members`는 맨 `Pageable` → **size=20, 미배정 회원 21명부터 안 보인다** | 백엔드 `backend/.../trainer/presentation/TrainerController.java:108`, `:121` / 웹 `feature/manage/api/queries.ts:13,27` (쿼리스트링 없음) | S14는 실사용에 지장이 있을 수 있다. **사용자 확인 필요** |
| **BUG-45** 🔴 | **이미지 업로드가 현재 백엔드와 계약이 다르다.** 웹은 presigned URL 방식(`POST /api/v1/file` JSON `{fileNames: string[]}` → `PUT {presignedUrl}`)인데, 현재 백엔드 `ComnFileController`는 **multipart 하나뿐**(`@RequestPart("files") List<MultipartFile>`)이고 로컬 스토리지에 저장한 뒤 `{baseUrl}/files/{path}`를 돌려준다. 백엔드에 `presigned` 문자열은 **0건**이고, `{fileNames}`를 받는 `CommandUploadFile` 레코드는 **어떤 컨트롤러도 참조하지 않는 유물**이다 | 웹 `entity/image/api/mutations.ts:13-40` vs 백엔드 `backend/.../file/presentation/ComnFileController.java:26-31`, `.../file/application/ComnFileService.java:23`, `.../LocalFileStorageService.java:76`, 미사용 DTO `.../file/presentation/dto/in/CommandUploadFile.java:5` | **웹 코드가 낡았다. 그대로 이관하면 S9·S10·S11의 업로드가 전부 실패한다.** Flutter는 multipart(`files` 파트명)로 구현해야 한다 |

> BUG-45의 방증: 웹 `shared/utils/file-url.ts:4`의 `FILES_PATH_PREFIX = '/files/'` 와 `normalizeDisplayFileUrl`은 **새 계약(로컬 `/files/` 서빙)에 맞춰 이미 갱신돼 있다.** 즉 조회 경로만 갱신되고 업로드 경로는 구 계약에 남았다. 참고로 `useUploadImageMutation`(`entity/image/api/mutations.ts:46`, multipart `POST /api/v1/lessonhistory/file`)은 정의만 있고 이 19개 화면에서 **호출되지 않는다.**

---

## 6. 스타일 실측

### 6.1 커스텀 스페이싱 환산표 — §0.4 참조

19개 화면에서 실제로 쓰인 스케일 값:

| 클래스 | px | 주 사용처 |
|---|---|---|
| `p-6` / `px-6` / `py-6` | 16 | 카드 내부, 검색바, 댓글 항목 |
| `p-7` / `px-7` / `py-7` | 20 | 화면 좌우 여백(거의 모든 화면), 헤더 |
| `py-8` / `px-8` | 24 | 내역 리스트 항목 세로, 바로가기 카드 좌우 |
| `py-5` / `px-5` | 12 | 운동 미리보기 박스, 탭 트리거 |
| `py-4` / `px-4` | 10 | 검색바 안쪽, 상태 뱃지 |
| `gap-x-3` / `gap-3` | 8 | 버튼 2개 사이 |
| `gap-4` | 10 | 탭 트리거 사이, 푸터 아이콘 |
| `gap-y-11` / `py-11` / `mb-11` | 36 | 별칭 화면 섹션 간격, 초대 화면 |
| `py-12` / `px-12` | 48 | S15 본문 상하 |
| `h-12` | 48 | 다이얼로그/시트 버튼 높이 |
| `h-11` | 36 | Button `size='default'`, 세로 구분선 |
| `h-10 w-10` | 32 | Button `size='icon'` |
| `h-7 w-7` | 20 | 검색 아이콘 버튼, 체크박스 |
| `h-8` | 24 | 댓글 textarea |
| `h-6 w-6` | 16 | S12 주 이동 화살표 버튼 |
| **`py-28`** | **112 (Tailwind 기본 7rem)** | **모든 "내역이 없습니다" 빈 상태** |
| `py-[88px]` | 88 (임의값) | S3 수강권 없음 블록 |

### 6.2 `[Npx]` 임의값 전체 목록

| 값 | 위치 (파일:줄) |
|---|---|
| `h-[2px]` | `feature/course/ui/CourseCard.tsx:90` (Progress) |
| `h-[2px] w-[2px]` | `feature/log-class/ui/TrainerCommentInput.tsx:83,104`; `feature/log-diet/ui/CommentInput.tsx:66,84` (댓글 상태바 점) |
| `space-x-[4px]` | `feature/log-class/ui/TrainerCommentInput.tsx:121` |
| `h-[80px] w-[80px]` | `feature/log-class/ui/TrainerCommentInput.tsx:127` (첨부 미리보기); `page/manage/ui/StudentEditNickname.tsx:121`; `page/manage/ui/TrainerStudentDetailPage/index.tsx:67` (프로필) |
| `py-[13px]` | `feature/log-class/ui/TrainerCommentInput.tsx:151`; `feature/log-diet/ui/CommentInput.tsx:96`; `feature/workout/ui/CommentInput.tsx:49`; `page/manage/ui/StudentEditNickname.tsx:133,151`; `page/feedback/ui/TrainerCreateLogPage.tsx:175,182`; `page/feedback/ui/TrainerEditLogPage.tsx:104,111`; `page/feedback/ui/TrainerLogPage.tsx:82` |
| `ml-[47px]` | `feature/log-class/ui/TrainerCommentList.tsx:79`; `feature/log-diet/ui/CommentList.tsx:88`; `feature/workout/ui/CommentList.tsx:78` (대댓글 들여쓰기) |
| `w-[120px]` | 위 3개 파일의 댓글 드롭다운 (`:148`, `:148`, `:131`); `page/feedback/ui/TrainerLogDetailPage/Header.tsx:61` |
| `w-[40px]` | `feature/manage/ui/AddStudentDialog.tsx:31`; `page/manage/ui/NotRegisteredStudentListPage.tsx:42`; `page/manage/ui/TrainerAppendStudentPage.tsx:65`; `page/manage/ui/TrainerInvitePage.tsx:93`; `page/feedback/ui/TrainerCreateLogPage.tsx:192`; `page/feedback/ui/TrainerEditLogPage.tsx:121` (헤더 균형 더미) |
| `h-[52px]` | `feature/manage/ui/CourseBottomSheet.tsx:40` (시트 버튼) |
| `w-[100px]`, `text-[40px]`, `leading-[130%]`, `py-[2px]` | `feature/manage/ui/CourseBottomSheet.tsx:104` (수강 횟수 입력) |
| `w-[calc(100%-20px)]` | `feature/manage/ui/CourseBottomSheet.tsx:122` |
| `w-[96px]` | `feature/manage/ui/StudentList.tsx:120` (정렬 드롭다운) |
| `mb-[30%]` | `feature/manage/ui/StudentList.tsx:139,160`; `page/manage/ui/NotRegisteredStudentListPage.tsx:70` |
| `w-[146px]` | `feature/manage/ui/StudentList.tsx:151` (회원 등록하기 버튼) |
| `h-[72px]` | `feature/manage/ui/StudentList.tsx:178` (회원 카드) |
| `py-[1.5px]`, `text-[10px]` | `feature/manage/ui/StudentList.tsx:200` (가입 뱃지) |
| `mr-[2px]` | `feature/manage/ui/StudentList.tsx:215` |
| `w-[35px]` | `feature/schedule/ui/TrainerStudentReservationSchedule.tsx:19`; `TrainerStudentLastReservationSchedule.tsx:38`; `page/manage/ui/StudentCourseDetailPage.tsx:345`; `page/manage/ui/StudentPointDetailPage.tsx:133`; `page/feedback/ui/TrainerStudentDietListPage.tsx:32`; `page/feedback/ui/TrainerFeedbackPage/DietFeedbackList.tsx:25` (빈 상태 아이콘 래퍼) |
| `w-[52px]`, `py-[2px]` | `feature/schedule/ui/TrainerStudentLastReservationSchedule.tsx:124` (출석 뱃지) |
| `h-[85px]` | `page/feedback/ui/TrainerCreateLogPage.tsx:208`; `TrainerEditLogPage.tsx:128` (수업 정보 박스) |
| `h-[60px] w-[60px]` | `page/feedback/ui/TrainerCreateLogPage.tsx:259,274`; `TrainerEditLogPage.tsx:169,184` (업로드 버튼·썸네일) |
| `h-[200px]` | `page/feedback/ui/TrainerCreateLogPage.tsx:290`; `TrainerEditLogPage.tsx:201` (내용 textarea) |
| `w-[50px]`, `ml-[2px]`, `w-[calc(100%-70px)]`, `h-[62px]` | `page/feedback/ui/TrainerFeedbackPage/DietFeedbackList.tsx:77,84,88,99/105/114` |
| `py-[3.5px]` | `page/feedback/ui/TrainerFeedbackPage/index.tsx:82` (주 이동 버튼 래퍼) |
| `h-[48px]` | `page/feedback/ui/TrainerLogDetailPage/Header.tsx:90,95`; `page/manage/ui/StudentCourseDetailPage.tsx:278,283` (알럿 버튼) |
| `w-[calc((100%-12px)/3)]` | `page/feedback/ui/TrainerStudentDietDetailPage.tsx:140` |
| `h-[88px]` | `page/feedback/ui/TrainerStudentDietDetailPage.tsx:147,164,201`; `TrainerStudentDietListPage.tsx:167,180,195`; `page/manage/ui/TrainerStudentDetailPage/index.tsx:359,372,381` (식사 썸네일) |
| `h-[56px]`, `h-[calc(100%-56px)]` | `page/feedback/ui/TrainerStudentDietDetailPage.tsx:179,184` (이미지 확대 다이얼로그) |
| `pb-[52px]` | `page/feedback/ui/TrainerStudentDietListPage.tsx:122` |
| `my-[4px]`, `gap-y-[4px]` | `page/manage/ui/NotRegisteredStudentListPage.tsx:87,88` |
| `h-[46px] w-[160px]` | `page/manage/ui/StudentCourseDetailPage.tsx:240,267` (액션 바 버튼) |
| `h-[30px] w-[1px]` | `page/manage/ui/StudentCourseDetailPage.tsx:262` (세로 구분선) |
| `py-[88px]` | `page/manage/ui/StudentCourseDetailPage.tsx:304` |
| `h-[37px] w-[112px]` | `page/manage/ui/StudentCourseDetailPage.tsx:313` (수강권 등록 pill) |
| `mt-[42px]`, `py-[11.5px]` | `page/manage/ui/TrainerAppendStudentPage.tsx:84,89,102`; `TrainerInvitePage.tsx:113,133` |
| `w-[130px]` | `page/manage/ui/TrainerStudentDetailPage/Header.tsx:91` (케밥 드롭다운); `index.tsx:199,245` (포인트/랭킹 카드) |
| `h-[11px] w-[1px]`, `w-[1px]` | `page/manage/ui/TrainerStudentDetailPage/index.tsx:85,105,114` |
| `ml-[3px]`, `ml-[2px]` | `page/manage/ui/TrainerStudentDetailPage/index.tsx:187,233,270,317` |
| `h-[127px]` | `page/manage/ui/TrainerStudentDetailPage/index.tsx:333` (수강권 없음 카드) |
| `py-[5px]` | `page/manage/ui/TrainerStudentReservationPage.tsx:62,72` (탭 pill) |
| `h-[500px]` | `page/manage/ui/TrainerStudentReservationPage.tsx:103` (로딩 박스) |
| `bottom-[56px]` | `widget/image-slide.tsx:72` |
| `h-[56px]` | `widget/layout.tsx:46` (헤더 높이) |
| `h-[72px]`, `h-[56px] w-[56px]` | `widget/month-picker.tsx:67,71` (월 셀 / 월 원형) |
| `py-[18px]` | `widget/navigation.tsx:28,130` (하단 네비) |
| `leading-[15px]` | `widget/navigation.tsx:150` |
| `w-[var(--max-width)]`, `max-w-[var(--max-width)]` | `widget/layout.tsx:31` 외 — 440px |

색 임의값: `text-[#8EC7FF]`(`CourseCard.tsx:79`), `bg-[#e2f1ff]`/`bg-[#E2F1FF]`(`TrainerStudentLastReservationSchedule.tsx:122,160`), `bg-[#E2F1FF]`(Button `variant='secondary'`, `shared/ui/button.tsx:15`), 랭킹 테두리 `#FFB950`/`#C4C5CD`/`#FFB58B`(`page/manage/utils.ts:3-5`).

### 6.3 SVG 아이콘 — 화면별 사용 목록

경로는 전부 `shared/assets/images/` 아래다. `IconXxx` 이름은 `shared/assets/index.ts`의 export 이름.

| 화면 | 아이콘 (파일명) |
|---|---|
| S1 | `back.svg`, `plus.svg`, `search.svg`, `alert_circle.svg`, `profile_default.svg`, `icon_arrow_down_up.svg`, `icon_close.svg`, `people_plus.svg`, `peoples.svg` |
| S2 | `back.svg`, `dots_vertical.svg`, `noCircleCheck.svg`, `arrow_down.svg`, `arrow_filled_down.svg`, `arrow_filled_up.svg`, `icon_arrow_right.svg`, `icon_calendar_blue.svg`, `check.svg`, `icon_default_profile.svg`, `icon_dumbel.svg`, `icon_edit.svg` |
| S3 | `back.svg`, `notification.svg`, `plus.svg`, `icon_arrow_left.svg`·`icon_arrow_right.svg`·`icon_triangle_down.svg` (MonthPicker) |
| S4 | `close.svg`, `notification.svg`, + MonthPicker 3종, + 학생 네비 8종(`home_filled/outlined`, `calendar_filled/outlined`, `community_filled/outlined`, `profile_filled/outlined`) |
| S5 | `back.svg`, `check.svg`, `no_schedule.svg`, + MonthPicker 3종 |
| S6 | `back.svg` |
| S7 | `icon_close.svg`, `icon_default_profile.svg` |
| S8 | `back.svg`, `calendar_x.svg`, `chat.svg`, `plus.svg`, + MonthPicker 3종, + `white_close.svg`(ImageSlide 확대) |
| S9 | `back.svg`, `icon_camera.svg`, `icon_close.svg`, `close_black.svg` |
| S10 | `back.svg`, `dots_vertical.svg`, `edit.svg`, `trash.svg`, `chat.svg`, `profile_default.svg`, `arrow_top.svg`, `picture.svg`, `icon_close_circle.svg`, `white_close.svg` |
| S11 | `icon_camera.svg`, `icon_close.svg`, `close_black.svg` |
| S12 | `back.svg`, `icon_arrow_left.svg`, `icon_arrow_right.svg`, `notification.svg`, `alert_circle.svg`, `check_circle.svg` |
| S13 | `icon_close.svg` (+ 이미지 `/images/letter_blue-heart.png`) |
| S14 | `icon_close.svg`, `alert_circle.svg`, `search.svg` |
| S15 | `icon_close.svg` |
| S16 | `back.svg`, `chat.svg`, `check.svg`, `like.svg`, `notification.svg`, + MonthPicker 3종 |
| S17 | `back.svg`, `chat.svg`, `check.svg`, `like.svg`, `white_close.svg`, `dots_vertical.svg`, `profile_default.svg`, `arrow_top.svg` |
| S18 | `back.svg`, `chat.svg`, `like.svg`, `lock.svg`, `group.svg`, `alert_circle.svg`, + MonthPicker 3종, + `white_close.svg` |
| S19 | `back.svg`, `chat.svg`, `like.svg`, `lock.svg`, `group.svg`, `dots_vertical.svg`, `profile_default.svg`, `arrow_top.svg`, `white_close.svg` |

PNG: `/images/point.png`(S2·S4), `/images/loading.gif`(S3·S4·S5·S12·S16·S18), `/images/letter_blue-heart.png`(S13), `/images/invitation.png`(S13 카카오 공유 이미지).

### 6.4 ⚠️ `="current"` 가 들어간 SVG — flutter_svg 주의

**① 도형이 통째로 안 그려지는 것 (`fill="current"` / `stroke="current"`)** — 반드시 실제 색 값이나 `currentColor`로 치환해야 한다.

| 파일 | 속성 | 위치 | 이 계열에서 쓰는 화면 |
|---|---|---|---|
| `arrow_filled_up.svg` | `fill="current"` | `<path>` 1개 | S2 |
| `arrow_filled_down.svg` | `fill="current"` | `<path>` 1개 | S2 |
| `arrow_top.svg` | `fill="current"` | `<path>` | S10, S17, S19 (댓글 전송) |
| `chat.svg` | `stroke="current"` | `<path>` (svg 루트엔 `stroke="#86888D"` 있음) | S8, S10, S16, S17, S18, S19 |
| `check.svg` | `fill="current"` + `stroke="current"` | 첫 `<path>` (두 번째는 `fill="white"`) | S2, S5, S16, S17 |
| `icon_arrow_left.svg` | `stroke="current"` | `<path>` (루트 `stroke="#1990FF"`) | S12, MonthPicker |
| `icon_arrow_right.svg` | `stroke="current"` | `<path>` (루트 `stroke="#5F6165"`) | S2, S12, MonthPicker |
| `icon_camera.svg` | `fill="current"` | 두 번째 `<path>`(렌즈 원). 첫 path는 `fill="#86888D"` | S9, S11 |
| `like.svg` | `fill="current"` + `stroke="current"` | `<path>` | S16, S17, S18, S19 |
| `notification.svg` | `stroke="current"` × 3 | `<path>` 3개 전부 | S3, S4, S12, S16 |
| `noCircleCheck.svg` | `fill="current"` | `<path>` | S2 (환불 삭제 체크박스) |
| `plus.svg` | `fill="current"` | **`<svg>` 루트**. `<path>`는 `fill="inherit"` → 루트를 상속하므로 결국 안 그려진다 | S1, S3, S8 |
| `trash.svg` | `stroke="current"` × 3 | `<path>` 3개 전부 (루트 `stroke='#FF4668'`) | S10 |
| `white_close.svg` | `stroke="current"` × 2 | `<path>` 2개 | S8, S10, S17, S18, S19 (ImageSlide 확대 닫기) |

> 웹에서는 React SVGR 컴포넌트에 `fill`/`stroke` prop을 넘겨 루트 속성을 덮어쓰므로(예: `<IconLike stroke='var(--point-color)' fill='var(--point-color)'/>`) 문제가 안 된다. **Flutter에서는 `flutter_svg`가 `"current"`를 색으로 파싱하지 못해 해당 도형이 사라진다.**

**② 무해한 것 (`width="current"` / `height="current"` — 루트 크기 지정용)** — `flutter_svg`가 무시하거나 viewBox로 대체한다.

`alert.svg`, `album.svg`, `avatar.svg`, `arrow_down.svg`, `camera_upload.svg`, `check.svg`, `close_black.svg`, `delete.svg`, `logo.svg`, `noCircleCheck.svg`, `notification.svg`, `plus.svg`, `profile_default.svg`

(`check.svg` / `noCircleCheck.svg` / `notification.svg` / `plus.svg`는 ①과 ② 둘 다 해당 — ①만 고치면 된다.)

---

## 7. 재사용 가능한 기존 위젯 / 새로 만들 위젯

Flutter 현황 근거: `flutter/lib/shared/ui/`, `flutter/lib/widget/`, `flutter/lib/core/theme/`, `flutter/lib/core/router/app_router.dart`.

### 7.1 이미 있는 공용 위젯 — 화면별 재사용표

| 화면 | AppLayout / AppLayoutHeader | AppTrainerBottomNavigation | AppCard(+Header/Content) | AppButton | AppTextInput / AppPlainInput | AppMonthPicker | AppProgress | AppCollapsible | 기타 |
|---|---|---|---|---|---|---|---|---|---|
| S1 | ○ (header: back+title+action) | **○ (`type='trainer'`)** | — (카드가 커스텀 `h-[72px]`) | ○ (회원 등록하기) | △ 검색 입력(라벨 없음, 높이 다름) | — | — | — | 새 Dropdown, 새 Dialog |
| S2 | ○ (backgroundColor 기본 gray-100) | — | ○ | ○ (알럿/시트 버튼) | — | — | ○ (수강권 진행바) | **○** (포인트 접이식) | `CourseCard` 재사용(`flutter/lib/feature/course/ui/course_card.dart:18`), 새 Dropdown/AlertDialog/BottomSheet/Checkbox |
| S3 | ○ | **○** | ○ | ○ | △ (시트의 40px 숫자 입력은 전용) | **○** | ○ | — | 새 BottomSheet, AlertDialog, InfiniteList |
| S4 | ○ | ✗ — **`AppBottomNavigation`(학생용)** 을 써야 웹과 동일 | ○ | — | — | **○** | — | — | 새 InfiniteList |
| S5 | ○ | — | ○ | ○ | — | **○** | — | — | 새 Tabs(pill 형), BottomSheet |
| S6 | ○ (`backgroundColor: white`) | — | — | ○(헤더 텍스트버튼은 `AppTextLink`가 더 맞다) | — | — | — | — | 새 Textarea |
| S7 | ○ (`backgroundColor: white`) | — | — | ○ | **○ `AppPlainInput`**(높이 52 ≒ `py-[13px]`+BODY_1) | — | — | — | 새 AlertDialog |
| S8 | ○ | — | ○ | — | — | **○** | — | — | 새 AlertDialog, Carousel(ImageSlide) |
| S9 | ○ (`bottomArea`) | — | ○ | ○ | — | — | — | — | 새 AlertDialog, Textarea, ImagePicker+업로더 |
| S10 | ○ (`bottomArea`) | — | ○ | ○ | — | — | — | — | 새 Dropdown, AlertDialog, Carousel, CommentThread, ImagePicker |
| S11 | ○ (`bottomArea`) | — | — | ○ | — | — | — | — | 새 AlertDialog, Textarea, ImagePicker |
| S12 | ○ | — | ○ | ○ (`작성하기`, secondary) | — | — | — | — | **새 WeekCalendar**, Tabs(기본형), InfiniteList |
| S13 | ○ (`bottomArea`) | — | — | ○ | ○ `AppPlainInput`×2 | — | — | — | 새 Dialog, 카카오 공유 채널 |
| S14 | ○ | — | ○ | ○ (`추가`, secondary) | △ 검색 입력 | — | — | — | — |
| S15 | ○ (`bottomArea`) | — | — | ○ | ○ `AppPlainInput`×2(하나는 readOnly — 이미 지원) | — | — | — | — |
| S16 | ○ | — | ○ | — | — | **○** | — | — | 새 InfiniteList |
| S17 | ○ (`bottomArea`) | — | ○ | ○ | — | — | — | — | 새 CommentThread, 이미지 확대 Dialog |
| S18 | ○ | — | ○ | — | — | **○** | — | — | 새 Carousel, InfiniteList |
| S19 | ○ (`bottomArea`) | — | ○ | — | — | — | — | — | 새 Carousel, CommentThread |

토스트는 전 화면 공통으로 `AppToastScope.read(context).showError(...)` (`flutter/lib/shared/ui/app_toast.dart:96,112`). **`AppToast`라는 클래스는 없다** — 착각하면 컴파일이 깨진다.
`AppSwitch`·`AppOtpInput`은 이 19개 화면에서 **쓰이는 곳이 없다**.

### 7.2 새로 만들어야 하는 공용 위젯

웹 `shared/ui/`·`widget/` 중 Flutter에 아직 없는 것. 괄호 안은 이 계열에서 필요로 하는 화면.

| 웹 컴포넌트 | 파일 | 필요 화면 | Flutter 구현 메모 |
|---|---|---|---|
| **`sheet`** (바텀시트) | `shared/ui/sheet.tsx` | S2, S3, S5, MonthPicker | `side='bottom'` 기본, `pb-9 px-7 rounded-t-lg`, 오버레이 `bg-black/80`. `showModalBottomSheet`로. **AppMonthPicker가 이미 자체 모달 시트를 갖고 있으므로**(`flutter/lib/widget/app_month_picker.dart:136`) 그 코드를 공통화하는 것이 첫 작업 |
| **`alert-dialog`** | `shared/ui/alert-dialog.tsx` | S2, S3, S7, S8, S9, S10, S11 | 제목 + (설명) + 버튼 2개. 버튼 높이 48, `gap-3`(8). 좌 `bg-gray-100 text-gray-600`, 우 `bg-point` 또는 `bg-primary-500` |
| **`dialog`** (전체화면/센터) | `shared/ui/dialog.tsx` | S1(AddStudentDialog, 전체화면), S13(하단 고정), S17(이미지 확대, 검정 배경) | 3가지 배치가 다르다 |
| **`dropdown-menu`** | `shared/ui/dropdown-menu.tsx` | S1(정렬), S2(케밥), S10·S17·S19(댓글 케밥) | 앵커 기준 절대 위치 팝업. 폭 96/120/130px |
| **`tabs`** | `shared/ui/tabs.tsx` | S5(pill 형), S12(기본 underline 형) | 두 스킨이 필요. **비활성 탭 내용은 언마운트**(웹 Radix 동작)해야 S12의 요청 타이밍이 맞는다 |
| **`textarea`** | `shared/ui/textarea.tsx` | S6, S9, S10, S11, S17, S19 | 댓글용(`h-8`=24, 한 줄 느낌)과 본문용(`h-[200px]`) 두 가지 |
| **`carousel`** (`widget/image-slide.tsx`) | `shared/ui/carousel.tsx` + `widget/image-slide.tsx` | S8, S10, S18, S19 | `PageView` + 인디케이터(`CarouselNav`). `enlargeMode`면 탭 시 전체화면 검정 배경 + `white_close.svg` |
| **`calendar`** (주간) | `shared/ui/calendar.tsx` (react-day-picker) | S12 | **가장 비싼 항목.** 월요일 시작, 해당 주 7칸만 노출, 미래 날짜 회색, 선택 원형 `bg-primary-500`, 좌우 ±7일 버튼 |
| **`select`** | `shared/ui/select.tsx` | (이 19개 화면에서 미사용) | 후순위 |
| **`scroll-area`** | `shared/ui/scroll-area.tsx` | (미사용 — `hide-scrollbar` 유틸로 대체) | 후순위 |
| **`time-swiper`** | `shared/ui/time-swiper.tsx` | (미사용) | 후순위 |
| **`generic-form`** | `shared/ui/generic-form.tsx` | (미사용 — S13은 react-hook-form 직접 사용) | 후순위 |
| **`separator`** | `shared/ui/separator.tsx` | (미사용 — 전부 `<div className='w-[1px] bg-gray-*'>` 로 직접 그린다) | 불필요 |
| **`week-picker`** | `widget/week-picker.tsx` | (이 19개에서 미사용. S12는 자체 Calendar) | 후순위 |
| **`rolling-banner`** | `widget/rolling-banner.tsx` | (미사용) | 후순위 |
| **`image-slide`** | `widget/image-slide.tsx` | 위 carousel 항목과 동일 | |

이 계열에서만 필요한 **추가 공용 요소**(웹엔 컴포넌트가 없고 인라인으로 반복되는 것):

| 이름(제안) | 반복 위치 | 내용 |
|---|---|---|
| `CommentThread` | S10·S17·S19 (`feature/log-class`·`log-diet`·`workout`의 CommentList가 사실상 같은 코드) | 재귀 트리, 대댓글 `ml-[47px]`, 활성 배경 `bg-blue-10`, 내 댓글만 케밥, `답글달기` |
| `CommentInputBar` | S10·S17·S19 (3벌 중복) | 상태바(`{이름}님에게 답글 남기는 중` / `댓글 수정 중` / `취소`) + textarea + 전송 `arrow_top.svg`. **S10만 사진 첨부가 있다** |
| `EmptyState` | S3·S4·S5·S12·S16·S18 | `py-28`(112) + 아이콘 + 문구(TITLE_1_BOLD). 아이콘/문구/색만 다르다 |
| `InfiniteListFooter` | S3·S4·S12·S16·S18 | 스크롤 감지 + `loading.gif`. Flutter에선 `ScrollController`/`VisibilityDetector` |
| `MealRow` | S2·S16·S17·S12(식단탭) | 아침/점심/저녁 3칸(단식 / 사진 / 빈 박스). 높이만 88 또는 62로 다르다 |
| `AttendanceBadge` | S5·S9·S11 | `출석`(`bg-blue-50 text-primary-500`) / `미출석`(`bg-gray-100 text-gray-700`), `rounded-sm` |
| `CourseHistoryRow` / `PointHistoryRow` | S3·S4 | `px-7 py-8` + 날짜/라벨/증감. 완전히 같은 레이아웃 |
| `S3ImageUploader` | S9·S10·S11 | presigned URL 발급 → S3 PUT → 목록 갱신. **BUG-27을 재현하지 말 것** |

### 7.3 회원(student) 쪽 화면과의 중복 — 이관 순서의 근거

Flutter 현황: 학생 쪽 식단/운동/수업일지는 **전부 미이관**(`/student/log`, `/student/diet`, `/student/workout`은 stub, **학생 식단 상세·운동 상세는 라우트조차 없다**). 반면 **트레이너 쪽 식단 상세·운동 상세 라우트는 이미 등록돼 있다**(`app_router.dart:609, 625`).

| 트레이너 화면 | 대응 학생 화면 | 중복 정도 | 차이점 |
|---|---|---|---|
| **S18 운동기록 목록** | `page/workout/ui/StudentWorkoutPage.tsx` | **거의 동일** | 쿼리(`useWorkoutQuery`)·카드(`WorkoutPost`)·MonthPicker 전부 같음. 차이: ① 학생은 `memberId`를 `useAuthSelector`에서, 트레이너는 props에서 ② 학생은 제목을 `useMyInfoQuery`로 별도 조회, 트레이너는 `mainData.name` 사용 ③ 학생 헤더에만 `+`(작성) 버튼 |
| **S19 운동기록 상세** | `page/workout/ui/StudentWorkoutDetailPage.tsx` | **거의 동일** | 트레이너는 케밥(수정/삭제)이 **없다**. 그 외 카드·PostMetrics·댓글 전부 동일 |
| **S8 수업일지 목록** | `page/feedback/ui/StudentLogPage.tsx` | **카드 UI 동일** | 엔드포인트가 다르다(`/lessonhistory` vs `/lessonhistory/student/{id}`). 트레이너에만 `+`(작성)·미작성 체크 알럿. 빈 상태 위치가 다름(학생은 `absolute top-1/2`) |
| **S10 수업일지 상세** | `page/feedback/ui/StudentLogDetailPage.tsx`(74줄) | 높음 | 트레이너에만 수정/삭제 케밥. 댓글 컴포넌트가 `TrainerCommentList` vs `StudentCommentList`로 **거의 복붙 수준으로 갈라져 있다**(`feature/log-class/ui/` 두 파일 각 178줄) |
| **S16 식단 목록** | `page/feedback/ui/StudentDietListPage.tsx` | **카드 UI 동일** | 엔드포인트 `/members/me/diets` vs `/members/{id}/diets`. 학생에만 `+`(등록) 버튼 |
| **S17 식단 상세** | `page/feedback/ui/StudentDietDetailPage.tsx` | 높음 | 학생에만 수정/삭제. 좋아요·댓글·이미지 확대는 동일 |
| **S4 포인트 내역** | `page/home/ui/StudentMyPointDetailPage.tsx` | **거의 동일** | 엔드포인트 `/members/point` vs `/members/{id}/point`. 리스트·카드·MonthPicker 동일 |
| **S3 수강권 내역** | `page/home/ui/StudentMyCourseDetailPage.tsx` | 높음 | 학생은 읽기 전용(등록/연장/삭제 없음) |

**결론**: S3·S4·S8·S10·S16·S17·S18·S19를 만들 때 만드는 위젯은 **학생 쪽 8개 화면을 거의 그대로 커버한다.** 이 8쌍을 "트레이너용/학생용" 플래그 하나로 파라미터화하면 학생 계열 이관 비용이 크게 줄어든다. 특히 `CommentThread`/`CommentInputBar`는 웹에서 3벌(log-class trainer/student, log-diet, workout)로 복붙돼 있는데, **Flutter에서는 처음부터 1벌로 만들 것**.

---

## 8. 이관 난이도와 권장 순서

판단 기준은 (a) 뮤테이션 개수, (b) 새로 만들 공용 위젯, (c) 다단계 상태, (d) 파일 업로드.

### 8.1 난이도 산정

| 화면 | (a) 뮤테이션 | (b) 새 공용 위젯 | (c) 다단계 상태 | (d) 업로드 | 난이도 |
|---|---|---|---|---|---|
| S15 | 1 | 0 | 없음 | 없음 | **하** |
| S6 | 1 | textarea | 없음 | 없음 | **하** |
| S14 | 0 | 0 | 검색 | 없음 | **하** |
| S7 | 1 | alert-dialog | 없음 | 없음 | **하** |
| S1 | 0 | dropdown, dialog | 검색+정렬 | 없음 | **하~중** |
| S16 | 0 | InfiniteList, MealRow | 월 + 페이지 | 없음 | **중** |
| S18 | 0 | InfiniteList, carousel | 월 + 페이지 | 없음 | **중** |
| S4 | 0 | InfiniteList | 월 + 페이지 + 학생 네비 | 없음 | **중** |
| S8 | 0 | alert-dialog, carousel | 월 | 없음 | **중** |
| S5 | 2 | tabs(pill), sheet | 탭 + 월 + 시트 | 없음 | **중~상** |
| S2 | 2 | dropdown, alert-dialog, sheet, checkbox | 드롭다운→시트→체크→버튼 | 없음 | **상** |
| S3 | 3 | sheet, alert-dialog, InfiniteList | 시트 2종 + 월 + 페이지 | 없음 | **상** |
| S11 | 1 | alert-dialog, textarea | 폼 프리필 | **○** | **상** |
| S9 | 1 | alert-dialog, textarea | **화면 모드 2개** + 수업 선택 | **○** | **상** |
| S17 | 5 | CommentThread, CommentInputBar, 확대 dialog | 댓글 target(생성/답글/수정) | 없음 | **상** |
| S19 | 5 | CommentThread, CommentInputBar, carousel | 댓글 target + 좋아요 낙관 업데이트+디바운스 | 없음 | **상** |
| S13 | 1 | dialog, **카카오 공유** | 폼 → 다이얼로그(실제론 안 열림) | 없음 | **상** |
| S12 | 0 | **주간 캘린더**, tabs, InfiniteList | 날짜 + 주 + 탭 | 없음 | **상** |
| S10 | 5 | dropdown, alert-dialog, carousel, CommentThread, CommentInputBar(+사진) | 댓글 target + 이미지 | **○** | **최상** |

### 8.2 권장 순서

**Phase 0 — 공용 위젯 선행 (화면 0개)**
`AppBottomSheet`(AppMonthPicker 내부 시트 코드를 승격), `AppAlertDialog`, `AppDropdownMenu`, `AppTextarea`.
> 이유: 19개 중 12개가 이 4개에 걸린다. 화면을 만들며 즉석으로 짜면 4벌로 갈라진다.

**Phase 1 — 쉬운 입력/목록 (S14 → S15 → S1 → S6 → S7)**
> 이유: `AppPlainInput`·`AppButton`·`AppLayout`만으로 되는 것들. 회원 추가 플로우(S1→S14→S15)가 한 덩어리로 완결돼 첫 E2E 확인이 가능하다. S6·S7은 `AppTextarea`/`AppAlertDialog`의 첫 실전 검증.

**Phase 2 — 월 피커 + 무한스크롤 목록 (S4 → S16 → S18 → S8)**
> 이유: 네 화면이 `AppMonthPicker`(이미 있음) + `InfiniteListFooter`(새로) + `EmptyState`(새로)를 공유한다. 여기서 만든 `MealRow`(S16)와 `carousel`(S18·S8)이 뒤 단계에 그대로 쓰인다. S4를 먼저 두는 이유는 **BUG-1의 학생 하단바 요청을 초반에 확정**해 두기 위해서다(직전 계열에서 놓친 유형).

**Phase 3 — 허브와 뮤테이션 (S2 → S3 → S5)**
> 이유: S2는 회원관리의 진입 허브라 앞에 두고 싶지만, 케밥+알럿+시트+체크박스가 다 필요해 Phase 0·1이 끝나야 싸게 만들어진다. S3는 S2에서 만든 `CourseCard`+`AppProgress`를 재사용한다. S5는 `tabs` 첫 구현 + 시트 재사용.

**Phase 4 — 댓글 트리 (S17 → S19)**
> 이유: `CommentThread`/`CommentInputBar`를 한 번에 만든다. S17이 먼저인 이유는 이미지 첨부가 없어 더 단순하고, S19는 여기에 좋아요 디바운스만 얹으면 된다.

**Phase 5 — 업로드 (S11 → S9 → S10)**
> 이유: 이미지 업로더를 만드는 단계. S11이 가장 단순(폼 프리필 + 업로드), S9는 화면 모드 전환이 추가, S10은 업로드 + 댓글 트리 + 케밥이 전부 겹쳐 마지막.
> **⚠️ 이 단계는 시작 전에 사용자 결정이 필요하다.** ① **BUG-45** — 웹의 presigned 방식은 현재 백엔드에 없다. Flutter는 multipart `POST /api/v1/file` (파트명 `files`)로 구현해야 한다. ② **BUG-27** — 다중 업로드 시 N² 중복. 재현하면 안 된다.

**Phase 6 — 남은 특수 화면 (S12 → S13)**
> 이유: S12의 주간 캘린더는 이 계열에서 유일하게 쓰이는 대형 위젯이라 마지막으로 미뤄도 다른 화면을 막지 않는다. S13은 카카오 공유가 Flutter 플랫폼 채널/SDK 작업이라 성격이 완전히 다르고, **BUG-2로 다이얼로그가 죽어 있어 사양 확인이 먼저 필요**하다.

---

## 9. 부록 — 미확인 항목과 그 이유

| # | 미확인 내용 | 왜 확인 못 했나 | 확인 방법 |
|---|---|---|---|
| U1 | **마운트 시 실제 네트워크 요청 순서.** §3의 순서는 훅 선언 순서다. TanStack Query는 effect 시점에 fetch하고 effect는 자식→부모 순으로 실행되므로, 하위 컴포넌트(S1의 `StudentList`, S4의 `StudentNavigation`, S12의 `LessonFeedbackList`)가 먼저 나갈 수 있다 | 브라우저를 띄우지 않았다 | DevTools Network 또는 HAR 캡처. `flutter/har/`에 기존 캡처 방식이 있다 |
| U2 | **S12에서 비활성 탭(`식단`)이 마운트 시 요청을 쏘는지.** Radix Tabs가 비활성 `TabsContent`를 언마운트한다는 전제로 "안 쏜다"고 적었다 | `node_modules` 미설치로 Radix 구현 확인 불가 | 실제 로드 후 Network 확인 |
| U3 | **BUG-34 — `dayjs(year+month, 'YYYYM')`의 실제 파싱 결과.** `customParseFormat` 미로드 시 코어 `REGEX_PARSE`가 `"20259"`/`"202512"`를 어떻게 자르는지 | `node_modules`가 없어 `require('dayjs')` 실행 실패 | `npm i` 후 1줄 스크립트로 확인 |
| U4 | **BUG-5·BUG-11·BUG-21·BUG-32 — CSS 특정도/실제 렌더 결과.** 콤마 연산자로 버려진 Typography가 최종적으로 어떤 폰트가 되는지, `text-6`이 무시된 뒤 상속되는 크기, `defaultValue` 비제어 입력의 실제 표시값 | 정적 분석으로는 tailwind-merge와 상속을 확정할 수 없다 | 브라우저 Computed Styles |
| U5 | **BUG-35 — Radix `Sheet`가 닫힐 때 `MonthlyCalendar`를 언마운트하는지** | 위와 동일 | 시트를 열고 월을 바꾼 뒤 닫았다 다시 열어보기 |
| U6 | **백엔드 실제 응답 JSON.** §4는 컨트롤러·DTO **소스 기준**이다. `isLast` 키 이름은 `@JsonProperty` + 체크인된 계약 테스트(`backend/src/test/java/com/tobe/healthy/ApiContractSerializationTest.java:33`)로 **확정**했지만, 나머지 nullable 여부·실제 값은 응답을 봐야 완전하다 | 서버를 띄우지 않았다 | 체험 계정으로 HAR 캡처 (`flutter/har/` 참조) |
| U7 | ~~`GET /api/v1/diets/{dietId}` 응답의 `type` 필드~~ → **해결.** 백엔드 `DietDetailDto`에 `type` 필드가 **없다**. 웹이 상세 쿼리에서만 클라이언트 주입한다 | — | BUG-42 참조 |
| U8 | **`invitationLink`의 실제 URL 형태.** DTO는 `MemberInviteResultCommand {uuid, invitationLink}`로 확인했지만, 실제 문자열(도메인·경로·쿼리)은 서버 설정에 달렸다 | 서버 미기동 | 실제 응답 또는 `TrainerService`의 링크 조립 코드 확인 |
| U9 | **`MemberDetailResult.diet`가 `null`일 수 있는지.** DTO상 `DietDto diet`라 null 가능하지만, 실제 쿼리가 항상 채우는지 확인 못 했다. S2가 `memberInfo.diet.dietId`를 옵셔널 체이닝 없이 접근한다(`TrainerStudentDetailPage/index.tsx:339`) → null이면 TypeError | 리포지토리 쿼리까지는 안 봤다 | `member/repository/`의 `MemberDetailResult` 프로젝션 확인 또는 식단이 없는 회원으로 실제 호출 |
| U10 | ~~`/images/invitation.png` 존재 여부~~ → **해결.** `frontend/public/images/`에 `invitation.png`, `letter_blue-heart.png`, `point.png`, `loading.gif` 모두 존재 | — | — |
| U11 | ~~각 화면의 권한~~ → **해결.** §4.5 참조. 프런트는 `UserRoleMiddleware`가 `TRAINER`를 강제하고, 백엔드는 일부만 `@PreAuthorize("hasAuthority('ROLE_TRAINER')")`다 | — | §4.5 |
| U12 | ~~`POST /api/v1/file` 계약~~ → **해결(그리고 문제 발견).** 현재 백엔드는 multipart 하나뿐이다 | — | BUG-45 참조 |
| U13 | ~~`SocialType`에 `APPLE`이 있는지~~ → **해결.** 웹 `SocialType = 'NONE' \| Uppercase<'kakao'\|'naver'\|'google'\|'apple'>`(`entity/auth/model/types.ts:13-15`) = 백엔드 `SocialType {NONE, KAKAO, NAVER, GOOGLE, APPLE}` ✓ 일치 | — | — |
| U14 | **BUG-41이 실제로 화면에 보이는지.** `isNonmember` → `nonmember` 불일치로 뱃지가 항상 뜬다는 것은 **소스 기준 추론**이다. 혹시 응답 어딘가에 `nonmember` 키도 함께 실린다면 아닐 수 있다 | 실제 응답 미확인 | `GET /api/v1/trainers/members` 응답 1건 확인 |
| U15 | **`/reservation/new`·`/reservation/old`의 `memberId` 바인딩 방식.** 컨트롤러가 `@RequestParam`이 아니라 Spring Data의 `@Param`을 쓴다(`TrainerController.java:7`). MVC는 이를 무시하므로 `-parameters` 컴파일 옵션에 의한 이름 추론에 의존한다. `build.gradle`에 명시적인 `-parameters`는 **없지만** Spring Boot Gradle 플러그인(`org.springframework.boot 3.5.13`, `build.gradle:3`)이 `JavaCompile`에 자동으로 붙여준다 → **동작할 것으로 본다 (추론)** | 실제 컴파일 산출물을 확인하지 않았다 | `./gradlew compileJava` 후 `javap -v`로 파라미터명 보존 확인, 또는 실제 호출 |
