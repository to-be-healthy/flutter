import 'package:flutter/material.dart';

import '../../core/network/server_message.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/member_info.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_plain_input.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/EditNamePage.tsx` 대응.
///
/// ## 요청 1건
///
/// 골든 `mypage-student-edit-name`은 `GET /api/v1/members/me` 하나다
/// (2026-09-15 실측). `/student/mypage/info`와 요청 목록이 같지만
/// **골든은 화면마다 따로 뜬다**(규율 #2) — 같아 보인다고 공유하면, 한쪽이
/// 요청을 늘렸을 때 어느 화면이 틀렸는지 알 수 없게 된다.
///
/// ## 입력창은 현재 이름을 보여주는데 버튼은 꺼져 있다
///
/// 웹은 `defaultValue={data?.name}`으로 **입력창만** 채우고 `name` 상태는
/// `''`로 둔다. 버튼 조건이 `name === data?.name || name === ''`이라
/// **글자가 보이는데 버튼은 비활성**인 상태로 시작한다(실측으로 확인).
///
/// 여기서도 같다 — 컨트롤러에 이름을 넣되 상태는 사용자가 타이핑할 때만
/// 채운다. 되돌려 같은 이름을 입력하면 다시 비활성이 된다.
///
/// ## 성공 후 재조회를 옮기지 않았다
///
/// 웹은 `queryClient.refetchQueries(['myinfo'])`를 **기다린 뒤** 이동한다.
/// TanStack Query의 캐시를 갱신해 두어야 돌아간 화면이 새 이름을 보여주기
/// 때문이다. 앱에는 공유 캐시가 없고 `/student/mypage/info`가 자기
/// `initState`에서 `members/me`를 부르므로, **같은 GET이 이동 뒤에 일어난다.**
/// 순서만 다르고 나가는 요청은 같다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageEditNamePage extends StatefulWidget {
  const StudentMyPageEditNamePage({
    required this.memberApi,
    required this.onNavigate,
    required this.onBack,
    super.key,
  });

  /// 제출 버튼 높이. 웹 `py-[18px]` + 줄 높이 20 = 56(실측).
  /// `/edit/password`와 같다.
  static const double submitButtonHeight = 56;

  /// 웹 `space-y-3` — 제목과 입력 상자 사이(8).
  static const double fieldGap = 8;

  final MemberApi memberApi;

  /// 라우터를 화면에 끼우지 않기 위한 이동 콜백(규율 #3).
  final ValueChanged<String> onNavigate;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageEditNamePage> createState() =>
      _StudentMyPageEditNamePageState();
}

class _StudentMyPageEditNamePageState extends State<StudentMyPageEditNamePage> {
  final TextEditingController _controller = TextEditingController();

  MemberInfo? _me;

  /// 웹 `useState('')`. **입력창에 보이는 글자와 다르다** — 사용자가
  /// 타이핑하기 전에는 비어 있다(클래스 주석 참고).
  String _name = '';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 하단 네비가 없어 순서를 맞출 상대가 없다 — 바로 부른다.
    _loadMe();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.memberApi.me();
      if (!mounted) {
        return;
      }
      setState(() {
        _me = me;
        // 웹 `defaultValue={data?.name}` — 화면에 보일 글자만 채운다.
        //
        // `_name`은 건드리지 않아 웹 `useState('')`와 모양이 같다. 다만
        // **여기 이름을 넣어도 화면 동작은 같다** — `_canSubmit`의
        // `_name != _me?.name`이 그 경우를 이미 포섭하기 때문이다
        // (뮤테이션으로 확인한 동치다). 웹 구조를 그대로 두는 쪽을 골랐다.
        _controller.text = me.name;
      });
    } catch (_) {
      // 웹 `useMyInfoQuery`에 `isError` 분기가 없다. 실패하면 입력창이 빈
      // 채로 남고, 그 상태로도 이름을 바꿀 수 있다 — `data?.name`이
      // undefined라 버튼 조건의 앞쪽이 참이 되지 않기 때문이다.
    }
  }

  /// 웹 `disabledButton = name === data?.name || name === ''`.
  bool get _canSubmit => _name.isNotEmpty && _name != _me?.name;

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      await widget.memberApi.changeName(_name);
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        // 웹은 이 자리에만 `?? '문제가 발생했습니다.'` 폴백이 없다
        // (서베이 BUG-6). 다만 웹 `errorToast` 자체가 같은 폴백을 갖고
        // 있어(`use-toast.tsx:213`) **실제로 달라지는 것은 없다.**
        // `AppToastController.showError`도 같은 자리에서 폴백한다.
        AppToastScope.read(context).showError(serverMessage(error));
      }
      return;
    }

    if (!mounted) {
      return;
    }
    // 웹 `router.replace('../info')`.
    widget.onNavigate('/student/mypage/info');
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: '이름 변경', onBack: widget.onBack),
      contents: Padding(
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
            const Text('변경하실 이름을 입력해주세요.', style: AppTypography.title3),
            const SizedBox(height: StudentMyPageEditNamePage.fieldGap),
            AppPlainInput(
              // 웹 `<Input>`에 `placeholder`가 없다 — 빈 문자열을 넘긴다.
              hint: '',
              controller: _controller,
              onChanged: (value) => setState(() => _name = value),
            ),
          ],
        ),
      ),
      bottomArea: AppButton(
        label: '변경 완료',
        height: StudentMyPageEditNamePage.submitButtonHeight,
        // 웹이 이 버튼을 덮지 않아 `button.tsx` base가 그대로 보인다.
        labelStyle: AppButton.baseLabel,
        onPressed: _canSubmit ? _submit : null,
      ),
    );
  }
}
