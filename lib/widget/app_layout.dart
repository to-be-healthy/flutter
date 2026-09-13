import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 웹 `src/widget/layout.tsx`의 `Layout.Header`/`Layout.Contents`/
/// `Layout.BottomArea` 슬롯 패턴 대응.
///
/// 웹은 body를 `position: fixed`로 고정하고 Contents만 `overflow-y-auto`로
/// 스크롤시켜 모바일 브라우저 바운스를 막았다(`global.css`). 네이티브에는 그
/// 문제가 없으므로 Scaffold 기본 구조(SafeArea + 스크롤 가능한 body)를 그대로
/// 쓴다.
///
/// Contents에는 기본 패딩을 두지 않는다 — 웹 `Layout.Contents`
/// (`h-full w-full flex-1 flex-shrink-0 overflow-y-auto`)도 좌우 패딩이
/// 없고, 화면마다 `className`으로 필요한 만큼만 얹는다(실측: `px-7`, `p-7`,
/// 전혀 없음 등 62개 화면에서 제각각). 그래서 이 셸도 패딩을 강제하지 않고
/// 화면(`contents`)이 스스로 감싸도록 둔다.
///
/// BottomArea 기본 패딩은 웹 `footer`의 `p-7`(사방 20px)을 그대로 옮긴다 —
/// 다수 화면이 별다른 override 없이 이 기본값을 그대로 쓴다(실측).
class AppLayout extends StatelessWidget {
  const AppLayout({
    required this.contents,
    this.header,
    this.bottomArea,
    super.key,
  });

  final Widget contents;
  final PreferredSizeWidget? header;
  final Widget? bottomArea;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    // Scaffold.bottomNavigationBar는 body와 달리 키보드(viewInsets.bottom)를
    // 피해 저절로 떠오르지 않는다 — _ScaffoldLayout이 그 자리를 항상 화면
    // 전체 높이 기준으로 고정하기 때문(직접 확인: 웹처럼 하단 영역에 제출
    // 버튼을 두는 화면에서 키보드가 열리면 그대로 가려진다). 그래서 키보드
    // 높이만큼 하단 패딩을 더해 수동으로 띄운다.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: header,
      body: SafeArea(child: SingleChildScrollView(child: contents)),
      bottomNavigationBar: bottomArea == null
          ? null
          : SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.all(spacing.s7) +
                    EdgeInsets.only(bottom: keyboardInset),
                child: bottomArea,
              ),
            ),
    );
  }
}

/// 웹 `Layout.Header` 대응.
///
/// 웹의 Header는 제목·뒤로가기가 없는 범용 슬롯이고, 실제 콘텐츠(뒤로가기
/// 버튼 + 제목)는 화면마다 직접 채워 넣는다. 62개 화면 대부분이 "뒤로가기 +
/// 가운데 제목"을 반복 구현하고 있어, Flutter에서는 그 반복 형태를 표준
/// 헤더로 승격했다.
class AppLayoutHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppLayoutHeader({required this.title, this.onBack, super.key});

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return AppBar(
      // 웹 Header 자체는 배경이 없고 부모(Layout 루트, 기본 gray-100 또는
      // 화면별 bg-white override)를 그대로 드러낸다. Flutter Scaffold의
      // 배경은 이미 AppTheme.light()에서 흰색으로 고정돼 있으므로, 헤더도
      // 그 값을 그대로 따라가 몸체와 이어져 보이게 한다 — 리터럴 색을 새로
      // 박지 않고 테마 값을 그대로 참조한다.
      backgroundColor: theme.scaffoldBackgroundColor,
      // Material3 기본 AppBar는 스크롤에 따라 표면에 elevation 틴트를
      // 얹는다. 디자인 토큰이 아니라 그 틴트를 끄기 위한 Flutter API 값.
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: colors.gray800),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(
        title,
        style: AppTypography.title1.copyWith(color: colors.gray800),
      ),
    );
  }
}
