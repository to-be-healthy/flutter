import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      // 본문은 **최소 뷰포트 높이**를 가진다. 웹 `Layout.Contents`가
      // `h-full flex-1 overflow-y-auto`라, 화면들이 그 안에서 `h-full` +
      // `justify-around`/`justify-between`으로 세로 배치를 잡는다. 그냥
      // `SingleChildScrollView`로 감싸면 높이가 무한이 되어 그 배치가 전부
      // 무너진다(자식 높이만큼만 차지하고 위로 몰린다).
      //
      // `ConstrainedBox(minHeight:)`만으로 충분하고 `IntrinsicHeight`는
      // 필요 없다 — `RenderFlex`가 자기 크기를 `constraints.constrain(...)`
      // 으로 확정하므로 자식이 더 짧아도 minHeight까지 늘어나고, 남은 공간을
      // `mainAxisAlignment`가 분배한다.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: contents,
            ),
          ),
        ),
      ),
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
  const AppLayoutHeader({this.title, this.onBack, this.onClose, super.key});

  /// 없으면 제목 없는 헤더가 된다. 웹 온보딩의 `<Layout.Header />`(자식 없음)
  /// 처럼 **56px 자리만 잡는** 용도와, 뒤로가기만 있는 헤더에 쓴다.
  final String? title;

  /// 누르면 할 일. 웹은 화면마다 다르다 — 로그인 화면은 `router.push('/')`,
  /// 로그인 수단 선택 화면은 `router.back()`이다. 그래서 기본 동작(pop)에
  /// 맡기지 않고 화면이 넘긴다.
  final VoidCallback? onBack;

  /// 오른쪽 닫기(X). 웹 `FindIdPage`/`FindPasswordPage`의
  /// `<Layout.Header className='... justify-end'>` + `IconClose` 대응.
  ///
  /// **닫기가 있으면 뒤로가기를 자동으로 띄우지 않는다.** 웹의 그 화면들은
  /// 헤더에 X 하나만 두고, 둘 다 보이면 같은 일을 하는 버튼이 둘이 된다.
  /// (`onBack`을 명시로 함께 넘기면 둘 다 나온다 — 그런 화면이 생기면
  /// 그때 웹 렌더를 보고 맞춘다.)
  final VoidCallback? onClose;

  /// 웹 `Layout.Header`의 `h-[56px]`(Tailwind 임의값 문법) 대응.
  ///
  /// 예외(토큰화하지 않는 리터럴): 56은 `AppSpacing.standard`의 12단
  /// (4/6/8/10/12/16/20/24/28/32/36/48) 어디에도 없다 — 웹도 같은 이유로
  /// 스페이싱 스케일 클래스 대신 임의값 문법(`h-[56px]`)을 썼다. 헤더
  /// 높이는 간격 토큰이 아니라 이 컴포넌트 고유의 고정 치수라 그대로 둔다.
  static const double height = 56;

  /// 웹 `back.svg`의 고유 크기(`width="20" height="20"`).
  static const double backIconSize = 20;

  /// 웹 `<IconClose width={14} height={14} />`. `close.svg`의 고유 크기와도 같다.
  static const double closeIconSize = 14;

  /// 닫기 버튼에 붙는 키.
  ///
  /// 라우터를 끼운 테스트에서는 **직전 화면이 트리에 그대로 남아 있어**
  /// `find.byType(IconButton)`이 아래 화면의 뒤로가기까지 함께 잡는다.
  /// 위 화면의 X만 지목하려면 식별자가 필요하다
  /// (`AppButton.backgroundKeyFor`와 같은 이유).
  static const Key closeButtonKey = ValueKey('AppLayoutHeader.close');

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return AppBar(
      // `preferredSize`만으로는 Scaffold가 잡아주는 **박스**만 커지고 툴바
      // 내용은 Material 기본값 `kToolbarHeight`(56) 기준으로 놓인다. 지금은
      // 우연히 둘 다 56이라 일치하지만, `height`를 바꾸는 순간 선언과 렌더가
      // 조용히 어긋난다(제목이 가운데를 벗어난다). 둘을 같은 상수로 묶는다.
      toolbarHeight: height,
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
      // Material 기본 뒤로가기를 끼워 넣지 못하게 막는다. 아래 `leading`
      // 규칙이 유일한 판단 근거여야 한다 — 기본값(true)으로 두면 `leading`이
      // null인 모든 경우에 AppBar가 제 판단으로 뒤로가기를 넣어, 웹에 없는
      // 버튼이 조용히 생긴다(닫기만 있는 화면이 정확히 그 경우다).
      automaticallyImplyLeading: false,
      // `onBack`이 있으면 스택과 무관하게 보인다. 웹 로그인 화면의 뒤로가기는
      // `router.push('/')`라 히스토리가 없어도 늘 떠 있다 — `canPop()`만 보면
      // 첫 화면으로 진입했을 때 사라진다.
      leading:
          (onBack != null ||
              (onClose == null && Navigator.of(context).canPop()))
          ? IconButton(
              // 웹 `IconBack`(`back.svg`) 자산을 그대로 쓴다. Material
              // `Icons.arrow_back_ios_new`는 자형이 다르다. 색을 덮지 않는
              // 이유는 자산이 `stroke="black"`으로 고정돼 있고 웹 렌더도
              // 순수 검정(픽셀 실측 `(0,0,0)`)이기 때문이다.
              icon: SvgPicture.asset(
                'assets/images/back.svg',
                width: backIconSize,
                height: backIconSize,
              ),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      actions: onClose == null
          ? null
          : [
              IconButton(
                key: closeButtonKey,
                // 웹 `close.svg`. 색을 덮지 않는 이유는 뒤로가기와 같다 —
                // 자산이 `stroke="black"`으로 고정돼 있다.
                icon: SvgPicture.asset(
                  'assets/images/close.svg',
                  width: closeIconSize,
                  height: closeIconSize,
                ),
                onPressed: onClose,
              ),
            ],
      title: title == null
          ? null
          : Text(
              title!,
              // 웹 `SignInPage.tsx:27` `Typography.HEADING_4_SEMIBOLD`
              // (18px/130% semibold). `title1`(16px bold)이 아니다.
              //
              // 색은 `gray800`이다. 웹 `<h2>`에는 텍스트 색 클래스가 없어
              // shadcn 기본 foreground(`#020817`)로 렌더되는데(픽셀 실측),
              // 그건 디자인이 고른 색이 아니라 **지정하지 않아서 나온 값**이다.
              // 이 팔레트의 가장 어두운 본문색인 gray800(`#2E3134`)을 쓴다 —
              // 디자인 검수에서 뒤집히면 그때 토큰을 추가한다.
              style: AppTypography.heading4SemiBold.copyWith(
                color: colors.gray800,
              ),
            ),
    );
  }
}
