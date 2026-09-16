import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/trainer_info.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/TrainerInfoPage.tsx` 대응.
///
/// ## 요청 1건
///
/// 골든 `mypage-student-trainer-info`는
/// `GET /api/v1/members/trainer-mapping/info` 하나다.
///
/// **캡처 때 401 → `refresh-token` → 재시도가 찍혔지만 골든에 담지 않았다.**
/// 액세스 토큰이 만료돼 웹 인터셉터가 자동으로 갱신한 것이고, 화면이
/// 의도해서 보내는 요청이 아니다. 401 리프레시는 이 프로젝트의 Phase B
/// 항목이라 앱에는 아직 그 경로가 없다(`docs/deferred-minors.md`).
///
/// ## 매핑이 없으면 `data`가 null이다
///
/// 에러가 아니라 정상 응답이다(`MemberService.java`의 `.orElse(null)`).
/// 그래서 [TrainerInfo.fromJson]이 null을 돌려주고 화면이 빈 상태를 고른다.
///
/// ## 로딩 중에도 빈 상태가 보인다
///
/// 웹 `{!data && <NoTrainer />}` — `isLoading` 분기가 없어서 **조회 중에
/// "등록된 트레이너가 없습니다."가 먼저 깜빡였다가** 데이터가 오면 사라진다
/// (서베이 BUG-10). 그대로 옮겼다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageTrainerInfoPage extends StatefulWidget {
  const StudentMyPageTrainerInfoPage({
    required this.memberApi,
    required this.onBack,
    super.key,
  });

  /// 웹 `h-[80px] w-[80px]` — 프로필 원의 바깥 지름.
  ///
  /// 테두리 1px이 안쪽을 먹어 **그림이 그려지는 자리는 78**이다(실측:
  /// 아바타 `<svg>`가 78 × 80으로 잡힌다).
  static const double avatarSize = 80;

  /// 웹 빈 상태의 `py-28`.
  ///
  /// **커스텀 스페이싱 스케일은 12까지만 덮는다.** 28은 Tailwind 기본값이
  /// 그대로 남아 `7rem = 112px`다 — 커스텀 스케일로 착각하면 값이 없다.
  static const double emptyVerticalPadding = 112;

  /// 웹 `IconAlertCircle`(`alert_circle.svg`)의 고유 크기.
  static const double emptyIconWidth = 35;
  static const double emptyIconHeight = 36;

  final MemberApi memberApi;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageTrainerInfoPage> createState() =>
      _StudentMyPageTrainerInfoPageState();
}

class _StudentMyPageTrainerInfoPageState
    extends State<StudentMyPageTrainerInfoPage> {
  TrainerInfo? _trainer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trainer = await widget.memberApi.trainerMappingInfo();
      if (mounted) {
        setState(() => _trainer = trainer);
      }
    } catch (_) {
      // 웹 쿼리에 `isError` 분기가 없다. 실패하면 빈 상태가 그대로 남는다 —
      // **매핑이 없는 것과 구분되지 않는다.**
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = _trainer;

    return AppLayout(
      // 루트도 헤더도 셸 기본값(gray-100)이다. 웹 `<Layout>`과
      // `<Layout.Header>` 둘 다 배경 클래스가 없다 — 알림 화면(헤더만 흰색)과
      // 다른 점이다.
      header: AppLayoutHeader(onBack: widget.onBack),
      contents: trainer == null
          ? const _NoTrainer()
          : _TrainerDetail(trainer: trainer),
    );
  }
}

/// 웹 `NoTrainer` (`TrainerInfoPage.tsx:16~29`).
class _NoTrainer extends StatelessWidget {
  const _NoTrainer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: StudentMyPageTrainerInfoPage.emptyVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/alert_circle.svg',
            width: StudentMyPageTrainerInfoPage.emptyIconWidth,
            height: StudentMyPageTrainerInfoPage.emptyIconHeight,
          ),
          // 웹 `mb-5` = 12.
          SizedBox(height: spacing.s5),
          Text(
            '등록된 트레이너가 없습니다.',
            style: AppTypography.title1.copyWith(color: colors.gray700),
          ),
        ],
      ),
    );
  }
}

/// 웹 `:44~81`.
class _TrainerDetail extends StatelessWidget {
  const _TrainerDetail({required this.trainer});

  final TrainerInfo trainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Padding(
      // 웹 `px-7 py-6` = 좌우 20, 상하 16.
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s7,
        vertical: spacing.s6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // 웹 `pb-11` = 36.
            padding: EdgeInsets.only(bottom: spacing.s11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(fileUrl: trainer.profileFileUrl),
                // 웹 `mb-6` = 16(아바타 래퍼에 붙어 있다).
                SizedBox(height: spacing.s6),
                Text(
                  trainer.name,
                  // 웹 `text-black` — gray800(`#2E3134`)이 아니라 **순검정**이다.
                  style: AppTypography.heading2.copyWith(color: Colors.black),
                ),
                // 웹 `mb-[2px]`가 이름에 붙어 있다.
                const SizedBox(height: 2),
                Text(
                  '트레이너',
                  style: AppTypography.body3.copyWith(color: colors.gray600),
                ),
              ],
            ),
          ),
          Container(
            // 웹 `rounded-lg bg-white px-6 py-7` = 라운드 12, 좌우 16, 상하 20.
            padding: EdgeInsets.symmetric(
              horizontal: spacing.s6,
              vertical: spacing.s7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius.l),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoRow(label: '이메일', value: trainer.email),
                // 웹 `mb-6` = 16(첫 행에만 붙어 있다).
                SizedBox(height: spacing.s6),
                _InfoRow(label: '헬스장', value: trainer.gymName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 웹 `data.trainer.profile ? <Image /> : <IconAvatar />` (`:47~59`).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.fileUrl});

  final String? fileUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final url = fileUrl;

    Widget fallback() => SvgPicture.asset('assets/images/avatar.svg');

    return Container(
      width: StudentMyPageTrainerInfoPage.avatarSize,
      height: StudentMyPageTrainerInfoPage.avatarSize,
      // 웹 `overflow-hidden rounded-full border border-gray-300`.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.gray300),
      ),
      // 크기를 명시하지 않는다 — 테두리를 뺀 안쪽(78)을 그대로 채운다.
      // 웹도 같은 결과다(실측: `<svg>`가 78 × 80으로 잡히고 그림은 78).
      child: url == null
          ? fallback()
          : Image.network(
              // 웹 `?w=300&h=300&q=90`. **`info` 화면의 `&=q=90` 오타가
              // 여기엔 없다** — 같은 프로젝트 안에서 두 줄이 다르다.
              '$url?w=300&h=300&q=90',
              // 웹 `object-contain`. 허브·내 정보는 `object-cover`다.
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}

/// 웹 `<dl className='flex items-center justify-between'>`.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        Text(label, style: AppTypography.body2.copyWith(color: colors.gray600)),
        // 긴 이메일이 좁은 화면에서 넘치지 않게 한다. 웹은 flex 자식이라
        // 저절로 줄지만 Flutter `Row`의 `Text`는 `Flexible` 없이는 넘친다.
        Expanded(
          child: Text(
            value,
            // 웹 `text-black` — 순검정이다.
            style: AppTypography.title2.copyWith(color: Colors.black),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
