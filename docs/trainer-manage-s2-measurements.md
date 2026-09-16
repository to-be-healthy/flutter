# 트레이너 "회원 정보" 화면 (`/trainer/manage/{memberId}`) — 네트워크 + 픽셀 실측

## 측정 개요

| 항목 | 값 |
|------|-----|
| 측정 일시 | 2026-09-16 09:11 ~ 09:16 KST (UTC 2026-09-16T00:11 ~ 00:16) |
| 기준 URL | `https://geonganghaejim.site/trainer/manage/6` (보조: `/trainer/manage/15`) |
| 뷰포트 | **440 × 900** (`document.documentElement.clientWidth` = **440**, 스크롤바 없음, `devicePixelRatio` = 1) |
| 계정 | 영속 프로필에 살아 있던 트레이너 세션 — JWT `userId: healthy-trainer0`, `memberType: TRAINER`, `memberId: 5`, `gymId: 1` (토큰 본문은 기록하지 않음) |
| 도구 | playwright MCP (`mcp__playwright__*`) |
| 폰트 | `Pretendard, ui-sans-serif, system-ui, -apple-system, "system-ui", "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, …` |

### 데이터 상태 (memberId 6 = 차은우)

- `nickName: null`, `fileUrl: null`(프로필 사진 없음 → 기본 아이콘), `ranking: 999`, `memo: "eedd2"`
- `course`: `courseId 3`, `totalLessonCnt 10`, `remainLessonCnt 3`, `completedLessonCnt 10` → **만료 상태로 렌더**(회색 카드)
- `point`: `monthPoint 0`, `totalPoint 85`
- `diet`: 모든 필드 null / `fast:false` → **`등록 식단` 분기**(오늘 식단 3칸 없음)
- `isNonmember: false`

### 데이터 상태 (memberId 15 = rr, 분기 확인용)

- `nickName: null`, `fileUrl: null`, `ranking: 999`, `memo: null`
- `course`: `courseId 2`, `totalLessonCnt 3`, `remainLessonCnt 3`, `completedLessonCnt 0` → **활성 상태로 렌더**(파란 카드)
- `point`: `monthPoint 0`, `totalPoint 0`
- `isNonmember: true`

### 측정 방식

모든 수치는 `browser_evaluate` 안에서 `getBoundingClientRect()` + `getComputedStyle()`로 직접 읽었다. 스냅샷 텍스트에서 추정한 값은 없다. rect 좌표는 뷰포트 기준 CSS px, 소수점 둘째 자리 반올림.

### 안전 확인

- 누르지 않음: `회원 삭제` 알럿의 `예`, 환불 시트의 체크박스, 환불 시트의 `회원 삭제` 버튼, 바로가기 카드 3개, 수강권 카드, 식단 카드, 개인 운동 기록 카드.
- 세션 전체 네트워크 로그에 `DELETE` 요청 **0건**. 나간 것은 `GET /api/v1/trainers/members/{6,15}` 2건과 Next.js RSC 프리페치(`?_rsc=…`) 뿐이다.

---

## 산출물 ① — 네트워크 요청

### 화면 진입 시 `/api/` 요청 — **1건** (기대값과 일치)

```
GET https://geonganghaejim.site/api/v1/trainers/members/6  →  200  (64ms, xhr, application/json)
```

`/api/` 요청은 이 1건이 전부다. 나머지 30건은 정적 자산(`/_next/*`·이미지·폰트)이고, 그 외 `/trainer/manage/6/{reservation,edit/memo,log,course-history,diet,workout,edit/nickname}?_rsc=…` 7건이 찍히는데 이는 **Next.js App Router의 RSC 프리페치**이지 `/api/` 호출이 아니다. (링크가 뷰포트에 들어오면서 자동 발생 — 클릭한 것 아님)

### 실제로 붙은 요청 헤더 (8개)

| 헤더 | 값 |
|------|-----|
| `authorization` | `Bearer …` → HAR에는 `***`로 마스킹 |
| `accept` | `application/json, text/plain, */*` |
| `accept-language` | `ko-KR` |
| `referer` | `https://geonganghaejim.site/trainer/manage/6` |
| `user-agent` | `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) … Chrome/152.0.0.0 Safari/537.36` |
| `sec-ch-ua` | `"Chromium";v="152", "Not?A_Brand";v="24", "Google Chrome";v="152"` |
| `sec-ch-ua-mobile` | `?0` |
| `sec-ch-ua-platform` | `"macOS"` |

**`content-type` 헤더는 붙지 않는다.** 본문 없는 GET이라 요청에 `content-type`이 없다 — Flutter(dio/http) 쪽에서 GET에 `Content-Type: application/json`을 기본으로 붙이고 있다면 웹과 다르게 나가는 것이다. `queryString`·`cookies` 모두 비어 있다(인증은 쿠키가 아니라 `authorization` 헤더).

응답 헤더에는 `content-type: application/json;charset=UTF-8`, `cache-control: no-cache, no-store, max-age=0, must-revalidate`가 붙는다.

### HAR 파일

`/Users/seonwoo_jung/workspace/personal/tobehealthy/flutter/har/trainer-manage-member.har` — 엔트리 1건. 기존 `har/trainer-manage.har`와 동일 구조(`log.version`/`log.creator`/`entries[].request{method,url,httpVersion,headers[],queryString[],cookies[],headersSize,bodySize}`/`response`/`cache`/`timings`). `authorization` 값은 문자열 `***`. 실토큰은 파일에 기록하지 않았다(JWT 패턴 검색 0건으로 검증).

---

## 산출물 ② — 픽셀 실측

> 별도 표기가 없으면 **memberId 6 (차은우)** 화면의 값이다.

### A. 헤더

#### A1. `<header>`

| 항목 | 값 |
|------|-----|
| rect | x 0, y 0, **w 440, h 56** |
| padding | top 16px / right 20px / bottom 16px / left 20px |
| backgroundColor | `rgba(0, 0, 0, 0)` (투명) |
| boxShadow | `none` |
| border | `0px solid rgb(226, 232, 240)` (실선 없음) |
| borderRadius | 0px |
| class | `relative flex h-[56px] w-full flex-none items-center justify-between px-7 py-6` |

#### A2. 뒤로가기

- 태그: **`<button>`** (`<a>` 아님)
- 버튼 rect: x 20, y 18, **w 20, h 20** (top 18 / left 20 / right 40 / bottom 38)
- 버튼 padding: 0px 전부 / backgroundColor 투명 / borderRadius 0px
- 내부 `svg` rect: x 20, y 18, **w 20, h 20** — 버튼과 완전히 동일(패딩 0)
- svg `width`/`height`: `20px` / `20px`, `color: rgb(2, 8, 23)`, `stroke: none`, `fill: none`
- 좌측 여백: 헤더 좌단에서 20px (= header `padding-left`)

