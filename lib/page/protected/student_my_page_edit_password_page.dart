import 'package:flutter/material.dart';

import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/member/api/member_api.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_plain_input.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/EditPasswordPage.tsx` 대응.
///
/// ## 진입 요청이 없다
///
/// `leave`와 같이 골든이 없는 화면이다. 요청 둘 다 사용자가 눌러야 나가고,
/// **둘 다 본문에 비밀번호가 들어가 캡처하면 HAR에 평문이 남는다.**
/// 그래서 골든을 만들지 않았고, 요청의 모양은 계약 단언이 고정한다.
///
/// ## 2스텝이다
///
/// 1. 현재 비밀번호 확인 — `POST /api/v1/members/password`
/// 2. 새 비밀번호 입력 — `PATCH /api/v1/members/password`
///
/// 같은 경로를 **메서드로 가른다.** 1단계가 성공해야 2단계가 보이고,
/// 뒤로 돌아가는 길은 없다(웹에 `setStep(1)`이 없다).
///
/// ## 웹 클래스 둘이 죽어 있다
///
/// - `mt-7`(20)이 `space-y-3`(8)에 **덮인다.** Tailwind의 `space-y-*`는
///   `.space-y-3 > :not([hidden]) ~ :not([hidden])` 선택자라 단일 클래스
///   `mt-7`보다 특정도가 높다. 실측 결과 그 자리의 간격은 **8**이다.
/// - 성공 토스트가 `//TODO`로 남아 있다(서베이 BUG-12). 비밀번호를 바꿔도
///   아무 말 없이 화면만 넘어간다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageEditPasswordPage extends StatefulWidget {
  const StudentMyPageEditPasswordPage({
    required this.memberApi,
    required this.onNavigate,
    required this.onBack,
    super.key,
  });

  /// 제출 버튼 높이. 웹 `py-[18px]` + 줄 높이 20 = **56**(실측).
  ///
  /// `AppButton.defaultHeight`(44)가 아니다 — 로그인 화면이 고른 값이고
  /// 이 화면은 다르다.
  static const double submitButtonHeight = 56;

  /// 웹 `space-y-3` — 섹션 안 요소 사이 간격(8).
  ///
  /// 힌트 문단의 `mt-7`(20)까지 **이 값이 이긴다**(위 클래스 주석 참고).
  static const double fieldGap = 8;

  final MemberApi memberApi;

  /// 라우터를 화면에 끼우지 않기 위한 이동 콜백(규율 #3).
  final ValueChanged<String> onNavigate;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageEditPasswordPage> createState() =>
      _StudentMyPageEditPasswordPageState();
}

