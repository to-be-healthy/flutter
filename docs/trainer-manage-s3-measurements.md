# S3 — 트레이너 "{name}님 수강권" (`/trainer/manage/{memberId}/course-history`) 네트워크 + 픽셀 실측

## 측정 개요

| 항목 | 값 |
|------|-----|
| 측정 일시 | 2026-09-18 21:56 ~ 22:01 KST (UTC 2026-09-18T12:56 ~ 13:01) |
| 기준 URL | `https://geonganghaejim.site/trainer/manage/6/course-history?name=차은우` (보조: `/trainer/manage/15/course-history?name=rr`) |
| 뷰포트 | **440 × 900**, `devicePixelRatio` = 1, 스크롤바 폭 0 |
| 계정 | 영속 프로필의 트레이너 세션 — JWT `userId: healthy-trainer0`, `memberType: TRAINER`, `memberId: 5`, `gymId: 1` |
| 도구 | playwright MCP (`mcp__playwright__*`) |
| 측정 방식 | `browser_evaluate` 안에서 `getBoundingClientRect()` + `getComputedStyle()` 직접 호출. 스냅샷 텍스트에서 추정한 값 없음 |

### 데이터 상태

| 회원 | 수강권 | 분기 |
|---|---|---|
| **memberId 6 (차은우)** | `courseId 3`, total 10 / remain 3 / **completed 10** | **만료** — 회색 카드, 헤더 `+` 렌더, `수업 횟수 추가` disabled |
| **memberId 15 (rr)** | `courseId 2`, total 3 / remain 3 / **completed 0** | **활성** — 파란 카드, 헤더 `+` 없음, `수업 횟수 추가` 활성 |

### 안전 확인

- **누르지 않음**: 삭제 알럿의 `예`(`DELETE /course/{id}` — §2.1 복구 불가), 시트의 `수강권 등록`·`수업 횟수 추가` 제출 버튼.
- 세션 전체 네트워크 로그에 `POST`/`PATCH`/`DELETE /api/v1/course*` **0건**. 나간 것은 `GET /members/{6,15}/course` 와 `POST /auth/refresh-token` 1건(아래), 조회용 `GET /trainers/members` 뿐이다.
- 시트에 `501`을 입력한 것은 에러 문구 분기 확인용이고 **제출하지 않았다**.

---

## 산출물 ① — 네트워크

### 진입 시 `/api/` 요청 — **1건**

```
GET https://geonganghaejim.site/api/v1/members/6/course?page=0&size=20&searchDate=2026-09  →  200
```

- 요청 헤더에 **`content-type`이 없다**(본문 없는 GET). 붙는 것은 `authorization: Bearer …` 뿐 — `select-gym`·`trainer-manage-member`와 같다.
- 골든: `har/trainer-manage-course-history.har` → `test/fixtures/requests/trainer-manage-course-history.json`.

### ⚠️ 첫 캡처는 401 → refresh → 재요청 3건이었다

처음 진입했을 때 액세스 토큰이 만료돼 있어 실제로 나간 것은 아래 셋이다.

```
GET  /api/v1/members/6/course?...  → 401
POST /api/v1/auth/refresh-token    → 200
GET  /api/v1/members/6/course?...  → 200
```

**이대로 골든을 떴으면 요청 3건짜리 골든이 나온다.** 앱에는 401 리프레시가 없으므로(`AuthInterceptor`는 토큰 부착만 한다) 위젯 테스트가 매번 2건 누락으로 떨어졌을 것이다. 토큰이 갱신된 뒤 **다시 진입해 1건짜리를 캡처**했고, 골든은 그것이다.

> 부수 소득: 웹의 401 경로를 실제로 봤다. 갱신 뒤 **원 요청이 재시도된다**(`next-steps.md` §5가 "재시도하지 않는다"고 적어 둔 것과 다르다 — 인터셉터가 아니라 React Query 쪽에서 재요청이 나가는 것으로 보인다). 401 리프레시를 옮길 때 이 실측을 근거로 다시 판단할 것.

### 월 변경 시

`2026-03` 선택 → `GET /api/v1/members/6/course?page=0&size=20&searchDate=2026-03` 1건. `page`는 **0으로 되돌아간다**(queryKey가 바뀌어 새 무한쿼리).

### 무한스크롤

`size=20`, 다음 `page` = 이미 받은 페이지 수(`allPages.length`), 종료 조건 `lastPage.isLast`. **실측 못 함** — 이 계정의 최대 내역이 4건이라 2페이지를 만들 수 없다. 계약 테스트로 고정한다.

