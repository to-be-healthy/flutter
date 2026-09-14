import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_spacing.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/widget/app_layout.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  group('AppLayout', () {
    testWidgets('세 슬롯을 모두 렌더한다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppLayout(
            header: AppLayoutHeader(title: '로그인'),
            contents: Text('본문'),
            bottomArea: Text('하단'),
          ),
        ),
      );

      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('본문'), findsOneWidget);
      expect(find.text('하단'), findsOneWidget);
    });

    testWidgets('header·bottomArea 없이도 동작한다', (tester) async {
      await tester.pumpWidget(_wrap(const AppLayout(contents: Text('본문만'))));

      expect(find.text('본문만'), findsOneWidget);
    });

    testWidgets('본문이 길면 스크롤된다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppLayout(
            contents: Column(
              children: List.generate(
                50,
                (i) => SizedBox(height: 100, child: Text('항목 $i')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('항목 0'), findsOneWidget);

      // 브리프 원안은 드래그 후 `find.text('항목 0')`가 findsNothing이길
      // 기대했지만, SingleChildScrollView의 자식 Column은 지연 빌드가
      // 아니라서 스크롤로 화면 밖으로 밀려나도 Element는 계속 마운트돼
      // 있다 — find.text는 페인트 클리핑이 아니라 Element 트리를 보므로
      // 스크롤을 아무리 해도 findsOneWidget으로 남는다(직접 확인:
      // ScrollableState.position.pixels는 3000까지 정상 이동했는데도
      // 이 단언은 항상 실패했다). 그래서 스크롤 위치 자체를 검증한다.
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, 0);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pump();

      expect(scrollable.position.pixels, greaterThan(0));
    });

    testWidgets('SafeArea로 노치·홈인디케이터를 회피한다', (tester) async {
      await tester.pumpWidget(_wrap(const AppLayout(contents: Text('본문'))));

      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('Contents에는 기본 패딩을 강제하지 않는다 '
        '(웹 Layout.Contents는 좌우 패딩이 없고 화면마다 직접 얹는다)', (tester) async {
      await tester.pumpWidget(_wrap(const AppLayout(contents: Text('본문'))));

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(scrollView.padding, isNull);
    });

    testWidgets('BottomArea 기본 패딩은 웹 footer의 p-7(사방 20px, spacing.s7)과 같다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppLayout(contents: Text('본문'), bottomArea: Text('하단'))),
      );

      final paddings = tester.widgetList<Padding>(
        find.ancestor(of: find.text('하단'), matching: find.byType(Padding)),
      );

      expect(
        paddings.map((p) => p.padding),
        contains(EdgeInsets.all(AppSpacing.standard.s7)),
      );
    });

    testWidgets('키보드가 올라오면 bottomArea가 그만큼 떠서 가려지지 않는다', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppLayout(contents: Text('본문'), bottomArea: Text('하단'))),
      );

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      // Scaffold.bottomNavigationBar는 body와 달리 키보드를 피해 저절로
      // 떠오르지 않는다(직접 확인) — 키보드가 300 논리픽셀을 가린다고
      // 가정하면 bottomArea는 그 위(screenHeight - 300)에 있어야 한다.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // 논리 300
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump();

      final bottomAreaY = tester.getBottomLeft(find.text('하단')).dy;

      expect(bottomAreaY, lessThanOrEqualTo(screenHeight - 300));
    });

    testWidgets('배경 기본값은 웹 Layout 루트의 bg-gray-100과 같다 (AppColors.gray100)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppLayout(contents: Text('본문'))));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      expect(scaffold.backgroundColor, AppColors.light.gray100);
    });

    testWidgets('backgroundColor를 넘기면 그 색으로 덮는다 (웹 화면별 bg-white override 대응)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppLayout(contents: Text('본문'), backgroundColor: Colors.white),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      expect(scaffold.backgroundColor, Colors.white);
    });

    testWidgets('헤더 배경은 이음매 없이 Scaffold 기본 배경(gray100)과 같게 보인다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppLayout(
            header: AppLayoutHeader(title: '로그인'),
            contents: Text('본문'),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final appBar = tester.widget<AppBar>(find.byType(AppBar));

      // AppBar 자체가 투명해야 그 뒤로 Scaffold가 실제로 칠한 배경이
      // 비쳐 보인다 — 둘 중 하나라도 어긋나면(예: 누가 AppBar에 색을
      // 하드코딩하면) 헤더와 몸체 사이에 이음매가 생긴다.
      expect(scaffold.backgroundColor, AppColors.light.gray100);
      expect(appBar.backgroundColor, Colors.transparent);
    });

    testWidgets('backgroundColor를 override해도 헤더가 그 색과 이음매 없이 같게 보인다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppLayout(
            header: AppLayoutHeader(title: '상세'),
            contents: Text('본문'),
            backgroundColor: Colors.white,
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final appBar = tester.widget<AppBar>(find.byType(AppBar));

      expect(scaffold.backgroundColor, Colors.white);
      expect(appBar.backgroundColor, Colors.transparent);
    });

    testWidgets('헤더 제목 타이포·색은 웹 HEADING_4_SEMIBOLD + gray-800과 같다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppLayout(
            header: AppLayoutHeader(title: '로그인'),
            contents: Text('본문'),
          ),
        ),
      );

      final title = tester.widget<Text>(find.text('로그인'));

      // 웹 `SignInPage.tsx:27` = `cn(Typography.HEADING_4_SEMIBOLD,
      // 'layout-header-title')` → 18px/130% semibold. 127개 화면이 이 헤더를
      // 쓰므로 여기서 한 번 어긋나면 전부 어긋난다.
      expect(
        title.style,
        AppTypography.heading4SemiBold.copyWith(color: AppColors.light.gray800),
      );
    });

    testWidgets('헤더의 선언 높이와 실제 렌더 높이가 같다', (tester) async {
      // `preferredSize`만 바꾸고 `AppBar.toolbarHeight`를 넘기지 않으면 실제
      // 높이는 Material 기본값 `kToolbarHeight`로 남는다. 지금은 둘 다 56이라
      // 우연히 일치하지만, 상수를 바꾸는 순간 선언과 렌더가 조용히 어긋난다.
      await tester.pumpWidget(
        _wrap(
          const AppLayout(
            header: AppLayoutHeader(title: '로그인'),
            contents: Text('본문'),
          ),
        ),
      );

      // 박스 크기는 Scaffold가 `preferredSize`로 잡아주므로 선언만 따라온다.
      // 실제로 어긋나는 건 **툴바 내용의 배치**다: `toolbarHeight`를 넘기지
      // 않으면 내용은 `kToolbarHeight`(56) 기준으로 놓여, 선언 높이가 56이
      // 아닌 순간 제목이 박스 가운데에서 벗어난다.
      expect(
        tester.getSize(find.byType(AppBar)).height,
        AppLayoutHeader.height,
        reason: 'preferredSize가 선언 높이를 그대로 전달해야 한다',
      );

      final titleRect = tester.getRect(find.text('로그인'));
      expect(
        titleRect.center.dy,
        moreOrLessEquals(AppLayoutHeader.height / 2, epsilon: 0.5),
        reason:
            '제목이 선언 높이의 세로 가운데에 놓여야 한다 '
            '(toolbarHeight 미전달이면 kToolbarHeight 기준으로 밀린다)',
      );
    });

    testWidgets('canPop이 true면(하위 화면) 뒤로가기 버튼을 보여준다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppLayout(
                    header: AppLayoutHeader(title: '상세'),
                    contents: Text('본문'),
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      // 웹 `IconBack`(`back.svg`) 자산을 쓴다 — Material 기본 아이콘이 아니다.
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('onBack이 있으면 스택이 비어 있어도 뒤로가기를 보여준다', (tester) async {
      // 웹 로그인 화면의 뒤로가기는 `router.push('/')`라 히스토리와 무관하게
      // 늘 떠 있다. `canPop()`만 보면 첫 화면으로 진입했을 때 사라진다.
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AppLayout(
            header: AppLayoutHeader(title: '회원 로그인', onBack: () => tapped++),
            contents: const Text('본문'),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(tapped, 1, reason: 'onBack이 불리지 않았다');
    });

    testWidgets('canPop이 false면(루트 화면) 뒤로가기 버튼을 감춘다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppLayout(
            header: AppLayoutHeader(title: '로그인'),
            contents: Text('본문'),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsNothing);
    });
  });
}
