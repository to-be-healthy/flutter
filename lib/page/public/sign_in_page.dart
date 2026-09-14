import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/server_message.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/sign_in_request.dart';
import '../../entity/auth/ui/auth_scope.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_text_input.dart';
import '../../shared/ui/app_text_link.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/SignInPage.tsx` + `feature/auth/ui/SignInForm.tsx` 대응.
///
/// Phase 1~8이 복사할 참조 화면이다. 지켜야 할 규율:
/// - 색·간격은 전부 `Theme.of(context).extension<...>()`을 경유한다. 타이포는
///   `AppTypography` 정적 상수(= `AppTheme.light()`가 쓰는 값 그 자체)를 쓴다.
///   토큰화하지 않는 리터럴은 **이유를 코드에 남긴다**(아래 `Colors.white`).
/// - 레이아웃 패딩은 셸(`AppLayout`)이 아니라 화면이 준다 — 웹
///   `Layout.Contents`도 좌우 패딩 없이 화면마다 `className`으로 얹는다.
///
/// **웹의 임의값(`[Npx]`)은 스케일로 반올림하지 않고 상수로 옮긴다.**
/// 웹 저자가 스페이싱 클래스를 두고 임의값 문법을 골랐다면 그 자체가 결정이고,
/// 가장 가까운 단계로 스냅하면 오차가 한 화면 안에서 누적된다 — 이 화면만 해도
/// 40→36, 55→48, 46→48로 13px이 밀린다. 이미 `AppButton.height`(44)·
/// `AppTextInput.height`(50)·`AppLayoutHeader.height`(56)가 같은 규칙이었다.
/// 반대로 웹이 스케일 클래스(`mb-8`·`gap-y-3`·`mt-11`)를 쓴 곳은 전부 토큰이다.
class SignInPage extends StatefulWidget {
  const SignInPage({
    required this.authApi,
    this.memberType = 'STUDENT',
    super.key,
  });

  final AuthApi authApi;

  /// 'STUDENT' | 'TRAINER'. 백엔드가 필수로 요구한다.
  /// 웹은 `/sign-in?type=student` 쿼리로 받는다.
  final String memberType;

  /// 웹 `<IconLogo width={64} height={64} />`.
  static const double logoSize = 64;

  /// 웹 로고 블록의 `mt-[40px]` / `mb-[55px]`.
  static const double logoTopGap = 40;
  static const double logoBottomGap = 55;

  /// 웹 `SignInForm`의 제출 버튼 블록 `mt-[46px]`.
  static const double submitBlockGap = 46;

  /// 웹 SignInPage와 동일한 분기.
  String get _title => memberType == 'TRAINER' ? '트레이너 로그인' : '회원 로그인';

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _userIdError;
  String? _passwordError;
  String? _submitError;
  bool _isSubmitting = false;

