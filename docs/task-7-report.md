# Task 7 report — 공통 위젯: AppButton, AppTextInput

## 구현한 것

- `lib/shared/ui/app_button.dart` — `AppButton` (`AppButtonVariant { primary, secondary, ghost }`, `isLoading`)
- `lib/shared/ui/app_text_input.dart` — `AppTextInput` (`label`, `errorText`, `onChanged`, `controller`, `obscureText`, `keyboardType`)
- `test/shared/ui/app_button_test.dart` — `AppButton` 테스트 6개

브리프 Step 1~6을 순서대로 진행했다 (TDD: RED → 구현 → GREEN → 커밋 전 mutation 검증).

## TDD 증거

### RED (Step 2)

```
flutter test test/shared/ui/app_button_test.dart
```

```
Failed to load ".../test/shared/ui/app_button_test.dart":
Compilation failed ...: Error when reading 'lib/shared/ui/app_button.dart': No such file or directory
Error: Couldn't find constructor 'AppButton'. / Method not found: 'AppButton'.
+0 -1: Some tests failed.
```

브리프가 기대한 그대로 "URI 없음"으로 실패했다.

### GREEN (Step 4, `AppButton` 구현 직후)

```
flutter test test/shared/ui/app_button_test.dart
```

```
00:00 +0: AppButton 라벨을 표시한다
00:00 +1: AppButton 탭하면 콜백이 호출된다
00:00 +2: AppButton primary 변형은 테마의 primary500을 배경으로 쓴다
00:00 +3: AppButton 비활성 상태에서는 콜백이 호출되지 않는다
00:00 +4: AppButton isLoading이면 라벨 대신 인디케이터를 보여준다
00:00 +5: AppButton isLoading이면 onPressed가 있어도 탭이 막힌다 (중복 제출 방지)
00:00 +6: All tests passed!
```

### Mutation 검증 (배경색 단언에 이빨이 있는지)

커밋 전에 `colors.primary500` → `colors.primary600`으로 임시 변경 후 재실행:

```
00:00 +2 -1: AppButton primary 변형은 테마의 primary500을 배경으로 쓴다 [E]
  Expected: Color(0xFF1990FF) / Actual: Color(0xFF1F82F0)
```

배경색 단언이 살아있음을 확인. 원복은 `git checkout` 대신 동일 문자열의 정확한 치환(`colors.primary600` → `colors.primary500`, 파일 내 유일한 출현)으로 수행했고, 재실행해 6/6 GREEN을 재확인했다.

## 테스트 매처를 바꾼 이유

브리프 Step 1 코드의 배경색 검증은
`find.descendant(of: find.byType(AppButton), matching: find.byType(Container))`를 썼다.
사전에 안내된 대로, 이 매처는 `AppButton` 내부 트리 모양(예: `Container`를 한 겹 더 감싸는 리팩터)이 바뀌면
`findsOneWidget` 기대가 무너지는 취약한 형태다.

대신 `AppButton`에 `static const Key backgroundKey = Key('app_button_background')`를 추가하고,
배경을 그리는 `Container`에 그 키를 달아 `find.byKey(AppButton.backgroundKey)`로 찾도록 바꿨다.
검증 대상은 "배경이 테마의 `primary500`을 쓴다"는 동작이지 위젯 트리 모양이 아니므로,
트리가 바뀌어도 테스트 의도가 유지된다.

## 테마 경유 규율 점검 (리터럴 잔존 여부)

`lib/shared/ui/` 두 파일에 대해 `Color(0x...)` 리터럴과 숫자 `EdgeInsets` 리터럴을 grep했다 — 매치 없음(둘 다 exit 1).
색·간격·라운드는 전부 `Theme.of(context).extension<AppColors/AppSpacing/AppRadius>()!`를 경유한다.

**의도적으로 남긴 리터럴(토큰화하지 않음, 각 파일 상단 docstring에도 명시):**

- `Colors.white`, `Colors.transparent` — `AppColors`에 대응 토큰이 없는 Flutter 프레임워크 상수. 토큰을 추가하려면
  Task 2에서 이미 커밋·테스트된 `app_colors.dart`/`app_colors_test.dart`를 건드려야 해서 이 태스크(3파일) 범위를 벗어난다.
