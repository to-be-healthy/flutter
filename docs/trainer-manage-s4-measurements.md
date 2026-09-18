# S4 — 트레이너 "{name}님 포인트" (`/trainer/manage/{memberId}/point-history`) 네트워크 + 픽셀 실측

## 측정 개요

| 항목 | 값 |
|------|-----|
| 측정 일시 | 2026-09-18 22:36 ~ 22:38 KST (UTC 2026-09-18T13:36 ~ 13:38) |
| 기준 URL | `https://geonganghaejim.site/trainer/manage/6/point-history` |
| 뷰포트 | **440 × 900**, `devicePixelRatio` = 1 |
| 계정 | 영속 프로필의 트레이너 세션 — `healthy-trainer0`, `memberId: 5`, `gymId: 1` |
| 도구 | playwright MCP, `getBoundingClientRect()` + `getComputedStyle()` |
| 대상 회원 | memberId 6 (차은우) — `monthPoint 0` / `totalPoint 85`(2026-09), 내역은 **2026-04에 12건** |

### 안전 확인

**이 화면은 읽기 전용이다** — 뮤테이션 버튼이 하나도 없다(서베이 §"상호작용 요청: 없음"). 월 변경으로 GET만 추가 발생했다.

---

## 산출물 ① — 네트워크: **3건. 그리고 서베이의 순서 추론이 틀렸다**

```
1. GET /api/v1/members/trainer-mapping                                   → 200
2. GET /api/v1/trainers/members/6                                        → 200
3. GET /api/v1/members/6/point?page=0&size=20&searchDate=2026-09         → 200
```

**서베이는 ①`trainers/members` → ②`point` → ③`trainer-mapping`으로 추론하고
"(추론)"이라 표시해 뒀는데, 실제로는 `trainer-mapping`이 1번이다.** 두 번
캡처해 같은 순서를 확인했다.

- 1번은 **화면 본체가 아니라 학생 하단바**가 쏜다(BUG-1). 트레이너 화면인데
  `<Layout type='student'>`를 써서 학생 네비가 붙고, 그 안의
  `useCheckTrainerMemberMappingQuery`에 `enabled`가 없어 마운트 즉시 나간다.
- 학생 홈에서 이미 겪은 것과 **같은 함정이다**: 네비가 화면보다 먼저 쏜다.
  Flutter `initState`는 부모가 먼저라 그대로 두면 순서가 뒤집힌다 —
  학생 홈이 `addPostFrameCallback`으로 해결한 그 문제다.
- 골든: `har/trainer-manage-point-history.har` → `test/fixtures/requests/trainer-manage-point-history.json`.

**하단바가 학생용이라는 증거(실측):** `nav`의 링크가
`/student`, `/student/community`, `/student/mypage`다. 트레이너 네비였다면
`/trainer`·`/trainer/schedule`이어야 한다.

### 월 변경 시

3번만 새 `searchDate`로 다시 나간다(`page=0`). 1·2번은 다시 나가지 않는다.

---

## 산출물 ② — 응답 본문 (규율 #16, 실측)

### 1) `GET /api/v1/members/trainer-mapping`

```json
{"message":"매핑 여부가 조회되었습니다.","data":{"mapped":false},"status":"OK"}
```

이미 `MemberApi.trainerMapping()`이 쓰는 모양 그대로다. **트레이너 계정이라
`mapped: false`** — 화면은 이 값을 쓰지 않는다(네비가 가드에만 쓴다).

### 2) `GET /api/v1/trainers/members/6`

S2와 **같은 엔드포인트·같은 응답**이다(`TrainerMemberDetail`). 이 화면은
그중 **`name` 하나만** 쓴다(헤더 제목).

### 3) `GET /api/v1/members/6/point?...` — 내역 0건 (2026-09)

```json
{"message":"포인트가 조회되었습니다.","data":{"content":[],"pageNumber":0,
"pageSize":20,"totalPages":0,"totalElements":0,"isLast":true,
"mainData":{"searchDate":"2026-09","monthPoint":0,"totalPoint":85}},"status":"OK"}
```

### 3') 내역 12건 (2026-04)

```json
{"pointId":12,"type":"DIET","calculation":"PLUS","point":5,
 "createdAt":"2026-04-11T14:47:52"}
```

### 확정된 것

| 항목 | 실측 결과 |
|---|---|
| **페이징 봉투** | **수강권(S3)과 완전히 같다** — `content` `pageNumber` `pageSize` `totalPages` `totalElements` `isLast` `mainData`. 다른 것은 `mainData`의 내용뿐 |
| `mainData` | `{searchDate: String, monthPoint: int, totalPoint: int}` — S3의 `{course, gymName}` 자리다 |
| 항목 | `pointId` `type` `calculation` `point` `createdAt` |
| 빈 목록 | `[]` (S3와 같다) |
| `totalPoint` | **그 달까지의 누적**이다. 2026-03에서 0, 2026-04에서 85, 이후 달도 85 — 전역 상수가 아니다 |

---

