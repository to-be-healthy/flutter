import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/server_message.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/find_account.dart';
import '../../entity/auth/ui/social_icon.dart';
import '../../feature/auth/ui/find_account_form.dart';
import '../../feature/auth/ui/find_account_result.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/FindIdPage.tsx` 대응.
///
/// 한 위젯 안의 **세 가지 상태**다(웹도 컴포넌트 하나에 세 분기다):
/// 1. 폼 — 이름·이메일 입력
/// 2. 결과 · 일반 가입(`socialType == 'NONE'`) — 마스킹된 아이디 카드
/// 3. 결과 · 소셜 가입 — 어느 소셜로 가입했는지 안내
///
/// **패리티 범위:** `har/find-id.har`에서 만든 골든이 덮는 것은 1번의 제출
/// 요청 하나뿐이다. 2·3번은 응답에 따라 갈리는데 실계정 없이는 성공 응답을
/// 캡처할 수 없어(예약 도메인으로 캡처한 HAR의 응답은 404다) **요청 패리티가
/// 아니라 위젯 테스트로만 고정**돼 있다. 특히 3번의 소셜 아이콘 4종은
/// 웹 렌더를 실제로 본 적이 없다 — 디자인 검수 대상이다.
class FindIdPage extends StatefulWidget {
  const FindIdPage({required this.authApi, super.key});

  final AuthApi authApi;

  /// 웹 결과 카드의 `mt-[96px]`.
  static const double cardTopGap = 96;

  /// 웹 하단 안내문의 `w-[160px]`. 이 폭이 문구를 세 줄로 접는다.
  static const double noteWidth = 160;

  @override
  State<FindIdPage> createState() => _FindIdPageState();
}

class _FindIdPageState extends State<FindIdPage> {
  final FindAccountFormController _form = FindAccountFormController();

  FindIdResponse? _completed;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 폼이 바뀔 때마다 다시 그려야 한다 — 에러 문구(Contents)와 제출 버튼의
    // 활성 여부(BottomArea)가 **서로 다른 슬롯**에 있어서, 어느 한쪽만
    // 구독하면 나머지가 멈춘다.
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

    // **`await` 앞에서 컨트롤러를 잡는다.** 뒤에서 `read(context)`를 부르면
    // 그 사이 화면이 버려졌을 때 죽은 컨텍스트를 조회한다 (`app_toast.dart`).
    final toast = AppToastScope.read(context);
    setState(() => _isSubmitting = true);

    try {
      final response = await widget.authApi.findId(_form.toRequest());
      if (mounted) {
        setState(() => _completed = response);
      }
    } catch (error) {
      // 웹 `onError: (error) => errorToast(error?.response?.data.message)` —
      // 이 화면은 에러를 인라인 텍스트가 아니라 토스트로 띄운다.
      toast.showError(serverMessage(error));
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  /// 웹의 `router.back()` 세 곳(헤더 X, '로그인 하기', '완료') 전부.
  ///
  /// 돌아갈 곳이 없으면 온보딩으로 보낸다. `/sign-in`이 아닌 이유는 그
  /// 화면이 `?type=`을 **필수로** 요구하기 때문이다 — 이 경로로 직접
  /// 진입했다면(딥링크·알림) 역할 정보가 애초에 없으므로, 타입 없이
  /// `/sign-in`으로 보내봐야 라우터가 온보딩으로 다시 튕긴다.
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
      // 웹 `<Layout className='bg-white'>`.
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: '아이디 찾기', onClose: _close),
      contents: switch (completed) {
        null => FindAccountFields(controller: _form),
        final result when result.socialType == socialTypeNone => _IdCard(
          result: result,
        ),
        final result => FindAccountResult(
          icon: AppSocialIcon(socialType: result.socialType),
          message: FindAccountMessage.social(
            // 웹도 응답이 아니라 폼의 현재 값(`watch('email')`)을 쓴다.
            email: _form.email.text,
            providerName: socialProviders[result.socialType]?.name ?? '',
          ),
        ),
      },
      bottomArea: AppButton(
        label: switch (completed) {
          null => '이메일 전송하기',
          final result when result.socialType == socialTypeNone => '로그인 하기',
          _ => '완료',
        },
        // 웹 `disabled={!isValid}` — 첫 화면부터 비활성이다.
        // 결과 화면의 버튼에는 `disabled`가 없어 늘 활성이다.
        onPressed: completed == null
            ? (_form.isValid ? _submit : null)
            : _close,
        // 웹에는 로딩 상태가 없다(mutate 중에도 버튼이 눌린다 — 중복 POST가
        // 가능한 웹 쪽 결함이다). 로그인 화면과 같은 방식으로 막는다.
        isLoading: _isSubmitting,
      ),
    );
  }
}

/// 웹 결과 · 일반 가입 분기의 파란 카드와 그 아래 안내문.
class _IdCard extends StatelessWidget {
  const _IdCard({required this.result});

  final FindIdResponse result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;
    final createdAt = result.createdAt;

    return Padding(
      // 웹 `<Layout.Contents className='px-7'>`.
      padding: EdgeInsets.symmetric(horizontal: spacing.s7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: FindIdPage.cardTopGap),
          Container(
            // 웹 `p-6 py-10` — 좌우 16px, 위아래 32px(`py-10`이 `p-6`의
            // 세로값을 덮는다).
            padding: EdgeInsets.symmetric(
              horizontal: spacing.s6,
              vertical: spacing.s10,
            ),
            decoration: BoxDecoration(
              color: colors.blue50,
              // 웹 `rounded-lg` = 12px.
              borderRadius: BorderRadius.circular(radius.l),
            ),
            child: Column(
              children: [
                Text(
                  result.userId,
                  textAlign: TextAlign.center,
                  style: AppTypography.heading4.copyWith(
                    color: colors.primary500,
                  ),
                ),
                if (createdAt != null) ...[
                  // 웹 카드의 `gap-3` = 8px.
                  SizedBox(height: spacing.s3),
                  Text(
                    '가입일자: ${formatYearMonthDay(createdAt)}',
                    textAlign: TextAlign.center,
                    style: AppTypography.body1.copyWith(color: colors.gray700),
                  ),
                ],
              ],
            ),
          ),
          // 웹 `mt-7` = 20px.
          SizedBox(height: spacing.s7),
          // 웹 `mx-auto w-[160px] text-center`. 폭이 문구를 접는 장치라
          // 고정값 그대로 옮긴다.
          Center(
            child: SizedBox(
              width: FindIdPage.noteWidth,
              child: Text(
                '개인정보보호를 위해 아이디 중 일부는 *로 표기됩니다.',
                textAlign: TextAlign.center,
                style: AppTypography.body3.copyWith(color: colors.gray500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
