# Task 1 리포트: 프로젝트 생성 + 검증 파이프라인

## 커밋

`02c1d67 chore: Flutter 프로젝트 초기 셋업 및 검증 스크립트 추가` (브랜치 `feature/flutter-phase0`, 68 files changed)

## 환경 확인

- 로컬 Flutter: `Flutter 3.47.0-1.0.pre-79 • channel stable`, `Dart 3.12.2`
  - Dart는 브리프 기재(3.12.2)와 정확히 일치.
  - Flutter는 채널은 `stable`이지만 버전 문자열이 `3.47.0-1.0.pre-79`로, 브리프의 "3.47.0 stable" 표기와 완전히 같지는 않다 (pre-release 빌드 넘버가 붙어 있음). 지침 5번에 따라 보고만 하고 진행함 — 문제 없이 전체 파이프라인 통과.

## 구현 내용

### Step 1: `flutter create`
```
flutter create --org com.geonganghaejim --project-name geonganghaejim --platforms android,ios --overwrite .
```
실행. 결과 `README.md (overwritten)` 확인됨 — 예상대로 덮어써짐.

**번들 ID 확인 결과: 예상대로 틀어져 있었음. 직접 수정함.**
- `flutter create`가 생성한 값: Android `namespace`/`applicationId` = `com.geonganghaejim.geonganghaejim`, iOS `PRODUCT_BUNDLE_IDENTIFIER` = `com.geonganghaejim.geonganghaejim` (+ RunnerTests 타깃 3곳은 `...geonganghaejim.RunnerTests`).
- 수정 후: 둘 다 정확히 `com.geonganghaejim.app`.
  - `android/app/build.gradle.kts`: `namespace`, `applicationId` → `com.geonganghaejim.app`
  - `ios/Runner.xcodeproj/project.pbxproj`: 전체 6개 `PRODUCT_BUNDLE_IDENTIFIER` 항목 치환 (Runner 3곳 → `com.geonganghaejim.app`, RunnerTests 3곳 → `com.geonganghaejim.app.RunnerTests`)
  - `ios/Runner/Info.plist`의 `CFBundleIdentifier`는 `$(PRODUCT_BUNDLE_IDENTIFIER)` 빌드 변수를 참조하므로 별도 수정 불필요.
- **브리프에 명시되지 않았지만 추가로 고친 것**: `android/app/src/main/kotlin/com/geonganghaejim/geonganghaejim/MainActivity.kt`의 `package` 선언과 디렉터리 경로. `AndroidManifest.xml`의 `android:name=".MainActivity"`는 `namespace` 기준 상대경로로 해석되므로, `namespace`만 바꾸고 이 파일의 실제 패키지를 그대로 두면 AGP가 매니페스트에서 `com.geonganghaejim.app.MainActivity`를 기대하는데 실제 클래스는 `com.geonganghaejim.geonganghaejim.MainActivity`로 컴파일되어 **런타임에 클래스를 찾지 못해 앱이 크래시**한다. 그래서 파일을 `android/app/src/main/kotlin/com/geonganghaejim/app/MainActivity.kt`로 이동하고 `package com.geonganghaejim.app`로 변경, 빈 디렉터리 정리까지 했다. (기계적이고 모호함 없는 수정이라 판단해 에스컬레이션 없이 진행함.)
- 수정 후 저장소 전체에서 `com.geonganghaejim.geonganghaejim` 잔존 여부 재검색 → 0건.

**README.md 보존 여부: 덮어써졌던 것을 원래 내용("# flutter", trailing newline 없음)으로 복원한 뒤 Flutter 표준 안내문을 덧붙였다.** 최종 `README.md`는 원래 제목 줄을 유지하면서 `flutter create`가 생성한 "Getting Started" 섹션이 이어진다.

### Step 2: `analysis_options.yaml` 강화
브리프의 yaml을 그대로 적용 (`strict-casts`, `strict-raw-types`, `invalid_annotation_target: ignore`, 4개 lint rule 추가).

### Step 3: `tool/verify.sh` 작성
브리프 내용 그대로 생성, `chmod +x` 적용 (커밋에 `100755`로 반영됨 확인).

