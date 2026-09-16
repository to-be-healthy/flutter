import 'package:flutter/material.dart';

import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/ui/auth_scope.dart';
import '../../entity/member/api/member_api.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_checkbox.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/LeavePage.tsx` 대응.
///
/// ## 진입 요청이 없다
///
/// 골든이 없는 화면이다 — 마운트 시 아무것도 부르지 않는다. 유일한 요청은
/// `POST /api/v1/members/delete`이고, 그것은 **공유 체험 계정을 실제로
/// 지우므로 캡처할 수 없다**(`/select-gym`의 등록 POST와 같은 부류).
/// 요청의 모양은 테스트의 계약 단언이 고정한다.
///
/// ## 확인 다이얼로그의 첫 레퍼런스
///
/// 웹은 shadcn `Dialog`(Radix)를 쓰고 이 화면이 그 첫 사용처다. 공용으로
/// 올리지 않고 [_ConfirmDeleteDialog]로 여기 둔다 — 같은 모양을 쓰는 화면이
/// 하나 더 나오면 그때 승격한다(`AppButton`·`_GrantCourseButton`과 같은 규칙).
/// 승격할 때 필요한 치수는 아래 상수에 실측값으로 박혀 있다.
///
/// ## 웹과 다르게 한 것 하나
///
/// 다이얼로그의 두 버튼을 **같은 폭으로** 그린다. 웹 실측은 129.67 / 140.33로
/// 다른데, 그 차이는 디자인이 아니라 CSS flex-shrink가 **콘텐츠 박스 기준**
/// 으로 배분되기 때문이다(`탈퇴하기`만 좌우 패딩 10을 갖는다). Flutter에
/// 같은 알고리즘이 없고, 재현하려면 설명 불가능한 비율 상수를 박아야 한다.
/// `docs/deferred-minors.md`에 수치와 함께 적었다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageLeavePage extends StatefulWidget {
  const StudentMyPageLeavePage({
    required this.memberApi,
    required this.onNavigate,
    required this.onBack,
    super.key,
  });

  /// 웹 `gap-[72px]` — 유의사항 섹션과 동의 섹션 사이.
  static const double sectionGap = 72;

  /// 웹 `py-5` = 12. 계정 삭제 버튼의 상하 패딩.
  ///
  /// 테두리 1px과 줄 높이 24를 더해 **버튼 높이 50**이 된다(실측).
  static const double deleteButtonVerticalPadding = 12;

  /// 웹 `w-[320px]` — 확인 다이얼로그 폭.
  static const double dialogWidth = 320;

  /// 웹 `py-[13px]` — 다이얼로그 두 버튼의 상하 패딩.
  static const double dialogButtonVerticalPadding = 13;

  /// 웹 `bg-destructive` = `hsl(0 84.2% 60.2%)`.
  ///
  /// **`--point-color`(`#FF4668`)가 아니다.** 같은 화면에서 계정 삭제 버튼은
  /// point를 쓰고 다이얼로그의 탈퇴하기만 이 색을 쓴다 — shadcn 기본
  /// 팔레트가 그대로 남은 자리다.
  static const Color destructive = Color(0xFFEF4444);

  /// 웹 `text-destructive-foreground` = `hsl(210 40% 98%)`.
  /// 순백이 아니다.
  static const Color destructiveForeground = Color(0xFFF8FAFC);

  /// 웹 `border`(shadcn `--border` = `hsl(214.3 31.8% 91.4%)`) —
  /// 다이얼로그 테두리. 앱 팔레트의 gray와 다른 값이라 토큰으로 올리지 않는다.
  static const Color dialogBorder = Color(0xFFE2E8F0);

  /// 웹 `bg-black/80` — 다이얼로그 뒤를 덮는 막.
  static const Color barrier = Color(0xCC000000);

  /// 웹 유의사항 문구 3줄. **불릿은 CSS가 아니라 문자열의 일부다.**
  static const List<String> notices = <String>[
    '• 탈퇴 후에는 위 계정으로 로그인하실 수 없습니다.',
    '• 보유한 포인트 및 이용 기록, 수강권 등은 탈퇴 시 소멸되며 복구가 불가능합니다.',
    '• 회원탈퇴 후 재 가입하더라도 탈퇴 전의 회원 정보, 운동 기록, 예약 내역, '
        '수강권 등은 복구되지 않습니다.',
  ];

  final MemberApi memberApi;

  /// 라우터를 화면에 끼우지 않기 위한 이동 콜백(규율 #3).
  final ValueChanged<String> onNavigate;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageLeavePage> createState() => _StudentMyPageLeavePageState();
}

class _StudentMyPageLeavePageState extends State<StudentMyPageLeavePage> {
  bool _agreed = false;

  /// 탈퇴 요청이 날아가는 중인지. 웹에는 없는 가드다 —
  /// `info` 화면의 로그아웃과 같은 이유로 넣었다(`deferred-minors.md`).
  bool _isDeleting = false;

