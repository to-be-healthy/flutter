# Task 8: Layout 셸 — 구현 보고

## 커밋

`54859ea` `feat(widget): AppLayout 슬롯 셸 추가`
- `lib/widget/app_layout.dart` (신규)
- `test/widget/app_layout_test.dart` (신규, 9개 테스트)

## 웹 `layout.tsx` 대조 결과

웹 파일: `frontend/src/widget/layout.tsx` (76줄). 브리프의 `AppLayout` 초안과 대조한 결과, **세 군데가 웹과 달라 웹 실측 기준으로 고쳤다.** 확인은 코드만 읽지 않고 실제 화면 62개의 사용처를 `grep`으로 전수 조사해서 "기본값 vs 화면별 override"를 구분했다.

### 1. Contents 좌우 패딩 — 브리프 `spacing.s6`(16px) 가정은 틀렸다. 정답은 "패딩 없음"

웹 `Layout.Contents`의 CSS는 `h-full w-full flex-1 flex-shrink-0 overflow-y-auto`뿐이고 **좌우 패딩이 전혀 없다.** 실제로 127개 `<Layout.Header>` 사용처와 함께 `<Layout.Contents>` 사용처를 전수 조사한 결과 `px-7`(20px), `p-7`(20px), `bg-white px-7`, 패딩 전혀 없음 등 화면마다 제각각이었다(예: `TrainerHomePage`·`TrainerSelectStudentPage`·`StudentMyCourseDetailPage`는 패딩 없음, `StudentHomePage`는 `p-7 pt-6`, `TrainerScheduleSettingPage`는 `bg-white px-7`). 즉 Contents는 셸이 패딩을 고정하지 않고 **화면마다 직접 얹는 것이 웹의 실제 패턴**이다.

→ 브리프가 제안한 `padding: EdgeInsets.symmetric(horizontal: spacing.s6)`을 제거했다. `SingleChildScrollView(child: contents)`만 두고 패딩은 화면(호출부)이 스스로 감싸도록 했다 — 인터페이스는 그대로 유지(`contents: Widget` 한 장), 화면 쪽 위젯이 필요하면 `Padding`으로 감싸면 된다.

### 2. BottomArea 기본 패딩 — 브리프의 비대칭 값은 웹에 없다. 정답은 `p-7`(사방 20px)

웹 `Layout.BottomArea`의 `footer`는 `className='w-full p-7'` — **사방 20px 균등 패딩**이다. 브리프는 `EdgeInsets.fromLTRB(s6, s5, s6, s6)`(16/12/16/16)를 제안했는데, 이 값의 근거를 웹에서 찾을 수 없었다. 실제 23개 `<Layout.BottomArea>` 사용처를 전수 조사하면 다수(`EditNamePage`·`EditPasswordPage`·`TrainerCreateLogPage`·`TrainerAppendStudentPage`·`TrainerInvitePage`·`CreateWorkoutPage`·`EditWorkoutPage`·`FindPasswordPage`(×3)·`FindIdPage`(×3) 등)가 별도 override 없이 기본값을 그대로 쓰고, override하는 곳도 `p-0`(탭/세그먼트류) 또는 `px-7 pb-10 pt-7`처럼 명시적으로 다른 의도를 표현한다 — 브리프의 16/12/16/16 조합과 일치하는 사례는 없었다.

→ `EdgeInsets.all(spacing.s7)`(20px 균등)로 고쳤다.

### 3. Header 배경 — `Colors.white` 리터럴 대신 `theme.scaffoldBackgroundColor` 참조로 대체

브리프는 `AppBar(backgroundColor: Colors.white, ...)`를 제안했지만, Task 7 규율(색 리터럴 금지, `Colors.white`/`Colors.transparent`만 예외 — 그때도 이유를 주석에)에 비춰 정당화 근거가 약했다. 웹의 `Header` 자체는 배경이 없고 부모(`Layout` 루트, 기본 `bg-gray-100`, 화면별 `bg-white` override)를 그대로 드러낸다 — 즉 "헤더 전용 고정 색"이 웹에 없다.

