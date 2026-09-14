import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/server_message.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/sign_in_request.dart';
import '../../entity/auth/ui/auth_scope.dart';
import '../../shared/ui/app_text_link.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/OnboardingPage.tsx` 대응.
///
/// **한 URL에 두 화면이다.** 웹은 `/`에서 `useSearchParams()`의 `type` 유무로
/// 갈린다 — 없으면 역할 선택, 있으면 로그인 수단 선택. 별도 라우트가 아니라
/// 쿼리만 바뀌므로 여기서도 한 위젯이 [memberType]으로 분기한다.
///
/// **웹 대비 의도적 생략**(별도 작업이 필요해 이번 범위 밖):
/// - `SocialSignIn`(카카오·애플·네이버·구글) — 각 OAuth SDK 연동이 필요하다
/// - `RollingBanner`(일정관리·회원관리·루틴생성 3장 캐러셀) — PNG 자산 + 애니메이션
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.authApi, this.memberType, super.key});

  final AuthApi authApi;

  /// 웹 `?type=` 쿼리. `'student'` | `'trainer'` | null(역할 선택 화면).
  final String? memberType;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  /// 웹 `ComplimentaryButton.tsx:8-12`에 상수로 박혀 있는 체험 계정.
  ///
  /// 값을 코드에 두는 것이 웹과 같은 선택이다 — 이 버튼의 동작 자체가
  /// "정해진 데모 계정으로 로그인한다"라서, 값을 빼면 기능이 사라진다.
  /// (문서에 옮겨 적는 것과는 다른 문제다. 문서에서는 가리키기만 하면 된다.)
  static const String _demoPassword = '12345678a';
  static const String _demoStudentId = 'healthy-student0';
  static const String _demoTrainerId = 'healthy-trainer0';

  bool _isSubmitting = false;
  String? _submitError;

  bool get _isRoleSelection => widget.memberType == null;

  /// 웹 `memberType.toUpperCase()`.
  String get _upperMemberType => widget.memberType!.toUpperCase();

  /// 웹 `ComplimentaryButton`의 `onClick`.
  Future<void> _signInAsDemo() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final isTrainer = widget.memberType == 'trainer';
    String? error;
    try {
      final response = await widget.authApi.signIn(
        SignInRequest(
          userId: isTrainer ? _demoTrainerId : _demoStudentId,
          password: _demoPassword,
          memberType: _upperMemberType,
          complimentaryLogin: true,
        ),
      );
      if (!mounted) {
        return;
      }
      // 라우팅은 하지 않는다. `AuthState`가 바뀌면 `refreshListenable`이
      // 물린 라우터가 리다이렉트를 다시 계산해 홈으로 보낸다 — 웹의
      // `router.replace(`/${data.memberType}`)`에 해당하는 자리다.
      await AuthScope.read(context).signIn(response);
    } catch (e) {
      error = serverMessage(e) ?? '문제가 발생했습니다.';
    }

    // 성공해도 `_isSubmitting`을 되돌린다 — 이동하지 않는 경우에 링크가
    // 영구히 비활성으로 굳는 것을 막는다.
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _submitError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return AppLayout(
      backgroundColor: Colors.white,
      header: _isRoleSelection
          // 웹 `<Layout.Header />` — 자식이 없어 56px 자리만 잡는다.
          ? const AppLayoutHeader()
          // 웹 `SelectLoginMethodPage`의 헤더는 뒤로가기 하나뿐이다
          // (`router.back()`).
          : AppLayoutHeader(onBack: () => _goBack(context)),
      contents: _isRoleSelection
          ? _roleSelection(colors, spacing)
          : _loginMethodSelection(colors, spacing),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  /// 웹 `OnboardingPage`의 기본 분기(쿼리 없음).
  Widget _roleSelection(AppColors colors, AppSpacing spacing) {
    return Padding(
      // 웹 `px-7`.
      padding: EdgeInsets.symmetric(horizontal: spacing.s7),
      child: Column(
        // 웹 `h-full ... justify-around`.
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              SvgPicture.asset(
                'assets/images/logo.svg',
                width: _logoSize,
                height: _logoSize,
              ),
              // 웹 `gap-y-9`.
              SizedBox(height: spacing.s9),
              Text(
                '안녕하세요!\n건강해짐입니다!',
                textAlign: TextAlign.center,
                // 웹 `<h1>`에는 텍스트 색 클래스가 없어 shadcn 기본
                // foreground(`#020817`)로 렌더된다 — 디자인이 고른 색이
                // 아니라 지정하지 않아서 나온 값이라, 이 팔레트의 가장
                // 어두운 본문색을 쓴다(`AppLayoutHeader`와 같은 판단).
                style: AppTypography.heading1.copyWith(color: colors.gray800),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RoleTile(
                label: '트레이너로 시작',
                onPressed: () => _selectRole('trainer'),
              ),
              // 웹 `gap-y-5`.
              SizedBox(height: spacing.s5),
              _RoleTile(
                label: '회원으로 시작',
                onPressed: () => _selectRole('student'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 웹 `<Link href='?type=trainer'>` — 경로는 그대로 두고 쿼리만 바꾼다.
  ///
  /// `go`가 아니라 `push`인 이유: 웹은 Next.js 히스토리에 쌓여 다음 화면의
  /// `router.back()`이 동작한다. `go`는 스택을 교체해서 뒤로가기가 사라진다.
  void _selectRole(String type) => context.push(
    Uri(
      path: AppRoutes.onboarding,
      queryParameters: {AppRoutes.memberTypeQuery: type},
    ).toString(),
  );

  /// 웹 `SelectLoginMethodPage`(쿼리 있음).
  Widget _loginMethodSelection(AppColors colors, AppSpacing spacing) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.s7),
      child: Column(
        children: [
          // 웹 `mt-12`.
          SizedBox(height: spacing.s12),
          Text(
            '차별화된 PT 서비스를\n경험해보세요!',
            textAlign: TextAlign.center,
            style: AppTypography.heading1.copyWith(color: colors.gray800),
          ),
          // 웹은 여기에 `RollingBanner`(3장 캐러셀)가 있다 — 자산·애니메이션이
          // 필요해 생략했다. 그만큼 이 화면은 웹보다 비어 있다.
          //
          // 웹 두 번째 블록의 `py-12`.
          SizedBox(height: spacing.s12),
          // 웹은 여기에 `SocialSignIn`(카카오·애플·네이버·구글)이 있다.
          AppTextLink(
            label: '아이디 로그인',
            style: AppTypography.title3.copyWith(color: colors.gray500),
            onPressed: () => context.push(
              Uri(
                path: AppRoutes.signIn,
                queryParameters: {AppRoutes.memberTypeQuery: widget.memberType},
              ).toString(),
            ),
          ),
          // 웹 `mt-5`.
          SizedBox(height: spacing.s5),
          AppTextLink(
            label: '체험하기',
            style: AppTypography.title3.copyWith(color: colors.gray500),
            onPressed: _isSubmitting ? null : _signInAsDemo,
          ),
          if (_submitError != null) ...[
            SizedBox(height: spacing.s6),
            Text(
              _submitError!,
              textAlign: TextAlign.center,
              style: AppTypography.body3.copyWith(color: colors.point),
            ),
          ],
          // 웹 `mt-10`.
          SizedBox(height: spacing.s10),
          AppTextLink(
            label: '건강해짐 고객센터',
            underline: true,
            style: AppTypography.body4.copyWith(color: colors.gray400),
            onPressed: () => context.push(AppRoutes.customerService),
          ),
          SizedBox(height: spacing.s12),
        ],
      ),
    );
  }

  /// 웹 `<IconLogo width={64} height={64} />`.
  static const double _logoSize = 64;
}

/// 역할 선택 타일. 웹은 `Button`에 `h-[80px] bg-gray-100 text-black`을
/// 얹어 만들지만, Flutter에서 같은 방식을 쓰려면 [AppButton]에 높이·배경·
/// 전경·타이포 오버라이드를 전부 열어야 한다. 한 화면에서만 쓰는 모양이라
/// 여기 두고, 값은 토큰을 경유한다.
class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.label, required this.onPressed});

  /// 웹 `h-[80px]`.
  static const double height = 80;

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.gray100,
            // 웹 `Button` base의 `rounded-lg`.
            borderRadius: BorderRadius.circular(radius.l),
          ),
          child: Text(
            label,
            // 웹 `cn(Typography.HEADING_4, 'h-[80px] bg-gray-100 text-black')`.
            // `text-black`은 gray800이 아니라 순수 검정이다.
            style: AppTypography.heading4.copyWith(
              // 예외(토큰화하지 않는 리터럴): 웹이 `text-black`을 명시했고
              // `AppColors`에 대응 토큰이 없다.
              color: Colors.black,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
    );
  }
}