  Future<void> _confirmAndDelete() async {
    // **동의 가드는 여기가 아니라 버튼에 있다.** 웹 `DialogTrigger`가
    // `disabled={!agreement}`이고 [_DeleteButton]이 그것을 그대로 옮겼다
    // (`onTap: enabled ? onPressed : null`). 여기에 `if (!_agreed) return;`을
    // 한 번 더 두었다가 뮤테이션으로 지워 봤는데 **아무 테스트도 깨지지
    // 않았다** — 도달할 수 없는 코드였다.
    final confirmed = await showDialog<bool>(
      context: context,
      // 웹 오버레이 `bg-black/80`.
      barrierColor: StudentMyPageLeavePage.barrier,
      builder: (context) => const _ConfirmDeleteDialog(),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) {
      return;
    }
    setState(() => _isDeleting = true);

    try {
      await widget.memberApi.deleteAccount();
    } catch (error) {
      // 웹 `onError: errorToast(message ?? '문제가 발생했습니다.')`.
      // 실패하면 **계정도 세션도 그대로다.**
      if (mounted) {
        setState(() => _isDeleting = false);
        AppToastScope.read(context).showError(serverMessage(error));
      }
      return;
    }

    if (!mounted) {
      return;
    }
    // 웹 `deleteUserInfo()`.
    //
    // **웹은 여기서 `localStorage.clear()`를 하지 않는다** — 로그아웃과
    // 비대칭이다(서베이 BUG-13). 앱에서는 토큰과 프로필이 로컬 상태의
    // 전부라 `signOut()` 하나로 둘 다 지워지고, 그래서 그 비대칭이 사라진다.
    await AuthScope.read(context).signOut();

    if (!mounted) {
      return;
    }
    // 웹 `router.replace('/')` — 로그아웃의 `push`와 달리 **replace**다.
    // 지워진 계정의 화면으로 뒤로가기를 못 하게 하는 의도로 보인다.
    widget.onNavigate('/');
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: '회원 탈퇴', onBack: widget.onBack),
      contents: Padding(
        // 웹 `px-7 py-8` = 좌우 20, 상하 24.
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s7,
          vertical: spacing.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _NoticeSection(),
            const SizedBox(height: StudentMyPageLeavePage.sectionGap),
            _AgreementSection(
              agreed: _agreed,
              onToggle: () => setState(() => _agreed = !_agreed),
              onDelete: _confirmAndDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `LeavePage.tsx:55~70`.
class _NoticeSection extends StatelessWidget {
  const _NoticeSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final bulletStyle = AppTypography.body3.copyWith(color: colors.gray700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('회원탈퇴 유의사항', style: AppTypography.title3),
        // 웹 `mt-3`(8)과 첫 `li`의 `mt-2`(6)가 **마진 병합**돼 8이 된다
        // (실측: 제목 아래 8px). 둘을 더해 14를 주면 웹보다 벌어진다.
        SizedBox(height: spacing.s3),
        for (final (index, notice)
            in StudentMyPageLeavePage.notices.indexed) ...<Widget>[
          // 줄 사이는 `mt-2` = 6.
          if (index > 0) SizedBox(height: spacing.s2),
          Text(notice, style: bulletStyle),
        ],
      ],
    );
  }
}

/// 웹 `LeavePage.tsx:71~113`.
class _AgreementSection extends StatelessWidget {
  const _AgreementSection({
    required this.agreed,
    required this.onToggle,
    required this.onDelete,
  });

  final bool agreed;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            // 웹 `label`은 flex 기본 정렬이라 20짜리 체크박스가 21짜리 문구의
            // **위에 맞는다**(실측: 둘의 y가 같다).
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCheckbox(checked: agreed),
              // 웹 `gap-3` = 8.
              SizedBox(width: spacing.s3),
              const Expanded(
                child: Text(
                  '위 내용을 모두 확인하였으며, 회원 탈퇴합니다.',
                  style: AppTypography.body2,
                ),
              ),
            ],
          ),
        ),
        // 웹 `space-y-8` = 24.
        SizedBox(height: spacing.s8),
        _DeleteButton(enabled: agreed, onPressed: onDelete),
      ],
    );
  }
}

/// 웹 `:80~82`의 `<span>` + 그 안의 체크 아이콘.
/// 웹 `DialogTrigger` (`:88~92`).
///
/// 웹 클래스에 `diabled:text-gray-400` 오타가 있지만(서베이 BUG-7) 뒤에
/// 올바른 `disabled:text-gray-400`이 함께 있어 결과는 같다.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final color = enabled ? colors.point : colors.gray300;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          vertical: StudentMyPageLeavePage.deleteButtonVerticalPadding,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          // 웹 `rounded-md` = 8. 다이얼로그의 탈퇴하기(12)와 다르다.
          borderRadius: BorderRadius.circular(radius.m),
        ),
        child: Text(
          '계정 삭제하기',
          // 웹은 이 버튼에 글꼴 클래스를 주지 않는다 — 상속값 16px / 24px /
          // 400이고, 그것이 곧 `BODY_1`이다(실측).
          style: AppTypography.body1.copyWith(
            color: enabled ? colors.point : colors.gray400,
          ),
        ),
      ),
    );
  }
}