#### A3. 제목 `회원 정보`

| 항목 | 값 |
|------|-----|
| rect | x **186.75**, y **16.3**, w **66.5**, h **23.4** |
| fontSize | **18px** |
| lineHeight | **23.4px** (= 130%) |
| fontWeight | **600** |
| color | **`rgb(0, 0, 0)`** (순수 검정 — 본문 텍스트의 `rgb(2,8,23)`과 다름) |
| textAlign | `start` |
| class | `text-[18px]/[130%] font-semibold layout-header-title text-black` |

가로 중앙 정렬이 아니라 **flex `justify-between`의 가운데 아이템**이라 위치가 좌우 버튼 폭에 따라 정해진다. 중심 = (186.75 + 253.25) / 2 = **220.0** → 뷰포트 440의 정확한 중앙이긴 하다.

#### A4. 케밥 (`IconDotsVertical`)

| 항목 | 값 |
|------|-----|
| 버튼 rect | x **396**, y **10**, w **24**, h **36** (right 420 / bottom 46) |
| 버튼 width/height | `24px` / `36px` |
| 버튼 padding | top 18px / right 10px / bottom 18px / left 10px |
| 버튼 borderRadius | **12px** |
| 버튼 backgroundColor | 투명 |
| svg rect | x **406**, y **20**, w **4**, h **16** |
| svg width/height | `4px` / `16px` |
| svg color | `rgb(2, 8, 23)`, `stroke: none`, `fill: none` |

버튼 우단 420 = 440 − 20(header padding-right). 버튼 높이 36이 헤더 56보다 작아 y 10부터 시작(수직 중앙).

---

### B. 케밥 드롭다운 (열기 → 측정 → Escape)

Radix DropdownMenu. 패널은 `[data-radix-popper-content-wrapper]`(fixed, `translate(408px, 50px)`) 안의 `[role="menu"]`이며, 그 자신은 `position: absolute` + `-right-5 top-0` 클래스로 다시 이동한다.

#### B5. 패널

| 항목 | 값 |
|------|-----|
| rect | x **290**, y **50**, **w 130, h 145** (right 420 / bottom 195) |
| width / height | `130px` / `145px` |
| padding | **4px** (top/right/bottom/left 전부) |
| borderRadius | **8px** |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | **`rgba(0, 0, 0, 0.16) 0px 4px 12px 0px`** |
| border | **`1px solid rgb(226, 232, 240)`** |
| position / zIndex | `absolute` / `50` |
| overflow | `hidden` |

패널 안쪽 여백 실측: 첫 항목 top − 패널 top = **5px**, 패널 bottom − 마지막 항목 bottom = **5px**, 첫 항목 left − 패널 left = **5px** (= padding 4px + border 1px).

#### B6. 케밥 버튼 기준 상대 위치

버튼 rect = (left 396, right 420, bottom 46).

| 측정 | 값 |
|------|-----|
| 패널.left − 버튼.left | **−106px** |
| 패널.right − 버튼.right | **0px** (우변 정렬) |
| 패널.top − 버튼.bottom | **+4px** |

#### B7. 항목 3개

세 항목 모두 **w 120 / h 45**, padding `12px 16px`, `fontSize 14px`, `lineHeight 21px`(150%), `fontWeight 600`, `borderRadius 4px`, `backgroundColor` 투명, `display:flex`, `alignItems:center`, `textAlign:start`, `cursor: default`.

| 항목 | 태그 | rect | color |
|------|------|------|-------|
| `별칭 설정` | `<a href="/trainer/manage/6/edit/nickname">` | x 295, y **55**, w 120, h 45 | **`rgb(2, 8, 23)`** |
| `회원 삭제` | `<div>` | x 295, y **100**, w 120, h 45 | **`rgb(2, 8, 23)`** |
| `환불 회원 삭제` | `<div>` | x 295, y **145**, w 120, h 45 | **`rgb(255, 70, 104)`** (`text-point`) |

3개는 `<div role="group" class="flex flex-col">` (rect x 295, y 55, w 120, h 135) 안에 들어 있다.

#### B8. 항목 사이 간격

- `별칭 설정` → `회원 삭제`: **0px**
- `회원 삭제` → `환불 회원 삭제`: **0px**

간격 없이 45px 높이로 맞붙어 쌓인다(그룹 `rowGap: normal`). 구분선도 없다.

---

### C. 회원 삭제 알럿 (**띄우기만 함 — `예` 누르지 않음**)

Radix AlertDialog (`role="alertdialog"`).

#### C9. 패널 / 오버레이

| 항목 | 값 |
|------|-----|
| rect | x **20**, y **360.8**, **w 400, h 178.4** (right 420 / bottom 539.2) |
| width / height | `400px` / `178.398px` |
| position | `fixed`, `top: 450px`, `left: 220px`, `transform: matrix(1, 0, 0, 1, -200, -89.1992)` (= translate(−50%, −50%)) |
| padding | top **36px** / right **20px** / bottom **36px** / left **20px** (`px-7 py-11`) |
| borderRadius | **8px** |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | **`rgba(0, 0, 0, 0.16) 0px 4px 8px 0px`** |
| border | **`1px solid rgb(226, 232, 240)`** |
| rowGap (`gap-4`) | **10px** |
| zIndex | 50 |
| 폭 계산식 | `w-[calc(100%-20px*2)] max-w-[calc(var(--max-width)-20px*2)]` → 440 − 40 = 400 |

**오버레이**: `fixed inset-0 z-50 bg-black/80`, rect 0,0,440,900, `backgroundColor: rgba(0, 0, 0, 0.8)`, `backdropFilter: none`, `opacity: 1`.

#### C10. 제목 `차은우님을 삭제하시겠습니까?`

| 항목 | 값 |
|------|-----|
| rect | x **41**, y **397.8**, w **358**, h **22.4** |
| fontSize | **16px** |
| lineHeight | **22.4px** (140%) |
| fontWeight | **700** |
| color | **`rgb(2, 8, 23)`** |
| textAlign | **`center`** |

제목을 감싼 래퍼 `flex flex-col space-y-2 sm:text-left mb-8 text-center`: rect (41, 397.8, 358, 22.4), `marginBottom: 24px`, `textAlign: center`.

#### C11. 버튼 2개

| 항목 | `아니요` | `예` |
|------|---------|------|
| rect | x **41**, y 454.2, w **175.55**, h **48** | x **224.55**, y 454.2, w **174.45**, h **48** |
| padding | 18px 10px 18px 10px | 18px 10px 18px 10px |
| borderRadius | **8px** | **8px** |
| backgroundColor | **`rgb(242, 243, 245)`** (`bg-gray-100`) | **`rgb(255, 70, 104)`** (`bg-point`) |
| color | **`rgb(95, 97, 101)`** (`text-gray-600`) | **`rgb(255, 255, 255)`** |
| fontSize / lineHeight | 16px / 22.4px | 16px / 22.4px |
| fontWeight | **600** | **600** |
| border | **`1px solid rgb(226, 232, 240)`** | `0px` |
| height | 48px (`h-12`) | 48px |