---

## 산출물 ② — 응답 본문 (규율 #16, 실측)

### 내역 0건 (`searchDate=2026-09`, memberId 6)

```json
{"message":"수강권이 조회되었습니다.","data":{"content":[],"pageNumber":0,"pageSize":20,
"totalPages":0,"totalElements":0,"isLast":true,
"mainData":{"course":{"courseId":3,"totalLessonCnt":10,"remainLessonCnt":3,
"completedLessonCnt":10,"createdAt":"2026-03-13T14:44:48"},
"gymName":"건강해짐 홍대점"}},"status":"OK"}
```

### 내역 4건 (`searchDate=2026-03`, memberId 6)

```json
"content":[
 {"courseHistoryId":7,"cnt":1,"calculation":"MINUS","type":"RESERVATION","createdAt":"2026-03-29T14:44:48"},
 {"courseHistoryId":6,"cnt":1,"calculation":"MINUS","type":"RESERVATION","createdAt":"2026-03-26T14:44:48"},
 {"courseHistoryId":5,"cnt":1,"calculation":"MINUS","type":"RESERVATION","createdAt":"2026-03-22T14:44:48"},
 {"courseHistoryId":4,"cnt":10,"calculation":"PLUS","type":"COURSE_CREATE","createdAt":"2026-03-13T14:44:48"}],
"pageNumber":0,"pageSize":20,"totalPages":1,"totalElements":4,"isLast":true
```

### 확정된 것

| 항목 | 실측 결과 |
|---|---|
| **`isLast` 와이어 키** | **`isLast`** 다. Java `boolean isLast`의 빈 게터가 `last`로 직렬화되는 흔한 함정에 **걸리지 않았다** |
| **빈 목록** | `content: []` — **빈 배열이다. `null`이 아니다.** 단 웹은 `content === null`도 함께 방어하므로(`:340`) 양쪽 다 파싱되게 만든다 |
| 페이징 봉투 | `pageNumber` `pageSize` `totalPages` `totalElements` `isLast` `mainData` `content` |
| `mainData` | `{course: CourseDto \| null, gymName: String}` — `gymName`은 course 바깥의 형제 |
| `CourseDto` | `courseId` `totalLessonCnt` `remainLessonCnt` `completedLessonCnt` `createdAt` |
| 항목 | `courseHistoryId` `cnt` `calculation`(`PLUS`/`MINUS`) `type` `createdAt` |
| 날짜 | `createdAt: "2026-03-29T14:44:48"` → 화면 `26.03.29` (`YY.MM.DD`) |
| 부호 | `calculation === 'PLUS' ? '+' : '-'` + `cnt` → `+10` / `-1` |

---

## 산출물 ③ — 픽셀 실측 (440 × 900)

### A. 헤더 `relative flex h-[56px] w-full flex-none items-center px-7 py-6 justify-start bg-white`

| # | 대상 | 실측 |
|---|---|---|
| A1 | header rect | **440 × 56** @ `0,0`, `bg-white` |
| A2 | 뒤로가기 버튼 | **20 × 20** @ `20,18` |
| A3 | 제목 `차은우님 수강권` | `text-[18px]/[130%] font-semibold` → **18px/23.4 600**, rect **113.17 × 23.4** @ `163.41,16.3` |
| A4 | 제목 `rr님 수강권`(짧은 이름) | **80.07 × 23.4** @ `179.96,16.3` — 가운데 정렬 확인 |
| A5 | **`+` 버튼(만료일 때만)** | **20 × 20** @ `400,18` — `absolute right-7` → 440−20−20 |

### B. 본문 상단 `bg-white p-7 pb-0` — rect **440 × 294.5** @ `0,56`

#### B-1. CourseCard (S2와 동일 컴포넌트)