## 산출물 ③ — 픽셀 실측 (440 × 900)

### A. 헤더 — **X 링크가 제목을 덮는다**

| # | 대상 | 실측 |
|---|---|---|
| A1 | header | **440 × 56**, `bg-white`, padding 16/20 |
| A2 | **`<a>` 링크** | **400 × 24** @ `20,16` — `h-full w-full`이라 **헤더 폭 전체**를 차지한다 |
| A3 | 그 안의 X 아이콘 | **14 × 14** @ `20,16` |
| A4 | 제목 `차은우님 포인트` | `18px/23.4 600`, **113.17 × 23.4** @ `163.41,16.3` |

> **A2가 서베이의 "(추론)"을 확정한다 — 단 결론은 반쪽이다.**
> 링크 rect(20~420, 16~40)가 제목 rect(163.41~276.58, 16.3~39.7)를 좌표상
> 덮는다. **그런데 제목이 DOM에서 링크 뒤에 와서 위에 그려지고, 실제로
> 포인터를 가로챈다** — playwright가 링크 가운데를 클릭하려다
> `<h2 …>차은우님 포인트</h2> intercepts pointer events`로 실패했다.
>
> 즉 **제목 글자 위는 눌리지 않고**, 그 좌우의 링크 영역과 X는 눌린다.
> 처음에 "제목을 눌러도 이동한다"고 적었다가 클릭 실패로 정정했다 —
> **rect가 겹친다고 눌리는 것이 아니다.**
>
> **목적지는 `/trainer/manage/{memberId}`다**(실측: X를 눌러 `/trainer/manage/6`
> 도착). `./`가 현재 경로의 디렉터리로 해석된 결과이고 **뒤로가기가 아니다** —
> 어디서 들어왔든 회원 정보(S2)로 간다.

### B. 상단 블록 `bg-white p-7 pb-11 pt-6` — **440 × 224.4** @ `0,56`

padding 실측 **16 / 20 / 36 / 20** (`pt-6`=16, `px-7`=20, `pb-11`=36).

#### B-1. 월 선택 — **좌측 정렬이다** (S3는 우측)

| # | 대상 | 실측 |
|---|---|---|
| B1 | 래퍼 | 400 × 51.5 @ `20,72` |
| B2 | 버튼 | **81.98 × 51.5 @ `20,72`** — 래퍼에 `justify-end`가 없어 **왼쪽**이다 |
| B3 | 라벨 `2026년 9월` | `13px/19.5 600`, 65.98 × 19.5 @ `20,88` |
| B4 | 삼각형 | 12 × 13 @ `89.98,91.25` |

#### B-2. 포인트 카드 `rounded-lg p-6 mb-6 gap-y-1 bg-primary-500 px-6 py-7`

| # | 대상 | 실측 |
|---|---|---|
| B5 | 카드 rect | **400 × 86.9** @ `20,123.5`, bg **`rgb(25,144,255)`**, radius **12** |
| B6 | padding | **20 / 16 / 20 / 16** (`py-7`=20, `px-6`=16) |
| B7 | 카드 아래 `mb-6` | **16** (카드 하단 210.4 → 안내문 226.4) |
| B8 | 헤더 행 | 368 × 23.4 @ `36,143.5`, `justify-between` |
| B9 | `9월 활동 포인트` | `13px/19.5 600` **white**, 81.81 × 19.5 |
| B10 | 포인트 아이콘 | **21 × 21** @ `367.12,144.7`, `rounded-full` |
| B11 | `monthPoint` 값 `0` | `18px/23.4 700` white, `ml-1`=**4** |
| B12 | 본문 행 (`gap-y-1`=4) | 368 × 19.5 @ `36,170.9` |
| B13 | `누적` | `12px/18 500` **`rgb(219,234,254)`** — 아래 BUG-14 정정 참고 |
| B14 | `totalPoint` 값 `85` | `13px/19.5 400` white |

#### B-3. 안내문

| # | 대상 | 실측 |
|---|---|---|
| B15 | `<p>` | 400 × 18 @ `20,226.4` |
| B16 | 아이콘 | **12 × 12** @ `20,229.4` (`IconNotification`, `stroke='black'`) |
| B17 | 문구 | `활동 포인트는 매월 1일 자정 초기화됩니다.` `12px/18 400` `rgb(2,8,23)`, `ml-1`=4 |

### C. 내역 리스트 `ul.bg-gray-100` — S3와 **거의** 같다

| # | 대상 | 실측 |
|---|---|---|
| C1 | 항목 `px-7 py-8` | **440 × 87**, padding 24 / 20 — S3와 동일 |
| C2 | 날짜 | `12px/18` **400** `rgb(134,136,141)` — **S3는 500이다**(아래 정정 참고) |
| C3 | 타입 라벨 | `14px/21 600` `rgb(76,78,82)` — S3와 동일 |
| C4 | 증감 | `14px/21 600` `rgb(0,0,0)`, 우측 정렬 — S3와 동일 |
| C5 | 빈 상태 | **440 × 291.4**, `py-28`=112 + 아이콘 33 + `mb-5`=12 + 22.4 + 112 — S3와 **완전히 동일** |
| C6 | 빈 문구 | `포인트 내역이 없습니다.` `16px/22.4 700` gray700 |

