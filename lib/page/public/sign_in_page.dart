import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/sign_in_request.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_text_input.dart';
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
/// **웹 대비 의도적 생략**(Phase 1~2에서 추가):
/// - 로고 아이콘(`IconLogo` 64x64) — SVG 자산 이식은 Phase 2
/// - 회원가입 버튼(outline) · "비밀번호 찾기 / 아이디 찾기" 링크 — 라우터 부재
/// - 헤더 뒤로가기의 `router.push('/')` — 라우터 부재
class SignInPage extends StatefulWidget {
  const SignInPage({
    required this.authApi,
    this.memberType = 'STUDENT',
    super.key,
  });

  final AuthApi authApi;

  /// 'STUDENT' | 'TRAINER'. 백엔드가 필수로 요구한다.
  /// 웹은 `/sign-in?type=student` 쿼리로 받는다 — 역할 선택 화면은 Phase 1.
  final String memberType;

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
      await widget.authApi.signIn(
        SignInRequest(
          userId: _userIdController.text.trim(),
          password: _passwordController.text,
          memberType: widget.memberType,
        ),
      );
      // 토큰 저장·라우팅은 Phase 1에서 연결한다.
    } catch (e) {
      error = _serverMessage(e) ?? '문제가 발생했습니다.';
    }

    // `await` 뒤에는 화면이 이미 dispose됐을 수 있다. 성공·실패 어느 쪽이든
    // 상태 갱신을 이 한 곳으로 모아 `mounted`를 한 번만 확인한다 —
    // 성공 경로에만 가드를 두면 실패 경로에서 예외가 난다.
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _submitError = error;
    });
  }

  /// 웹 SignInForm의 `error.response?.data?.message ?? '문제가 발생했습니다.'` 대응.
  /// 백엔드 응답은 `{status, message, data}` envelope라 실패 시에도 `message`가 온다.
  ///
  /// 화면이 늘어나면 `core/network`의 공용 헬퍼로 올린다. 사용처가 한 곳뿐인
  /// 지금 올리면 추상화만 늘고 얻는 게 없다.
  String? _serverMessage(Object error) {
    if (error is! DioException) {
      return null;
    }
    final data = error.response?.data;
    if (data is! Map) {
      return null;
    }
    final message = data['message'];
    return message is String ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    // 웹 SignInPage는 `<Layout className='bg-white'>`로 셸 기본 배경(gray-100)을
    // 흰색으로 덮고, Contents 안쪽에 `px-7`을 직접 준다. 제출 버튼도
    // bottomArea가 아니라 폼 안에 있다(SignInForm의 `mt-[46px]` 블록).
    return AppLayout(
      // 예외(토큰화하지 않는 리터럴): `Colors.white`는 `AppColors`에 대응
      // 토큰이 없는 프레임워크 상수다(`AppButton`의 전경색과 같은 예외).
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: widget._title),
      contents: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.s7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 웹은 여기에 로고 블록(`mt-[40px]` + 64px + `mb-[55px]`)이 있다.
            // 로고를 생략한 만큼 상단 여백은 웹과 1:1이 아니다 — 자산이
            // 들어오는 Phase 2에 웹 값으로 되돌린다.
            SizedBox(height: spacing.s10),
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
            // 웹은 `mt-[46px]`(임의값)이다. 46은 스페이싱 스케일에 없고, 필드
            // 그룹 사이 간격은 컴포넌트 고유 치수가 아니라 정확히 간격 토큰이
            // 다루는 값이라 가장 가까운 단계인 s12(48px)로 맞춘다.
            //
            // **2px 차이는 시각 대조에서 실측했다**(iPhone 17 Pro 시뮬레이터 vs
            // 같은 뷰포트 웹, 픽셀 열 프로파일): 입력2 아래끝→버튼 위끝이
            // Flutter 48.0pt, 웹 46.0pt. 예상대로 정확히 2px이고 그대로 둔다 —
            // 웹의 임의값을 글자대로 옮기면 62개 화면의 간격에 리터럴이
            // 흩어져, Phase 0이 세운 토큰 체계가 2px을 위해 무너진다.
            // (`h-[50px]`은 반대 판단이었다: 그건 간격이 아니라 컴포넌트
            // 고유 치수라 `AppTextInput.height` 상수로 받았다.)
            SizedBox(height: spacing.s12),
            AppButton(
              label: '로그인',
              onPressed: _submit,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