| # | 대상 | 실측 |
|---|---|---|
| B1 | 카드 rect | **400 × 141** @ `20,76`, `rounded-lg`, `mb-6` = **16** (카드 하단 217 → 액션바 상단 233) |
| B2 | **만료 배경** | `bg-gray-500` — **클래스 기준**(색은 직접 재지 않았다). 같은 세션에서 `text-gray-500`이 **`rgb(134,136,141)`**로 나왔으므로 토큰값은 그것이다 |
| B3 | **활성 배경** | `bg-primary-500` → **`rgb(25,144,255)`** |
| B4 | 헤더 블록 `px-6 pb-8 pt-7` | 400 × **93.5** @ `20,76` |
| B5 | 체육관명 / 배지 행 | 368 × **19.5** @ `36,96`, 둘 다 `13px/19.5 400` `text-gray-100` |
| B6 | 큰 문구 `10회 PT수강 만료` | `20px/26 700` white, 368 × 26 @ `36,119.5` |
| B7 | 콘텐츠 블록 `px-6 pb-7` | 400 × **47.5** @ `20,169.5` |
| B8 | 진행바 | **368 × 2** @ `36,195`, 트랙 `bg-blue-600/20` |
| B9 | 진행바 채움(만료) | `bg-gray-400`, 폭 368(=100%) |
| B10 | 진행바 채움(활성 0/3) | `bg-white`, rect x=**−332** (368 폭을 100% 왼쪽으로 민 상태 = 0%) |

#### B-2. 액션 바 `mb-7 flex items-center justify-center rounded-lg bg-gray-100 text-black`

| # | 대상 | 실측 |
|---|---|---|
| B11 | 바 rect | **400 × 46** @ `20,233`, bg **`rgb(242,243,245)`** |
| B12 | `수업 횟수 추가` | **160 × 46** @ `59.5,233`, `13px/19.5 600` |
| B13 | ↳ 만료 시 | `disabled`, `text-gray-400` |
| B14 | ↳ 활성 시 | 활성, `rgb(0,0,0)` |
| B15 | 세로 구분선 | **1 × 30** @ `219.5,241`, `bg-gray-200` |
| B16 | `수강권 삭제` | **160 × 46** @ `220.5,233` |
| B17 | 가운데 정렬 | 160+1+160 = 321, 여백 (400−321)/2 = 39.5 → 첫 버튼 x = 20+39.5 = **59.5** |

#### B-3. 월 선택 `flex justify-end`

| # | 대상 | 실측 |
|---|---|---|
| B18 | 래퍼 | 400 × **51.5** @ `20,299` |
| B19 | 버튼 | **81.98 × 51.5** @ `338.02,299` (우측 정렬) |
| B20 | 라벨 `2026년 9월` | `13px/19.5 600`, 65.98 × 19.5 @ `338.02,315` |
| B21 | 화살표 아이콘 | **12 × 13** @ `408,318.25` |
| B22 | 내부 `flex items-center space-x-1 py-6` | 라벨과 아이콘 간격 4 (`space-x-1`) |

> 월 선택 시트는 이미 이관된 **`AppMonthPicker`** 와 같은 컴포넌트다(`월 선택하기` 헤딩, 12칸 그리드 100×72, 하단 버튼 400×58). 재사용한다.

### C. 내역 리스트 `ul.bg-gray-100` — bg **`rgb(242,243,245)`**

#### C-1. 항목 있을 때 (4건, `searchDate=2026-03`)

| # | 대상 | 실측 |
|---|---|---|
| C1 | ul rect | 440 × **348** @ `0,350.5` (87 × 4) |
| C2 | 항목 `px-7 py-8` | 440 × **87**, padding **24 / 20 / 24 / 20** |
| C3 | 날짜 `26.03.29` | `12px/18 500` **`rgb(134,136,141)`**(gray-500), 폭 400(블록), 높이 18 |
| C4 | `dl` 행 | 400 × **21**, `justify-between` |
| C5 | 타입 라벨 `수업 예약` | `14px/21 600` **`rgb(76,78,82)`**(gray-700), 51.73 × 21 |
| C6 | 증감 `-1` | `14px/21 600` **`rgb(0,0,0)`**, 12.64 × 21, 우측 끝 x=407.36 |
| C7 | `수강권 생성` / `+10` | 63.82 × 21 / **24.39 × 21** (x=395.61) |
| C8 | 항목 높이 산식 | 24 + 18 + 21 + 24 = **87** ✓ |

#### C-2. 항목 0건

| # | 대상 | 실측 |
|---|---|---|
| C9 | `li ... py-28 text-gray-700` | 440 × **291.4** @ `0,350.5` |
| C10 | 아이콘 span `mb-5 w-[35px]` | **35 × 33** @ `202.5,462.5` — svg 자체는 **33 × 33** (span이 2px 더 넓고 좌측 정렬) |
| C11 | 문구 `수강권 내역이 없습니다.` | `16px/22.4 700` **`rgb(76,78,82)`** |
| C12 | 높이 산식 | 112(`py-28`, Tailwind 기본) + 33 + **12**(`mb-5` = 커스텀 스케일) + 22.4 + 112 = **291.4** ✓ |