두 버튼 폭이 1.1px 다른 건 `아니요`에만 `border: 1px`가 있고 둘 다 `w-full` + `gap-3`로 나뉘어서다(175.547 vs 174.453).

#### C12. 간격

| 측정 | 값 |
|------|-----|
| 두 버튼 사이 | **8px** (`gap-3` → `columnGap: 8px`) |
| 제목 아래 ~ 버튼 줄 위 | **34px** (제목 래퍼 `mb-8`=24px + 다이얼로그 `gap-4`=10px) |
| 패널 top ~ 제목 top | **37px** (padding 36 + border 1) |
| 버튼 줄 bottom ~ 패널 bottom | **37px** |

#### C13. Escape

`Escape` 1회로 닫힘 확인 — `[role="alertdialog"]` 0개, `[role="menu"]` 0개, URL은 `/trainer/manage/6` 그대로.

---

### D. 환불 회원 삭제 시트 (**띄우기만 함 — 체크박스·삭제 버튼 누르지 않음**)

Radix Sheet (`role="dialog"`, 하단 고정).

#### D14. 시트 패널 / 오버레이

| 항목 | 값 |
|------|-----|
| rect | x **0**, y **626.6**, **w 440, h 273.4** (bottom 900) |
| width / height | `440px` / `273.398px` |
| position | `fixed`, `top: 626.602px`, `left: 0px`, `bottom: 0px`, `transform: none` (`inset-x-0 bottom-0`) |
| padding | top **20px** / right **20px** / bottom **28px** / left **20px** (`p-7 pb-9`) |
| borderRadius | **`12px 12px 0px 0px`** (`rounded-t-lg`) |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | `rgba(0, 0, 0, 0.16) 0px 4px 8px 0px` |
| rowGap (`gap-4`) | 10px — 단, 자식들이 자체 `mb-*`를 쓰므로 실제 간격은 D19 참고 |
| zIndex | 50 |

**오버레이**: `fixed inset-0 z-50 bg-black/80`, rect 0,0,440,900, `backgroundColor: rgba(0, 0, 0, 0.8)`.

**닫기 X 버튼**(시트 우상단): rect (406, 647.6, **14**, **14**), `position: absolute`, `top: 20px`, `right: 20px`, 내부 svg **14×14** (`stroke="#000"`, `stroke-width="1.5"`).

#### D15. 제목 `환불 회원 삭제하기`

| 항목 | 값 |
|------|-----|
| rect | x 20, y **647.6**, w **400**, h **23.4** |
| fontSize | **18px** |
| lineHeight | **23.4px** (130%) |
| fontWeight | **700** |
| color | `rgb(0, 0, 0)` |
| textAlign | `left` |
| marginBottom | **20px** (`mb-7`) |

#### D16. 설명 문구

`회원 삭제시 회원 정보, 운동 기록, 예약 내역, 수강권 등은 복구되지 않습니다.`

| 항목 | 값 |
|------|-----|
| rect | x 20, y **691**, w **400**, h **48** (2줄) |
| fontSize | **16px** |
| lineHeight | **24px** (150%) |
| fontWeight | 400 |
| color | **`rgb(95, 97, 101)`** (`text-gray-600`) |
| marginBottom | **32px** (`mb-10`) |
| **제목과의 간격** | **20px** |

#### D17. 체크박스 (비활성/미체크 상태 그대로)

`<label class="custom-checkbox mb-10 flex items-center">` rect (20, **771**, 400, **21**), `marginBottom: 32px`, `alignItems: center`.

| 요소 | 값 |
|------|-----|
| `<input type="checkbox">` | `class="peer hidden"`, `display: none`, rect 0×0, **`checked: false`**, `disabled: false` |
| 가짜 박스 `<span>` | rect x **20**, y **771.5**, **w 20, h 20** |
| 박스 borderRadius | **4px** (`rounded-sm`) |
| 박스 backgroundColor | **`rgba(0, 0, 0, 0)`** (투명 — 미체크) |
| 박스 border | **`1px solid rgb(203, 207, 211)`** (`border-gray-300`) |
| 체크 시(미측정) | `peer-checked:border-none peer-checked:bg-primary-500` — 체크하지 않았으므로 실측 없음 |

옆 문구 `위 내용을 확인하였으며, 회원을 삭제합니다.`

| 항목 | 값 |
|------|-----|
| rect | x **48**, y 771, w **238.99**, h **21** |
| fontSize | **14px** |
| lineHeight | **21px** (150%) |
| fontWeight | 400 |
| color | **`rgb(0, 0, 0)`** |
| marginLeft | 8px (`ml-3`) |

**체크박스 – 문구 간격: 8px** (박스 right 40 → 문구 left 48).

#### D18. 하단 버튼 2개

| 항목 | `취소` | `회원 삭제` (**disabled**) |
|------|-------|--------------------------|
| rect | x **20**, y 824, w **190.77**, h **48** | x **218.77**, y 824, w **201.23**, h **48** |
| `disabled` | false | **true** |
| backgroundColor | **`rgb(242, 243, 245)`** (`bg-gray-100`) | **`rgb(203, 207, 211)`** (`disabled:bg-gray-300`) |
| color | **`rgb(95, 97, 101)`** | **`rgb(255, 255, 255)`** |
| fontSize / lineHeight | 16px / 22.4px | 16px / 22.4px |
| fontWeight | **600** | **600** |
| borderRadius | **8px** | **8px** |
| padding | 0px 전부 | 18px 10px 18px 10px |
| border | `0px` | `0px` |
| opacity | 1 | **1** (흐려지지 않고 배경색만 회색) |
| cursor | `pointer` | `default` (`disabled:pointer-events-none`) |

**두 버튼 사이 간격: 8px** (`gap-x-3`). 활성 상태의 `회원 삭제` 색은 누르지 않아 측정 대상이 아니었으므로 미측정.

폭이 190.77 vs 201.23으로 다른 건 두 버튼 모두 `w-full`인데 `취소`에는 `px-4`가 없고 `회원 삭제`에는 있어 flex basis 계산이 달라서다.

#### D19. 블록 사이 세로 간격

| 구간 | 값 |
|------|-----|
| 패널 top ~ 제목 top | **21px** (padding-top 20 + border-top 1) |
| 제목 ~ 설명 | **20px** |
| 설명 ~ 체크박스 | **32px** |
| 체크박스 ~ 버튼 줄 | **32px** |
| 버튼 줄 ~ 패널 bottom | **28px** |