- `strokeWidth: 2` (로딩 인디케이터) — 디자인 토큰이 아니라 `CircularProgressIndicator` 자체의 굵기 값.
- `BorderSide.none` (`AppTextInput`의 기본 테두리) — 마찬가지로 프레임워크 상수.
- `double.infinity` (`AppButton`의 너비) — 레이아웃 제약값이지 색/간격/타이포 토큰이 아니다. 단, 이 때문에
  `AppButton`은 폭 제약이 없는 부모(예: `Expanded` 없는 `Row`) 안에 놓이면 예외를 던진다 — 브리프가 명시한 대로이고,
  이후 화면 이식 시 알아둬야 할 특성으로 남겨둔다.

**타이포:** `AppTypography.title1`처럼 정적 상수를 직접 참조했다(`Theme.of(context).extension` 아님).
`AppTypography`는 `ThemeExtension`이 아니라 정적 상수 모음이고, `app_theme.dart`가 `AppTheme.light()`에서
바로 그 상수들로 `TextTheme`을 구성한다 — 즉 `AppTypography.title1`은 이미 테마 값 그 자체이며, 두 파일
모두 docstring에 이 근거를 남겼다.

## 브리프와 실제 구현 사이 불일치 (보고, 임의 해석 안 함)

1. **Step 4 "Expected: PASS (8 tests)"** — Step 1 코드 블록에는 `testWidgets`가 5개뿐이다.
   자기 검토 체크리스트("isLoading일 때 탭이 실제로 막히는가?")를 만족하려면 "로딩 중 탭 차단" 테스트가
   반드시 필요한데 브리프의 5개 중엔 없어서 하나 추가해 총 6개다. 8개를 맞추려고 없는 테스트를 지어내지 않았다.
   코드 블록(원본 산출물)을 근거로 삼았고, 프로세 카운트가 stale하다고 판단했다.
2. **Interfaces 절의 `AppButton({..., VoidCallback? onPressed, ...})`(옵션 취급)** vs **Step 3의 `required this.onPressed`**
   — Step 3(실제 구현 코드)을 따랐다. 널러블 타입이라도 `required`로 두면 호출부가 활성화 여부를 명시적으로
   결정하게 강제된다. 테스트도 `onPressed: null`을 명시적으로 넘기는 형태다.

## 변경 파일

- `lib/shared/ui/app_button.dart` (신규)
- `lib/shared/ui/app_text_input.dart` (신규)
- `test/shared/ui/app_button_test.dart` (신규)

## `./tool/verify.sh` 결과 (4단계 전부 통과)

```
== dart format ==      Formatted 27 files (0 changed)
== flutter analyze ==  No issues found!
== har_to_golden.py 테스트 ==  Ran 14 tests ... OK
== flutter test ==     +66: All tests passed!  (기존 60 + 신규 6)
```

## 셀프 리뷰 결과

- **색·간격·라운드·타이포 전부 테마 경유, 리터럴 잔존 여부** — 위 "테마 경유 규율 점검" 절 참고. 색/간격/라운드
  리터럴은 0건(grep 확인). 문서화된 예외(`Colors.white`/`transparent`/`BorderSide.none`/`strokeWidth: 2`/`double.infinity`)만 남음.
- **테스트가 실제 동작을 검증하는가** — mutation 검증으로 배경색 단언이 실패를 잡아내는 것을 확인했다(위 로그).
- **isLoading 탭 차단** — 전용 테스트로 확인. `isEnabled = onPressed != null && !isLoading`이 `GestureDetector.onTap`을
  `null`로 만들어 탭이 먹지 않는다.
- **비활성 상태 색이 `AppColors` 실값을 쓰는가** — `primary` 변형은 `colors.gray200`/`colors.gray400`(둘 다 Task 2의
  실제 토큰)을 쓴다. 단, **`secondary`/`ghost` 변형은 비활성 시각 상태가 없다** — `isEnabled`와 무관하게 배경/전경이
  고정이다(콜백 차단 자체는 정상 동작). 브리프 코드 자체의 한계이며, 값이 명시되지 않은 상태에서 임의로
  비활성 색을 지어내지 않았다. 아래 우려사항에 기재.
- **완전성/YAGNI** — `AppTextInput` 테스트 파일은 브리프 범위 밖이라 만들지 않았다. `AppTextInput`은 `AppButton`과
  동일한 테마 경유 규율을 따르는지 코드 리뷰로 확인했다(리터럴 0건).
- **테스트 출력 청결도** — `flutter test`(compact reporter)가 비-tty 캡처에서 진행률 갱신 줄을 개행으로 흩뿌려
  같은 테스트명이 여러 줄 반복 출력되는 현상이 있다. 이는 이 태스크가 만든 문제가 아니라 기존 `verify.sh`의
  reporter 설정이 원래 가진 특성이며(이전 태스크들의 실행에서도 동일 패턴), 실제 결과(`+66: All tests passed!`)는
  깨끗하다.

