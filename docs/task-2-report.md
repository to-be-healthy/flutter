# Task 2 리포트 — 디자인 토큰 (spacing + 색상)

## 구현한 것

브리프(`task-2-brief.md`)에 명시된 대로 3개 파일을 각각 생성했다 (하나로 합치지 않음):

- `lib/core/theme/app_spacing.dart` — `AppSpacing extends ThemeExtension<AppSpacing>`, `s1..s12` (12개 값), `AppSpacing.standard`, `copyWith`, `lerp`, 자체 `static double lerpDouble(...)`
- `lib/core/theme/app_colors.dart` — `AppColors extends ThemeExtension<AppColors>`, `primary50..primary900`(10) + `gray100..gray800`(8) + `point/blue10/blue50`(3) = 21개 값, `AppColors.light`, `copyWith`, `lerp`
- `lib/core/theme/app_radius.dart` — `AppRadius extends ThemeExtension<AppRadius>`, `s/m/l`, `AppRadius.standard`, `copyWith`, `lerp` (전용 테스트 없음 — Task 3에서 테마 주입 테스트로 검증 예정, 지시대로 `app_radius_test.dart` 미생성)

테스트는 브리프 원문 그대로 생성:

- `test/core/theme/app_spacing_test.dart`
- `test/core/theme/app_colors_test.dart`

`lib/main.dart`는 건드리지 않았다.

## TDD 증거

### Step 1~2: AppSpacing — RED

명령:
```
flutter test test/core/theme/app_spacing_test.dart
```

결과 (요약, 컴파일 실패로 exit 1):
```
test/core/theme/app_spacing_test.dart:2:8: Error: Error when reading 'lib/core/theme/app_spacing.dart': No such file or directory
import 'package:geonganghaejim/core/theme/app_spacing.dart';
       ^
test/core/theme/app_spacing_test.dart:6:15: Error: Undefined name 'AppSpacing'.
...
Some tests failed.
```

**브리프의 Expected 메시지(`Target of URI doesn't exist`)와 실제 메시지가 다르다.** 실제로는 `Error when reading '...': No such file or directory`였다. 두 메시지 모두 "해당 파일이 없어 import가 해석되지 않는다"는 동일한 근본 원인(컴파일 실패, RED)을 가리키므로 실패의 성격은 브리프 의도와 일치한다고 판단했다. Dart SDK/CFE 버전에 따라 동일 상황의 에러 문구가 달라질 수 있는 것으로 보인다.

### Step 3~4: AppSpacing — GREEN

명령:
```
flutter test test/core/theme/app_spacing_test.dart
```

결과:
```
00:00 +0: AppSpacing — 웹 tailwind.config.js 비선형 스케일 고정 Tailwind 기본값이 아닌 웹 정의값과 일치한다
00:00 +1: AppSpacing — 웹 tailwind.config.js 비선형 스케일 고정 Tailwind 기본 스케일과 다르다 (회귀 방지)
00:00 +2: AppSpacing — 웹 tailwind.config.js 비선형 스케일 고정 lerp는 두 스케일 사이를 보간한다
00:00 +3: All tests passed!
```
3/3 PASS (브리프 Expected와 일치).

### Step 5~6: AppColors — RED

명령:
```
flutter test test/core/theme/app_colors_test.dart
```

결과 (요약, 컴파일 실패로 exit 1):
```
test/core/theme/app_colors_test.dart:3:8: Error: Error when reading 'lib/core/theme/app_colors.dart': No such file or directory
import 'package:geonganghaejim/core/theme/app_colors.dart';
       ^
test/core/theme/app_colors_test.dart:7:15: Error: Undefined name 'AppColors'.
...
Some tests failed.
```
Step 2와 동일한 사유로 브리프 Expected(`URI 없음`) 취지와 일치하는 RED.

### Step 6: AppColors — GREEN

명령:
```
flutter test test/core/theme/app_colors_test.dart
```

결과:
```
00:00 +0: AppColors — 웹 global.css :root 변수 고정 primary 팔레트 10단이 웹 값과 일치한다
00:00 +1: AppColors — 웹 global.css :root 변수 고정 gray 팔레트는 100~800 8단이다 (900은 웹 global.css에 없음)
00:00 +2: AppColors — 웹 global.css :root 변수 고정 포인트·blue 색상이 웹 값과 일치한다
00:00 +3: All tests passed!
```
3/3 PASS.

### Step 7: 전체 검증

명령:
```
./tool/verify.sh
```

1차 실행 시 `dart format --set-exit-if-changed`가 새로 작성한 `app_spacing_test.dart`의 `const AppSpacing(...)` 다중값 한 줄 표기를 표준 포맷(줄바꿈)으로 자동 정규화하면서 "변경됨"으로 exit 1을 반환해 스크립트가 `set -e`에 의해 중단됐다 (정상 동작 — 포맷 드리프트 검출). 값 자체는 변경되지 않았음을 diff로 확인했다.

재실행 결과 전체 통과:
```
== dart format ==
Formatted 7 files (0 changed) in 0.01 seconds.
== flutter analyze ==
No issues found! (ran in 3.6s)
== flutter test ==
...
00:01 +7: All tests passed!
OK: 모든 검증 통과
```
7개 테스트(신규 6개 + 기존 boilerplate `widget_test.dart` 1개) 모두 PASS. `flutter analyze`에서 `lerpDouble` 이름 충돌 경고는 발생하지 않았다 (`dart:ui` import 안 함, 브리프대로 `package:flutter/material.dart`만 import).

## 변경 파일

- `lib/core/theme/app_spacing.dart` (신규)
- `lib/core/theme/app_colors.dart` (신규)
- `lib/core/theme/app_radius.dart` (신규)
- `test/core/theme/app_spacing_test.dart` (신규)
- `test/core/theme/app_colors_test.dart` (신규)

커밋: `eaed9ef feat(theme): 웹 디자인 토큰(spacing·색상·radius)을 ThemeExtension으로 이식`

## 셀프 리뷰 결과

- **완전성**: spacing 12개(`s1..s12`), 색상 21개(primary 10 + gray 8 + point/blue10/blue50 3) 값 전부 브리프와 1:1로 옮겼음을 재대조 완료.
- **값 정확성**: 브리프의 숫자·hex와 구현 코드를 한 번 더 나란히 grep/diff로 대조 — 전부 일치 (오타 없음).
- **이름 일치**: 클래스명·필드명·`standard`/`light` 정적 인스턴스명 전부 브리프와 동일.
- **YAGNI**: `app_radius_test.dart` 추가하지 않음. spacing/color 외 다른 토큰(폰트 등) 추가하지 않음. `main.dart` 미변경.
- **테스트 품질**: 각 값을 개별 `expect`로 직접 검증, "Tailwind 기본값과 다르다"는 회귀 방지 테스트도 포함. 출력 깨끗함(경고 없음).
- **파일 구조**: 계획대로 토큰 4종(spacing/color/radius + 테마 자체는 이후 태스크)을 파일별로 분리, 병합하지 않음.

## 우려사항

- RED 단계에서 브리프가 명시한 정확한 에러 문구(`Target of URI doesn't exist`)가 아니라 `Error when reading '...': No such file or directory`가 출력됐다. 근본 원인(파일 부재로 인한 컴파일 실패)은 브리프 의도와 동일하다고 판단해 그대로 진행했으나, 사용하는 Dart/Flutter SDK 버전 차이에서 오는 문구 차이일 수 있어 기록해 둔다. 기능적으로는 문제 없음.
