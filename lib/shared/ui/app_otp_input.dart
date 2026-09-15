import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// 웹 `src/shared/ui/input-otp.tsx`(`input-otp` 패키지 래핑) 대응.
///
/// **입력은 하나, 슬롯은 여섯이다.** 웹 `OTPInput`도 실제 `<input>` 하나를
/// 투명하게 깔고 그 위에 슬롯을 그린다. Flutter에서 `TextField` 6개로
/// 만들면 붙여넣기(6자가 한 칸에 들어간다)와 슬롯 경계 backspace(빈 칸에서
/// 지우면 앞 칸으로 넘어가야 한다)가 웹과 달라진다 — 그 동작을 손으로
/// 재구현하는 대신 입력 하나에 맡긴다.
///
/// 값은 부모가 들고 있다(웹도 `value`/`onChange`를 받는 controlled
/// 컴포넌트다). 웹 `clickNext`가 `setAuthValue('')`로 값을 비우므로, 부모가
/// 넘긴 값이 내부 컨트롤러와 다르면 부모 쪽을 따른다.
class AppOtpInput extends StatefulWidget {
  const AppOtpInput({
    required this.value,
    required this.onChanged,
    this.length = defaultLength,
    super.key,
  });

  /// 웹 `GymVerificationCode`의 `maxLength={6}`.
  static const int defaultLength = 6;

  /// 웹 `input-otp.tsx`의 `h-[44px] w-[44px]`.
  ///
  /// 예외(토큰화하지 않는 리터럴): 44는 Tailwind 커스텀 스페이싱 스케일
  /// (4/6/8/10/12/16/20/24/28/32/36/48)에 없다 — 웹도 그래서 임의값 문법을
  /// 썼다. 슬롯 고유 치수다.
  static const double slotSize = 44;

  /// 웹 `rounded-[6px]`. `AppRadius`는 4/8/12이라 6은 토큰이 아니다.
  static const double slotRadius = 6;

  /// 웹 `InputOTPGroup`의 `w-[320px]`.
  static const double groupWidth = 320;

  /// 웹 활성 슬롯의 `ring-2`.
  static const double activeRingWidth = 2;

  final String value;
  final ValueChanged<String> onChanged;
  final int length;

  /// 슬롯을 지목하는 키. 테스트가 슬롯별 장식을 확인할 때 쓴다.
  static Key slotKey(int index) => ValueKey<String>('AppOtpInput.slot.$index');

  @override
  State<AppOtpInput> createState() => _AppOtpInputState();
}

class _AppOtpInputState extends State<AppOtpInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  // 웹 `GymVerificationCode`의 `useEffect(() => ref.current.focus(), [])`.
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(AppOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모가 값을 갈아끼웠을 때만 따라간다. 매번 덮어쓰면 입력 중에 커서가
    // 앞으로 튄다.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppOtpInput.groupWidth,
      height: AppOtpInput.slotSize,
      child: Stack(
        children: [
          Positioned.fill(child: _slots(context)),
          // 투명한 실제 입력을 슬롯 위에 깐다. 웹 `OTPInput`도 같은 구조다
          // (`className='input-otp-override'`로 입력을 보이지 않게 만든다).
          // 위에 두는 이유는 탭·드래그를 이쪽이 받아야 키보드가 뜨기 때문이다.
          Positioned.fill(
            child: EditableText(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: 1,
              // 글자·커서·선택 모두 투명 — 보이는 것은 아래 슬롯뿐이다.
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              cursorColor: Colors.transparent,
              backgroundCursorColor: Colors.transparent,
              selectionColor: Colors.transparent,
              // 웹 `input-otp`의 `inputMode` **기본값이 `'numeric'`**이다
              // (패키지 문서 확인). 웹 `GymVerificationCode`는 이 prop을
              // 넘기지 않으므로 모바일 웹에서도 숫자 키패드가 뜬다 —
              // 이쪽이 임의 선택이 아니라 패리티다.
              keyboardType: TextInputType.number,
              // **문자 자체는 거르지 않는다.** 웹은 `pattern`을 주지 않았고,
              // 그러면 `input-otp`는 아무 문자나 받는다(키 입력·붙여넣기 모두).
              // 여기에 숫자 필터를 넣으면 웹이 받는 입력을 앱이 막는다.
              //
              // 백엔드 가입 코드는 실제로 숫자 6자리다
              // (`Utils.getAuthCode(6)` → `RandomStringUtils.randomNumeric`,
              // `Gym.joinCode`가 `@Column(length = 6)`). 다만 서버는 입력의
              // 길이·문자 종류를 **전혀 검증하지 않고** 저장값과 문자열
              // 동등 비교만 하므로, 형식 제약을 서버에 기대면 안 된다.
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(widget.length),
              ],
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slots(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final value = widget.value;
    // 전부 채우면 인덱스가 length가 되어 어느 슬롯도 활성이 아니게 된다.
    // 웹은 마지막 슬롯에 커서가 남으므로 마지막으로 클램프한다.
    final activeIndex = value.length >= widget.length
        ? widget.length - 1
        : value.length;

    return Row(
      // 웹 `InputOTPGroup`의 `justify-between`.
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(widget.length, (index) {
        final isActive = index == activeIndex;
        return Container(
          key: AppOtpInput.slotKey(index),
          width: AppOtpInput.slotSize,
          height: AppOtpInput.slotSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // 웹 `GymVerificationCode`가 슬롯에 얹는 `bg-gray-100`.
            color: colors.gray100,
            borderRadius: BorderRadius.circular(AppOtpInput.slotRadius),
            // 웹 활성 슬롯의 `ring-2 ring-primary-500`. ring은 바깥으로
            // 그려지지만 Flutter의 border는 안쪽이라 슬롯 크기가 유지된다 —
            // 치수 단언(44x44)을 지키는 쪽을 택했다.
            border: isActive
                ? Border.all(
                    color: colors.primary500,
                    width: AppOtpInput.activeRingWidth,
                  )
                : null,
          ),
          child: index < value.length
              ? Text(
                  value[index],
                  // 웹 `cn(Typography.HEADING_1, '... text-black')`.
                  //
                  // 예외(토큰화하지 않는 리터럴): `Colors.black`은 `AppColors`에
                  // 대응 토큰이 없는 프레임워크 상수다(`AppToast`의
                  // `Colors.white`와 같은 예외).
                  style: AppTypography.heading1.copyWith(color: Colors.black),
                )
              : null,
        );
      }),
    );
  }
}
