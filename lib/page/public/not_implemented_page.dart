import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widget/app_layout.dart';

/// 아직 옮기지 않은 웹 화면의 자리.
///
/// **왜 화면을 만들어 두나:** go_router는 등록되지 않은 경로로 이동하면
/// 에러 화면을 띄운다. 로그인 화면의 "회원가입"·"아이디 찾기" 링크를 웹처럼
/// 되살리려면 목적지가 있어야 하는데, 그 화면들을 지금 다 옮기는 것은 이번
/// 범위가 아니다.
///
/// **왜 빈 화면이 아니라 이 화면인가:** 링크가 동작하되 **덜 된 티가 나야**
/// 한다. 빈 화면을 두면 "옮겼는데 비어 있는 화면"과 "아직 안 옮긴 화면"이
/// 구별되지 않는다. 대응하는 웹 경로를 함께 보여주는 이유도 같다 — 다음에
/// 이 화면을 여는 사람이 무엇을 옮겨야 하는지 바로 안다.
class NotImplementedPage extends StatelessWidget {
  const NotImplementedPage({
    required this.title,
    required this.webRoute,
    super.key,
  });

  /// 헤더 제목. 웹 화면의 이름을 그대로 쓴다.
  final String title;

  /// 대응하는 웹 URL. 이 화면을 실제 구현으로 바꿀 때 볼 곳이다.
  final String webRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: title),
      contents: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.s7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: spacing.s12),
            Text(
              '아직 옮기지 않은 화면입니다.',
              textAlign: TextAlign.center,
              style: AppTypography.title3.copyWith(color: colors.gray800),
            ),
            SizedBox(height: spacing.s6),
            Text(
              '웹 $webRoute 에 해당합니다.',
              textAlign: TextAlign.center,
              style: AppTypography.body3.copyWith(color: colors.gray500),
            ),
          ],
        ),
      ),
    );
  }
}
