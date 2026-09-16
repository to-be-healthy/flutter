import 'package:flutter/material.dart';

import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/member_info.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_plain_input.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/EditEmailPage.tsx` 대응.
///
/// ## 요청 1건, 그리고 토큰 없는 요청 하나
///
/// 골든 `mypage-student-edit-email`은 `GET /api/v1/members/me` 하나다.
/// 상호작용으로 둘이 더 나간다:
///
/// | 버튼 | 요청 | 토큰 |
/// |---|---|---|
/// | 인증 요청 · 재전송 | `POST /api/v1/auth/validation/send-email` | **없다** |
/// | 인증 완료 | `PATCH /api/v1/members/email` | 있다 |
///
/// **마이페이지 아홉 화면 중 토큰 없는 인스턴스를 쓰는 유일한 요청**이다
/// (웹은 `api`, 앱은 `AuthInterceptor._publicPaths`의 `/auth/validation/`).
/// 그 줄이 없어서 앱만 헤더를 붙이고 있었고, 이 화면을 옮기며 찾았다.
///
/// ## 2단계에서 인증번호 칸이 이메일 칸보다 **위**다
///
/// 웹 DOM 순서가 그렇다(`:67~81`이 `:82~92`보다 앞) — 서베이 BUG-15.
/// 나중에 생긴 입력이 위로 가는 어색한 배치지만 그대로 옮긴다.
///
/// 이메일 칸은 2단계에서 **`readOnly`**가 된다. `disabled`가 아니라서
/// 흐려지지 않고 테두리도 그대로다.
///
/// ## 인증번호 행의 높이는 옆 버튼이 정한다
///
/// 상자 자체는 52짜리(`py-[13px]`)인데 **실측 56**이다. `재전송` 버튼이
/// `py-[18px]`로 56이고 행이 `flex`(기본 `align-items: stretch`)라 상자가
/// 끌려 올라간다. 클래스만 읽으면 52로 틀린다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageEditEmailPage extends StatefulWidget {
  const StudentMyPageEditEmailPage({
    required this.authApi,
    required this.memberApi,
    required this.onNavigate,
    required this.onBack,
    super.key,
  });

  /// 제출 버튼 높이. `/edit/password`·`/edit/name`과 같은 56.
  static const double submitButtonHeight = 56;

  /// 웹 `space-y-3` — 제목과 입력 사이(8).
  static const double fieldGap = 8;

  /// 웹 `gap-2` — 인증번호 칸과 재전송 버튼 사이.
  ///
  /// **6이다**(커스텀 스케일). Tailwind 기본 8이 아니다.
  static const double codeRowGap = 6;

  /// 웹 `재전송` 버튼의 `px-6` = 16.
  static const double resendHorizontalPadding = 16;

  /// 웹 `재전송` 버튼의 `py-[18px]`.
  ///
  /// className이 `h-full px-6`만 덮고 **`size: default`의 `py-[18px]`는
  /// 그대로 남는다.** 그래서 버튼의 자연 높이가 `18 + 20 + 18 = 56`이 되고,
  /// 그 값이 행 전체(인증번호 상자 포함)를 56으로 끌어올린다.
  /// 이 패딩을 빠뜨리면 행이 52에 머물러 웹과 4px 어긋난다.
  static const double resendVerticalPadding = 18;

  final AuthApi authApi;
  final MemberApi memberApi;

  /// 라우터를 화면에 끼우지 않기 위한 이동 콜백(규율 #3).
  final ValueChanged<String> onNavigate;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageEditEmailPage> createState() =>
      _StudentMyPageEditEmailPageState();
}

class _StudentMyPageEditEmailPageState
    extends State<StudentMyPageEditEmailPage> {
  final TextEditingController _emailController = TextEditingController();

  MemberInfo? _me;

  /// 웹 `useState(1)`. 1 → 2로만 간다.
  int _step = 1;

  /// 웹 `useState('')`. 입력창에 보이는 글자와 별개다
  /// (`/edit/name`과 같은 구조).
  String _email = '';
  String _code = '';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.memberApi.me();
      if (mounted) {
        setState(() {
          _me = me;
          // 웹 `defaultValue={data?.email}` — 화면에 보일 글자만 채운다.
          _emailController.text = me.email;
        });
      }
    } catch (_) {
      // 웹 쿼리에 `isError` 분기가 없다.
    }
  }

  /// 웹 `disabled={email === data?.email || email === ''}`.
  bool get _canSendCode => _email.isNotEmpty && _email != _me?.email;

  /// 웹 `disabled={!code}`.
  bool get _canConfirm => _code.isNotEmpty;

  /// 인증 요청. 성공하면 2단계로 간다.
  Future<void> _sendCode() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      await widget.authApi.sendVerificationCode(_email);
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToastScope.read(context).showError(serverMessage(error));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _step = 2;
      });
    }
  }

  /// 재전송. **성공·실패 어느 쪽도 알리지 않는다** — 웹이 콜백을 하나도
  /// 넘기지 않기 때문이다(`onClick={() => sendCode(email)}`, 서베이 BUG-14).
  /// 눌러도 화면이 아무 반응을 하지 않는 것이 웹의 현재 동작이다.
  Future<void> _resendCode() async {
    try {
      await widget.authApi.sendVerificationCode(_email);
    } catch (_) {
      // 웹에 `onError`가 없다. 토스트를 띄우면 웹에 없는 피드백이 된다.
    }
  }

  Future<void> _confirm() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      await widget.memberApi.changeEmail(email: _email, emailKey: _code);
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
    // 웹은 `refetchQueries(['myinfo'])`를 기다린 뒤 `router.replace('../info')`
    // 한다. 앱에는 공유 캐시가 없고 목적지 화면이 자기 `initState`에서 같은
    // GET을 하므로 재조회를 옮기지 않았다(`/edit/name`과 같은 판단).
    widget.onNavigate('/student/mypage/info');
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: '이메일 변경', onBack: widget.onBack),
      contents: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // **인증번호 칸이 위다**(BUG-15). 2단계에서만 나온다.
          if (_step == 2)
            _Section(
              title: '이메일로 발송된 인증번호를 입력해주세요.',
              child: _CodeRow(
                onChanged: (value) => setState(() => _code = value),
                onResend: _resendCode,
              ),
            ),
          _Section(
            title: '변경하실 이메일을 입력해주세요.',
            child: AppPlainInput(
              // 웹 `<Input>`에 `placeholder`가 없다.
              hint: '',
              controller: _emailController,
              // 2단계에서 잠긴다.
              readOnly: _step != 1,
              onChanged: (value) => setState(() => _email = value),
            ),
          ),
        ],
      ),
      bottomArea: _step == 1
          ? AppButton(
              label: '인증 요청',
              height: StudentMyPageEditEmailPage.submitButtonHeight,
              labelStyle: AppButton.baseLabel,
              onPressed: _canSendCode ? _sendCode : null,
            )
          : AppButton(
              label: '인증 완료',
              height: StudentMyPageEditEmailPage.submitButtonHeight,
              labelStyle: AppButton.baseLabel,
              onPressed: _canConfirm ? _confirm : null,
            ),
    );
  }
}

/// 웹 `<section className='space-y-3 px-7 pt-8'>`.
///
/// 두 섹션이 **각자** `pt-8`을 갖는다 — 사이 여백이 24가 되는 이유다
/// (섹션 간 마진은 없다).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Padding(
      // 웹 `px-7 pt-8` = 좌우 20, 위 24. 아래 패딩은 없다.
      padding: EdgeInsets.only(
        left: spacing.s7,
        right: spacing.s7,
        top: spacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTypography.title3),
          const SizedBox(height: StudentMyPageEditEmailPage.fieldGap),
          child,
        ],
      ),
    );
  }
}

/// 웹 `<div className='flex w-full gap-2'>` — 인증번호 칸 + 재전송 버튼.
class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.onChanged, required this.onResend});

  final ValueChanged<String> onChanged;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    // **행 높이를 `재전송` 버튼(56)이 정한다.** 상자 혼자면 52다.
    // `IntrinsicHeight`가 "가장 큰 자식만큼"으로 상한을 만들고, 그 안에서
    // `AppPlainInput`의 `Container(alignment: topLeft)`가 늘어난 높이를
    // 채우며 내용을 위에 붙인다 — 웹과 같은 결과다(실측: 상자 56, 입력
    // 24가 위 13 자리에서 시작).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppPlainInput(hint: '', onChanged: onChanged),
          ),
          const SizedBox(width: StudentMyPageEditEmailPage.codeRowGap),
          _ResendButton(onPressed: onResend),
        ],
      ),
    );
  }
}

/// 웹 `<Button className='h-full bg-gray-700 px-6'>재전송</Button>`.
///
/// `AppButton`을 쓰지 않는다 — 그 위젯은 폭을 꽉 채우는 제출 버튼용
/// (`width: double.infinity`)인데 이것은 **글자 폭만큼**이다(실측 68.31).
class _ResendButton extends StatelessWidget {
  const _ResendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: StudentMyPageEditEmailPage.resendHorizontalPadding,
          vertical: StudentMyPageEditEmailPage.resendVerticalPadding,
        ),
        decoration: BoxDecoration(
          // 웹 `bg-gray-700` — 이 화면에만 나오는 버튼 색이다.
          color: colors.gray700,
          // 웹 `button.tsx` base의 `rounded-lg` = 12.
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Text(
          '재전송',
          // base `text-sm font-medium` + variant default 의 `text-white`.
          style: AppButton.baseLabel.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
