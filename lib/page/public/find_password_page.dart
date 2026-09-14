import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/server_message.dart';
import '../../core/router/app_router.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/find_account.dart';
import '../../entity/auth/ui/social_icon.dart';
import '../../feature/auth/ui/find_account_form.dart';
import '../../feature/auth/ui/find_account_result.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/FindPasswordPage.tsx` 대응.
///
/// `FindIdPage`와 뼈대가 같다(205줄 vs 204줄). 실제 차이는 셋뿐이다:
/// 폼 아래 안내문 한 줄, 일반 가입 결과의 아이콘(`love_letter.svg`),
/// 그리고 결과 버튼 문구가 두 분기 모두 '완료'라는 것.
///
/// 응답도 더 얇다 — 웹 타입이 `Pick<FindIdResponse, 'socialType'>`라
/// 소셜 여부만 온다. 이메일은 응답이 아니라 **폼에 입력한 값**을 그대로
/// 보여준다(웹 `watch('email')`).
///
/// **패리티 범위:** 골든(`har/find-password.har`)이 덮는 것은 제출 요청
/// 하나뿐이다. 결과 분기는 위젯 테스트로만 고정돼 있다 — 실계정의 비밀번호를
/// 실제로 초기화하지 않고서는 성공 응답을 캡처할 수 없기 때문이다.
class FindPasswordPage extends StatefulWidget {
  const FindPasswordPage({required this.authApi, super.key});

  final AuthApi authApi;

  /// `love_letter.svg`의 고유 크기.
  static const double letterIconWidth = 56;
  static const double letterIconHeight = 41;

  @override
  State<FindPasswordPage> createState() => _FindPasswordPageState();
}

class _FindPasswordPageState extends State<FindPasswordPage> {
  final FindAccountFormController _form = FindAccountFormController();

  FindPasswordResponse? _completed;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _form.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _form.removeListener(_onFormChanged);
    _form.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  Future<void> _submit() async {
    if (_isSubmitting || !_form.isValid) {
      return;
    }

    // `await` 앞에서 잡는다 — 이유는 `app_toast.dart` 참고.
    final toast = AppToastScope.read(context);
    setState(() => _isSubmitting = true);

    try {
      final response = await widget.authApi.findPassword(_form.toRequest());
      if (mounted) {
        setState(() => _completed = response);
      }
    } catch (error) {
      toast.showError(serverMessage(error));
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  /// 웹 `router.back()`. 대체 경로를 온보딩으로 두는 이유는 `FindIdPage` 참고.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed;

    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: '비밀번호 찾기', onClose: _close),
      contents: switch (completed) {
        null => FindAccountFields(
          controller: _form,
          note: '가입하신 이메일 주소로 초기화된 비밀번호를 보내드립니다.',
        ),
        final result when result.socialType == socialTypeNone =>
          FindAccountResult(
            icon: SvgPicture.asset(
              'assets/images/love_letter.svg',
              width: FindPasswordPage.letterIconWidth,
              height: FindPasswordPage.letterIconHeight,
            ),
            message: FindAccountMessage.passwordSent(email: _form.email.text),
          ),
        final result => FindAccountResult(
          icon: AppSocialIcon(socialType: result.socialType),
          message: FindAccountMessage.social(
            email: _form.email.text,
            providerName: socialProviders[result.socialType]?.name ?? '',
          ),
        ),
      },
      bottomArea: AppButton(
        // 결과 분기는 소셜이든 아니든 '완료'다(아이디 찾기만 '로그인 하기').
        label: completed == null ? '이메일 전송하기' : '완료',
        onPressed: completed == null
            ? (_form.isValid ? _submit : null)
            : _close,
        isLoading: _isSubmitting,
      ),
    );
  }
}