Flutter의 `Scaffold.scaffoldBackgroundColor`는 이미 Task 2/3(`AppTheme.light()`)에서 흰색으로 고정돼 있다(이 값 자체를 바꾸는 것은 이번 태스크 범위 밖이라 건드리지 않았다). 헤더가 그 값과 다른 색을 쓰면 헤더-바디 경계가 눈에 띄게 되므로, 리터럴을 새로 박는 대신 **`theme.scaffoldBackgroundColor`를 그대로 참조**하도록 했다 — 웹의 "헤더는 고유 배경이 없다"는 동작을 가장 가깝게 재현하면서, 값이 바뀌면(추후 Task 2/3 재검토로 gray100이 되더라도) 헤더도 자동으로 따라간다.

**컨트롤러에게 전달할 값 자체의 불일치**: 웹의 실제 기본 배경은 `bg-gray-100`(`#F2F3F5`)이고, 화면이 명시적으로 `bg-white`를 얹은 경우만 흰색이다(127개 Header 사용처 중 13개만 `bg-white` 명시, 나머지 다수는 기본값 사용). 반면 Flutter는 Task 2/3에서 이미 `scaffoldBackgroundColor: Colors.white`로 고정해 놓았다 — 이는 이번 태스크의 파일이 아니라서 고치지 않았지만, "기본 배경이 웹은 회색, Flutter는 흰색"이라는 불일치가 이미 이전 태스크에 존재한다는 점은 컨트롤러가 알아야 할 사실이라 여기 적는다.

### 4. (참고, 고치지 않음) 웹 Header의 `px-7 py-6` 자체 패딩은 이식하지 않았다

웹 `Header`는 일반 `<header>` div라 자체 패딩(`px-7 py-6`)이 필요했지만, Flutter의 `AppLayoutHeader`는 Material `AppBar`를 그대로 쓴다 — `AppBar`는 `leading`/`title` 배치용 표준 인셋을 자체적으로 제공하므로 웹의 `px-7 py-6`을 별도로 옮기지 않았다. 값을 빠뜨린 게 아니라 "이미 다른 방식으로 같은 문제(여백)를 해결하는 표준 위젯을 썼다"는 의도적 판단이다.

### 5. (참고, 이번 태스크 범위 밖) 웹의 `type` prop — role별 네비게이션과 BottomArea는 상호 배타적

웹 `Layout`은 `type` prop이 있어 `trainer`/`student`면 `TrainerNavigation`/`StudentNavigation`을, `undefined`면 `BottomArea`를 — **셋 중 하나만** 하단에 렌더한다. 브리프의 인터페이스(`AppLayout({header, contents, bottomArea})`)에는 이 `type` 분기가 없고, 라우팅/네비게이션 패키지가 아직 없는 Phase 0 시점에서 이걸 구현하는 건 범위 밖이라 판단해 손대지 않았다. 다만 Flutter `Scaffold`는 `bottomNavigationBar` 슬롯이 하나뿐이라, 추후(Task 9+에서 하단 탭 네비게이션을 실제로 이식할 때) `bottomArea`와 "역할별 하단 네비게이션"이 같은 슬롯을 두고 경합하게 된다 — 그때 이 상호 배타성을 어떻게 재현할지(예: `AppLayout`에 `navigationType` 같은 파라미터 추가) 미리 설계 판단이 필요하다는 점을 남겨둔다.

## TDD 증거

### Step 1~2: RED

`test/widget/app_layout_test.dart`에 브리프의 4개 테스트 + 위 대조 결과를 반영한 5개 테스트(총 9개, 아래 "테스트 구성" 참고)를 먼저 작성하고 실행:

```
$ flutter test test/widget/app_layout_test.dart --reporter compact
Compilation failed for testPath=.../app_layout_test.dart:
  Error when reading 'lib/widget/app_layout.dart': No such file or directory
  Error: Method not found: 'AppLayoutHeader'.
  Error: Couldn't find constructor 'AppLayout'.
  ...
00:00 +0 -1: Some tests failed.
```
예상대로 실패(구현 파일 없음).

### Step 3: 구현

`lib/widget/app_layout.dart` 작성(위 웹 대조 결과 3건 반영). 첫 구현 직후 전체 테스트를 돌리자, **브리프가 그대로 준 스크롤 테스트 자체가 잘못됐다는 게 드러났다**:

