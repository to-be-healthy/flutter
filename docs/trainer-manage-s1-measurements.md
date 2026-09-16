# `/trainer/manage` (트레이너 "나의 회원") 픽셀 실측

- **측정 일시**: 2026-09-15
- **측정 도구**: Playwright MCP (Chromium), `getBoundingClientRect()` + `getComputedStyle()`
- **URL**: `https://geonganghaejim.site/trainer/manage`
- **계정**: 브라우저 영속 프로필에 트레이너 세션이 이미 살아 있어 로그인 없이 진입 (`건강해짐 홍대점`)
- **뷰포트**: `window.innerWidth = 440`, `window.innerHeight = 900`, `document.documentElement.clientWidth = 440`, `devicePixelRatio = 1`
  → **스크롤바 폭 0px. 440이 그대로 확보됨(425 같은 축소 없음).**
- **`--max-width`**: `440px`
- **데이터 상태**: 회원 2명 (`차은우` 잔여 3/10, `rr` 잔여 3/3)
- 모든 수치는 **실측 computed 값**이다. 추정값은 포함하지 않았고, 못 잰 항목은 "측정 실패"로 표기했다.

> **Tailwind 스페이싱 스케일 주의**: 이 프로젝트는 기본 Tailwind 스케일이 아니다. 실측 결과
> `px-7 = 20px`, `px-6 = 16px`, `py-7 = 20px`, `py-6 = 16px`, `py-5 = 12px`, `py-4 = 10px`,
> `px-5 = 12px`, `px-4 = 10px`, `px-3 = 8px`, `px-11 = 36px`, `pb-8 = 24px`,
> `gap-x-6 = 16px`, `gap-y-4 = 10px`, `gap-y-5 = 12px`, `gap-y-11 = 36px`, `gap-2 = 6px`, `gap-x-1 = 4px`, `gap-y-2 = 6px`,
> `mb-4 = 10px`, `mt-1 = 4px`, `h-7/w-7 = 20px`, `h-11 = 36px`, `rounded-sm = 4px`, `rounded-md = 8px`, `rounded-lg = 12px`.
> 클래스명만 보고 기본 스케일(4px 단위)로 환산하면 전부 틀린다.

---

## A. 헤더

`<header class="relative flex h-[56px] w-full flex-none items-center justify-between px-7 py-6 bg-transparent">`

| # | 항목 | 측정값 |
|---|------|--------|
| A1 | header width × height | **440 × 56** px |
| A1 | header padding | top `16px` / right `20px` / bottom `16px` / left `20px` |
| A1 | header backgroundColor | `rgba(0, 0, 0, 0)` (투명) |
| A1 | header borderRadius / boxShadow | `0px` / `none` |
| A2 | `+` 버튼 width × height | **20 × 20** px (`h-7 w-7` → 20px) |
| A2 | `+` 버튼 위치 | left `400`, top `18` (right `420`, bottom `38`) |
| A2 | `+` 버튼 padding / borderRadius | `0px` 전부 / `12px` |
| A2 | `+` 버튼 안 svg | **17 × 16** px @ left `401.5`, top `20` (버튼보다 크고 비대칭) |
| A3 | 제목 `나의 회원` fontSize | `18px` |
| A3 | 제목 lineHeight | `23.4px` (= 130%) |
| A3 | 제목 fontWeight | `700` |
| A3 | 제목 color | `rgb(2, 8, 23)` |
| A3 | 제목 rect | `66.38 × 23.41` px @ left `186.81`, top `16.3` |
| A3 | 제목 fontFamily | `Pretendard, ui-sans-serif, system-ui, …` |

좌측 뒤로가기 `<a>` + svg: **20 × 20** px @ left `20`, top `18` (참고값).

---

## B. 검색바