#### D20. Escape

`Escape` 1회로 닫힘 확인 — dialog 0개, menu 0개, URL 유지. 체크박스는 끝까지 미체크였고 `회원 삭제`는 끝까지 `disabled`였다.

---

### E. 본문 — 프로필 행

#### E21. `Layout.Contents` (`<main class="… p-7 pt-8">`)

| 항목 | 값 |
|------|-----|
| rect | x 0, y **56**, w **440**, h **844** |
| paddingTop | **24px** (`pt-8`) |
| paddingRight | **20px** |
| paddingBottom | **20px** |
| paddingLeft | **20px** |
| class | `h-full w-full flex-1 flex-shrink-0 overflow-y-auto hide-scrollbar p-7 pt-8` |

#### E22. 프로필 사진 — **기본 아이콘** (`fileUrl: null`)

| 항목 | 값 |
|------|-----|
| 태그 | **`<svg>`** (`<img>` 아님) |
| rect | x **20**, y **80**, **w 82, h 82** |
| width / height | `82px` / `82px` |
| borderRadius | **`0px`** (원형 클리핑 없음 — svg 내부에 `<circle>`로 원을 그린다) |
| border | `0px solid rgb(226, 232, 240)` (없음) |

**이름과의 gap: 24px** (프로필 행 `gap-x-8` → `columnGap: 24px`, 아바타 right 102 → 이름 열 left 126).

#### E23. 이름 `차은우`

| 항목 | 값 |
|------|-----|
| rect | x **126**, y **106.7**, w **57.05**, h **28.6** |
| fontSize | **22px** |
| lineHeight | **28.6px** (130%) |
| fontWeight | **700** |
| color | **`rgb(2, 8, 23)`** |
| class | `flex gap-x-3 text-[22px]/[130%] font-bold` |

#### E24. 이름 아래 줄 (`nickName` / 구분선 / `랭킹 N`) — **보이지 않음**

`<div class="text-[13px]/[150%] font-normal flex items-center gap-x-2 text-gray-500">`는 **DOM에 존재하지만 완전히 비어 있다.**

- rect: x 126, y 135.3, w 57.05, **h 0** — `childElementCount: 0`, `innerHTML: ""`, `textContent: ""`
- **이유:** `nickName`이 `null`이고 `ranking`이 **999**(= 랭킹 없음 센티넬)라서 별칭·구분선·`랭킹 N` 세 조각 모두 렌더되지 않음. memberId 15도 동일하게 비어 있었다(`ranking: 999`).
- 렌더됐다면 적용될 컨테이너 스타일(빈 상태에서도 computed로 읽힘): `fontSize 13px`, `lineHeight 19.5px`(150%), `fontWeight 400`, `color rgb(134, 136, 141)`(`text-gray-500`), `columnGap 6px`(`gap-x-2`), `display flex`, `alignItems center`.
- **구분선의 width/height/backgroundColor는 측정 실패: 두 계정 모두 `ranking: 999`·`nickName: null`이라 요소 자체가 렌더되지 않음.**

#### E25. 프로필 행

| 항목 | 값 |
|------|-----|
| rect | x **20**, y **80**, w **400**, h **82** |
| **marginBottom** | **16px** (`mb-6`) |
| columnGap | 24px |
| alignItems | center |

---

### F. 바로가기 카드 (3열)

#### F26. 카드

| 항목 | 값 |
|------|-----|
| rect | x **20**, y **178**, **w 400, h 71.5** (bottom 249.5) |
| padding | top **12px** / right **24px** / bottom **12px** / left **24px** (`px-8 py-5`) |
| borderRadius | **12px** |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | **`rgba(0, 0, 0, 0.08) 0px 4px 12px 0px`** |
| **marginBottom** | **16px** (`mb-6`) |
| display / justifyContent | `flex` / `space-between` |

카드를 감싼 래퍼 `<div class="flex items-center justify-center gap-x-3">`의 rect는 (20, 178, 400, **87.5**) = 카드 71.5 + 카드 자신의 `mb-6` 16.

#### F27. 각 열

| 열 | 태그/href | 열 rect | 아이콘 svg (w×h) | 아이콘 rect | 문구 rect |
|----|-----------|---------|------------------|-------------|-----------|
| `예약 내역` | `<a href="/trainer/manage/6/reservation?name=차은우">` | x **44**, y 190, w **48.03**, h **47.5** | **19 × 18** | (58.52, 191) | (44, 218, 48.03, 19.5) |
| `회원 메모` | `<a href="/trainer/manage/6/edit/memo">` | x **195.98**, y 190, w **48.03**, h **47.5** | **21 × 20** | (209.5, 190) | (195.98, 218, 48.03, 19.5) |
| `수업 일지` | `<a href="/trainer/manage/6/log">` | x **347.97**, y 190, w **48.03**, h **47.5** | **20 × 11** | (361.98, 194.5) | (347.97, 218, 48.03, 19.5) |

세 열의 아이콘 래퍼는 모두 `flex h-7 items-center justify-center` = **높이 20px** 고정이고, 그 안의 svg 실제 크기만 위처럼 제각각이다(19×18 / 21×20 / 20×11).

문구 스타일(3열 공통): `fontSize 13px`, `lineHeight 19.5px`(150%), `fontWeight 600`, `color rgb(2, 8, 23)`.
열 스타일(3열 공통): `flex-col`, `alignItems center`, `justifyContent space-between`, `rowGap 8px`.

#### F28. 세로 구분선 2개

| 항목 | 값 |
|------|-----|
| 1번 rect | x **143.51**, y **195.75**, **w 1, h 36** |
| 2번 rect | x **295.49**, y **195.75**, **w 1, h 36** |
| width / height | `1px` / `36px` (`h-11 w-[1px]`) |
| backgroundColor | **`rgb(242, 243, 245)`** (`bg-gray-100`) |

카드 세로 중앙(카드 y 178~249.5의 중심 213.75 = 구분선 중심 213.75)에 맞춰져 있다.

#### F29. 아이콘 – 문구 간격

**8px** (3열 모두 동일, `gap-y-3` → `rowGap: 8px`; 아이콘 래퍼 bottom 210 → 문구 top 218).

---

### G. 수강권 카드

**memberId 6은 "만료" 분기다** (`completedLessonCnt 10 / totalLessonCnt 10`). 활성 분기는 memberId 15에서 확인했고 G35/G36은 memberId 15 기준으로 적었다(6번은 접이식이 아예 없기 때문 — 아래 참고).

#### G30. 카드 (memberId 6, 만료)