```
$ flutter test test/widget/app_layout_test.dart --reporter compact
...
AppLayout 본문이 길면 스크롤된다 [E]
Expected: no matching candidates
  Actual: _TextWidgetFinder:<Found 1 widget with text "항목 0": ...>
```

원인을 `ScrollableState.position.pixels`로 직접 찍어 확인했다: 드래그 후 오프셋은 정상적으로 0 → 3000까지 이동했는데도 `find.text('항목 0')`는 계속 `findsOneWidget`이었다. `SingleChildScrollView`의 자식 `Column`은 지연 빌드가 아니라서(`ListView.builder`와 달리 전부 즉시 빌드) 화면 밖으로 스크롤돼도 Element는 계속 마운트돼 있고, `find.text`는 페인트 클리핑이 아니라 Element 트리를 훑기 때문에 스크롤량과 무관하게 항상 찾힌다. 브리프의 `expect(find.text('항목 0'), findsNothing)`은 이 구조에서 **원리적으로 항상 실패**한다(TDD 없이 그대로 구현했다면 여기서 막혔을 것). 테스트를 `ScrollableState.position.pixels` 비교로 고쳤다.

또한 **자체 리뷰 중 키보드 회피 항목을 검증하다가 실제 결함을 발견했다**: `Scaffold.bottomNavigationBar`는 `body`와 달리 키보드(`viewInsets.bottom`)를 피해 저절로 떠오르지 않는다는 걸 Flutter SDK 소스(`scaffold.dart`의 `_ScaffoldLayout.performLayout`, `final double bottom = size.height;` — 화면 전체 높이 기준으로 고정, `viewInsets`는 `body`의 `contentBottom` 계산에만 반영됨)와 `tester.view.viewInsets`를 이용한 직접 실험으로 확인했다. 최초 구현(`Padding(padding: EdgeInsets.all(spacing.s7))`)에서는 키보드를 시뮬레이션해도 하단 위젯 위치가 전혀 움직이지 않았다(`before/after bottomY` 동일). `MediaQuery.viewInsetsOf(context).bottom`을 패딩에 더해 수동으로 띄우도록 고쳤고, 고친 뒤 같은 실험으로 정상 동작(가려지지 않음)을 확인했다.

### Step 4: GREEN

```
$ flutter test test/widget/app_layout_test.dart --reporter compact
...
00:01 +9: All tests passed!
```
9개 테스트 전부 통과.

### 뮤테이션 검증 (핵심 로직이 테스트에 걸리는지)

`body: SafeArea(child: SingleChildScrollView(child: contents))`에서 `SingleChildScrollView`를 제거해 `body: SafeArea(child: contents)`로 바꾼 뒤 재실행:

```
AppLayout 본문이 길면 스크롤된다 [E]   (ScrollableState를 못 찾음 — Scrollable 자체가 없음)
AppLayout Contents에는 기본 패딩을 강제하지 않는다 ... [E]  (SingleChildScrollView를 못 찾음)
00:01 +7 -2: Some tests failed.
```
의도한 2개 테스트가 정확히 실패함을 확인한 뒤, 문자열 치환으로 원복(`git checkout` 사용 안 함 — 사용자 전역 규칙 준수).

## 테스트 구성 (9개)

1. 세 슬롯을 모두 렌더한다 (브리프 원안)
2. header·bottomArea 없이도 동작한다 (브리프 원안)
3. 본문이 길면 스크롤된다 (브리프 의도 유지, 단언은 `ScrollableState.position.pixels`로 교체 — 위 RED 단계 참고)
4. SafeArea로 노치·홈인디케이터를 회피한다 (브리프 원안)
5. **Contents에는 기본 패딩을 강제하지 않는다** (신규 — 웹 대조 1번 반영, `SingleChildScrollView.padding`이 `null`임을 확인)
6. **BottomArea 기본 패딩은 웹 footer의 p-7과 같다** (신규 — 웹 대조 2번 반영, `EdgeInsets.all(s7)` 확인)
7. **키보드가 올라오면 bottomArea가 그만큼 떠서 가려지지 않는다** (신규 — 자체 리뷰 중 발견한 결함의 회귀 테스트)
8. **canPop이 true면 뒤로가기 버튼을 보여준다** (신규)
9. **canPop이 false면 뒤로가기 버튼을 감춘다** (신규)