> **측정 아티팩트:** 항목 12건일 때 세로 스크롤바가 생겨 폭이 **425**로 잡힌다
> (440 − 15). 항목 폭 자체가 다른 게 아니다 — 빈 상태(스크롤 없음)에서는 440이다.

### 타입 라벨 (`feature/point/const.ts`)

| 코드 | 문구 |
|---|---|
| `NO_SHOW` | `노쇼` |
| `NO_SHOW_CANCEL` | `노쇼취소` |
| `WORKOUT` | `개인운동` |
| `DIET` | `식단등록` |

---

## 산출물 ④ — 서베이 정정 3건

### 1. 요청 순서 — `trainer-mapping`이 1번이다

서베이가 `(추론)`으로 남긴 부분이고, 실제와 **반대**였다. 산출물 ① 참고.
**골든을 먼저 뜨지 않았으면 패리티가 깨졌을 것이다.**

### 2. BUG-14는 **버그가 아니다** — `text-blue-100`은 정상 렌더된다

서베이: "`text-blue-100`은 tailwind config에 없다(blue는 10·50만 정의) →
클래스가 생성되지 않는다."

**실측: `rgb(219,234,254)`로 정상 렌더된다.** Tailwind 기본 `blue-100`
(`#DBEAFE`)이다. 이유는 `tailwind.config.js:14`의 **`theme.extend`** —
`colors.blue`가 extend 안에 있어 기본 팔레트를 **덮어쓰지 않고 병합**한다.
`blue: {10, 50}`은 두 키를 **추가**할 뿐이고 `blue-100`은 기본값이 그대로 산다.

> **규율 #5가 스페이싱에 대해 말한 것과 같은 함정이다** — "`theme.extend` 안이라
> 목록에 없는 키는 Tailwind 기본값이 그대로 산다." 서베이가 스페이싱에는 그
> 규칙을 적용했는데 **색에는 적용하지 않았다.** 색 토큰도 같은 규칙으로 읽어라.

### 3. 내역 날짜의 굵기가 S3와 다르다

서베이는 "내역 리스트 — S3와 동일 형태"라고 적었지만 **날짜만 다르다**:

| | S3 수강권 | S4 포인트 |
|---|---|---|
| 날짜 | `BODY_4_MEDIUM` → **500** | `BODY_4` → **400** |
| 타입 라벨 · 증감 | `TITLE_3` 600 | 같음 |
| 항목 높이 | 87 | 87 |

소스로도 확인했다(`StudentPointDetailPage.tsx:150`은 `Typography.BODY_4`,
`StudentCourseDetailPage.tsx`는 `BODY_4_MEDIUM`). **"동일 형태"를 믿고
위젯을 공유했으면 굵기가 틀린 채 통과했을 것이다.**

---

## 산출물 ⑤ — 옮길 웹 버그

| 버그 | 내용 | 처리 |
|---|---|---|
| **BUG-1** | 트레이너 화면에 **학생 하단바**가 붙고 `trainer-mapping`을 쏜다 | **그대로 옮긴다.** 골든이 3건이라 재현이 강제된다 |
| **BUG-3** | `{M}월 활동 포인트`의 월이 `searchDate.split('-')[1].split('')[1]` → 10·11·12월이 `0`·`1`·`2`월 | **그대로 옮긴다.** 학생 홈에서 이미 만든 `StudentPoint.webMonthLabel` 재사용 |
| **BUG-13** | 로딩 중 스타일 없는 raw `Loading..` 텍스트 | 그대로 옮긴다(문구까지) |
| **BUG-6** | 언마운트 시 `removeQueries(['myPointHistory'])` — 실제 키는 `studentPointHistory`라 아무것도 안 지운다 | **Flutter에 대응물 없음**(쿼리 캐시가 없다). 옮기지 않는다 |
| 헤더 링크 | X 링크가 폭 400이지만 **제목이 위에 그려져 가운데는 안 눌린다**. 목적지는 `./` → `/trainer/manage/{memberId}` | **그대로 옮긴다** — 제목을 뺀 헤더 영역이 탭 영역이고, 이동은 pop이 아니라 **S2로 go**다 |

---

## 산출물 ⑥ — 실측하지 못한 것

| 항목 | 이유 |
|---|---|
| 무한스크롤 2페이지 | 최대 내역이 12건(한 페이지 20건)이라 2페이지를 만들 수 없다. S3와 같이 계약 테스트로 고정 |
| `NO_SHOW` / `NO_SHOW_CANCEL` 라벨 렌더 | 이 계정 내역에 `DIET`·`WORKOUT`만 있다. 상수 매핑은 소스에서 확인 |
| 로딩 분기(`Loading..`) | 응답이 즉시 와서 못 잡음. 소스 기준 |
