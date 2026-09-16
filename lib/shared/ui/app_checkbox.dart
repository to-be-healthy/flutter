import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// 웹의 커스텀 체크박스 — `<input type='checkbox' class='peer hidden'>` +
/// 그 옆 `<span>`이 실제로 보이는 사각형이다.
///
/// ```
/// <span className='flex h-7 w-7 items-center justify-center rounded-sm
///                  border border-solid border-gray-300
///                  peer-checked:border-none peer-checked:bg-primary-500'>
///   {checked && <IconNoCircleCheck width={15} height={12} fill='white' />}
/// </span>
/// ```
///
/// **라벨은 포함하지 않는다.** 화면마다 문구·간격·글꼴이 다르다
/// (회원 탈퇴는 자기 레이아웃, 환불 회원 삭제 시트는 `ml-3` + `BODY_2`).
/// 공유하는 것은 사각형뿐이다.
///
/// ## 왜 이제 공용인가
///
/// 회원 탈퇴 화면(`/student/mypage/leave`)이 첫 사용처였고 그때는 화면 안
/// private 위젯이었다. `/trainer/manage/[memberId]`의 환불 삭제 시트가 두
/// 번째 사용처이고 **치수·색·아이콘 크기가 전부 같아서**(20 / 15×12 /
/// `rounded-sm` / gray-300 / primary-500) 올렸다 — 이 프로젝트의
/// "두 번째 사용처에서 승격" 규칙이다.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({required this.checked, super.key});

  /// 웹 `h-7 w-7`(커스텀 스케일 7 = 20) — 한 변.
  static const double size = 20;

  /// 웹 `<IconNoCircleCheck width={15} height={12} />`. 정사각형이 아니다.
  static const double checkWidth = 15;
  static const double checkHeight = 12;

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 웹 `peer-checked:bg-primary-500`.
        color: checked ? colors.primary500 : null,
        // 웹 `peer-checked:border-none` — 켜지면 테두리가 사라진다.
        border: checked ? null : Border.all(color: colors.gray300),
        borderRadius: BorderRadius.circular(radius.s),
      ),
      // **체크 표시는 꺼져 있을 때도 그려진다.** 웹이 `fill='white'`를 늘
      // 주므로 흰 배경 위에서 안 보일 뿐이다 — 조건부 렌더가 아니다.
      // 그대로 옮긴다(체크 위치가 켤 때 흔들리지 않는 부수 효과가 있다).
      child: SvgPicture.asset(
        'assets/images/no_circle_check.svg',
        width: checkWidth,
        height: checkHeight,
        // 자산의 `fill="current"`를 `currentColor`로 정규화해 두었다
        // (규율 #13). 웹이 넘기는 prop 값이 흰색이다.
        theme: const SvgTheme(currentColor: Colors.white),
      ),
    );
  }
}
