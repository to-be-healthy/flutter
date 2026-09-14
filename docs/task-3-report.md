# Task 3 Report: 타이포그래피 + Pretendard 폰트

## 구현 내용

- `lib/core/theme/app_typography.dart`: `AppTypography` — 웹 `src/shared/mixin/typography.ts`의 19개 상수를 3쌍의 별칭(HEADING_4==HEADING_4_BOLD, TITLE_1==TITLE_1_BOLD, BODY_4==BODY_4_REGULAR)을 통합해 16종 `static const TextStyle`로 이식. `AppTypography.all`에 16개 전부 포함.
- `lib/core/theme/app_theme.dart`: `AppTheme.light()` — `ThemeData`에 `fontFamily: 'Pretendard'`, `colorScheme`(seed = `AppColors.light.primary500`, error = `point`), `textTheme`(Material 슬롯에 `AppTypography` 매핑), `extensions`(`AppSpacing.standard`, `AppColors.light`, `AppRadius.standard`) 조립.
- `assets/fonts/`: Pretendard 9웨이트(otf) 배치.
- `pubspec.yaml`: 기존 `flutter:` 섹션(주석, `uses-material-design: true`) 보존한 채 `fonts:` 블록만 추가.
- `test/core/theme/app_typography_test.dart`: 신규 파일. `AppTypography` 값 검증 5개 그룹 + `AppTheme` 그룹(테마 주입 위젯 테스트) 1개.

## TDD 증거

**RED**
```
$ flutter test test/core/theme/app_typography_test.dart
```
결과: 컴파일 실패. `Error: Undefined name 'AppTypography'.` / `Error: Undefined name 'AppTheme'.` — `app_typography.dart`, `app_theme.dart`가 아직 없어 import가 해석되지 않음. 예상된 실패(브리프 Step 4 "FAIL — URI 없음"과 동일한 원인, import 자체가 없어 URI 대신 undefined name 형태로 나타남).

**GREEN**
```
$ flutter test test/core/theme/app_typography_test.dart --reporter compact
```
결과: `All tests passed!` (6개 테스트: HEADING/TITLE/BODY/NAV_TEXT/폰트패밀리 5개 + AppTheme 주입 1개)

**전체 검증**
```
$ ./tool/verify.sh
```
- `dart format --set-exit-if-changed`: `Formatted 10 files (0 changed)` — 통과
- `flutter analyze --no-fatal-infos`: `No issues found!` — 통과
- `flutter test`: `All tests passed!` (13개: 기존 7개 + 신규 6개) — 통과
- `OK: 모든 검증 통과`

## 변경 파일

- `lib/core/theme/app_typography.dart` (신규)
- `lib/core/theme/app_theme.dart` (신규)
- `test/core/theme/app_typography_test.dart` (신규)
- `pubspec.yaml` (수정 — `fonts:` 블록 추가)
- `assets/fonts/Pretendard-{Thin,ExtraLight,Light,Regular,Medium,SemiBold,Bold,ExtraBold,Black}.otf` (신규, 9개)

## 폰트 자산 확인 결과

- 소스: 사용자가 미리 받아둔 `/private/tmp/claude-501/.../scratchpad/pretendard.zip` (45MB) — 재다운로드하지 않음.
- `unzip -l`로 zip 내부에 `public/static/*.otf` 9개(Thin/ExtraLight/Light/Regular/Medium/SemiBold/Bold/ExtraBold/Black) 존재 확인 후 `assets/fonts/`에 추출.
- 추출 후 `assets/fonts/` 파일 목록 = 정확히 9개, 파일명 오타·누락 없음.
- `pubspec.yaml`의 weight 매핑을 파일명과 1:1 대조:

  | 파일 | weight |
  |---|---|
  | Pretendard-Thin.otf | 100 |
  | Pretendard-ExtraLight.otf | 200 |
  | Pretendard-Light.otf | 300 |
  | Pretendard-Regular.otf | 400 |
  | Pretendard-Medium.otf | 500 |
  | Pretendard-SemiBold.otf | 600 |
  | Pretendard-Bold.otf | 700 |
  | Pretendard-ExtraBold.otf | 800 |
  | Pretendard-Black.otf | 900 |

  표준 웨이트 넘버링과 일치, 어긋남 없음.

## pubspec.yaml 병합 결과

`git diff pubspec.yaml`로 확인 — 기존 `flutter:` 섹션의 주석 전체와 `uses-material-design: true`가 그대로 남아 있고, 파일 맨 끝(`# For details regarding fonts from package dependencies` 주석 바로 다음)에 `fonts:` 블록만 순수 추가(diff에 `-` 라인 없음, `+` 라인만 24줄). 섹션 대체가 아니라 append임을 확인.

## 셀프 리뷰 결과

- **완전성**: 16종 스타일(heading1~5+heading4SemiBold=6, title1/title1SemiBold/title2/title3=4, body1~4+body4Medium=5, navText=1 → 6+4+5+1=16) 전부 정의. `AppTypography.all` 목록도 정확히 이 16개와 1:1 일치(순서까지 선언 순서와 동일). `pubspec.yaml`의 `uses-material-design: true` 보존 확인.
- **웹 원본 대조**: `frontend/src/shared/mixin/typography.ts`를 직접 읽어 19개 상수 값(px, line-height %, font-weight)을 브리프의 테스트 기댓값과 대조 — 전부 일치. 3쌍 별칭(HEADING_4/HEADING_4_BOLD, TITLE_1/TITLE_1_BOLD, BODY_4/BODY_4_REGULAR)도 실제로 값이 동일함을 원본에서 재확인.
- **NAV_TEXT height**: 웹 원본에 `text-[10px]`만 있고 line-height 클래스가 없어 `height`를 지정하지 않음 — 임의 추측이 아니라 원본 부재를 그대로 반영.
- **품질/YAGNI**: `app_typography.dart`(스타일 정의)와 `app_theme.dart`(조립) 분리 유지, 계획을 넘는 추가 파일·헬퍼 없음.
- **테스트 실질성**: 각 테스트가 실제 fontSize/height/fontWeight/fontFamily 값을 하드코딩된 기댓값과 비교 — 트리비얼(항상 참) 어서션 없음. `flutter test` 출력 깨끗함(경고 없음, `flutter analyze`도 0 issue).
- **폰트 파일/매핑 육안 확인**: 위 표 참조 — 파일 9개 실재, weight 숫자와 파일명 어긋남 없음.

## 우려사항

없음. 브리프의 모든 단계(Step 1~8)를 순서대로 수행했고, 사전에 확정된 모호함(폰트 zip 경로, pubspec 병합 방식, 9웨이트 전부 선언, 파일 재사용, 16종 통합, height 배수 변환) 전부 지시대로 반영했다.
