import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../entity/auth/model/find_account.dart';
import '../../../shared/ui/app_text_input.dart';

/// 웹 `FindIdPage`/`FindPasswordPage`가 쓰는 react-hook-form
/// (`useForm<FindIdRequest>({mode: 'onChange'})`) 대응.
///
/// **`mode: 'onChange'`의 두 성질을 그대로 옮긴다.**
/// 1. 제출 버튼은 `disabled={!isValid}`라 **첫 화면부터 비활성**이고,
///    두 필드가 모두 통과하는 키 입력에서 활성으로 바뀐다.
/// 2. 에러 문구는 **건드린 필드에만** 뜬다. 이름을 치는 동안 아직 비어 있는
///    이메일에 "이메일을 입력해주세요."가 뜨지 않는다 — RHF가 `errors`는
///    변경된 필드에만 채우고 `isValid`만 폼 전체로 계산하기 때문이다.
///
/// 두 화면이 같은 폼을 쓴다(`FindPasswordRequest = FindIdRequest`). 다른
/// 것은 아래 안내문 한 줄뿐이라 [FindAccountFields.note]로 열어 뒀다.
class FindAccountFormController extends ChangeNotifier {
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();

  bool _nameTouched = false;
  bool _emailTouched = false;

  /// 건드리지 않은 필드에는 에러를 보이지 않는다(위 성질 2).
  String? get nameError => _nameTouched ? validateName(name.text) : null;
  String? get emailError => _emailTouched ? validateEmail(email.text) : null;

  /// 웹 `formState.isValid` — 건드림 여부와 무관하게 폼 전체로 계산한다.
  bool get isValid =>
      validateName(name.text) == null && validateEmail(email.text) == null;

  void onNameChanged(String _) {
    _nameTouched = true;
    notifyListeners();
  }

  void onEmailChanged(String _) {
    _emailTouched = true;
    notifyListeners();
  }

  /// **trim하지 않는다.** 웹은 RHF 폼 객체를 그대로 `mutate(form)`에 넘긴다.
  FindAccountRequest toRequest() =>
      FindAccountRequest(name: name.text, email: email.text);

  /// 웹 `register('name', {required, pattern})`의 순서와 문구 그대로.
  ///
  /// '한글 또는 영문만 입력해주세요'에 마침표가 없는 것도 웹 그대로다
  /// (다른 문구들과 달리 웹 저자가 마침표를 빠뜨렸다).
  static String? validateName(String value) {
    if (value.isEmpty) {
      return '이름을 입력해주세요.';
    }
    if (!AuthRegExp.name.hasMatch(value)) {
      return '한글 또는 영문만 입력해주세요';
    }
    return null;
  }

  static String? validateEmail(String value) {
    if (value.isEmpty) {
      return '이메일을 입력해주세요.';
    }
    if (!AuthRegExp.email.hasMatch(value)) {
      return '이메일 형식이 아닙니다.';
    }
    return null;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }
}

/// 웹 두 화면의 `<form className='flex flex-col gap-8 p-7'>` 대응.
///
/// 웹은 테두리를 `<div>`가, 입력을 장식 없는 raw `<input>`이 맡는 구조라
/// 공용 `TextInput` 컴포넌트를 쓰지 않는다. 그래도 [AppTextInput]을 그대로
/// 쓰는 이유는 **치수가 정확히 같기 때문**이다 — 웹 래퍼의 `py-[13px]` +
/// `BODY_1` 행높이(16 × 1.5 = 24) + `py-[13px]` = 50px이고, 이는
/// `AppTextInput.height`(= 웹 `TextInput`의 `h-[50px]`)와 같은 값이다.
/// 라벨 간격(`gap-3` = 8px)과 테두리(`rounded-md border-gray-200`,
/// 에러 시 `border-point`)도 일치한다.
///
/// 남는 차이는 둘이고 **의도적으로 공용 컴포넌트 쪽을 따른다**:
/// - 에러 문구 굵기: 이 두 화면은 `BODY_4_MEDIUM`(500), 로그인 화면은
///   `BODY_4`(400)다. 웹 안에서 이미 갈려 있어 공용 컴포넌트가 하나를
///   골라야 하고, 이미 픽셀 대조를 마친 로그인 화면 쪽(400)을 남긴다.
/// - 라벨 색: 이 두 화면은 색 클래스가 없어 shadcn 기본 foreground
///   (`#020817`)로, 로그인 화면은 `text-gray-800`으로 렌더된다.
///   `AppLayoutHeader`의 제목 색과 같은 종류의 미지정 값이라 같은 결론
///   (gray800)을 따른다.
///
/// 둘 다 12px·1px 수준 차이고, 디자인 검수에서 뒤집히면 공용 컴포넌트
/// 한 곳만 고치면 된다.
class FindAccountFields extends StatelessWidget {
  const FindAccountFields({required this.controller, this.note, super.key});

  final FindAccountFormController controller;

  /// 웹 `FindPasswordPage`의 폼 아래 안내문(`<p className='pt-12 ...'>`).
  /// `FindIdPage`에는 없다.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      // 웹 `p-7` — 사방 20px.
      padding: EdgeInsets.all(spacing.s7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextInput(
            label: '이름을 입력해주세요.',
            hint: '이름 입력',
            controller: controller.name,
            errorText: controller.nameError,
            onChanged: controller.onNameChanged,
          ),
          // 웹 form의 `gap-8` = 24px.
          SizedBox(height: spacing.s8),
          AppTextInput(
            label: '가입한 이메일 주소를 입력해주세요.',
            hint: '이메일 주소 입력',
            // 웹 `type='email' inputMode='email'` — 키보드가 @ 와 . 을
            // 첫 화면에 올린다.
            keyboardType: TextInputType.emailAddress,
            controller: controller.email,
            errorText: controller.emailError,
            onChanged: controller.onEmailChanged,
          ),
          if (note != null) ...[
            // 웹 `<p className='pt-12'>` — 48px. 이 `<p>`는 form 바깥
            // 형제라 위의 `gap-8`이 걸리지 않는다.
            SizedBox(height: spacing.s12),
            Text(
              note!,
              style: AppTypography.body3.copyWith(color: colors.gray500),
            ),
          ],
        ],
      ),
    );
  }
}