8·9는 브리프에 없었지만 넣었다 — `AppLayoutHeader`가 62개 화면 전부의 공통 헤더로 쓰일 것이고, `canPop()` 분기는 코드에 이미 있는데 이 분기가 깨지면(예: 리팩터링 중 조건이 뒤집히면) 전체 화면에서 뒤로가기 버튼이 있어야 할 곳에 없거나 반대로 나타나는 조용한 회귀가 된다 — 셸 단위에서 이 정도 대표성 있는 동작은 락인할 가치가 있다고 판단했다.

## 규율(테마 경유) 점검

- 간격: `spacing.s7`(BottomArea 패딩) — 리터럴 없음.
- 색: `colors.gray800`(뒤로가기 아이콘·제목), `theme.scaffoldBackgroundColor`(헤더 배경, 테마 참조이지 리터럴 아님) — 리터럴 색은 `Colors.transparent`(surfaceTintColor, Material3 틴트를 끄기 위한 Flutter API 값) 하나뿐이고 파일 내 주석으로 이유를 남겼다. **`Colors.white`는 아예 쓰지 않았다**(위 대조 3번).
- 타이포: `AppTypography.title1` — 리터럴 없음.
- 라운드: 이 위젯엔 라운드가 없어 해당 없음.

## 셀프 리뷰

- **62개 화면을 담기에 맞는가**: Contents/BottomArea 기본값을 웹 실측(전수 조사)에 맞춰 고쳤고, 화면마다 필요한 만큼 자유롭게 얹을 수 있는 구조(Contents는 패딩 없음)를 유지해 향후 화면 이식 시 웹 대응 패딩을 그대로 재현할 수 있다.
- **슬롯 구조·패딩 대응**: 위 3건 수정으로 웹과 실제로 대응함을 확인.
- **테마 경유**: 위 점검 결과 통과.
- **키보드 회피**: 초기 구현은 결함이 있었고(`bottomNavigationBar`는 키보드를 자동으로 피하지 않음), 실험으로 확인 후 `MediaQuery.viewInsetsOf(context).bottom`을 더하는 방식으로 고치고 회귀 테스트로 락인했다.
- **테스트가 실제 동작을 검증하는가 / 스크롤 단언을 지우면 통과하는가**: 뮤테이션 검증으로 확인(위 참고) — `SingleChildScrollView` 제거 시 스크롤 테스트와 Contents 패딩 테스트가 정확히 실패한다.
- **완전성·YAGNI**: 브리프가 지정한 파일 2개(`lib/widget/app_layout.dart`, `test/widget/app_layout_test.dart`)만 추가했고, 인터페이스(`AppLayout({header, contents, bottomArea})`)를 넘어서는 파라미터(예: BottomArea 패딩 override, Contents 패딩 override)는 추가하지 않았다 — 필요해지면(Task 9+에서 특정 화면이 `p-0`을 요구할 때) 그때 추가하는 게 맞다고 판단.
- **테스트 출력 청결도**: `verify.sh` 전체 실행 결과 경고·에러 없음(`flutter analyze`: No issues found; `dart format`: 0 changed).

## 변경 파일

- `lib/widget/app_layout.dart` (신규, 107줄)
- `test/widget/app_layout_test.dart` (신규, 162줄)

## 우려사항

1. **웹 기본 배경(`gray-100`) vs Flutter `scaffoldBackgroundColor`(흰색) 불일치**는 Task 2/3에서 이미 확정된 값이라 이번 태스크에서 건드리지 않았지만, 62개 화면을 이식하면서 "기본 배경이 계속 흰색이어도 되는지" 한 번은 검토가 필요해 보인다.
2. **웹의 `type`(trainer/student 역할별 네비게이션) vs `bottomArea`의 상호 배타성**은 라우팅 패키지 도입 후(Task 9+) `AppLayout`이 다시 손볼 대상이 될 가능성이 높다 — 지금은 인터페이스에 없다.
3. BottomArea 패딩(`EdgeInsets.all(s7)`)과 Contents 패딩(없음) 모두 override 파라미터가 없다 — 특정 화면이 웹처럼 `p-0`이나 다른 조합을 요구하면 그때 `AppLayout` 시그니처 확장이 필요하다.

---

# Fix 라운드 1 — 기본 배경색 (우려 #4)

## 코디네이터 판정 요약