class _StudentMyPageEditPasswordPageState
    extends State<StudentMyPageEditPasswordPage> {
  /// 웹 `useState(1)`. 1 → 2로만 간다.
  int _step = 1;

  String _password = '';
  String _newPassword = '';
  String _confirmPassword = '';

  /// 요청이 날아가는 중인지. 웹에는 없는 가드다 — `info`의 로그아웃,
  /// `leave`의 탈퇴와 같은 이유로 넣었다(`docs/deferred-minors.md`).
  bool _isSubmitting = false;

  Future<void> _verifyPassword() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final verified = await widget.memberApi.verifyPassword(_password);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        // 웹 `if (data) setStep(2)` — false면 **아무 일도 일어나지 않는다.**
        // 안내도 없다. 서버가 틀린 비밀번호에 400을 주므로 실제로는
        // 아래 `catch`로 빠지는 경로다.
        if (verified) {
          _step = 2;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        // 웹 `setPassword('')`.
        //
        // **입력창은 비워지지 않는다.** 웹의 `<Input>`이 비제어라
        // `setPassword('')`는 상태만 비우고 화면의 글자는 그대로 남는다 —
        // 그 결과 **글자가 보이는데 버튼이 비활성**이 된다. 여기서도
        // 컨트롤러를 두지 않아 같은 상태가 재현된다(서베이에 기록).
        _password = '';
      });
      AppToastScope.read(context).showError(serverMessage(error));
    }
  }

  Future<void> _changePassword() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      await widget.memberApi.changePassword(
        password: _newPassword,
        confirmPassword: _confirmPassword,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToastScope.read(context).showError(serverMessage(error));
      }
      return;
    }

    if (!mounted) {
      return;
    }
    // 웹 `router.replace('../info')` + `//TODO: SUCCESS TOAST`.
    // **성공 토스트가 없다** — 아무 말 없이 화면만 넘어간다(BUG-12).
    widget.onNavigate('/student/mypage/info');
  }

  /// 웹 `disabled={!password}`.
  bool get _canVerify => _password.isNotEmpty;

  /// 웹 `disabled={!newPassword || !confirmPassword ||
  /// newPassword !== confirmPassword}`.
  ///
  /// **길이·형식 검증은 없다.** 플레이스홀더가 "영문+숫자 조합 8자리 이상"이라
  /// 말하지만 화면은 그것을 확인하지 않는다 — 서버가 거절하면 토스트가 뜬다.
  bool get _canChange =>
      _newPassword.isNotEmpty &&
      _confirmPassword.isNotEmpty &&
      _newPassword == _confirmPassword;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: '비밀번호 변경', onBack: widget.onBack),
      contents: Padding(
        // 웹 `px-7 pt-8` = 좌우 20, 위 24. **아래 패딩은 없다.**
        padding: EdgeInsets.only(
          left: spacing.s7,
          right: spacing.s7,
          top: spacing.s8,
        ),
        child: _step == 1
            ? _VerifyStep(
                onChanged: (value) => setState(() => _password = value),
                onFindPassword: () => widget.onNavigate('/find/pw'),
              )
            : _ChangeStep(
                onNewPasswordChanged: (value) =>
                    setState(() => _newPassword = value),
                onConfirmPasswordChanged: (value) =>
                    setState(() => _confirmPassword = value),
              ),
      ),
      bottomArea: _step == 1
          ? AppButton(
              label: '비밀번호 확인',
              height: StudentMyPageEditPasswordPage.submitButtonHeight,
              // 웹이 이 버튼을 덮지 않아 `button.tsx` base가 그대로 보인다.
              labelStyle: AppButton.baseLabel,
              onPressed: _canVerify ? _verifyPassword : null,
            )
          : AppButton(
              label: '비밀번호 변경하기',
              height: StudentMyPageEditPasswordPage.submitButtonHeight,
              labelStyle: AppButton.baseLabel,
              onPressed: _canChange ? _changePassword : null,
            ),
    );
  }
}

/// 웹 `:68~86` — 1단계.
class _VerifyStep extends StatelessWidget {
  const _VerifyStep({required this.onChanged, required this.onFindPassword});

  final ValueChanged<String> onChanged;
  final VoidCallback onFindPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('현재 비밀번호를 입력해주세요.', style: AppTypography.title3),
        const SizedBox(height: StudentMyPageEditPasswordPage.fieldGap),
        AppPlainInput(hint: '비밀번호', obscureText: true, onChanged: onChanged),
        const SizedBox(height: StudentMyPageEditPasswordPage.fieldGap),
        _FindPasswordHint(onTap: onFindPassword),
      ],
    );
  }
}

/// 웹 `:87~107` — 2단계.
class _ChangeStep extends StatelessWidget {
  const _ChangeStep({
    required this.onNewPasswordChanged,
    required this.onConfirmPasswordChanged,
  });

  final ValueChanged<String> onNewPasswordChanged;
  final ValueChanged<String> onConfirmPasswordChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('새로운 비밀번호를 입력해주세요.', style: AppTypography.title3),
        const SizedBox(height: StudentMyPageEditPasswordPage.fieldGap),
        // **1단계의 힌트 문단이 여기에는 없다.**
        AppPlainInput(
          hint: '영문+숫자 조합 8자리 이상',
          obscureText: true,
          onChanged: onNewPasswordChanged,
        ),
        const SizedBox(height: StudentMyPageEditPasswordPage.fieldGap),
        AppPlainInput(
          hint: '비밀번호 재입력',
          obscureText: true,
          onChanged: onConfirmPasswordChanged,
        ),
      ],
    );
  }
}

/// 웹 `:79~84`의 힌트 문단.
class _FindPasswordHint extends StatelessWidget {
  const _FindPasswordHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Wrap(
      // 웹 링크의 `ml-3` = 8. `Wrap`을 쓰는 이유는 웹이 인라인 텍스트라
      // 좁아지면 줄바꿈되기 때문이다(`Row`는 넘친다).
      spacing: spacing.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '비밀번호가 기억나지 않으세요?',
          style: AppTypography.body4.copyWith(color: colors.gray500),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            '비밀번호 찾기',
            style: AppTypography.body4.copyWith(color: colors.primary500),
          ),
        ),
      ],
    );
  }
}