  /// 웹 `?type=` 쿼리에 되돌려 넣을 소문자 값.
  String get _lowerMemberType => widget.memberType.toLowerCase();

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 웹 react-hook-form의 `register(..., {required: {message}})` 대응.
  /// 문구도 웹과 글자까지 같다.
  bool _validate() {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _userIdError = userId.isEmpty ? '아이디를 입력해주세요.' : null;
      _passwordError = password.isEmpty ? '비밀번호를 입력해주세요.' : null;
    });

    return _userIdError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    String? error;
    try {
      final response = await widget.authApi.signIn(
        SignInRequest(
          userId: _userIdController.text.trim(),
          password: _passwordController.text,
          memberType: widget.memberType,
        ),
      );
      if (!mounted) {
        return;
      }
      // 화면 이동을 여기서 하지 않는다. `AuthState`가 바뀌면
      // `refreshListenable`이 물린 라우터가 리다이렉트를 다시 계산해
      // `/${memberType}`로 보낸다 — 웹 `router.replace(...)` 자리다.
      //
      // **`memberType`은 서버 응답 값을 따른다.** 웹도
      // `data.memberType?.toLowerCase()`로 응답을 쓴다. 요청은 STUDENT로
      // 보냈는데 계정이 TRAINER면 서버 쪽이 옳다.
      await AuthScope.read(context).signIn(response);
    } catch (e) {
      error = serverMessage(e) ?? '문제가 발생했습니다.';
    }

    // `await` 뒤에는 화면이 이미 dispose됐을 수 있다(로그인이 성공하면
    // 라우터가 홈으로 옮기면서 이 화면을 버린다). 성공·실패 어느 쪽이든
    // 상태 갱신을 이 한 곳으로 모은다.
    //
    // **성공 경로에서도 `_isSubmitting`을 되돌린다.** 이동이 일어나면 어차피
    // 보이지 않지만, 이동하지 않는 경우(리다이렉트 규칙이 바뀌거나 실패)에
    // 버튼이 로딩 상태로 영구히 굳는다.
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

    // 웹 SignInPage는 `<Layout className='bg-white'>`로 셸 기본 배경(gray-100)을
    // 흰색으로 덮고, Contents 안쪽에 `px-7`을 직접 준다.
    return AppLayout(
      // 예외(토큰화하지 않는 리터럴): `Colors.white`는 `AppColors`에 대응
      // 토큰이 없는 프레임워크 상수다(`AppButton`의 전경색과 같은 예외).
      backgroundColor: Colors.white,
      header: AppLayoutHeader(
        title: widget._title,
        // 웹은 `router.push('/')`다. 앱에서는 `go`를 쓴다 — `push`면 로그인
        // 화면 위에 온보딩이 쌓여 거기서 뒤로가면 다시 로그인으로 돌아온다.
        // 도착지는 웹과 같다.
        onBack: () => context.go(AppRoutes.onboarding),
      ),
      contents: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.s7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: SignInPage.logoTopGap),
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: SignInPage.logoSize,
              height: SignInPage.logoSize,
            ),
            const SizedBox(height: SignInPage.logoBottomGap),
            AppTextInput(
              label: '아이디',
              // 웹 `SignInForm.tsx:57`의 placeholder. 필수 입력 에러 문구와
              // 글자가 같은 것도 웹 그대로다.
              hint: '아이디를 입력해주세요.',
              controller: _userIdController,
              errorText: _userIdError,
            ),
            // 웹 SignInForm 첫 필드 그룹의 `mb-8`(= 24px, 웹 비선형 스케일).
            SizedBox(height: spacing.s8),
            AppTextInput(
              label: '비밀번호',
              // 웹 `SignInForm.tsx:83`.
              hint: '비밀번호를 입력해주세요.',
              controller: _passwordController,
              errorText: _passwordError,
              obscureText: true,
            ),
            if (_submitError != null) ...[
              SizedBox(height: spacing.s6),
              Text(
                _submitError!,
                style: AppTypography.body3.copyWith(color: colors.point),
              ),
            ],
            const SizedBox(height: SignInPage.submitBlockGap),
            AppButton(
              label: '로그인',
              onPressed: _submit,
              isLoading: _isSubmitting,
            ),
            // 웹 제출 블록의 `gap-y-2.5`. 이 키는 `tailwind.config.js`의
            // 커스텀 스케일(1~12)에 없고 그 설정이 `theme.extend` 안이라
            // **Tailwind 기본값 0.625rem = 10px**이 그대로 산다. 우리 스케일의
            // s4가 마침 같은 10px이라 토큰으로 표현된다.
            SizedBox(height: spacing.s4),
            AppButton(
              label: '회원가입',
              variant: AppButtonVariant.outline,
              onPressed: () => context.push(
                Uri(
                  path: AppRoutes.signUp,
                  queryParameters: {
                    AppRoutes.memberTypeQuery: _lowerMemberType,
                  },
                ).toString(),
              ),
            ),
            // 웹 `<ul className='mt-11 ...'>`.
            SizedBox(height: spacing.s11),
            const _FindLinks(),
            SizedBox(height: spacing.s12),
          ],
        ),
      ),
    );
  }
}

/// 웹 SignInPage 하단의 `<ul className='mt-11 flex items-center gap-x-5'>`.
class _FindLinks extends StatelessWidget {
  const _FindLinks();

  /// 웹 Separator의 `className='h-5'` — 커스텀 스케일에서 5 = 12px이다
  /// (Tailwind 기본 20px이 아니다).
  static const double separatorHeight = 12;

  /// 웹 Separator는 `w-[1px]`. 간격 토큰이 아니라 선 두께다.
  static const double separatorWidth = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final style = AppTypography.body3.copyWith(color: colors.gray500);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppTextLink(
          label: '비밀번호 찾기',
          style: style,
          onPressed: () => context.push(AppRoutes.findPassword),
        ),
        // 웹 `gap-x-5`(= 12px)가 항목 사이마다 들어간다.
        SizedBox(width: spacing.s5),
        // 웹 `<Separator orientation='vertical' className='h-5' />` —
        // `bg-gray-300`, 너비 1px.
        Container(
          width: separatorWidth,
          height: separatorHeight,
          color: colors.gray300,
        ),
        SizedBox(width: spacing.s5),
        AppTextLink(
          label: '아이디 찾기',
          style: style,
          onPressed: () => context.push(AppRoutes.findId),
        ),
      ],
    );
  }
}
