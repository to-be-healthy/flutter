import 'package:flutter/material.dart';

import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/member_info.dart';
import '../../shared/ui/app_switch.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/EditAlarmPage.tsx` 대응.
///
/// ## 요청 1건, 토글마다 2건
///
/// 골든 `mypage-student-alarm`은 `GET /api/v1/members/me` 하나다.
/// 스위치를 누르면 `PATCH /api/v1/members/alarm/{type}/{status}` 뒤에
/// **`members/me`를 다시 부른다** — 웹이 `refetchQueries(['myinfo'])`로
/// 하는 일이고, 여기서는 화면 자신이 그 값을 쓰므로 **반드시 옮겨야 한다**
/// (`/edit/name`은 이동해 버려서 옮기지 않았다).
///
/// 즉 **화면은 낙관적으로 갱신하지 않는다.** 서버가 응답하고 재조회가
/// 끝나야 스위치가 움직인다. 웹도 같다.
///
/// ## 헤더에 제목이 없다
///
/// 제목 "알림 설정"은 헤더가 아니라 **본문 첫 블록**이다(`<h1>`, 흰 배경).
/// 헤더는 뒤로가기만 있는 흰 바다. 루트는 gray-100이라
/// `AppLayoutHeader.backgroundColor`로 헤더만 희게 한다(허브와 같은 구조).
///
/// ## 웹 버그 셋을 그대로 옮겼다
///
/// 1. **커뮤니티 스위치를 `scheduleNoticeStatus`로 게이팅한다**(서베이 BUG-1).
///    값이 비면 커뮤니티 스위치만 사라지고 나머지 둘은 남는다.
/// 2. **`SCHEDULENOTICE` 토글 UI가 없다**(BUG-2). 타입 유니온과 백엔드에는
///    있는데 화면에 자리가 없다 — 위 게이팅에만 쓰인다.
/// 3. **로딩·에러 분기가 없다**(BUG-3). 조회 전에는 **라벨만 보이고 스위치
///    셋이 전부 없다.** 스켈레톤도 스피너도 없다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageAlarmPage extends StatefulWidget {
  const StudentMyPageAlarmPage({
    required this.memberApi,
    required this.onBack,
    super.key,
  });

  /// 웹 `py-[18px]` — 첫 행(앱 푸쉬 알림)의 상하 패딩.
  ///
  /// 스위치 높이 28과 합쳐 **행 높이 64**가 된다(실측). 글자(24)가 아니라
  /// **스위치가 행 높이를 정한다.**
  static const double firstRowVerticalPadding = 18;

  final MemberApi memberApi;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageAlarmPage> createState() => _StudentMyPageAlarmPageState();
}

class _StudentMyPageAlarmPageState extends State<StudentMyPageAlarmPage> {
  MemberInfo? _me;

  /// 토글이 날아가는 중인지. 웹에는 없는 가드다 — 앞의 화면들과 같은
  /// 이유로 넣었다(`docs/deferred-minors.md`).
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.memberApi.me();
      if (mounted) {
        setState(() => _me = me);
      }
    } catch (_) {
      // 웹 `useMyInfoQuery`에 `isError` 분기가 없다. 실패하면 라벨만 남고
      // 스위치가 하나도 안 보인다 — **로딩 중과 구분되지 않는다.**
    }
  }

  Future<void> _toggle(String type, bool enabled) async {
    if (_isToggling) {
      return;
    }
    setState(() => _isToggling = true);

    try {
      await widget.memberApi.toggleAlarm(type: type, enabled: enabled);
    } catch (error) {
      if (mounted) {
        setState(() => _isToggling = false);
        AppToastScope.read(context).showError(serverMessage(error));
      }
      return;
    }

    // 웹 `await queryClient.refetchQueries({ queryKey: ['myinfo'] })`.
    // **이 재조회가 스위치를 움직인다** — 낙관적 갱신이 없다.
    await _loadMe();
    if (mounted) {
      setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final me = _me;

    return AppLayout(
      // 루트는 gray-100(셸 기본값)이고 헤더만 희다.
      header: AppLayoutHeader(
        backgroundColor: Colors.white,
        onBack: widget.onBack,
      ),
      contents: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 웹 `<h1 className='bg-white px-7 pb-7 pt-8'>` — 헤더가 아니라
          // 본문 첫 블록이다. 높이 70(24 + 26 + 20).
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              spacing.s7,
              spacing.s8,
              spacing.s7,
              spacing.s7,
            ),
            child: const Text('알림 설정', style: AppTypography.heading3),
          ),
          _AlarmRow(
            label: '앱 푸쉬 알림',
            // 웹 `{data?.pushAlarmStatus && <Switch .../>}`.
            gate: me?.pushAlarmStatus,
            isOn: me?.pushAlarmStatus == MemberInfo.alarmEnabled,
            verticalPadding: StudentMyPageAlarmPage.firstRowVerticalPadding,
            onChanged: (value) => _toggle('PUSH', value),
          ),
          // 웹 `mt-3` = 8. **회색 틈이 구분선 역할을 한다** — 이 화면에
          // 구분선 요소는 없다. 아래 두 행 사이에는 틈이 없다.
          SizedBox(height: spacing.s3),
          _AlarmRow(
            label: '커뮤니티',
            description: '내 글에 댓글, 좋아요',
            // **`communityAlarmStatus`가 아니라 `scheduleNoticeStatus`다**
            // (서베이 BUG-1). 웹 오타를 그대로 옮겼다 — 값이 비면 이 스위치만
            // 사라진다.
            gate: me?.scheduleNoticeStatus,
            isOn: me?.communityAlarmStatus == MemberInfo.alarmEnabled,
            verticalPadding: spacing.s6,
            onChanged: (value) => _toggle('COMMUNITY', value),
          ),
          _AlarmRow(
            label: '피드백',
            description: '수업 일지, 식단 피드백 작성 알림',
            gate: me?.feedbackAlarmStatus,
            isOn: me?.feedbackAlarmStatus == MemberInfo.alarmEnabled,
            verticalPadding: spacing.s6,
            onChanged: (value) => _toggle('FEEDBACK', value),
          ),
        ],
      ),
    );
  }
}

/// 웹 `<section className='flex items-center justify-between bg-white px-7 ...'>`.
class _AlarmRow extends StatelessWidget {
  const _AlarmRow({
    required this.label,
    required this.gate,
    required this.isOn,
    required this.verticalPadding,
    required this.onChanged,
    this.description,
  });

  final String label;

  /// 부제. 첫 행(앱 푸쉬 알림)에는 없다.
  final String? description;

  /// 웹 `{data?.xxxStatus && ...}`의 그 값.
  ///
  /// **null이거나 비어 있으면 스위치를 그리지 않는다.** 라벨은 그대로
  /// 남는다 — 조회 전 화면이 그 모습이다.
  final String? gate;

  final bool isOn;
  final double verticalPadding;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final currentDescription = description;
    final hasSwitch = gate != null && gate!.isNotEmpty;

    return Container(
      color: Colors.white,
      // 웹 `px-7` = 20. 상하는 행마다 다르다(18 / 16).
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s7,
        vertical: verticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTypography.body1),
                if (currentDescription != null)
                  Text(
                    currentDescription,
                    style: AppTypography.body2.copyWith(color: colors.gray600),
                  ),
              ],
            ),
          ),
          if (hasSwitch) AppSwitch(value: isOn, onChanged: onChanged),
        ],
      ),
    );
  }
}