| # | 항목 | 측정값 |
|---|------|--------|
| B4 | 바깥 래퍼 `flex h-fit w-full px-7 py-6` rect | **440 × 76** px @ `0, 56` |
| B4 | 바깥 래퍼 padding | top `16px` / right `20px` / bottom `16px` / left `20px` |
| B5 | 회색 박스 `rounded-md bg-gray-200 px-6 py-4` rect | **400 × 44** px @ `20, 72` |
| B5 | 회색 박스 borderRadius | `8px` |
| B5 | 회색 박스 backgroundColor | `rgb(222, 225, 230)` |
| B5 | 회색 박스 padding | top `10px` / right `16px` / bottom `10px` / left `16px` |
| B6 | 돋보기 버튼 width × height | **20 × 20** px @ `36, 82` |
| B6 | 돋보기 버튼 안 svg | **20 × 20** px @ `36, 82` (버튼과 정확히 동일) |
| B7 | `input` rect | **348 × 24** px @ `56, 82` |
| B7 | `input` padding | top `0px` / right `12px` / bottom `0px` / left `12px` (`px-5` = 12px) |
| B7 | `input` fontSize / lineHeight | `16px` / `24px` |
| B7 | `input` color | `rgb(2, 8, 23)` |
| B8 | placeholder fontSize (`::placeholder`) | `16px` |
| B8 | placeholder lineHeight (`::placeholder`) | **`normal`** ⚠️ 아래 주석 참조 |
| B8 | placeholder color | `rgb(134, 136, 141)` (gray-500) |
| B8 | placeholder fontWeight | `400` |

> ⚠️ **B8 lineHeight 주의**: 클래스는 `placeholder:text-[16px]/[150%]`인데 `getComputedStyle(input, '::placeholder').lineHeight`가
> **`normal`**로 나온다. 같은 호출에서 fontSize(`16px`)·color(gray-500)는 유틸리티대로 정상 반영되므로 유틸리티 자체는 적용 중이다.
> 440px·1920px 두 뷰포트에서 동일하게 `normal`이 나왔다. 다만 Chromium이 `::placeholder`의 line-height를 계산값으로 노출하지 않는
> 제약일 가능성도 있어, "150%가 적용되지 않았다"고 단정하지는 않는다. **실측 결과는 `normal`.**
> 참고로 `input` 자체의 lineHeight는 `24px`(150%)이다.

---

## C. 카운트 + 정렬 행

| # | 항목 | 측정값 |
|---|------|--------|
| C9 | 행 `mb-4 flex items-center justify-between` rect | **400 × 36** px @ `20, 136` |
| C9 | 행 marginBottom | **`10px`** (`mb-4`) |
| C9 | 행 padding | 전부 `0px` |
| C9 | 부모 `hide-scrollbar mt-1 … px-7` rect | **440 × 683** px @ `0, 136` |
| C9 | 부모 marginTop | **`4px`** (`mt-1`) |
| C9 | 부모 padding | top `0px` / right `20px` / bottom `0px` / left `20px` |
| C10 | `총 2명` `<p>` rect | `36.17 × 21` px @ `20, 143.5` |
| C10 | `<p>` fontSize / lineHeight | `14px` / `21px` (150%) |
| C10 | `<p>` fontWeight / color | `400` / `rgb(2, 8, 23)` |
| C10 | 숫자 `<span>` rect | `8.44 × 16` px @ `35.63, 145.5` (인라인 span이라 높이가 line box 21px가 아닌 **16px**로 잡힘) |
| C10 | 숫자 `<span>` fontSize / lineHeight | `14px` / `21px` |
| C10 | 숫자 `<span>` fontWeight / color | `600` / `rgb(25, 144, 255)` |
| C11 | 정렬 트리거 rect | **73.97 × 36** px @ `346.03, 136` |
| C11 | 정렬 트리거 padding | top `18px` / right `10px` / bottom `18px` / left `10px` |
| C11 | 정렬 트리거 borderRadius | `12px` |
| C11 | 정렬 트리거 backgroundColor | `rgba(0, 0, 0, 0)` |
| C11 | 아이콘(svg) width × height | **13 × 14** px @ `356.03, 147` |
| C11 | 아이콘–글자 gap | **`4px`** (computed `column-gap: 4px`, 실측 rect 간격도 `4.00`) |
| C11 | 라벨 `기본 순` rect (Range 실측) | `36.97 × 15` px @ `373.03, 146.25` |
| C11 | 라벨 fontSize / lineHeight | `13px` / `19.5px` (150%) |
| C11 | 라벨 color / fontWeight | `rgb(2, 8, 23)` / `400` |

