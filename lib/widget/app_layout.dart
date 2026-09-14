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
///
/// 배경은 웹 `Layout` 루트의 `bg-gray-100`을 기본값으로 쓴다 — 웹은 셸이
/// gray-100을 깔고 화면마다 필요하면 `bg-white`로 덮는 구조다(실측: 127개
/// Header 사용처 중 화면 전체를 흰 배경으로 덮는 곳이 다수, 나머지는 셸
/// 기본값 그대로). `backgroundColor`를 넘기면 그 색으로 덮는다.
class AppLayout extends StatelessWidget {
  const AppLayout({
    required this.contents,
    this.header,
    this.bottomArea,
    this.backgroundColor,
    super.key,
  });

  final Widget contents;
  final PreferredSizeWidget? header;
  final Widget? bottomArea;

  /// 웹 `Layout` 루트 배경 대응. 기본값은 `AppColors.gray100`(웹
  /// `bg-gray-100`) — 화면이 흰 배경을 쓰려면 `Colors.white`를 넘긴다.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final colors = theme.extension<AppColors>()!;

    // Scaffold.bottomNavigationBar는 body와 달리 키보드(viewInsets.bottom)를
    // 피해 저절로 떠오르지 않는다 — _ScaffoldLayout이 그 자리를 항상 화면
    // 전체 높이 기준으로 고정하기 때문(직접 확인: 웹처럼 하단 영역에 제출
    // 버튼을 두는 화면에서 키보드가 열리면 그대로 가려진다). 그래서 키보드
    // 높이만큼 하단 패딩을 더해 수동으로 띄운다.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.gray100,
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

  /// 웹 `Layout.Header`의 `h-[56px]`(Tailwind 임의값 문법) 대응.
  ///
  /// 예외(토큰화하지 않는 리터럴): 56은 `AppSpacing.standard`의 12단
  /// (4/6/8/10/12/16/20/24/28/32/36/48) 어디에도 없다 — 웹도 같은 이유로
  /// 스페이싱 스케일 클래스 대신 임의값 문법(`h-[56px]`)을 썼다. 헤더
  /// 높이는 간격 토큰이 아니라 이 컴포넌트 고유의 고정 치수라 그대로 둔다.
  static const double height = 56;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return AppBar(
      // 웹 Header 자체는 고유 배경이 없고 부모(AppLayout, 기본 gray100 또는
      // 화면별 backgroundColor override)를 그대로 드러낸다. AppBar는
      // Scaffold와 별개로 자기 자신을 불투명하게 칠하는 Material이라
      // transparent로 두어야 AppLayout이 고른 배경(기본값이든 override든)이
      // 그대로 비쳐 보인다 — 특정 색을 골라 참조하면 AppLayout의
      // backgroundColor가 바뀔 때마다 다시 맞춰줘야 한다.
      //
      // Scaffold는 자기 배경(widget.backgroundColor)을 AppBar 뒤를 포함한
      // 전체 캔버스에 먼저 칠하는 Material이다(Flutter SDK
      // scaffold.dart의 `color: widget.backgroundColor ?? ...` 참고). 이
      // AppBar가 transparent인 한, 헤더 영역에는 그 Scaffold 배경이
      // 그대로 비친다 — 회귀 테스트(app_layout_test.dart)가 이 둘을 함께
      // 확인한다.
      backgroundColor: Colors.transparent,
      // Material3 기본 AppBar는 스크롤에 따라 표면에 elevation 틴트를
      // 얹는다. 디자인 토큰이 아니라 그 틴트를 끄기 위한 Flutter API 값.
      surfaceTintColor: Colors.transparent,
      // 그림자 깊이(0=없음) 자체는 AppSpacing 같은 간격 토큰이 아니라
      // Material 위젯의 elevation API 값이다 — 웹 Header에는 그림자가
      // 없어 0으로 껐다(AppButton의 strokeWidth: 2와 같은 종류의 예외).
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
        // 웹 `SignInPage.tsx:27` `Typography.HEADING_4_SEMIBOLD`
        // (18px/130% semibold). `title1`(16px bold)이 아니다.
        style: AppTypography.heading4SemiBold.copyWith(color: colors.gray800),
      ),
    );
  }
}