## 우려사항

1. `AppButton`의 `secondary`/`ghost` 변형에 비활성 시각 피드백이 없다(색은 그대로, 탭만 막힘). 62개 화면이
   이 패턴을 그대로 복사하면 "버튼이 눌리는 것처럼 보이는데 안 눌리는" UX 이슈가 생길 수 있다. 다만 값이
   브리프/디자인 토큰 어디에도 정의돼 있지 않아 이번에 임의로 만들지 않았다 — 다음 태스크나 디자인 확인이
   필요하면 그때 토큰을 추가하는 게 맞다고 판단했다.
2. `AppButton`은 `width: double.infinity`를 쓰므로 폭 제약이 없는 부모(`Expanded` 없는 `Row` 등) 안에 두면
   레이아웃 예외가 난다. 브리프 명세 그대로이며 향후 화면 이식 시 알아둬야 할 특성이다.

## 커밋

`b438817 feat(ui): 공통 위젯 AppButton·AppTextInput 추가`

---

# Fix 라운드 1 — 리뷰 반영 보고

리뷰에서 확정된 3건을 웹 원본 대조 결과 그대로 반영했다. 각 건마다 (a) 새/수정 테스트가 실제로
버그를 잡는지 mutation으로 RED 확인 → (b) 수정 재적용 → GREEN 확인 순서로 검증했다. mutation 원복은
`destructive-command-safety` 규칙에 따라 `git checkout` 대신 유일한 문자열의 정확 치환으로 했다.

## 1. 비활성 배경 — variant 무관 `gray300`, 전경색은 비활성이어도 유지

**변경 (`lib/shared/ui/app_button.dart`):**
```dart
// 웹 button.tsx의 base가 `disabled:bg-gray-300` — variant 무관.
final background = !isEnabled
    ? colors.gray300
    : switch (variant) {
        AppButtonVariant.primary => colors.primary500,
        AppButtonVariant.secondary => colors.blue50,
        AppButtonVariant.ghost => Colors.transparent,
      };

// 웹은 비활성에서 전경색을 바꾸지 않는다(disabled:text-* 없음).
final foreground = switch (variant) {
  AppButtonVariant.primary => Colors.white,
  AppButtonVariant.secondary => colors.primary500,
  AppButtonVariant.ghost => colors.gray600,
};
```

**덮는 테스트:** `test/shared/ui/app_button_test.dart`의 `비활성 배경은 variant와 무관하게 gray300이다
(웹 disabled:bg-gray-300)` — `AppButtonVariant.values` 3개 전부를 순회하며 비활성 배경이 `gray300`인지 확인.
기존에는 `primary`만 덮였다.

**RED (mutation, 리뷰 이전 코드로 복귀 후):**
```
flutter test test/shared/ui/app_button_test.dart
00:00 +3 -1: AppButton 비활성 배경은 variant와 무관하게 gray300이다 (웹 disabled:bg-gray-300) [E]
00:00 +6 -2: AppButton AppButton이 둘 이상이어도 label로 각각의 배경을 찾을 수 있다 [E]
00:00 +6 -2: Some tests failed.
```
(두 번째 실패의 원인: `둘 이상` 테스트의 `취소` 버튼은 `ghost` variant + 비활성이라
`gray300`을 기대하는데, 리뷰 이전 코드는 `ghost`의 배경을 활성/비활성 구분 없이 항상
`Colors.transparent`로 고정하므로 불일치가 난 것 — 키 충돌이 아니라 색 로직 자체가
되돌아갔기 때문이다. 키 충돌만 따로 보는 검증은 3번 항목에 별도로 있다.)

**GREEN (수정 재적용 후):**
```
flutter test test/shared/ui/app_button_test.dart
00:00 +7: AppButton isLoading이면 onPressed가 있어도 탭이 막힌다 (중복 제출 방지)
00:00 +8: All tests passed!
```

## 2. `AppTextInput.errorBorder` 죽은 코드 제거 — `hasError` 기반 테두리 직접 선택

**변경 (`lib/shared/ui/app_text_input.dart`):** `errorBorder`(도달 불가) 제거,
`border`/`enabledBorder`/`focusedBorder` 세 개를 `hasError`로 직접 분기.

