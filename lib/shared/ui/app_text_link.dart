import 'package:flutter/material.dart';

/// 웹 `Button variant='link'`(및 `<li onClick>`·`<Link>`)로 만든 텍스트 링크.
///
/// [AppButton]과 나눈 이유는 모양이 아니라 **크기 규칙이 다르기 때문이다.**
/// `AppButton`은 웹 `h-[44px]`를 그대로 옮긴 고정 높이 블록이고, 이쪽은
/// 글자 크기만큼만 차지하는 인라인 요소다. 하나로 합치려면 높이·배경·
/// 테두리를 전부 선택적으로 만들어야 하는데, 그건 62개 화면이 복사할
/// 컴포넌트를 className 주머니로 만드는 길이다.
///
/// 웹은 텍스트 링크마다 타이포·색이 제각각이라([style]로 받는다) 여기서
/// 기본값을 정하지 않는다 — 정하면 호출부가 전부 덮어쓰게 된다.
class AppTextLink extends StatelessWidget {
  const AppTextLink({
    required this.label,
    required this.onPressed,
    required this.style,
    this.underline = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 웹 호출부가 `cn(Typography.X, 'text-gray-Y')`로 지정하는 것에 대응한다.
  final TextStyle style;

  /// 웹 `underline underline-offset-4` 대응(고객센터 링크).
  final bool underline;

  /// 손가락이 닿는 최소 세로 크기.
  ///
  /// 웹에는 없는 개념이다 — 마우스 커서는 1px도 맞힐 수 있지만 손가락은
  /// 아니다. 글자(12~14px)만큼만 잡으면 누르기 어려운 링크가 된다.
  /// Material 권고 48은 이 화면들의 링크 간격(12px)보다 커서 겹치므로,
  /// 겹치지 않는 선에서 가장 큰 값을 쓴다.
  static const double minTapHeight = 32;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      link: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTapHeight),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: underline
                  ? style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: style.color,
                    )
                  : style,
            ),
          ),
        ),
      ),
    );
  }
}