> `py-[18px]` 18+18 = 36 이고 `h-11`(36px)과 같아, 콘텐츠 박스 높이는 0이 되고 아이콘·라벨은 오버플로로 렌더된다.

---

## D. 정렬 드롭다운 (Radix DropdownMenu)

트리거 클릭 → `data-state="open"` 상태에서 측정. 애니메이션 종료 확인(`transform: none`, `opacity: 1`).
트리거 rect: `73.97 × 36` @ `346.03, 136` (bottom `172`, right `420`).

| # | 항목 | 측정값 |
|---|------|--------|
| D12 | 패널 width × height | **96 × 100** px |
| D12 | 패널 padding | `4px` (상하좌우 동일, `p-1`) |
| D12 | 패널 borderRadius | `8px` |
| D12 | 패널 backgroundColor | `rgb(255, 255, 255)` |
| D12 | 패널 boxShadow | `rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.16) 0px 4px 12px 0px` (유효 그림자는 셋째 레이어) |
| D12 | 패널 border | `1px solid rgb(226, 232, 240)` |
| D13 | 패널 화면 좌표 | left **`315`**, top **`180`** (right `411`, bottom `280`) |
| D13 | 패널.left − 트리거.left | **`-31.03`** px |
| D13 | 패널.top − 트리거.bottom | **`+8`** px |
| D13 | (참고) 패널.right − 트리거.right | `-9` px |
| D14 | `기본 순` 항목 rect | **86 × 45** px @ `320, 185` |
| D14 | `기본 순` padding | top `12px` / right `16px` / bottom `12px` / left `16px` |
| D14 | `기본 순` fontSize / lineHeight | `14px` / `21px` (150%) |
| D14 | `기본 순` fontWeight / color | `600` / **`rgb(0, 0, 0)`** (선택 상태, `text-black`) |
| D14 | `기본 순` borderRadius | `4px` |
| D14 | `랭킹 순` 항목 rect | **86 × 45** px @ `320, 230` |
| D14 | `랭킹 순` padding | top `12px` / right `16px` / bottom `12px` / left `16px` |
| D14 | `랭킹 순` fontSize / lineHeight | `14px` / `21px` |
| D14 | `랭킹 순` fontWeight / color | `600` / **`rgb(134, 136, 141)`** (비선택, `text-gray-500`) |
| D15 | 항목 사이 간격 (2번째.top − 1번째.bottom) | **`0`** px (간격 없이 맞붙음) |
| D16 | 닫기 | `Escape`로 닫음 — 확인됨 (`[role="menu"]` 제거) |

> 구조 메모: Radix popper wrapper는 `position: fixed; transform: translate(383px, 176px)`에 놓이고,
> 패널 자체가 `absolute -right-9 top-1 w-[96px]`로 그 기준에서 다시 오프셋된다. 즉 최종 위치는 popper 계산값이 아니라
> 이 `-right-9 / top-1` 오버라이드가 결정한다. 높이 100px = border 1+1 + padding 4+4 + 항목 45×2.

---

## E. 회원 카드 (첫 번째 카드 = `차은우`)