- 웹 대조로 고친 3곳(Contents 패딩 없음 / BottomArea `p-7` 균등 / Header 배경을 `scaffoldBackgroundColor` 참조)과 스크롤 테스트 교체, 키보드 회피 결함 수정 — **전부 승인**.
- 우려 #3(웹 role별 네비게이션과 bottomArea 상호배타성)은 **Phase 2 범위**로 이연.
- **우려 #4(웹 기본 배경 `bg-gray-100` vs Flutter `scaffoldBackgroundColor` 흰색 불일치)만 수정 대상.**

## 지시 사항

`src/widget/layout.tsx:31` 확인 결과 Layout 루트가 `bg-gray-100`이고, 개별 화면이 `bg-white`(86곳) 또는 `bg-gray-100`(39곳)로 덮는 구조. `AppLayout`에 `Color? backgroundColor` 파라미터를 추가해 기본값 `colors.gray100`, override 시 그 색을 쓰도록 수정. `AppTheme.light()`의 `scaffoldBackgroundColor`는 그대로 둔다(Task 3 재작업 아님).

## 구현

`lib/widget/app_layout.dart`:

1. `AppLayout`에 `final Color? backgroundColor;` 필드·생성자 파라미터 추가.
2. `build()`에서 `colors = theme.extension<AppColors>()!`를 추가로 얻어 `Scaffold(backgroundColor: backgroundColor ?? colors.gray100, ...)`로 변경.
3. **부수 수정(지시받지 않았지만 필요했던 부분)**: `AppLayoutHeader`의 `AppBar.backgroundColor`를 `theme.scaffoldBackgroundColor` 참조에서 `Colors.transparent`로 바꿨다. 이유: 기존 구현은 "헤더가 `Scaffold`의 배경과 항상 같은 값을 보이게 하자"는 의도로 전역 테마의 `scaffoldBackgroundColor`(흰색, 고정값)를 참조했다. 이번 수정으로 `Scaffold.backgroundColor`가 인스턴스별로 `colors.gray100` 기본값 또는 화면별 override로 바뀌는데, 헤더가 여전히 전역 테마 값(흰색)만 참조하면 **헤더는 항상 흰색, 몸체/하단은 기본 회색** — 화면 하나 안에서 색이 어긋나는 새로운 결함이 생긴다. `AppBar`는 그 자체로 불투명한 Material이라 `backgroundColor: Colors.transparent`로 두면 `AppLayout`이 그 순간 실제로 칠한 배경(기본값이든 override든)이 그대로 비쳐 보인다 — 웹의 "Header는 고유 배경이 없다"는 서술과도 더 정확히 맞는다. 이 조정을 하지 않으면 우려 #4를 고치는 과정에서 눈에 보이는 이음매(seam)가 새로 생기므로, 지시된 범위를 벗어나지만 함께 처리했다.

## 테스트

`test/widget/app_layout_test.dart`에 2개 추가(총 11개):

```dart
testWidgets(
  '배경 기본값은 웹 Layout 루트의 bg-gray-100과 같다 (AppColors.gray100)',
  (tester) async {
    await tester.pumpWidget(_wrap(const AppLayout(contents: Text('본문'))));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.light.gray100);
  },
);

testWidgets(
  'backgroundColor를 넘기면 그 색으로 덮는다 (웹 화면별 bg-white override 대응)',
  (tester) async {
    await tester.pumpWidget(_wrap(
      const AppLayout(contents: Text('본문'), backgroundColor: Colors.white),
    ));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.white);
  },
);
```

실행 결과:

```
$ flutter test test/widget/app_layout_test.dart --reporter compact
...
00:01 +11: All tests passed!
```

11개 전부 통과(기존 9개 + 신규 2개).

## `./tool/verify.sh` 4단계 전체 실행

```
$ ./tool/verify.sh
== dart format ==
Formatted 30 files (0 changed) in 0.04s   # (첫 실행에서 신규 테스트 1개 파일 자동 정렬 후 재실행 결과)
== flutter analyze ==
No issues found!
== har_to_golden.py 테스트 ==
Ran 14 tests in 0.003s — OK
== flutter test ==
...
00:02 +83: All tests passed!
OK: 모든 검증 통과
```

4단계 전부 통과(Dart 83개 + Python 14개).

