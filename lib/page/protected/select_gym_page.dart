import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/server_message.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/ui/auth_scope.dart';
import '../../entity/gym/api/gym_api.dart';
import '../../entity/gym/model/gym.dart';
import '../../feature/gym/ui/gym_select_list.dart';
import '../../feature/gym/ui/gym_verification_code.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/SelectGymPage.tsx` 대응.
///
/// 로그인 직후 **헬스장을 아직 고르지 않은 계정**이 처음 보는 화면이다.
/// 라우터의 `isHome && gymId == null → /select-gym` 규칙이 여기로 보낸다.
///
/// 한 위젯 안의 **두 단계**다(웹도 `step` 상태 하나로 갈린다):
/// 1. 헬스장 목록에서 하나 고르기 — STUDENT는 여기서 끝난다
/// 2. 가입 코드 6자리 — **TRAINER만** 거친다
///
/// **패리티 범위:** 골든(`select-gym`)이 덮는 것은 1단계 진입 시의
/// `GET /api/v1/gyms` 하나뿐이다. 등록 `POST`는 그 계정의 소속 헬스장을
/// 실제로 바꾸는 공유 상태 뮤테이션이고 TRAINER 경로는 유효한 가입 코드가
/// 있어야 캡처되므로, **골든 대신 `select_gym_page_test.dart`의 계약
/// 테스트**가 요청 모양을 고정한다(근거: 웹 `entity/gym/api/mutations.ts` +
/// `openapi/api-docs.json`).
class SelectGymPage extends StatefulWidget {
  const SelectGymPage({required this.gymApi, super.key});

  final GymApi gymApi;

  /// 웹 step 1 `<Layout.Contents className='p-7 pt-[100px]'>`의 `pt-[100px]`.
  static const double step1TopPadding = 100;

  /// 웹 step 2 `<Layout.Contents className='p-7 pt-[60px]'>`의 `pt-[60px]`.
  static const double step2TopPadding = 60;

  /// 웹 step 1 제목의 `mb-[80px]`.
  static const double titleGap = 80;

  /// 웹 하단 버튼의 `h-[57px]`. 로그인 화면의 44px가 아니다.
  static const double submitButtonHeight = 57;

  /// 웹 `disabled={authValue.length < 6}`.
  static const int joinCodeLength = 6;

  @override
  State<SelectGymPage> createState() => _SelectGymPageState();
}

class _SelectGymPageState extends State<SelectGymPage> {
  List<Gym> _gyms = const <Gym>[];
  bool _isLoadingGyms = true;