```dart
border: OutlineInputBorder(
  borderRadius: BorderRadius.circular(radius.m),
  borderSide: hasError ? BorderSide(color: colors.point) : BorderSide.none,
),
enabledBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(radius.m),
  borderSide: hasError ? BorderSide(color: colors.point) : BorderSide.none,
),
focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(radius.m),
  borderSide: BorderSide(color: hasError ? colors.point : colors.primary500),
),
```

**신규 파일:** `test/shared/ui/app_text_input_test.dart` (4개 테스트) — 브리프는 `AppTextInput` 테스트를
요구하지 않았지만, 이번에 "검증할 동작"(테두리 색 전환)이 생겼으므로 리뷰 지시대로 최소 범위로 만들었다.
- 에러 없음 → `enabledBorder`가 `BorderSide.none`
- 에러 있음 → `enabledBorder` 색이 `AppColors.light.point`, 그리고 `decoration.errorText`가 여전히
  `null`임을 함께 확인(= `errorBorder`가 애초에 켜질 수 없는 상태에서 테스트 중임을 명시)
- 에러 메시지가 별도 `Text`로 렌더됨
- 라벨 표시(회귀 방지용 기본 스모크)

**RED (mutation, 리뷰 이전 코드로 복귀 후):**
```
flutter test test/shared/ui/app_text_input_test.dart
00:00 +0 -1: AppTextInput 에러가 없으면 테두리에 색을 넣지 않는다 [E]
  (Null check operator used on a null value — enabledBorder가 정의돼 있지 않았음)
00:00 +0 -2: AppTextInput 에러가 있으면 테두리가 point 색이 된다 (errorBorder는 도달 불가라 쓰지 않는다) [E]
  (Null check operator used on a null value)
00:00 +2 -2: Some tests failed.
```

**GREEN (수정 재적용 후):**
```
flutter test test/shared/ui/app_text_input_test.dart
00:00 +3: AppTextInput 라벨을 표시한다
00:00 +4: All tests passed!
```

## 3. `backgroundKey`(static const) → `backgroundKeyFor(String label)`

**변경 (`lib/shared/ui/app_button.dart`):**
```dart
static Key backgroundKeyFor(String label) =>
    ValueKey('AppButton.background.$label');
```
`Container`도 `key: backgroundKeyFor(label)`로 라벨마다 고유한 키를 갖는다.

**덮는 테스트(신규):** `test/shared/ui/app_button_test.dart`의
`AppButton이 둘 이상이어도 label로 각각의 배경을 찾을 수 있다` — 활성 `확인`(primary)과
비활성 `취소`(ghost)를 같은 트리에 렌더링하고, 각 라벨 키로 서로 다른 배경색(`primary500` vs `gray300`)을
정확히 집어내는지 확인한다.

**RED (mutation: `backgroundKeyFor`가 label을 무시하고 고정 키를 반환하도록 되돌림):**
```
flutter test test/shared/ui/app_button_test.dart
Bad state: Too many elements
  at WidgetController.widget (find.byKey가 두 위젯을 동시에 매치)
00:00 +7 -1: AppButton AppButton이 둘 이상이어도 label로 각각의 배경을 찾을 수 있다 [E]
```

**GREEN (수정 재적용 후):**
```
flutter test test/shared/ui/app_button_test.dart
00:00 +7: AppButton AppButton이 둘 이상이어도 label로 각각의 배경을 찾을 수 있다
00:00 +8: All tests passed!
```

## 전체 검증

```
./tool/verify.sh
== dart format ==      Formatted 28 files (0 changed)
== flutter analyze ==  No issues found!
== har_to_golden.py 테스트 ==  Ran 14 tests ... OK
== flutter test ==     +72: All tests passed!  (직전 66 + 신규 6: AppButton 2개, AppTextInput 4개)
```

## 변경 파일 (이번 라운드)

- `lib/shared/ui/app_button.dart` (수정)
- `lib/shared/ui/app_text_input.dart` (수정)
- `test/shared/ui/app_button_test.dart` (수정, 테스트 2개 추가)
- `test/shared/ui/app_text_input_test.dart` (신규, 테스트 4개)

## 커밋

`2a4a70e fix(ui): 리뷰 반영 — 비활성 배경 gray300 통일, 죽은 errorBorder 제거, backgroundKey 라벨 분리`

## 남은 우려사항

이전 라운드에서 보고한 두 가지(① `double.infinity` 폭 특성, ② 이번 라운드로 해소된 secondary/ghost
비활성 무반응 — 이제 gray300으로 해소됨)는 이번 수정으로 ②가 닫혔다. ①은 브리프 명세 그대로라 여전히
남아있는 특성으로 기록해둔다.