## 커밋

`9f0153f` `fix(widget): AppLayout 기본 배경을 웹 bg-gray-100에 맞춘다`
- `lib/widget/app_layout.dart` (backgroundColor 파라미터 추가, Header 배경을 transparent로 변경)
- `test/widget/app_layout_test.dart` (배경 기본값/override 테스트 2개 추가)

## 남은 우려 (변경 없음)

- 우려 #3(웹 role별 네비게이션 vs bottomArea 상호배타성) — Phase 2에서 처리하기로 확정, 이번 라운드에서 손대지 않음.
- 우려 #2/#3(BottomArea·Contents 패딩 override 파라미터 부재)는 Task 8 최초 보고 그대로 유효 — 이번 fix에서 다루지 않음.

---

# Fix 라운드 2 — 태스크 리뷰 Important 2건

## 코디네이터 판정 요약

- 웹 대조로 고친 네 곳(Contents 패딩 없음 / BottomArea `p-7` 균등 / 기본 배경 gray100 / Header 배경 상속), 스크롤 테스트 진단, 키보드 회피 결함 진단 — **전부 리뷰어가 독립적으로 재확인, 승인**.
- **Important #1**: `Size.fromHeight(56)`의 56이 `AppSpacing.standard` 12단 어디에도 없는데 예외 사유 주석이 없었다. 자체 감사가 이걸 놓쳤다는 지적도 있었다.
- **Important #2**: `AppBar.backgroundColor: Colors.transparent`(직전 라운드에서 범위를 넘어 추가한 판단, 그 자체는 승인)에 회귀 테스트가 없었다.
- Deferred: 웹 Header의 `px-7 py-6` 인셋 미이식(Phase 0 범위 밖, 시각 parity는 골든/스크린샷 영역), 키보드 회피 수정의 별도 뮤테이션 검증(커버리지 폭 문제이지 결함 아님) — 둘 다 그대로 둔다.

## Important #1 — 헤더 높이 리터럴 근거 명시

`lib/widget/app_layout.dart`에 `AppLayoutHeader.height`를 named static const로 노출하고, 그 위에 예외 사유를 남겼다(파일 88~94줄):

```dart
/// 웹 `Layout.Header`의 `h-[56px]`(Tailwind 임의값 문법) 대응.
///
/// 예외(토큰화하지 않는 리터럴): 56은 `AppSpacing.standard`의 12단
/// (4/6/8/10/12/16/20/24/28/32/36/48) 어디에도 없다 — 웹도 같은 이유로
/// 스페이싱 스케일 클래스 대신 임의값 문법(`h-[56px]`)을 썼다. 헤더
/// 높이는 간격 토큰이 아니라 이 컴포넌트 고유의 고정 치수라 그대로 둔다.
static const double height = 56;

@override
Size get preferredSize => const Size.fromHeight(height);
```

56이 실제로 12단 스케일에 없다는 근거(웹 `layout.tsx:46`의 `h-[56px]` 자체가 Tailwind 표준 스케일 클래스가 아니라 임의값 문법이라는 점)는 코디네이터가 이미 짚었고, `AppSpacing.standard`(s1~s12: 4/6/8/10/12/16/20/24/28/32/36/48) 정의를 직접 다시 읽어 대조해 확인했다.

## Important #2 — 헤더 배경 이음매 회귀 테스트

`test/widget/app_layout_test.dart`에 2개 추가(총 13개):

```dart
testWidgets(
  '헤더 배경은 이음매 없이 Scaffold 기본 배경(gray100)과 같게 보인다',
  (tester) async {
    await tester.pumpWidget(_wrap(
      const AppLayout(
        header: AppLayoutHeader(title: '로그인'),
        contents: Text('본문'),
      ),
    ));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(scaffold.backgroundColor, AppColors.light.gray100);
    expect(appBar.backgroundColor, Colors.transparent);
  },
);

testWidgets(
  'backgroundColor를 override해도 헤더가 그 색과 이음매 없이 같게 보인다',
  (tester) async {
    await tester.pumpWidget(_wrap(
      const AppLayout(
        header: AppLayoutHeader(title: '상세'),
        contents: Text('본문'),
        backgroundColor: Colors.white,
      ),
    ));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(scaffold.backgroundColor, Colors.white);
    expect(appBar.backgroundColor, Colors.transparent);
  },
);
```