| # | 항목 | 측정값 |
|---|------|--------|
| E17 | 카드 `h-[72px] … px-6 py-7` rect | **400 × 72** px @ `20, 182` |
| E17 | 카드 borderRadius | `12px` |
| E17 | 카드 backgroundColor | `rgb(255, 255, 255)` |
| E17 | 카드 padding | top `20px` / right `16px` / bottom `20px` / left `16px` |
| E17 | 카드 boxShadow | `none` |
| E17 | (래핑 `<button>`) rect | `400 × 72` @ `20, 182`, padding 전부 `0px` |
| E18 | 카드 사이 세로 간격 | **`10px`** (2번째.top `264` − 1번째.bottom `254`; computed `row-gap: 10px`) |
| E19 | 리스트 컨테이너 `gap-y-4 pb-8` rect | **400 × 178** px @ `20, 182` |
| E19 | 리스트 컨테이너 paddingBottom | **`24px`** (`pb-8`) |
| E20 | 기본 프로필 아이콘 svg | **32 × 32** px @ `36, 202` (computed `width/height: 32px`) |
| E21 | 아바타–이름 블록 gap | **`16px`** (computed `column-gap: 16px`, rect 실측 `16.00`) |
| E21 | 좌측 블록 `flex items-center gap-x-6` rect | `128.78 × 32` @ `36, 202` |
| E21 | 이름 블록 `flex flex-col text-left` rect | `80.78 × 22.41` @ `84, 206.8` |
| E22 | 이름 `<p>` fontSize / lineHeight | `16px` / `22.4px` (140%) |
| E22 | 이름 `<p>` fontWeight / color | `700` / `rgb(2, 8, 23)` |
| E22 | 이름 `<p>` rect | `41.48 × 22.41` @ `84, 206.8` |
| E23 | **`가입` 배지 rect** | **`33.3 × 22.41`** px @ `131.48, 206.8` |
| E23 | 배지 padding | top `1.5px` / right `8px` / bottom `1.5px` / left `8px` (`px-3` = 8px) |
| E23 | 배지 borderRadius | `4px` (`rounded-sm`) |
| E23 | 배지 backgroundColor | `rgb(226, 241, 255)` (blue-50) |
| E23 | 배지 color | `rgb(25, 144, 255)` (primary) |
| E23 | 배지 fontSize | `10px` |
| E23 | **배지 lineHeight (상속값)** | **`15px`** |
| E23 | 배지 fontWeight / display | `400` / `flex` (`align-items: center`, `justify-content: center`) |
| E24 | 이름–배지 gap | **`6px`** (computed `column-gap: 6px`, rect 실측 `6.00`) |
| E25 | `잔여` span fontSize / lineHeight | `13px` / `19.5px` (150%) |
| E25 | `잔여` span fontWeight / color | `400` / `rgb(25, 144, 255)` |
| E25 | `잔여` span marginRight | **`2px`** |
| E25 | `잔여` span rect | `22.48 × 19.5` @ `351.48, 208.25` |
| E25 | 숫자 `3` span fontSize / lineHeight | `14px` / `21px` |
| E25 | 숫자 `3` span fontWeight / color | `600` / `rgb(25, 144, 255)` |
| E25 | 숫자 `3` span rect | `8.86 × 21` @ `375.97, 207.5` |
| E25 | `/10` span fontSize / lineHeight | `14px` / `21px` |
| E25 | `/10` span fontWeight / color | `400` / `rgb(167, 169, 174)` (gray-400) |
| E25 | `/10` span rect | `19.17 × 21` @ `384.83, 207.5` |
| E26 | 우측 블록 `flex items-center` rect | **`52.52 × 32`** px @ `351.48, 202` |

### E23 배지 line-height 추적 (요청된 확인 사항)

`text-[10px]`는 font-size만 설정하므로 line-height는 상속된다. 조상 체인을 전부 실측했다:

| 요소 | fontSize | lineHeight | 비율 |
|------|----------|-----------|------|
| `span` (배지) | `10px` | **`15px`** | 1.500 |
| `div.flex.flex-row.gap-2` | `16px` | `24px` | 1.500 |
| `div.flex.flex-col.text-left` | `16px` | `24px` | 1.500 |
| `div.flex.items-center.gap-x-6` | `16px` | `24px` | 1.500 |
| 카드 `div.h-[72px]` | `16px` | `24px` | 1.500 |
| `button` / 리스트 / main / body / **html** | `16px` | `24px` | 1.500 |

→ 체인 전 구간 비율이 정확히 **1.500**이고, 10px 요소에서 `15px`로 재계산되므로
**상속되는 line-height는 길이값(24px)이 아니라 단위 없는 `1.5`** 다. 즉 배지의 실효 line-height = `10px × 1.5 = 15px`.

