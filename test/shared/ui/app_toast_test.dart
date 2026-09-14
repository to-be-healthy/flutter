import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/shared/ui/app_toast.dart';

Widget _wrap(AppToastController controller, {Widget? child}) {
  return MaterialApp(
    theme: AppTheme.light(),
    // 프로덕션(`app.dart`)과 같은 조립이다 — 스코프가 호스트보다 **위**에
    // 있어야 `AppToastScope.of(context)`가 찾는다.
    home: AppToastScope(
      notifier: controller,
      child: AppToastHost(child: child ?? const SizedBox.shrink()),
    ),
  );
}

/// 전환 애니메이션을 끝까지 돌린다. `pumpAndSettle`을 쓰면 2초 타이머가
/// 함께 흘러 토스트가 사라진 뒤를 보게 된다.
Future<void> _settleTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppToastHost.transitionDuration);
}

void main() {
  group('AppToastController', () {
    test('메시지가 없으면 웹과 같은 기본 문구를 쓴다', () {
      // 웹 `errorToast`: `message ?? '문제가 발생했습니다.'`.
      final controller = AppToastController();
      addTearDown(controller.dispose);

      controller.showError(null);

      expect(controller.current!.text, '문제가 발생했습니다.');
    });

    test('빈 문자열도 기본 문구로 바꾼다', () {
      // 서버가 `message: ''`를 주면 웹은 빈 토스트를 띄우지만, 그건 빈
      // 검은 막대라 아무 정보가 없다.
      final controller = AppToastController();
      addTearDown(controller.dispose);

      controller.showError('');

      expect(controller.current!.text, AppToastController.defaultErrorText);
    });

    test('동시에 하나만 남는다 — 새 토스트가 이전 것을 밀어낸다', () {
      // 웹 `TOAST_LIMIT = 1`.
      final controller = AppToastController();
      addTearDown(controller.dispose);

      controller.showError('첫 번째');
      controller.showError('두 번째');

      expect(controller.current!.text, '두 번째');
    });

    test('dispose가 타이머를 끊는다', () {
      // 끊지 않으면 2초 뒤 dispose된 notifier에 `notifyListeners()`가 날아가
      // 앱이 죽는다. 이 테스트는 타이머가 남으면 프레임워크가 실패시킨다.
      final controller = AppToastController()..showError('곧 버려질 토스트');

      controller.dispose();
    });
  });

  group('AppToastHost', () {
    testWidgets('에러 토스트를 웹과 같은 모양으로 그린다', (tester) async {
      final controller = AppToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller));

      controller.showError('회원이 존재하지 않습니다.');
      await _settleTransition(tester);

      expect(find.text('회원이 존재하지 않습니다.'), findsOneWidget);

      // 웹 toast variant `default`: `rounded-lg bg-gray-700 text-white`.
      final box = tester.widget<Container>(
        find.ancestor(
          of: find.text('회원이 존재하지 않습니다.'),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;

      expect(decoration.color, AppColors.light.gray700);

      controller.dismiss();
    });

    testWidgets('2초 뒤 스스로 사라진다', (tester) async {
      // 웹 `TOAST_DURATION = 2000`.
      final controller = AppToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller));

      controller.showError('잠시 뒤 사라진다');
      await _settleTransition(tester);
      expect(find.text('잠시 뒤 사라진다'), findsOneWidget);

      // 타이머는 시간 경과 중에 `dismiss()`를 부르지만 그 리빌드는 다음
      // 프레임이고, 퇴장 애니메이션이 또 200ms 남는다.
      await tester.pump(AppToastController.visibleDuration);
      await tester.pumpAndSettle();

      expect(find.text('잠시 뒤 사라진다'), findsNothing);
    });

    testWidgets('토스트를 띄운 화면이 사라진 뒤에 불러도 뜬다', (tester) async {
      // **이 위젯이 존재하는 이유 자체다.**
      //
      // 웹 `useToast()`는 React context가 아니라 모듈 전역 스토어라,
      // `errorToast(...)`를 부른 컴포넌트가 이미 언마운트됐어도 토스트가
      // 뜬다. Flutter에서 같은 성질을 얻으려면 토스트 상태가 화면보다 오래
      // 사는 객체에 있어야 한다.
      //
      // 뮤테이션: 컨트롤러를 화면(State) 안에서 만들면 화면이 버려질 때
      // 함께 버려져 이 단언이 깨진다.
      final controller = AppToastController();
      addTearDown(controller.dispose);

      late AppToastController captured;
      late StateSetter setOuter;
      var pageMounted = true;

      await tester.pumpWidget(
        _wrap(
          controller,
          child: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              if (!pageMounted) {
                return const SizedBox.shrink();
              }
              return Builder(
                builder: (pageContext) {
                  // 화면이 `await` 앞에서 잡아두는 참조와 같다.
                  captured = AppToastScope.read(pageContext);
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      );

      setOuter(() => pageMounted = false);
      await tester.pump();

      captured.showError('요청에 실패했습니다.');
      await _settleTransition(tester);

      expect(find.text('요청에 실패했습니다.'), findsOneWidget);

      controller.dismiss();
    });

    testWidgets('토스트 자리가 아래 버튼의 탭을 가로채지 않는다', (tester) async {
      // 뷰포트는 헤더 위를 덮고 있어서, 포인터를 받으면 화면 상단의
      // 닫기·뒤로가기가 눌리지 않는다. 토스트가 **없을 때도** 그렇다.
      //
      // 뮤테이션: `IgnorePointer`를 지우면 아래 두 탭 중 하나가 0회가 된다.
      final controller = AppToastController();
      addTearDown(controller.dispose);

      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          controller,
          child: Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => taps++,
              behavior: HitTestBehavior.opaque,
              // 헤더의 닫기 버튼과 비슷한 자리·크기.
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(24, 24));
      expect(taps, 1, reason: '토스트가 없을 때도 상단 탭이 통과해야 한다');

      controller.showError('토스트가 떠 있는 상태');
      await _settleTransition(tester);

      await tester.tapAt(const Offset(24, 24));
      expect(taps, 2, reason: '토스트가 떠 있어도 상단 탭이 통과해야 한다');

      controller.dismiss();
    });
  });
}