논리: `Scaffold`는 `widget.backgroundColor`를 AppBar 뒤를 포함한 전체 캔버스에 먼저 칠하는 Material이다(Flutter SDK `scaffold.dart:3237`, `color: widget.backgroundColor ?? themeData.scaffoldBackgroundColor`). `AppBar.backgroundColor`가 `transparent`인 한 그 뒤로 Scaffold가 고른 색이 그대로 비친다 — 두 값을 함께 단언하면 "헤더가 Scaffold와 같은 색으로 보인다"는 사실이 논리적으로 성립한다(픽셀 골든 없이도).

### 테스트 실행 (GREEN)

```
$ flutter test test/widget/app_layout_test.dart --reporter compact
...
00:01 +13: All tests passed!
```

13개 전부 통과(기존 11개 + 신규 2개).

### 뮤테이션 검증 — 새 테스트가 실제로 걸리는지

`AppBar.backgroundColor: Colors.transparent`를 `Colors.white`로 바꿔 "누가 헤더 배경을 하드코딩하면"을 재현:

```
$ flutter test test/widget/app_layout_test.dart --reporter compact
...
AppLayout 헤더 배경은 이음매 없이 Scaffold 기본 배경(gray100)과 같게 보인다 [E]
Expected: Color:<Color(alpha: 0.0000, ...)>   (transparent)
  Actual: Color:<Color(alpha: 1.0000, red: 1.0000, green: 1.0000, blue: 1.0000, ...)>  (white)

AppLayout backgroundColor를 override해도 헤더가 그 색과 이음매 없이 같게 보인다 [E]
...
00:01 +9 -2: Some tests failed.
```

의도한 2개 테스트가 정확히 실패함을 확인한 뒤, 문자열 치환으로 원복(`Colors.white` → `Colors.transparent`, `git checkout` 미사용).

## 컴플라이언스 자체 감사 재수행 (항목별 확인 방법 + 결과)

지난 라운드 감사는 "리터럴 없음"이라고만 적고 실제로 훑은 흔적이 없었다는 지적을 받았다. 이번엔 각 항목마다 실행한 명령과 그 출력을 그대로 남긴다.

### 1) 색상(Colors.*, Color(...)) 전수

```
$ grep -n "Colors\.\|Color(0x" lib/widget/app_layout.dart
41:  /// 웹 `Layout` 루트 배경 대응. 기본값은 `AppColors.gray100`(웹     ← 주석
42:  /// `bg-gray-100`) — 화면이 흰 배경을 쓰려면 `Colors.white`를 넘긴다.  ← 주석
118:      backgroundColor: Colors.transparent,
121:      surfaceTintColor: Colors.transparent,
```
실제 코드에서 쓰인 색 리터럴은 `Colors.transparent` 2곳뿐(둘 다 41번 라인 근방이 아니라 118·121줄 — 각각 118줄 위 105~117줄, 121줄 바로 위 119~120줄에 예외 사유 주석 있음). `Color(0x...)` 하드코딩 없음. `Colors.white`는 코드에는 없고 문서 주석(42줄, "override 시 이렇게 쓴다"는 사용 예시)에만 등장 — 실제 로직에 박혀 있지 않음을 확인.

### 2) 숫자 리터럴 전수(주석 제외, 실제 코드 라인만)

```
$ grep -nE '[0-9]' lib/widget/app_layout.dart | grep -v '^\s*[0-9]\+\s*///\?'
```
(주석 라인을 눈으로 걸러 코드 라인만 추린 결과)
- `59: backgroundColor: backgroundColor ?? colors.gray100,` — 리터럴 아님(토큰 참조)
- `67: EdgeInsets.all(spacing.s7) +` — 리터럴 아님(토큰 참조)
- `94: static const double height = 56;` — 리터럴, 예외 사유 주석 있음(88~93줄)
- `122~125: elevation: 0,` — 리터럴, 이번 라운드에서 예외 사유 주석 추가(122~124줄)
- `126: icon: Icon(Icons.arrow_back_ios_new, color: colors.gray800),` — `Icons.arrow_back_ios_new`는 색·간격·라운드·타이포 카테고리가 아니라 아이콘 콘텐츠 식별자라 이 규율의 대상이 아니라고 판단(별도 `AppIcons` 토큰 체계가 이 프로젝트에 없음 — Task 2·3·7 어디에도 아이콘 토큰화 언급 없음을 확인).