**배지 높이가 15+1.5+1.5 = 18px가 아니라 22.41px인 이유**: 배지는 부모 `div.flex.flex-row.gap-2`의 flex item이고
그 부모의 `align-items`가 `normal`(= stretch)이라, 형제인 이름 `<p>`(높이 22.41px)에 맞춰 세로로 늘어난다.
콘텐츠 기준 높이는 `18px`, 실제 렌더 높이는 `22.41px`.

---

## F. 검색 결과 없음 상태 (`zzzz` 입력)

검색창에 `zzzz` 입력 → `총 0명`, 빈 상태 블록 렌더 확인.

| # | 항목 | 측정값 |
|---|------|--------|
| F27 | 컨테이너 `mb-[30%] flex h-full flex-col items-center justify-center` rect | **400 × 517** px @ `20, 182` |
| F27 | 컨테이너 **marginBottom (`mb-[30%]`의 실제 px)** | **`120px`** |
| F27 | 컨테이너 height | `517px` |
| F27 | (30% 기준) 부모 콘텐츠 폭 | `400px` → 30% × 400 = 120px (퍼센트 마진은 **포함 블록의 높이가 아니라 폭** 기준) |
| F27 | `alert_circle` 아이콘 rect | **`35 × 36`** px @ `202.5, 405.3` (computed `width: 35px`, `height: 36px` — **정사각형 아님**) |
| F27 | `검색 결과가 없습니다.` fontSize / lineHeight | `16px` / `22.4px` (140%) |
| F27 | 텍스트 fontWeight / color | `700` / `rgb(134, 136, 141)` (gray-500) |
| F27 | 텍스트 rect | `136.34 × 22.41` @ `151.83, 453.3` |
| F27 | 아이콘–글자 gap | **`12px`** (computed `row-gap: 12px`, rect 실측 `12.00`) |
| F27 | 내부 래퍼 `flex flex-col items-center gap-y-5` rect | `136.34 × 70.41` @ `151.83, 405.3` |
| F27 | 바깥 래퍼 `flex flex-col items-center gap-y-11` rect | `136.34 × 70.41` @ `151.83, 405.3` (computed `row-gap: 36px`이지만 **자식이 1개라 실효 없음**) |
| F28 | 복원 | 검색창 비우고 `총 2명` / 카드 2개 복귀 확인 |

---

## G. 회원 추가 다이얼로그 (헤더 `+` 버튼)

애니메이션 종료 확인(`data-state="open"`, `opacity: 1`, transform이 최종 `translate(-220px, 0)`).

