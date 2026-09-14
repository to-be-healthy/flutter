import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 저장된 세션을 복원하는 동안 보여주는 화면.
///
/// 웹 `app/page.tsx`의 `role === undefined` 분기 대응 —
/// `bg-primary-500` 전면에 `loading_splash.gif`(88x88)를 띄운다.
///
/// **웹 대비 의도적 차이:** GIF 자산은 아직 옮기지 않았다. 애니메이션 자산은
/// SVG처럼 원본을 그대로 쓸 수 없어(프레임·용량) 별도 판단이 필요하고,
/// 이 화면은 보통 한 프레임도 안 보이고 지나간다. 배경색만 웹과 맞춰 두면
/// 전환이 튀지 않는다.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.primary500,
      body: const Center(
        child: CircularProgressIndicator(
          // 예외(토큰화하지 않는 리터럴): primary500 배경 위의 전경색으로,
          // `AppColors`에 대응 토큰이 없는 프레임워크 상수다
          // (`AppButton`의 전경색과 같은 예외).
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}
