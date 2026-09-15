import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/core/theme/app_typography.dart';
import 'package:geonganghaejim/shared/ui/app_otp_input.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

/// 부모가 `value`를 갈아끼우는 상황(웹 `setAuthValue('')`)을 재현하는 껍데기.
class _Controlled extends StatefulWidget {
  const _Controlled();

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppOtpInput(
          value: _value,
          onChanged: (next) => setState(() => _value = next),
        ),
        TextButton(
          onPressed: () => setState(() => _value = ''),
          child: const Text('리셋'),
        ),
      ],
    );
  }
}

/// 슬롯 안의 글자만 잡는다.
///
/// 맨 `find.text`를 쓰면 **보이지 않는 입력(EditableText)의 값까지 함께**
/// 잡힌다 — 같은 문자열이 두 곳에 존재하는 것이 이 위젯의 구조다.
/// "슬롯에 보인다"를 단언하려면 슬롯 안으로 범위를 좁혀야 한다.
Finder _slotText(int index, String char) => find.descendant(
  of: find.byKey(AppOtpInput.slotKey(index)),
  matching: find.text(char),
);

BoxDecoration _slotDecoration(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find.byKey(AppOtpInput.slotKey(index)),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('AppOtpInput', () {
    testWidgets('기본 길이만큼 슬롯을 그린다', (tester) async {
      await tester.pumpWidget(_wrap(AppOtpInput(value: '', onChanged: (_) {})));

      for (var i = 0; i < AppOtpInput.defaultLength; i++) {
        expect(find.byKey(AppOtpInput.slotKey(i)), findsOneWidget);
      }
      expect(
        find.byKey(AppOtpInput.slotKey(AppOtpInput.defaultLength)),
        findsNothing,
      );
    });

    // 웹 `input-otp`는 **입력 하나 + 슬롯 6개 렌더**다. 입력이 6개면
    // 붙여넣기와 슬롯 경계 backspace가 달라진다.
    testWidgets('보이지 않는 입력은 하나뿐이다', (tester) async {
      await tester.pumpWidget(_wrap(AppOtpInput(value: '', onChanged: (_) {})));

      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('입력한 문자가 슬롯에 순서대로 보인다', (tester) async {
      await tester.pumpWidget(_wrap(const _Controlled()));

      await tester.enterText(find.byType(EditableText), '135');
      await tester.pump();

      expect(_slotText(0, '1'), findsOneWidget);
      expect(_slotText(1, '3'), findsOneWidget);
      expect(_slotText(2, '5'), findsOneWidget);
    });

    testWidgets('최대 길이를 넘겨 입력해도 길이까지만 전달한다', (tester) async {
      final received = <String>[];
      await tester.pumpWidget(
        _wrap(AppOtpInput(value: '', onChanged: received.add)),
      );

      await tester.enterText(find.byType(EditableText), '12345678');
      await tester.pump();

      expect(received.last, '123456');
      expect(received.last.length, AppOtpInput.defaultLength);
    });

    testWidgets('입력할 때마다 현재 값으로 onChanged를 부른다', (tester) async {
      final received = <String>[];
      await tester.pumpWidget(
        _wrap(AppOtpInput(value: '', onChanged: received.add)),
      );

      await tester.enterText(find.byType(EditableText), '12');
      await tester.pump();

      expect(received.last, '12');
    });

    // 웹 `clickNext`가 `setAuthValue('')`로 값을 비운다. 내부 컨트롤러가
    // 부모 값을 따라오지 않으면 step 2에 남은 코드가 그대로 보인다.
    testWidgets('부모가 value를 비우면 슬롯도 비워진다', (tester) async {
      await tester.pumpWidget(_wrap(const _Controlled()));

      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();
      expect(_slotText(0, '1'), findsOneWidget);

      await tester.tap(find.text('리셋'));
      await tester.pump();

      expect(_slotText(0, '1'), findsNothing);
      expect(_slotText(5, '6'), findsNothing);
    });

    // 웹 `GymVerificationCode`의 `useEffect(() => ref.current.focus(), [])`.
    testWidgets('마운트하면 곧바로 포커스를 받는다', (tester) async {
      await tester.pumpWidget(_wrap(AppOtpInput(value: '', onChanged: (_) {})));
      await tester.pump();

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('활성 슬롯은 다음에 채워질 자리 하나뿐이다', (tester) async {
      await tester.pumpWidget(
        _wrap(AppOtpInput(value: '12', onChanged: (_) {})),
      );

      expect(_slotDecoration(tester, 2).border, isNotNull);
      expect(_slotDecoration(tester, 0).border, isNull);
      expect(_slotDecoration(tester, 1).border, isNull);
      expect(_slotDecoration(tester, 3).border, isNull);
    });

    testWidgets('전부 채우면 활성 표시가 마지막 슬롯에 머문다', (tester) async {
      // 클램프가 없으면 인덱스 6을 활성으로 보고 어느 슬롯에도 표시가
      // 남지 않는다 — 커서가 사라진 것처럼 보인다.
      await tester.pumpWidget(
        _wrap(AppOtpInput(value: '123456', onChanged: (_) {})),
      );

      expect(_slotDecoration(tester, 5).border, isNotNull);
    });

    // 이 둘은 **짝으로 의도된 것**이다. 웹 `input-otp`는 `inputMode` 기본값이
    // `'numeric'`이라 숫자 키패드를 띄우면서도, `pattern`이 없으면 아무 문자나
    // 받는다. 한쪽만 보고 "일관성 있게" 숫자 필터를 넣으면 웹이 받는 입력을
    // 앱이 막게 된다.
    testWidgets('숫자 키보드를 띄운다 (웹 inputMode 기본값 numeric)', (tester) async {
      await tester.pumpWidget(_wrap(AppOtpInput(value: '', onChanged: (_) {})));

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).keyboardType,
        TextInputType.number,
      );
    });

    testWidgets('숫자가 아닌 문자를 걸러내지는 않는다 (웹 pattern 미지정)', (tester) async {
      final received = <String>[];
      await tester.pumpWidget(
        _wrap(AppOtpInput(value: '', onChanged: received.add)),
      );

      // 붙여넣기 경로로 들어올 수 있는 입력이다.
      await tester.enterText(find.byType(EditableText), 'ab12cd');
      await tester.pump();

      expect(received.last, 'ab12cd');
    });

    testWidgets('슬롯 치수·반경·배경은 웹과 같다', (tester) async {
      await tester.pumpWidget(_wrap(AppOtpInput(value: '', onChanged: (_) {})));

      // 웹 `input-otp.tsx`의 `h-[44px] w-[44px]` + `rounded-[6px]`,
      // `GymVerificationCode`가 얹는 `bg-gray-100`.
      expect(
        tester.getSize(find.byKey(AppOtpInput.slotKey(0))),
        const Size(AppOtpInput.slotSize, AppOtpInput.slotSize),
      );
      final decoration = _slotDecoration(tester, 0);
      expect(decoration.color, AppColors.light.gray100);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppOtpInput.slotRadius),
      );
    });

    testWidgets('슬롯 글자는 웹 HEADING_1 + text-black이다', (tester) async {
      await tester.pumpWidget(
        _wrap(AppOtpInput(value: '7', onChanged: (_) {})),
      );

      final char = tester.widget<Text>(_slotText(0, '7'));

      expect(char.style, AppTypography.heading1.copyWith(color: Colors.black));
    });
  });
}