  int? _selectedGymId;
  String _joinCode = '';
  bool _isVerifyingCode = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadGyms();
  }

  Future<void> _loadGyms() async {
    try {
      final gyms = await widget.gymApi.list();
      if (mounted) {
        setState(() {
          _gyms = gyms;
          _isLoadingGyms = false;
        });
      }
    } catch (_) {
      // 웹 `useGymListQuery`는 실패해도 토스트를 띄우지 않는다 —
      // `gymList?.map(...)`이 조용히 아무것도 그리지 않고, 사용자는 빈
      // 목록을 본다. 같은 동작을 옮긴다. 이 화면에서 벗어날 길이 없다는
      // 것은 웹에서 이미 그런 상태이고, 되살릴 방법(재시도 버튼)을 여기서
      // 발명하면 웹에 없는 화면이 된다.
      if (mounted) {
        setState(() => _isLoadingGyms = false);
      }
    }
  }

  /// 웹 `clickNext`: `setStep(prev + 1)` **그리고** `setAuthValue('')`.
  void _goToVerification() {
    setState(() {
      _isVerifyingCode = true;
      _joinCode = '';
    });
  }

  /// 웹 `clickBack`: `setStep(prev - 1)`뿐이다.
  ///
  /// **`setSelectGymId(null)`이 없다** — `clickNext`가 코드를 지우는 것과
  /// 비대칭이고, 그래서 돌아오면 고른 헬스장이 그대로 남아 다음 버튼이
  /// 활성 상태다. 여기서 선택까지 지우면 웹과 다른 화면이 된다.
  void _goBackToList() {
    setState(() => _isVerifyingCode = false);
  }

  Future<void> _register({required bool isTrainer}) async {
    final gymId = _selectedGymId;
    if (gymId == null || _isSubmitting) {
      return;
    }

    // **`await` 앞에서 잡는다.** 뒤에서 `read(context)`를 부르면 그 사이
    // 화면이 버려졌을 때 죽은 컨텍스트를 조회한다(`app_toast.dart`).
    final auth = AuthScope.read(context);
    final toast = AppToastScope.read(context);
    setState(() => _isSubmitting = true);

    try {
      await widget.gymApi.registerGym(
        gymId: gymId,
        // 웹 `payload = memberType === 'TRAINER' ? { joinCode } : undefined`.
        joinCode: isTrainer ? _joinCode : null,
      );

      // **순서가 강제된다.** 프로필 저장이 끝난 뒤에 이동해야 한다 —
      // 먼저 이동하면 `gymId == null`인 채 홈에 들어가 라우터의
      // `isHome && gymId == null` 규칙에 다시 `/select-gym`으로 튕긴다.
      await auth.setGymId(gymId);

      if (!mounted) {
        return;
      }
      // **명시적 이동이 필요하다.** `setGymId`의 알림만으로는 화면이 넘어가지
      // 않는다 — 라우터의 리다이렉트를 `/select-gym` 위치에서 돌리면 어느
      // 규칙에도 걸리지 않아 `null`(현재 위치 유지)을 반환한다. 웹도
      // `router.push(...)`로 직접 이동한다.
      context.go(
        isTrainer
            // 웹 TRAINER 분기는 `/trainer`가 아니라 수업시간 설정으로 간다.
            ? AppRoutes.trainerClassTimeSetting
            : AppRoutes.studentHome,
      );
      return;
    } catch (error) {
      // 웹 `onError: (error) => errorToast(error?.response?.data.message)`.
      toast.showError(serverMessage(error));
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    // 웹 `auth.memberType === 'TRAINER'` 분기. 라우터가 미로그인 접근을
    // 막으므로 여기서 user는 null이 아니다.
    final isTrainer = AuthScope.of(context).user!.memberType == 'TRAINER';

    return AppLayout(
      // 웹 `<Layout className='bg-white'>`.
      backgroundColor: Colors.white,
      // 웹 step 1에는 헤더가 없고, step 2에만 뒤로가기 하나짜리 헤더가 있다.
      header: _isVerifyingCode ? AppLayoutHeader(onBack: _goBackToList) : null,
      contents: Padding(
        // 웹 `p-7`(사방 20px)에 `pt-[...]`가 위쪽만 덮는다.
        padding: EdgeInsets.fromLTRB(
          spacing.s7,
          _isVerifyingCode
              ? SelectGymPage.step2TopPadding
              : SelectGymPage.step1TopPadding,
          spacing.s7,
          spacing.s7,
        ),
        child: _isVerifyingCode
            ? GymVerificationCode(
                value: _joinCode,
                onChanged: (value) => setState(() => _joinCode = value),
              )
            : _GymStep(
                isTrainer: isTrainer,
                isLoading: _isLoadingGyms,
                gyms: _gyms,
                selectedGymId: _selectedGymId,
                onSelected: (gymId) => setState(() => _selectedGymId = gymId),
              ),
      ),
      bottomArea: AppButton(
        label: _isVerifyingCode ? '완료' : '다음',
        // 웹 `h-[57px]` + `Typography.TITLE_1_BOLD`. 로그인 화면의
        // 44px/semibold와 다르다.
        height: SelectGymPage.submitButtonHeight,
        labelStyle: AppTypography.title1,
        isLoading: _isSubmitting,
        onPressed: _isVerifyingCode
            // 웹 `disabled={authValue.length < 6}`.
            ? (_joinCode.length >= SelectGymPage.joinCodeLength
                  ? () => _register(isTrainer: true)
                  : null)
            // 웹 `disabled={!selectGymId}`. 고른 뒤 눌렀을 때 STUDENT는
            // 곧바로 등록하고, TRAINER는 인증 코드 단계로 간다.
            : (_selectedGymId == null
                  ? null
                  : (isTrainer
                        ? _goToVerification
                        : () => _register(isTrainer: false))),
      ),
    );
  }
}

/// step 1의 본문: 제목 + 목록(또는 로딩).
class _GymStep extends StatelessWidget {
  const _GymStep({
    required this.isTrainer,
    required this.isLoading,
    required this.gyms,
    required this.selectedGymId,
    required this.onSelected,
  });

  /// 웹 로딩 자리의 `py-[200px]`.
  static const double loadingGap = 200;

  final bool isTrainer;
  final bool isLoading;
  final List<Gym> gyms;
  final int? selectedGymId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // 웹: `{auth.memberType === 'TRAINER' ? '수업하시는' : '다니시는'}
          // 헬스장을<br />선택해주세요.`
          '${isTrainer ? '수업하시는' : '다니시는'} 헬스장을\n선택해주세요.',
          textAlign: TextAlign.center,
          style: AppTypography.heading1,
        ),
        const SizedBox(height: SelectGymPage.titleGap),
        if (isLoading)
          // 웹은 `/images/loading.gif`(20×20)를 `py-[200px]` 안에 가운데
          // 정렬한다.
          //
          // **명시적 이탈:** 그 gif 자산을 가져오지 않았다. 애니메이션
          // 자산은 `assets_test.dart`의 목록 관리를 늘리는데 정작 움직임
          // 자체를 검증할 수단이 없다 — 위젯 테스트의 "파싱됨"은 "보인다"가
          // 아니다(`next-steps.md` §7-8). Material 인디케이터로 대체한다.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: loadingGap),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          GymSelectList(
            gyms: gyms,
            selectedGymId: selectedGymId,
            onSelected: onSelected,
          ),
      ],
    );
  }
}