| 항목 | 값 |
|------|-----|
| rect | x **20**, y **265.5**, **w 400, h 195.4** (bottom 460.9) |
| borderRadius | **12px** |
| backgroundColor | **`rgb(134, 136, 141)`** (`bg-gray-500` — 만료) |
| padding | **0px** 전부 (`p-0`, 내부 블록이 각자 패딩을 가짐) |
| marginBottom | **16px** |
| rowGap | 0px |

상단 링크 영역: `<a href="/trainer/manage/6/course-history?name=%EC%B0%A8%EC%9D%80%EC%9A%B0">` rect (20, 265.5, 400, **141**).
헤더 블록(`px-6 pb-8 pt-7`): rect (20, 265.5, 400, 93.5), padding top **20px** / right **16px** / bottom **24px** / left **16px**.

> memberId 15(활성)는 같은 rect (20, 265.5, 400, 195.4), 같은 borderRadius 12px, `backgroundColor: rgb(25, 144, 255)` (`bg-primary-500`).

#### G31. 헤더 좌/우

| 항목 | 좌: `건강해짐 홍대점` | 우: `PT 10회 수강권` |
|------|---------------------|---------------------|
| rect | x **36**, y **285.5**, w **81.91**, h **19.5** | x **323.28**, y **285.5**, w **80.72**, h **19.5** |
| fontSize | **13px** | **13px** |
| lineHeight | **19.5px** (150%) | **19.5px** |
| fontWeight | 400 | 400 |
| color | **`rgb(242, 243, 245)`** (`text-gray-100`) | **`rgb(242, 243, 245)`** |

행 자체: rect (36, 285.5, 368, 19.5), `marginBottom: 4px` (`mb-1`), `justify-between`.

#### G32. 큰 글씨

- **전체 텍스트: `10회 PT수강 만료`** (memberId 15는 **`3회 예약할 수 있어요!`**)
- rect: x **36**, y **309**, w **368**, h **26**
- fontSize **20px** / lineHeight **26px**(130%) / fontWeight **700** / color **`rgb(255, 255, 255)`**

#### G33. `PT 진행 횟수 N` + `/M`

전체 텍스트: **`PT 진행 횟수 10/10`**

| 항목 | `PT 진행 횟수 10` (p) | `/10` (span) |
|------|----------------------|--------------|
| rect | x 36, y **359**, w 368, h 19.5 | x **120.71**, y **361**, w **17.79**, h **15.5** |
| fontSize | **13px** | **13px** |
| lineHeight | 19.5px | 19.5px |
| fontWeight | **600** | **400** |
| color | **`rgb(255, 255, 255)`** | **`rgb(203, 207, 211)`** (`text-gray-300`) |
| marginBottom | **6px** (`mb-2`) | — |

진행 블록(`px-6 pb-7`): rect (20, 359, 400, 47.5), padding top 0 / right 16px / bottom 20px / left 16px.

#### G34. Progress 바

| 항목 | 값 |
|------|-----|
| 트랙 rect | x **36**, y **384.5**, **w 368, h 2** |
| 트랙 width / height | `368px` / **`2px`** |
| 트랙 backgroundColor | **`rgba(37, 99, 235, 0.2)`** (`bg-blue-600/20`) |
| 트랙 borderRadius | `9999px` |
| 채워진 부분 backgroundColor | **`rgb(167, 169, 174)`** (`bg-gray-400`, 만료) |
| 채워진 부분 width / transform | `368px` / `matrix(1,0,0,1,0,0)` = translateX(0) → **100% 채움** |

> memberId 15(활성, 0/3): 트랙 동일(`rgba(37,99,235,0.2)`, 368×2), 채워진 부분 `backgroundColor: rgb(255, 255, 255)`(`bg-white`), `transform: matrix(1,0,0,1,-368,0)` = translateX(−100%) → **0% 채움**.

#### G35. 접이식 `{M}월 활동 포인트` 바

**memberId 6 (만료 분기) — 접이식이 아니다.**

- 태그 `<div class="w-full rounded-bl-lg rounded-br-lg bg-gray-400 text-white">` — **`<button>` 없음, svg(화살표) 0개, `cursor: auto`, `data-state` 없음**
- rect (20, **406.5**, 400, **54.4**), `backgroundColor: rgb(167, 169, 174)`, `borderRadius: 0px 0px 12px 12px`
- 내부 `flex items-center justify-between p-6`: padding **16px** 전부
- 좌측 글자 `9월 활동 포인트`: rect (36, 423.95, 81.81, 19.5), **13px / 19.5px / 600 / `rgb(255,255,255)`**
- 우측 `point.png`: rect (363.44, 423.2, **21 × 21**), `borderRadius: 9999px`, 속성 `width="21" height="21"`, src `/images/point.png`
- 우측 숫자 `0`: rect (387.44, 422.5, 10.56, 22.4), **16px / 22.4px / 700 / 흰색**, `marginLeft: 3px`
- **화살표 svg: 없음.** 실제로 눌러봤으나(안전 — `<a>` 바깥) 카드 높이 195.4px 그대로, DOM 변화 없음, URL 변화 없음 → **만료 분기에서는 접이식이 아니다.**

**memberId 15 (활성 분기) — 접이식이다.**

| 항목 | 값 |
|------|-----|
| 바 rect | x 20, y **406.5**, **w 400, h 54.4** |
| 바 backgroundColor | **`rgb(31, 130, 240)`** (`bg-primary-600`) |
| 바 borderRadius | `0px 0px 12px 12px`, padding 0 |
| 트리거 `<button>` | rect (20, 406.5, **400 × 54.4**), `aria-expanded="false"`, `cursor: pointer`, padding 0, `color: rgb(255,255,255)` |
| 내부 `p-6` | padding **16px** 전부, `justify-between`, `alignItems center` |
| 좌측 글자 `9월 활동 포인트` | rect (36, 423.95, 81.81, 19.5), **13px / 19.5px / 600 / 흰색** |
| point.png | rect (342.66, 424.28, **18.84 × 18.84**) — 속성은 `width="21" height="21"`인데 flex 안에서 **18.84px로 줄어들어 렌더됨**, `borderRadius: 9999px` |
| 숫자 `0` | rect (364.49, 422.5, 10.56, 22.4), **16px / 22.4px / 700 / 흰색**, `marginLeft: 3px` |
| 화살표 svg (접힘) | rect (374.27, 426.7, **29.73 × 14**), `height: 14px`, **`width` 속성이 `"current"`(잘못된 값)** 라 computed width가 `29.7266px`로 늘어나 있다. `viewBox="0 0 14 14"`, `stroke="#fff"` |
| 아이콘–숫자 간격 | 3px (`ml-[3px]`) |
| 숫자 래퍼 marginRight | 6px (`mr-2`) |

#### G36. 접이식 펼친 상태 (memberId 15)