| # | 항목 | 측정값 |
|---|------|--------|
| G29 | 다이얼로그 패널 rect | **440 × 149.5** px |
| G29 | 패널 top / left | `0` / `0` (CSS는 `top: 0px; left: 220px` + `translateX(-220px)`) |
| G29 | 패널 padding | 전부 `0px` (`p-0`) |
| G29 | 패널 borderRadius | **`0px`** |
| G29 | 패널 backgroundColor | `rgb(255, 255, 255)` |
| G29 | 패널 boxShadow | `rgba(0,0,0,0) 0 0 0 0, rgba(0,0,0,0) 0 0 0 0, rgba(0, 0, 0, 0.16) 0px 4px 8px 0px` |
| G29 | 패널 border | `1px solid rgb(226, 232, 240)` (그래서 내부 콘텐츠 폭이 438) |
| G29 | 패널 grid gap | `10px` (`gap-4`) |
| G30 | 오버레이 backgroundColor | **`rgba(0, 0, 0, 0.8)`** (`bg-black/80`), opacity `1`, rect `440 × 900` @ `0,0` |
| G31 | 다이얼로그 헤더 rect | **438 × 56** px @ `1, 1` |
| G31 | 헤더 padding | top `16px` / right `20px` / bottom `16px` / left `20px` |
| G31 | 헤더 flexDirection | **`row-reverse`** |
| G31 | 닫기 버튼 width × height | **`20 × 36`** px @ `399, 11` (`h-11` = 36px, 폭은 svg 20px에 맞춰짐) |
| G31 | 닫기 버튼 안 svg | **`20 × 20`** px @ `399, 19` |
| G31 | 제목 `회원 추가` fontSize / lineHeight | `18px` / `23.4px` (130%) |
| G31 | 제목 fontWeight / color | `700` / `rgb(2, 8, 23)` |
| G31 | 제목 rect | `66.38 × 23.41` @ `196.81, 17.3` |
| G31 | 더미 div `w-[40px]` | width **`40px`**, height **`0px`**, rect `40 × 0` @ `21, 29` |
| G32 | 본문 `justify-evenly py-6` rect | **438 × 81.5** px @ `1, 67` |
| G32 | 본문 padding | top `16px` / right `0px` / bottom `16px` / left `0px` |
| G32 | 링크 1 `회원 직접 추가` (`/trainer/manage/invite`) rect | **219 × 49.5** px @ `1, 83` |
| G32 | 링크 2 `가입된 회원 추가` (`/trainer/manage/append`) rect | **219 × 49.5** px @ `220, 83` |
| G32 | 링크 1 안 svg | **`25 × 24`** px @ `98, 83` |
| G32 | 링크 2 안 svg | **`24 × 24`** px @ `317.5, 83` |
| G32 | 아이콘–글자 gap (`gap-y-2`) | **`6px`** (두 링크 모두, computed `row-gap: 6px`, rect 실측 `6.00`) |
| G32 | 글자 fontSize / lineHeight | `13px` / `19.5px` (150%) |
| G32 | 글자 fontWeight / color | `600` / `rgb(2, 8, 23)` |
| G32 | 글자 rect (`회원 직접 추가`) | `73.59 × 19.5` @ `73.7, 113` |
| G32 | 글자 rect (`가입된 회원 추가`) | `84.83 × 19.5` @ `287.08, 113` |
| G33 | 두 링크의 left 좌표 | **`1`** 과 **`220`** (right `220` / `439`) |
| G33 | `justify-evenly` 실효 | **없음.** 두 링크가 `w-full`이라 각 219px로 본문 콘텐츠 폭 438px를 정확히 채운다(219+219=438). 남는 공간이 0이라 `justify-evenly`가 만들 여백이 없다. 결과적으로 두 링크가 컨테이너를 정확히 반씩 나눠 갖는다. |
| G34 | 닫기 | `Escape`로 닫음 — 확인됨 (`[role="dialog"]` 제거). **링크는 누르지 않음.** |

---

## H. 하단 네비

| # | 항목 | 측정값 |
|---|------|--------|
| H35 | `<nav>` 전체 rect | **440 × 81** px @ `0, 819` |
| H35 | nav borderRadius | `8px 8px 0px 0px` (`rounded-tl-md rounded-tr-md`) |
| H35 | nav backgroundColor | `rgb(255, 255, 255)` |
| H35 | nav boxShadow (`shadow-nav`) | `rgba(0, 0, 0, 0.06) 0px -2px 8px 0px` |
| H35 | 내부 `<ul>` rect | `440 × 81` @ `0, 819` |
| H35 | `<ul>` padding | top `18px` / right `36px` / bottom `18px` / left `36px` (`px-11` = 36px, `py-[18px]`) |

참고 — 네비 아이템 (측정 요청 범위 밖이지만 같이 잡힘):

| 아이템 | svg | 라벨 rect | 라벨 스타일 |
|--------|-----|----------|------------|
| 홈 | `24 × 24` @ `36, 837` | `8.7 × 15` @ `43.7, 867` | `10px` / `font-medium` / `text-gray-700` |
| 스케줄 | `24 × 24` @ `147.5, 837` | `25.9 × 15` @ `146.5, 867` | 동일 |
| 커뮤니티 | `22 × 21` @ `265.2, 838.5` | `34.6 × 15` @ `258.9, 865.5` | 동일 |
| 마이 | `24 × 24` @ `380, 837` | `17.3 × 15` @ `383.3, 867` | 동일 |

아이콘–라벨 `gap-y-2`는 `justify-between` 때문에 실제로는 컬럼 높이(45px) 안에서 분배된다.