/// 웹 `DialogContent` (`:93~111`).
///
/// `true`를 돌려주면 탈퇴를 진행한다. 취소·바깥 탭은 `null`이다.
class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: StudentMyPageLeavePage.dialogWidth,
        // 웹 `p-7` = 20.
        padding: EdgeInsets.all(spacing.s7),
        decoration: BoxDecoration(
          color: Colors.white,
          // 웹 `rounded-md` = 8.
          borderRadius: BorderRadius.circular(radius.m),
          border: Border.all(color: StudentMyPageLeavePage.dialogBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('정말로 탈퇴하시겠어요?', style: AppTypography.title1),
            // **20이다.** 웹 `DialogContent` base의 `gap-4`(10)와 본문의
            // `mt-4`(10)가 **함께** 걸린다 — `flex flex-col`로 덮어도 `gap`은
            // 그대로 살아 있다(실측: 19.99). 둘 중 하나만 옮기면 절반이 된다.
            SizedBox(height: spacing.s4 * 2),
            const Text(
              '건강해짐 계정을 삭제하면 회원님의 수강권, 운동기록, 식단 등 '
              '모든 정보가 함께 사라지게 됩니다.',
              style: AppTypography.body2,
            ),
            // 같은 이유로 `gap-4`(10) + `mt-8`(24) = 34다.
            SizedBox(height: spacing.s4 + spacing.s8),
            // **두 버튼의 높이를 맞춰야 한다.** 웹 버튼 행은 flex 기본
            // `align-items: stretch`라, 내용상 46인 `탈퇴하기`(14px 줄 높이
            // 20 + 패딩 26)가 `취소`(16px 줄 높이 24 + 패딩 26 = 50)에 맞춰
            // 늘어난다 — 실측 둘 다 50이다.
            //
            // 그 일을 하는 것이 `IntrinsicHeight`다. 높이 상한을 "가장 큰
            // 자식만큼"으로 묶어 주면 두 버튼의 `Container(alignment:)`가 그
            // 느슨한 상한을 꽉 채운다. 학생 홈 `_PointDetail`과 같은 해법이고,
            // 규율 #12(본문에는 높이 상한이 없다)를 피하는 방법이기도 하다.
            //
            // `CrossAxisAlignment.stretch`를 함께 줘 봤지만 **뮤테이션으로
            // 지워도 아무 테스트가 깨지지 않았다** — 위 경로로 이미 늘어나서
            // 하는 일이 없다. 죽은 코드라 두지 않는다.
            IntrinsicHeight(
              child: Row(
                children: [
                  // 웹 두 버튼의 폭은 129.67 / 140.33으로 다르다. 같은 폭으로
                  // 그리는 이유는 클래스 주석 참고.
                  const Expanded(child: _CancelButton()),
                  // 웹 `gap-3` = 8(커스텀 스케일. Tailwind 기본 12가 아니다).
                  SizedBox(width: spacing.s3),
                  const Expanded(child: _ConfirmButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `DialogClose` (`:100~102`).
class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          vertical: StudentMyPageLeavePage.dialogButtonVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: colors.gray100,
          borderRadius: BorderRadius.circular(radius.m),
        ),
        // 웹이 이 버튼에는 글꼴 클래스를 주지 않아 상속값 16 / 24 / 400이
        // 그대로 쓰인다(실측) — 옆의 탈퇴하기(14 / 20 / 500)와 **다르다.**
        child: Text(
          '취소',
          style: AppTypography.body1.copyWith(color: colors.gray600),
        ),
      ),
    );
  }
}

/// 웹 `<Button variant='destructive' size='full'>` (`:103~109`).
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(true),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        // 웹 `size='full'`의 `px-4`(10) + className `py-[13px]`.
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s4,
          vertical: StudentMyPageLeavePage.dialogButtonVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: StudentMyPageLeavePage.destructive,
          // 웹 `button.tsx` base의 `rounded-lg` = 12. **취소(8)와 다르다.**
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Text(
          '탈퇴하기',
          // 웹 `button.tsx` base의 `text-sm font-medium`. `/edit/password`의
          // 제출 버튼도 같은 스타일이라 `AppButton`으로 올렸다.
          style: AppButton.baseLabel.copyWith(
            color: StudentMyPageLeavePage.destructiveForeground,
          ),
        ),
      ),
    );
  }
}