펼친 뒤: 바 rect (20, 406.5, 400, **215.1**) (`data-state="open"`), 트리거 h 54.4 → **51.5**, 화살표 rect **14 × 14** (`transform: matrix(-1, 0, 0, -1, 0, 0)` = 180° 회전).

콘텐츠 `<div class="p-6 pt-3">`: rect (20, **458**, 400, **163.6**), padding top **8px** / right 16px / bottom 16px / left 16px, 배경 투명.
`<ul class="flex">`: rect (36, 466, 368, 139.6).

**카드 1 — `이번달 포인트`** (`<a href="/trainer/manage/15/point-history?name=rr">`)

| 항목 | 값 |
|------|-----|
| li / 카드 rect | x **36**, y **466**, **w 130, h 139.6** |
| li width | `130px`, `marginLeft: 0px` |
| padding | **16px** 전부 (`p-6`) |
| borderRadius | **12px** |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | **`none`** |
| rowGap | **20px** (`gap-y-7`) |
| 아이콘 | `point.png` rect (52, 482, **21 × 21**), `borderRadius: 9999px` |
| `이번달 포인트` | rect (52, 482, 98, 21), **13px / 19.5px / 600 / `rgb(0,0,0)`** |
| `0` (큰 숫자) | p rect (52, **523**, 98, 28.6), **22px / 28.6px / 700 / `rgb(0,0,0)`**, `marginBottom: 20px` |
| `점` (단위) | span rect (68.52, 527.55, 11.24, 19.5), **13px / 19.5px / 600 / `rgb(76, 78, 82)`**, `marginLeft: 2px` |
| `누적 0` | span rect (52, **573.1**, 30.91, 14.5), **12px / 18px / 400 / `rgb(167, 169, 174)`** |

**카드 2 — `랭킹`** (링크 없음)

| 항목 | 값 |
|------|-----|
| li / 카드 rect | x **174**, y **466**, **w 130, h 139.6** |
| li | `width: 130px`, **`marginLeft: 8px`** (`ml-3`) |
| padding / borderRadius / bg / rowGap / boxShadow | 카드 1과 동일 (16px / 12px / `rgb(255,255,255)` / 20px / none) |
| 아이콘 | **없음** |
| `랭킹` | rect (190, 482, 98, 19.5), **13px / 19.5px / 600 / `rgb(0,0,0)`** |
| `-` (큰 글씨) | rect (190, **521.5**, 98, 28.6), **22px / 28.6px / 700 / `rgb(0,0,0)`**, `marginBottom: 20px` — `ranking: 999`라 값 대신 `-` |
| `총 2명` | rect (190, **571.6**, 30.8, 14.5), **12px / 18px / 400 / `rgb(167, 169, 174)`** |

**카드 사이 간격: 8px** (카드1 right 166 → 카드2 left 174).

#### G37. 수강권 없음 분기

**측정하지 못한 분기:** memberId 6·15 둘 다 `course`가 존재해 `현재 등록된 수강권이 없습니다.` 카드가 렌더되지 않았다. 해당 카드의 rect/backgroundColor/글자 스타일은 미측정.

---

### H. 식단 카드

#### H38. 카드

| 항목 | 값 |
|------|-----|
| 링크 | `<a href="/trainer/manage/6/diet?month=2026-09">` rect (20, 476.9, 400, 61) |
| 카드 rect | x **20**, y **476.9**, **w 400, h 61** (bottom 537.9) |
| padding | top **20px** / right **16px** / bottom **20px** / left **16px** (`px-6 py-7`) |
| borderRadius | **12px** |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | **`rgba(0, 0, 0, 0.08) 0px 4px 12px 0px`** |
| **marginBottom** | **16px** (`mb-6`) |
| rowGap | 12px (`gap-y-5`) — 자식이 하나뿐이라 실제로 쓰이지 않음 |

#### H39. 헤더

- 좌측 제목: **`등록 식단`** (`오늘 식단` 아님)
  - `<h4>` rect (36, **496.9**, 55.42, **21**), **fontSize 15px / lineHeight 21px(140%) / fontWeight 600 / color `rgb(46, 49, 52)`** (`text-gray-800`)
- 우측: **`식단전체` 텍스트가 아니라 화살표 svg**
  - rect (394, 498.9, **10 × 17**), `width: 10px`, `height: 17px`, `stroke="#5F6165"`, `stroke-width="2"`, `fill: none`
- 헤더 행 rect (36, 496.9, 368, 21), `justifyContent: space-between`, `alignItems: center`

#### H40. 3칸 (아침·점심·저녁)

**측정 실패: 해당 분기에서 렌더되지 않음.** 카드의 자식 요소가 **1개(헤더)뿐**이며 3칸 블록 자체가 DOM에 없다. `diet.dietId`가 `null`이고 `breakfast/lunch/dinner` 모두 `{fast:false, dietFile:null}`이라 `등록 식단` 분기로 떨어진다. 칸 rect·borderRadius·backgroundColor·칸 사이 간격·단식 체크 아이콘 크기 모두 미측정.

#### H41. 분기 표기

**`등록 식단` 분기다.** memberId 6, 15 둘 다 `등록 식단`으로 렌더됐다(각각 `href`의 `month=2026-09`만 다름). `오늘 식단` 분기는 확인하지 못했다.

---

### I. 개인 운동 기록 카드

| 항목 | 값 |
|------|-----|
| 링크 | `<a href="/trainer/manage/6/workout">` rect (20, 553.9, 400, 61) |
| 카드 rect | x **20**, y **553.9**, **w 400, h 61** (bottom 614.9) |
| padding | top **20px** / right **16px** / bottom **20px** / left **16px** |
| borderRadius | **12px** |
| backgroundColor | **`rgb(255, 255, 255)`** |
| boxShadow | `rgba(0, 0, 0, 0.08) 0px 4px 12px 0px` |
| marginBottom | **0px** (마지막 카드) |
| 제목 `개인 운동 기록` | rect (36, **573.9**, 84.91, **21**), **15px / 21px(140%) / 600 / `rgb(46, 49, 52)`** |
| 우측 화살표 svg | rect (394, 575.9, **10 × 17**), `stroke: rgb(95, 97, 101)` (`#5F6165`), `fill: none` |

식단 카드와 완전히 동일한 셸(`h-35 relative flex flex-col rounded-lg bg-white p-6 w-full gap-y-5 px-6 py-7 shadow-sm`)이며 `mb-6`만 빠져 있다.

### 본문 섹션 사이 세로 간격 (정리)

| 구간 | 간격 |
|------|------|
| 프로필 행 → 바로가기 카드 | **16px** (프로필 행 `mb-6`) |
| 바로가기 카드 래퍼 → 수강권 카드 | **0px** (간격 16px는 래퍼 *안쪽* 카드의 `mb-6`로 이미 포함됨) |
| 수강권 카드 → 식단 카드 | **16px** |
| 식단 카드 → 개인 운동 기록 카드 | **16px** (`<a>`엔 마진 없음, 안쪽 카드의 `mb-6`) |
| `main` padding-top → 프로필 행 | **24px** |