---

## 전체 세로 레이아웃 요약 (440 × 900)

| 영역 | top | height |
|------|-----|--------|
| header | 0 | 56 |
| main | 56 | 763 |
| ├ 검색바 래퍼 | 56 | 76 |
| └ 스크롤 영역 (`mt-1 … px-7`) | 136 | 683 |
| &nbsp;&nbsp;├ 카운트+정렬 행 | 136 | 36 (+ marginBottom 10) |
| &nbsp;&nbsp;└ 카드 리스트 | 182 | 178 (카드 72 + gap 10 + 카드 72 + pb 24) |
| nav | 819 | 81 |

---

## 측정 실패 / 주의 항목

| # | 상태 |
|---|------|
| B8 lineHeight | **측정은 됐으나 값이 `normal`.** 클래스 `placeholder:text-[16px]/[150%]`의 150%가 computed에 안 나타난다. Chromium의 `::placeholder` line-height 노출 제약일 가능성을 배제하지 못해, "150%가 적용되지 않음"으로 단정하지 않는다. |
| 그 외 | **측정 실패 항목 없음.** A1–H35 전 항목 실측 완료. |

### 예상과 달랐던 값

1. **Tailwind 스페이싱 스케일이 커스텀이다.** `px-7`=20px, `px-6`=16px, `py-4`=10px, `mb-4`=10px, `gap-2`=6px 등. 기본 스케일(각 28/24/16/16/8px)과 전부 다르다.
2. **`가입` 배지 line-height는 상속 길이값이 아니라 단위 없는 `1.5`** → `15px`. 그런데 실제 렌더 높이는 flex stretch로 **22.41px**(콘텐츠 기준 18px).
3. **정렬 드롭다운 항목 사이 간격이 `0px`** — 45px 항목 두 개가 맞붙어 있다.
4. **드롭다운 패널이 트리거보다 왼쪽·아래로 크게 어긋난다**: left −31.03px, top +8px. Radix popper 계산값을 `absolute -right-9 top-1`이 덮어쓴 결과.
5. **다이얼로그 `justify-evenly`가 실효 없음** — 두 링크가 `w-full`이라 여백이 0이다.
6. **`mb-[30%]` = 120px** — 퍼센트 마진이 부모 **폭**(400px) 기준으로 계산된다. 높이 기준으로 착각하기 쉽다.
7. **정렬 트리거 `py-[18px]`(18+18=36)가 `h-11`(36px)과 같아** 콘텐츠 박스 높이가 0이고 아이콘·라벨이 오버플로로 그려진다.
8. **비정사각 아이콘 3개**: 헤더 `+` svg `17 × 16`, 정렬 아이콘 `13 × 14`, 빈 상태 `alert_circle` `35 × 36`, 다이얼로그 링크1 svg `25 × 24`.
9. **다이얼로그 패널에 `border: 1px`가 있어** 내부 콘텐츠 폭이 440이 아니라 **438**이고, 헤더/본문이 x=1에서 시작한다.
10. **다이얼로그 닫기 버튼의 히트 영역이 `20 × 36`** (세로로만 큼). 폭은 svg 20px 그대로.

---

## 측정 중 수행한 인터랙션 (안전 규칙 준수)

허용된 셋만 사용했고, 공유 데이터를 바꾸는 동작은 하지 않았다.

1. 정렬 드롭다운 트리거 클릭 → 측정 → `Escape` (화면 상태만 변경)
2. 검색창에 `zzzz` 타이핑 → 측정 → 빈 문자열로 복원 (클라이언트 필터링만)
3. 헤더 `+` 버튼 클릭 → 다이얼로그 측정 → `Escape` (**다이얼로그 안 링크 미클릭**)

측정 종료 시점 상태 확인: `총 2명`, 카드 2개, 검색창 빈 값, 드롭다운·다이얼로그 모두 닫힘.
회원 추가/초대/수강권/포인트 관련 버튼은 한 번도 누르지 않았고, 회원 카드도 클릭하지 않았다.