> **C12가 규율 #5를 다시 확인해 준다.** `py-28`은 스케일 밖이라 기본값 112, `mb-5`는 스케일 안이라 20이 아니라 **12**다. 둘이 한 블록에 섞여 있다.

### D. 수강권 등록/추가 시트 (`CourseSheet`)

**등록 시트와 추가 시트는 치수가 완전히 같다. 다른 것은 제목 문구와 버튼 라벨뿐이다**(두 분기를 각각 재서 대조함).

| # | 대상 | 실측 |
|---|---|---|
| D1 | 패널 rect | **420 × 233.4** @ `10,646.6` — `w-[calc(100%-20px)]`, 하단 여백 **20**(`mb-7`) |
| D2 | 패널 padding | **24 / 20 / 28 / 20** (`pt-8` `px-7` `pb-9`) |
| D3 | 패널 radius | **12** (`rounded-lg`) |
| D4 | 패널 상단 테두리 | **1px `rgb(226,232,240)`** (shadcn sheet `side=bottom`의 `border-t`) |
| D5 | 오버레이 | **`rgba(0,0,0,0.8)`** |
| D6 | 제목 | `18px/23.4 700` **black**, 380 × 23.4 @ `30,671.6`, `mb-8`(=24) — 좌측 정렬 |
| D7 | ↳ 문구 | 등록 `등록할 수업횟수` / 추가 `추가할 수업횟수` |
| D8 | 입력 래퍼 `mb-8 text-center` | 380 × 57 @ `30,719` |
| D9 | 입력 | **100 × 57** @ `170,719`, `type=number`, `40px/52 700` black, `py-[2px]`, 밑줄만 |
| D10 | ↳ 밑줄색(포커스) | **`rgb(25,144,255)`**(primary-500). 비포커스는 `border-y-gray-400` |
| D11 | 제출 버튼 | **380 × 52** @ `30,800`, radius **12**, `16px/22.4 700` white |
| D12 | ↳ 비활성 배경 | **`rgb(203,207,211)`**(gray-300) — 입력이 비었거나 500 초과일 때 |
| D13 | ↳ 문구 | 등록 `수강권 등록` / 추가 `수업 횟수 추가` |
| D14 | 닫기 버튼 | **14 × 14** @ `396,667.6` (`absolute right-7 top-7`) |

#### D-2. 500 초과 에러

| # | 대상 | 실측 |
|---|---|---|
| D15 | 에러 문구 `500회 이하로 입력해주세요.` | `mt-3 text-point` → `12px/18 400` **`rgb(255,70,104)`**, 380 × 18 @ `30,758` |
| D16 | `mt-3` | **8** (커스텀 스케일) |
| D17 | 패널 높이 변화 | 233.4 → **259.4** (+26 = 8 + 18) |
| D18 | 버튼 | `501` 입력 상태에서도 **disabled 유지** |

### E. 수강권 삭제 알럿 (`AlertDialog`)

| # | 대상 | 실측 |
|---|---|---|
| E1 | 패널 rect | **400 × 178.4** @ `20,360.8` — `w-[calc(100%-20px*2)]` |
| E2 | padding | **36 / 20 / 36 / 20** (`py-11` = 36, `px-7` = 20) |
| E3 | radius / 테두리 | **8** / **1px `rgb(226,232,240)`** |
| E4 | 내부 gap | **10** (`gap-4`) |
| E5 | 제목 `수강권을 삭제하시겠습니까?` | `16px/22.4 700` `rgb(2,8,23)`, 358 × 22.4, **가운데**, `mb-8`(=24) |
| E6 | 버튼 행 | 2열 grid, gap **8**(`gap-3`), 358 × 48 |
| E7 | `아니요` | **175 × 48**, bg `rgb(242,243,245)`(gray-100), 글자 `rgb(95,97,101)`(gray-600), radius 8, 테두리 1px `rgb(226,232,240)` |
| E8 | `예` | **175 × 48**, bg **`rgb(255,70,104)`**(point), 글자 white, radius 8, 테두리 없음 |

> **S2의 `_DeleteAlert`와 치수가 같다**(폭 400 / 패딩 36·20 / 버튼 48 / radius 8). `h-12`는 커스텀 스케일에서 48이라 S2의 `h-12`와 S3의 `h-[48px]`이 같은 수다. **두 번째 사용처가 생겼으므로 공용 승격 대상**(프로젝트의 "두 번째 사용처에서 승격" 규칙).