---

### J. 다른 회원으로 분기 확인 (memberId 15 = `rr`, GET만)

#### J43. 달라지는 섹션

| 섹션 | memberId 6 (차은우) | memberId 15 (rr) |
|------|--------------------|------------------|
| **수강권 카드 유무** | **있음** — 만료 분기 | **있음** — 활성 분기 |
| 수강권 카드 배경 | `bg-gray-500` = `rgb(134, 136, 141)` | **`bg-primary-500` = `rgb(25, 144, 255)`** |
| 수강권 큰 글씨 | `10회 PT수강 만료` | **`3회 예약할 수 있어요!`** |
| 수강권 헤더 우측 | `PT 10회 수강권` | `PT 3회 수강권` |
| 진행 횟수 | `PT 진행 횟수 10/10` (fill `bg-gray-400`, 100%) | `PT 진행 횟수 0/3` (fill `bg-white`, 0%) |
| **포인트 바** | 정적 `<div>`, `bg-gray-400`, 화살표·버튼 없음 → **접이식 아님** | **접이식** `<button aria-expanded>`, `bg-primary-600` = `rgb(31,130,240)`, 화살표 svg 있음 |
| **식단 카드** | **`등록 식단`** | **`등록 식단`** (동일 — `오늘 식단` 분기 아님) |
| **랭킹 줄** | **안 보임** (`ranking: 999`, `nickName: null` → 컨테이너 h 0) | **안 보임** (동일한 이유) |
| **프로필 사진** | **없음** — 기본 `<svg>` 아이콘 82×82 (`fileUrl: null`) | **없음** — 동일한 기본 `<svg>` 아이콘 82×82 |
| 개인 운동 기록 카드 | 있음 | 있음 |
| 바로가기 카드 3열 | 동일 | 동일 |
| 헤더/케밥 | 동일 | 동일 (버튼 2개 = 뒤로가기 + 케밥) |
| 카드 rect | (20, 265.5, 400, 195.4) | **동일** (20, 265.5, 400, 195.4) |

전체 레이아웃 좌표(프로필 80, 바로가기 178, 수강권 265.5, 식단 476.9, 운동기록 553.9)는 두 회원이 **완전히 동일**하다.

#### J44. memberId 15 진입 시 `/api/` 요청

```
GET https://geonganghaejim.site/api/v1/trainers/members/15  →  200
```

**1건으로 memberId 6과 같은 모양이다.** 헤더 구성도 동일(`authorization`/`accept`/`accept-language`/`referer`/`user-agent`/`sec-ch-ua*` 8개, **`content-type` 없음**). 나머지는 RSC 프리페치 7건(6번과 동일 패턴 + `point-history` — 접이식을 펼쳐 링크가 생겼기 때문).

---

### K. 응답 본문

이미 받은 응답을 `browser_network_request(part="response-body")`로 읽은 것이며, `fetch`를 다시 쏘지 않았다.

#### K45-1. `GET /api/v1/trainers/members/6`

```json
{
  "message": "학생 상세가 조회되었습니다.",
  "data": {
    "memberId": 6,
    "name": "차은우",
    "nickName": null,
    "fileUrl": null,
    "memo": "eedd2",
    "ranking": 999,
    "lessonDt": null,
    "lessonStartTime": null,
    "diet": {
      "dietId": null,
      "member": null,
      "likeCnt": null,
      "commentCnt": null,
      "createdAt": null,
      "updatedAt": null,
      "eatDate": null,
      "liked": false,
      "feedbackChecked": false,
      "breakfast": { "fast": false, "dietFile": null },
      "lunch": { "fast": false, "dietFile": null },
      "dinner": { "fast": false, "dietFile": null }
    },
    "course": {
      "courseId": 3,
      "totalLessonCnt": 10,
      "remainLessonCnt": 3,
      "completedLessonCnt": 10,
      "createdAt": "2026-03-13T14:44:48"
    },
    "point": { "searchDate": "2026-09", "monthPoint": 0, "totalPoint": 85 },
    "rank": { "ranking": 999, "lastMonthRanking": 999, "totalMemberCnt": 2 },
    "gym": { "id": 1, "name": "건강해짐 홍대점" },
    "isNonmember": false
  },
  "status": "OK"
}
```

#### K45-2. `GET /api/v1/trainers/members/15`

```json
{
  "message": "학생 상세가 조회되었습니다.",
  "data": {
    "memberId": 15,
    "name": "rr",
    "nickName": null,
    "fileUrl": null,
    "memo": null,
    "ranking": 999,
    "lessonDt": null,
    "lessonStartTime": null,
    "diet": {
      "dietId": null,
      "member": null,
      "likeCnt": null,
      "commentCnt": null,
      "createdAt": null,
      "updatedAt": null,
      "eatDate": null,
      "liked": false,
      "feedbackChecked": false,
      "breakfast": { "fast": false, "dietFile": null },
      "lunch": { "fast": false, "dietFile": null },
      "dinner": { "fast": false, "dietFile": null }
    },
    "course": {
      "courseId": 2,
      "totalLessonCnt": 3,
      "remainLessonCnt": 3,
      "completedLessonCnt": 0,
      "createdAt": "2026-04-11T19:06:49.229525"
    },
    "point": { "searchDate": "2026-09", "monthPoint": 0, "totalPoint": 0 },
    "rank": { "ranking": 999, "lastMonthRanking": 999, "totalMemberCnt": 2 },
    "gym": { "id": 1, "name": "건강해짐 홍대점" },
    "isNonmember": true
  },
  "status": "OK"
}
```

두 응답의 **스키마는 완전히 동일**하다(키 집합·중첩 구조 모두). 차이는 값뿐이다. `diet` 객체는 `dietId`가 null이어도 `breakfast`/`lunch`/`dinner` 세 키가 항상 존재하고 각각 `{fast, dietFile}` 형태다 — Flutter 픽스처에서 `diet`를 nullable로 두면 안 되고, 내부 필드만 nullable로 잡아야 한다.

---

## 예상과 달랐던 값