### Step 4: 검증 스크립트 자체 검증 (실제 실행 결과)
1. 정상 상태에서 최초 실행 → `dart format`/`flutter analyze`(No issues found)/`flutter test`(1 passed) 모두 통과, `exit=0`.
2. `lib/main.dart`에 `printf '\n\nvoid   badlyFormatted(  ) {}\n' >> lib/main.dart`로 포맷 파손 주입 → `./tool/verify.sh` 실행 → `dart format`이 `Formatted lib/main.dart`를 출력하며 **`exit=1`로 종료** (기대대로 dart format 단계에서 비영 종료 확인).
   - 주의: `dart format --set-exit-if-changed`는 실패를 보고하는 동시에 파일을 실제로 재포맷해버린다. 그래서 브리프가 준 python 되돌리기 스니펫(원본 지저분한 문자열을 정확히 매치)이 이미 dart format이 정리해버린 `void badlyFormatted() {}` 한 줄과 매치되지 않아 `AssertionError`로 실패했다. `git checkout`을 쓰지 않고, 실제 파일에 남아있는 문자열(`\nvoid badlyFormatted() {}\n`)을 정확히 타깃으로 다시 문자열 치환하여 제거했다 — 이 부분은 브리프 스니펫을 문자 그대로 따르지 않고 실제 파일 상태에 맞춰 조정함.
3. 되돌린 후 재실행 → `dart format`/`analyze`/`test` 모두 통과, `exit=0`. `lib/main.dart`가 표준 카운터 템플릿과 동일함을 Read로 재확인.

### Step 5: 커밋
브리프 커밋 메시지 그대로 사용.

## 변경/생성 파일 (주요)
- `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart` — `flutter create` 표준 생성물 (미변경)
- `analysis_options.yaml` — 브리프 내용으로 전면 교체
- `tool/verify.sh` — 신규, 실행 권한 부여
- `README.md` — 원본 복원 + Flutter 안내문 추가 (수정)
- `android/app/build.gradle.kts` — 번들 ID 수정
- `android/app/src/main/kotlin/com/geonganghaejim/app/MainActivity.kt` — 이동 + package 수정 (기존 `.../geonganghaejim/geonganghaejim/` 경로는 삭제)
- `ios/Runner.xcodeproj/project.pbxproj` — 번들 ID 6곳 수정
- 그 외 Android/iOS 플랫폼 표준 스캐폴딩 전체 (아이콘, 매니페스트, xcodeproj 등)

## 셀프 리뷰

- **완전성**: 브리프 Step 1~5 전부 수행. Global Constraints(번들 ID, spacing 스케일은 이 태스크 범위 밖, 백엔드 불변 — 해당 없음, 커밋 전 analyze/format/test 통과) 충족.
- **품질**: `tool/verify.sh`는 브리프 원문 그대로 — `set -euo pipefail`로 각 단계 실패가 즉시 비영 종료로 전파됨을 실제로 검증했다. `analysis_options.yaml`도 브리프 verbatim.
- **규율(YAGNI)**: 브리프가 요구하지 않은 화면·위젯·의존성 추가 없음. `flutter create`가 만든 표준 카운터 앱을 그대로 둠(브리프가 lib/main.dart의 커스텀 내용을 요구하지 않았음 — Phase 0 이후 태스크의 몫으로 판단).
- **테스트**: happy path(1회차 통과)뿐 아니라 실패 시나리오(2회차 강제 파손 → exit=1)까지 직접 실행해 확인했다 — "에러 없음이 성공의 증거가 아니다"라는 지시를 그대로 따름.
- **잔여 우려**: 없음. 다만 아래 두 가지는 컨트롤러가 인지해야 할 사실 정보로 남긴다.
  1. Flutter 버전이 브리프 기재와 문자열 수준에서 완전히 일치하지 않음(pre-release 빌드 넘버). 기능적으로는 문제없이 전체 검증 통과.
  2. MainActivity.kt의 패키지/경로 수정은 브리프가 명시적으로 지시한 두 파일(`build.gradle.kts`, `project.pbxproj`) 밖의 변경이지만, 번들 ID를 실제로 `com.geonganghaejim.app`으로 만들기 위해 필수적인 후속 조치였다.
