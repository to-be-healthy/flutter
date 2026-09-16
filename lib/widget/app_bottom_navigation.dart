import 'dart:async';

import 'package:flutter/material.dart';

import 'app_navigation_bar.dart';

/// 웹 `src/widget/navigation.tsx`의 `StudentNavigation` 대응.
///
/// **이 위젯이 회원 홈 골든의 요청 하나를 책임진다.** 웹
/// `useCheckTrainerMemberMappingQuery`에 `enabled` 옵션이 없어서, 네비가
/// 마운트되는 순간 `GET /api/v1/members/trainer-mapping`이 자동으로 나간다 —
/// 홈 화면이 부르는 요청이 아니라 **네비가 부르는 요청**이고, 골든
/// `home-student`의 3건 중 첫 번째다. 네비를 빼면 요청이 2건이 되어
/// `expectParity`가 개수 불일치로 떨어진다.
///
/// 트레이너 쪽([AppTrainerBottomNavigation])은 이 성질이 **없다** — 훅이
/// 하나도 없어 요청을 쏘지 않는다. 그래서 골든 `home-trainer`의 3건은 전부
/// 페이지가 쏜다.
class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    required this.currentLocation,
    required this.loadTrainerMapping,
    required this.onSelect,
    required this.onScheduleBlocked,
    super.key,
  });

  /// 웹 탭 라벨. 활성 판정은 `pathname === <route>` 완전 일치다.
  static const List<AppNavigationTab> tabs = <AppNavigationTab>[
    AppNavigationTab(label: '홈', route: '/student', icon: 'home'),
    AppNavigationTab(
      label: '수업예약',
      route: '/student/schedule',
      icon: 'calendar',
    ),
    AppNavigationTab(
      label: '커뮤니티',
      route: '/student/community',
      icon: 'community',
    ),
    AppNavigationTab(label: '마이', route: '/student/mypage', icon: 'profile'),
  ];

  /// 웹 `errorToast('트레이너가 지정된 후에 예약 가능합니다')`. 문구가 두
  /// 실패 경로(매핑 없음 · 요청 실패)에서 **같다.**
  static const String scheduleBlockedMessage = '트레이너가 지정된 후에 예약 가능합니다';

  /// 활성 탭 판정용 현재 경로.
  final String currentLocation;

  /// `GET /api/v1/members/trainer-mapping`. 마운트 시 한 번, 수업예약 탭을
  /// 누를 때 한 번 더 부른다(웹 `staleTime: 0`이라 탭마다 새로 나간다).
  final Future<bool> Function() loadTrainerMapping;

  /// 탭 이동. 수업예약은 가드를 통과한 뒤에만 불린다.
  final ValueChanged<String> onSelect;

  /// 수업예약이 막혔을 때. 웹은 `errorToast`를 띄운다.
  final VoidCallback onScheduleBlocked;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // 마운트 시 자동 실행. 웹 `useCheckTrainerMemberMappingQuery`에 `enabled`가
    // 없는 것과 같다. **결과를 쓰지 않는다** — 웹도 마운트 시점의 결과는
    // 버리고 탭을 누를 때 `refetch()`한 값으로 판단한다. 요청 자체가 계약이다.
    //
    // 실패도 삼킨다. 웹 react-query는 이 쿼리의 에러를 화면에 드러내지 않고,
    // 여기서 흘리면 **화면과 무관한 미처리 예외**로 테스트가 깨진다.
    unawaited(widget.loadTrainerMapping().catchError((Object _) => false));
  }

  /// 웹 `clickCheckMappedTrainer`.
  ///
  /// 성공이든 실패든 **같은 토스트**다. `mapped`가 false인 것과 요청이 던진
  /// 것을 구별하지 않는 것이 웹 동작이다.
  Future<void> _openSchedule() async {
    if (_isChecking) {
      return;
    }
    setState(() => _isChecking = true);
    try {
      final mapped = await widget.loadTrainerMapping();
      if (!mounted) {
        return;
      }
      if (mapped) {
        widget.onSelect('/student/schedule');
      } else {
        widget.onScheduleBlocked();
      }
    } catch (_) {
      if (mounted) {
        widget.onScheduleBlocked();
      }
    }
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationBar(
      items: [
        for (final tab in AppBottomNavigation.tabs)
          AppNavigationItem.uniform(
            tab: tab,
            isActive: widget.currentLocation == tab.route,
            onTap: tab.route == '/student/schedule'
                // 웹만 이 탭이 `<Link>`가 아니라 `<Button onClick>`이다.
                ? _openSchedule
                : () => widget.onSelect(tab.route),
          ),
      ],
    );
  }
}

/// 웹 `src/widget/navigation.tsx`의 `TrainerNavigation` 대응.
///
/// 학생 네비와 다른 점 셋:
/// 1. **가드가 없다.** 탭 넷이 전부 `<Link>`이고 react-query 훅이 하나도
///    없어 **요청을 쏘지 않는다.**
/// 2. 탭 2가 "수업예약"이 아니라 **"스케줄"**이고 바로 이동한다.
/// 3. 홈 탭의 **아이콘과 라벨 활성 조건이 갈린다** — 아이콘은
///    `/trainer || /trainer/manage`, 라벨은 `/trainer`만(웹 L33 vs L41).
///    `/trainer/manage`에서 아이콘은 켜지고 라벨은 꺼진다. 실측이고
///    그대로 옮긴다.
class AppTrainerBottomNavigation extends StatelessWidget {
  const AppTrainerBottomNavigation({
    required this.currentLocation,
    required this.onSelect,
    super.key,
  });

  static const String homeRoute = '/trainer';

  /// 홈 탭 **아이콘만** 함께 활성으로 치는 경로(웹 L33).
  static const String manageRoute = '/trainer/manage';

  static const List<AppNavigationTab> tabs = <AppNavigationTab>[
    AppNavigationTab(label: '홈', route: homeRoute, icon: 'home'),
    AppNavigationTab(
      label: '스케줄',
      route: '/trainer/schedule',
      icon: 'calendar',
    ),
    AppNavigationTab(
      label: '커뮤니티',
      route: '/trainer/community',
      icon: 'community',
    ),
    AppNavigationTab(label: '마이', route: '/trainer/mypage', icon: 'profile'),
  ];

  final String currentLocation;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppNavigationBar(
      items: [
        for (final tab in tabs)
          AppNavigationItem(
            tab: tab,
            isIconActive: tab.route == homeRoute
                // 웹 L33: `pathname === '/trainer' || pathname === '/trainer/manage'`.
                ? (currentLocation == homeRoute ||
                      currentLocation == manageRoute)
                : currentLocation == tab.route,
            // 웹 L41: 라벨은 `pathname === '/trainer'`만 본다.
            isLabelActive: currentLocation == tab.route,
            onTap: () => onSelect(tab.route),
          ),
      ],
    );
  }
}