1. **식단 카드가 `오늘 식단`이 아니라 `등록 식단` 분기다 (H39/H41).** 두 회원 모두 그랬다. 그 결과 **아침·점심·저녁 3칸이 DOM에 아예 없다**(카드 자식 1개 = 헤더뿐, 카드 높이 61px). 브리프가 기대한 "3칸 rect/간격/단식 체크 아이콘"은 이 분기에서 측정 불가.
2. **헤더 우측이 `식단전체` 텍스트가 아니라 10×17 화살표 svg다 (H39).** `개인 운동 기록` 카드의 화살표와 완전히 같은 요소다.
3. **`{M}월 활동 포인트` 바가 항상 접이식인 게 아니다 (G35).** 수강권 **만료**(memberId 6)면 `<button>`도 화살표 svg도 없는 **정적 `<div>`**로 렌더된다(`bg-gray-400`, cursor auto). 실제로 눌러도 아무 변화가 없었다. 접이식은 **활성 수강권**(memberId 15)에서만 나타나며 배경도 `bg-primary-600`로 다르다.
4. **이름 아래 줄이 통째로 비어 있다 (E24).** 컨테이너 `<div>`는 렌더되지만 자식 0개, height **0px**. `ranking: 999` + `nickName: null`이 원인이고, **두 계정 모두 `ranking: 999`**라 구분선·`랭킹 N`을 한 번도 볼 수 없었다.
5. **뒤로가기가 `<a>`가 아니라 `<button>`이다 (A2).** 패딩 0으로 **히트 영역이 svg와 똑같은 20×20**뿐이다(케밥은 24×36으로 패딩이 있는 것과 대조적). 모바일 탭 타깃으로는 작다.
6. **케밥 드롭다운 항목 사이 간격이 0px다 (B8).** 구분선도 없이 45px 항목 3개가 그대로 맞붙는다. `회원 삭제`와 `환불 회원 삭제`가 붙어 있어 오클릭 위험이 실제로 있다.
7. **드롭다운 패널이 케밥 버튼 우변에 정확히 맞춰진다 (B6).** `패널.right − 버튼.right = 0`, `패널.top − 버튼.bottom = 4`. 클래스는 `-right-5`지만 popper wrapper의 translate와 합쳐져 최종 오프셋은 0이다.
8. **`아니요` 버튼에만 `1px solid rgb(226,232,240)` 테두리가 있다 (C11).** 그 탓에 두 버튼 폭이 175.55 vs 174.45로 1.1px 어긋난다. 시각적으로 같은 폭을 기대했다면 다르다.
9. **알럿과 시트의 boxShadow 블러가 다르다.** 알럿은 `0 4px 8px rgba(0,0,0,0.16)`, 드롭다운 패널은 `0 4px 12px rgba(0,0,0,0.16)`, 일반 카드는 `0 4px 12px rgba(0,0,0,0.08)`. 세 종류가 섞여 있다.
10. **환불 시트의 `회원 삭제` 비활성은 `opacity`가 아니라 배경색 교체다 (D18).** `opacity: 1` 그대로, `background`만 `rgb(203,207,211)`. Flutter에서 `Opacity`로 흉내 내면 다르게 보인다.
11. **시트의 두 버튼 폭이 190.77 vs 201.23으로 크게 다르다 (D18).** `취소`엔 `px-4`가 없고 `회원 삭제`엔 있어서 flex 분배가 어긋난 결과다. 디자인 의도라기보단 클래스 불일치로 보인다.
12. **활성 분기 포인트 바의 화살표 svg에 `width="current"`라는 잘못된 속성이 들어 있다 (G35).** 접힘 상태에서 computed width가 **29.73px**로 부풀고, 펼치면 14×14로 정상화된다. 같은 요소의 `widht="14"`(오타) 속성도 함께 있다. 명백한 마크업 버그.
13. **같은 포인트 아이콘(`point.png`, 속성 21×21)이 위치마다 다르게 렌더된다.** 만료 바 21×21, 활성 접이식 바 **18.84×18.84**(flex 축소), 펼친 카드 안 21×21.
14. **Progress 트랙 색이 카드 배경과 무관하게 항상 `rgba(37, 99, 235, 0.2)`(`bg-blue-600/20`)다 (G34).** 회색 만료 카드 위에서도 파란 계열 트랙이 그대로 쓰인다.
15. **`p-7 pt-8`이 28px/32px가 아니라 20px/24px다 (E21).** 이 프로젝트의 Tailwind spacing scale이 기본값과 다르게 커스터마이즈돼 있다(`p-6`=16px, `p-7`=20px, `gap-x-8`=24px, `mb-10`=32px, `py-11`=36px 등). Flutter로 옮길 때 클래스명에서 숫자를 유추하면 전부 틀린다 — **반드시 computed 값을 써야 한다.**
16. **화면 진입 시 `/api/` 요청은 1건이 맞지만, RSC 프리페치가 7건 따라붙는다.** 정적 자산 필터만으로는 걸러지지 않으니 HAR 비교 테스트를 짤 때 `/api/` 접두사로 명시적으로 필터링해야 한다.

---

## 측정하지 못한 분기 / 항목

| 항목 | 사유 |
|------|------|
| **E24** — `nickName` / 구분선 / `랭킹 N`의 rect·스타일, 구분선 width/height/backgroundColor | memberId 6·15 모두 `nickName: null`, `ranking: 999` → 요소가 렌더되지 않음. 별칭이 있고 랭킹이 999가 아닌 회원이 필요. |
| **G37** — `현재 등록된 수강권이 없습니다.` 카드 | 두 회원 모두 `course`가 존재. 수강권 없는 회원 필요. |
| **H40** — 아침·점심·저녁 3칸의 rect/borderRadius/backgroundColor/간격, 사진·단식·빈 박스 구분, 단식 체크 아이콘 크기·글자 스타일 | 두 회원 모두 `등록 식단` 분기라 3칸 블록이 DOM에 없음. 오늘 식단이 등록된 회원 필요. |
| **G36 (memberId 6)** — 만료 분기의 접이식 내부 카드 | 만료 분기엔 접이식 자체가 없음(정적 바). memberId 15의 활성 분기로 대체 측정함. |
| **G35/G36의 접이식을 memberId 6에서 측정** | 위와 동일 — 6번은 접이식이 아니다. |
| **C11** — `예` 버튼의 hover/active/pressed 상태 | 누르면 안 되는 버튼이라 기본 상태만 측정. |
| **D17** — 체크박스 **체크된** 상태(`peer-checked:bg-primary-500`, `border-none`)의 실측값 | 안전 규칙상 체크 금지. 클래스로만 확인. |
| **D18** — `회원 삭제` 버튼의 **활성** 상태 배경/색 | 체크박스를 눌러야 활성화되므로 측정 불가. 비활성 상태만 기록. |
| **프로필 사진(`fileUrl`)이 있는 회원의 `<img>` rect/borderRadius/border** | 두 회원 모두 `fileUrl: null` → 기본 `<svg>` 아이콘만 확인. |
| **`오늘 식단` 분기의 헤더 우측 `식단전체` 텍스트** | `등록 식단` 분기만 관측됨. |
| **`랭킹` 카드에 실제 순위가 찍힌 모습** | `ranking: 999` → `-`로 렌더. |