결과: 리터럴로 남는 숫자는 `56`(height)과 `0`(elevation) 둘뿐이고, 이번 라운드 조치로 **둘 다 예외 사유 주석이 붙었다.**

### 3) EdgeInsets/Size/Radius/BorderRadius 전수

```
$ grep -n "EdgeInsets\|Size\.\|Radius\|BorderRadius" lib/widget/app_layout.dart
67:                    EdgeInsets.all(spacing.s7) +
68:                    EdgeInsets.only(bottom: keyboardInset),
97:  Size get preferredSize => const Size.fromHeight(height);
```
`EdgeInsets`는 전부 토큰(`spacing.s7`) 또는 동적 값(`keyboardInset` = `MediaQuery.viewInsetsOf(context).bottom`)이라 리터럴 없음. `Size.fromHeight(height)`는 named const를 참조 — 그 상수 자체의 근거는 위 2)에서 확인. `Radius`/`BorderRadius` 사용 없음(이 위젯엔 라운드 요소가 없다는 최초 보고 그대로).

### 4) 테마 경유 확인(spacing./colors./AppTypography. 참조)

```
$ grep -n "spacing\.\|colors\.\|AppTypography\." lib/widget/app_layout.dart
59:      backgroundColor: backgroundColor ?? colors.gray100,
67:                    EdgeInsets.all(spacing.s7) +
126:              icon: Icon(Icons.arrow_back_ios_new, color: colors.gray800),
135:        style: AppTypography.title1.copyWith(color: colors.gray800),
```
색 3곳(`colors.gray100`, `colors.gray800` ×2), 간격 1곳(`spacing.s7`), 타이포 1곳(`AppTypography.title1`) 전부 테마/정적 상수 경유 확인.

### 5) 결론

- 색: `Colors.transparent` 2곳(예외, 주석 있음) 제외 전부 테마 경유.
- 간격: `s7` 1곳, 전부 토큰. 리터럴 없음.
- 라운드: 사용처 없음.
- 타이포: `AppTypography.title1` 1곳, 리터럴 없음.
- **토큰화 안 된 숫자 리터럴 2곳(`height = 56`, `elevation: 0`) — 둘 다 이번 라운드에서 예외 사유 주석을 갖췄다.** 지난 라운드에 "리터럴 없음"이라고 결론만 적어 전자를 놓쳤던 것과 달리, 이번엔 grep 결과를 라인 단위로 실제로 읽어 위 목록을 만들었다.

## `./tool/verify.sh` 4단계 전체 실행 (최종)

```
$ ./tool/verify.sh
== dart format ==
Formatted 30 files (0 changed) in 0.03s
== flutter analyze ==
No issues found! (ran in 0.7s)
== har_to_golden.py 테스트 ==
Ran 14 tests in 0.004s — OK
== flutter test ==
...
00:02 +85: All tests passed!
OK: 모든 검증 통과
```

Dart 85개(11개→13개 증가분 포함 재확인 후 총계) + Python 14개 전부 통과.

## 커밋

- `e5bf256` `fix(widget): 헤더 높이 리터럴 근거 명시하고 배경 이음매 회귀 테스트 추가` — Important #1(height 상수화+주석)과 #2(회귀 테스트 2개) 본 수정.
- `b09c9b2` `fix(widget): elevation:0 리터럴에도 예외 사유 주석 추가` — 이번 라운드 재감사(항목 2) 중 발견한 추가 미비점 보완. 새 문제가 아니라 지난 라운드에 이미 존재했던 것을 이번에 실제로 grep을 돌려 찾아냈다.

## 남은 우려 (변경 없음, 코디네이터 확정)

- 우려 #3(웹 role별 네비게이션 vs bottomArea 상호배타성) — Phase 2 범위로 확정, 손대지 않음.
- BottomArea·Contents 패딩 override 파라미터 부재 — 여전히 유효, 이번 라운드에서 다루지 않음.
- 웹 Header의 `px-7 py-6` 인셋 미이식 — 시각 parity 영역으로 deferred 확정.