---

## 산출물 ④ — 실측하지 못한 것

| 항목 | 이유 | 대안 |
|---|---|---|
| **수강권 없음 분기**(`bg-white py-[88px]`, `등록된 수강권이 없습니다.` + `수강권 등록` 버튼 `h-[37px] w-[112px] rounded-full border border-primary-500 text-primary-500`) | 이 트레이너의 회원이 **2명뿐이고 둘 다 수강권이 있다.** 수강권 없는 회원을 만들려면 회원 추가(뮤테이션)가 필요해 하지 않았다 | 웹 소스(`StudentCourseDetailPage.tsx:302-320`)에서 클래스를 읽어 옮기고, 이 표에 **미실측**으로 남긴다 |
| 무한스크롤 2페이지 | 최대 내역 4건 | 계약 테스트로 요청 모양 고정 |
| 로딩 분기 (`loading.gif` 30×30, `flex h-full items-center justify-center`) | 응답이 즉시 와서 못 잡음 | 소스 기준 |
| 하단 스크롤 감지 영역 (`flex items-center justify-center py-3` + 20×20 gif) | 위와 같음 | 소스 기준. `py-3` = **8** |

---

## 산출물 ⑤ — 서베이가 못 잡은 것 (이번 실측에서 새로 나온 것)

1. **수강권이 없으면 헤더 `+`가 뜬다 — 만료 분기와 같은 조건에 걸려서다.**
   조건이 `course?.totalLessonCnt === course?.completedLessonCnt`인데 course가 없으면
   **`undefined === undefined` → `true`**다. 서베이는 "만료일 때만 렌더"라고 적었지만
   실제로는 **만료 + 수강권없음 + 로딩중** 셋 다 렌더된다(로딩 중에도 `historyData`가
   undefined라 같은 결과). 수강권 없음 화면에서는 헤더 `+`와 본문 `수강권 등록` 버튼이
   **같은 등록 시트를 여는 중복 입구**가 된다.

2. **빈 목록은 `[]`이지 `null`이 아니다**(실측). 웹 타입 선언(`content: … | null`)과
   화면 가드(`content === null || length === 0`) 때문에 서베이는 null을 전제로 적었다.
   실서버는 빈 배열을 준다 — **양쪽 다 파싱되게 만든다.**

3. **`mb-5`가 12, `py-28`이 112.** 한 블록 안에서 커스텀 스케일과 Tailwind 기본이
   섞인다(C12). 계산으로 291.4가 정확히 재현되므로 다른 해석의 여지가 없다.

4. **등록 시트와 추가 시트는 완전히 같은 상자다.** 문구 2개만 파라미터로 받는
   위젯 하나로 충분하다 — 두 벌로 만들 이유가 없다(실측으로 확인).

5. **삭제 알럿은 S2 알럿과 상자만 같고 버튼이 다르다 — 그래서 승격하지 않았다.**
   처음에는 같은 상자로 보였으나 웹 소스를 대조해 보니 버튼이 갈린다.

   | | S2 (`Header.tsx`) | S3 (`StudentCourseDetailPage.tsx`) |
   |---|---|---|
   | 패널 | 기본 | **`py-11`** (둘 다 최종 36) |
   | 버튼 글꼴 | `TITLE_1_SEMIBOLD` → 16/22.4/**600** | **`text-base font-normal`** → 16/**24**/**400** |
   | 버튼 행 | `flex flex-row gap-3` → 폭 **175.55 / 174.45**(테두리 1px 탓, S2 실측 #8) | **`grid grid-cols-2 gap-3`** → 폭 **175 / 175** |

   상자(폭 400 · 패딩 36/20 · 라운드 8 · 테두리 · 제목~버튼 34 · 버튼 높이 48 ·
   간격 8 · gray100/gray600 + point/white · `아니요`/`예`)는 같지만, 공용으로
   올리면 **글꼴과 폭 분배 두 가지를 옵션으로 받아야 한다.** 회원 탈퇴 `Dialog`를
   합치지 않은 것과 같은 판단으로 **세 번째 알럿도 사설로 둔다.** 네 번째가
   생기면 그때 상자만 올리는 것을 재검토한다.

6. **첫 진입 캡처에 401→refresh→재요청이 섞였다.** 토큰 만료 상태로 캡처하면
   골든이 3건이 된다. 재캡처 전에 토큰이 살아 있는지 확인할 것 — `har/README.md`에 적었다.
