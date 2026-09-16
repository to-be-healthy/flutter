import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 웹 `src/shared/ui/toast/*` + `app/_providers/ToastProvider.tsx` 대응.
///
/// **왜 화면이 아니라 앱 루트가 토스트를 소유하는가.**
/// 웹의 `useToast()`는 React context가 아니라 **모듈 전역 스토어**다
/// (`use-toast.tsx`의 `memoryState`/`listeners`/`dispatch`). 그래서
/// `errorToast(...)`를 부른 컴포넌트가 이미 언마운트됐어도 토스트가 뜬다.
/// Flutter에서 같은 성질을 얻으려면 토스트 상태가 **화면보다 오래 사는
/// 객체**에 있어야 한다 — 여기서는 `GeonganghaejimApp`이 만들어
/// `MaterialApp.router`의 `builder`에 꽂는 [AppToastController]다.
///
/// **호출 규약: `await` 앞에서 잡아라.**
/// ```dart
/// final toast = AppToastScope.read(context);   // await 앞
/// try {
///   await api.something();
/// } catch (e) {
///   toast.showError(message);                  // await 뒤에도 안전
/// }
/// ```
/// `await` 뒤에 `AppToastScope.read(context)`를 부르면 그 사이에 화면이
/// 버려졌을 때 죽은 `BuildContext`를 조회하게 된다. 컨트롤러 **참조**를
/// 먼저 잡아두면 화면의 생사와 무관해진다 — 웹 전역 스토어와 같은 성질이다.
/// `test/shared/app_toast_test.dart`가 "화면이 사라진 뒤에 부른 토스트도
/// 뜬다"로 이 성질을 고정한다.
///
/// **성공 토스트는 2026-09-16에 추가했다** — `/trainer/manage/[memberId]`의
/// 환불 회원 삭제가 첫 사용처다(웹 `successToast(message)`).
///
/// 다만 **그 렌더를 보지 못했다.** 이 토스트는 되돌릴 수 없는 삭제가
/// 성공한 뒤에만 뜨고, 공유 체험 계정에서 그것을 실행할 수 없다. 그래서
/// 이 파일이 원래 요구하던 "쓰는 화면의 렌더를 보고 추가한다"를 만족시킬
/// 길이 없었다 — 웹 소스의 클래스에서 옮겼고, 에러 토스트와 **아이콘만
/// 다르다**(`check.svg` + `fill='var(--primary-500)'` vs `error.svg`).
/// 껍데기·간격·글꼴·불투명도는 같은 `toast()` 호출이라 공유한다.
/// `deferred-minors.md`에 디자인 검수 항목으로 남겼다.
class AppToastController extends ChangeNotifier {
  /// 웹 `use-toast.tsx`의 `TOAST_DURATION = 2000`.
  static const Duration visibleDuration = Duration(milliseconds: 2000);

  /// 웹 `errorToast`의 `message ?? '문제가 발생했습니다.'`.
  static const String defaultErrorText = '문제가 발생했습니다.';

  AppToastMessage? _current;
  Timer? _timer;
  int _nextId = 0;

  /// 지금 떠 있는 토스트. 없으면 null.
  ///
  /// 웹 `TOAST_LIMIT = 1`이라 동시에 하나뿐이고, 새 토스트가 이전 것을
  /// 밀어낸다(`[action.toast, ...state.toasts].slice(0, 1)`).
  AppToastMessage? get current => _current;

  void showError(String? text) {
    _show(
      (text == null || text.isEmpty) ? defaultErrorText : text,
      AppToastVariant.error,
    );
  }

  /// 웹 `successToast(message)`.
  ///
  /// **에러와 달리 폴백 문구가 없다.** 웹도 `message: string`을 필수로
  /// 받는다 — 부를 쪽이 서버 응답의 `message`를 그대로 넘긴다.
  void showSuccess(String text) => _show(text, AppToastVariant.success);

  void _show(String text, AppToastVariant variant) {
    _timer?.cancel();
    _current = AppToastMessage(
      // id는 [AnimatedSwitcher]가 "같은 자리의 다른 토스트"를 구분하는
      // 근거다. 문구가 같은 에러가 연달아 나도 전환이 다시 재생된다.
      id: _nextId++,
      text: text,
      variant: variant,
    );
    _timer = Timer(visibleDuration, dismiss);
    notifyListeners();
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_current == null) {
      return;
    }
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // 타이머를 남기면 dispose된 notifier에 `notifyListeners()`가 날아온다.
    _timer?.cancel();
    super.dispose();
  }
}

/// 웹 훅의 두 진입점(`errorToast` / `successToast`).
enum AppToastVariant { error, success }

@immutable
class AppToastMessage {
  const AppToastMessage({
    required this.id,
    required this.text,
    this.variant = AppToastVariant.error,
  });

  final int id;
  final String text;
  final AppToastVariant variant;
}

/// [AppToastController]를 위젯 트리에 흘린다. [AuthScope]와 같은 구조다.
class AppToastScope extends InheritedNotifier<AppToastController> {
  const AppToastScope({
    required AppToastController super.notifier,
    required super.child,
    super.key,
  });

  /// 구독한다. 토스트가 바뀌면 호출한 위젯이 다시 빌드된다 — [AppToastHost]만 쓴다.
  static AppToastController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppToastScope>();
    assert(scope != null, 'AppToastScope가 위에 없다');
    return scope!.notifier!;
  }

  /// 구독하지 않고 읽는다. **화면은 이쪽만 쓴다** — 토스트를 띄우는 화면이
  /// 토스트 상태 변화로 리빌드될 이유가 없다.
  static AppToastController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppToastScope>();
    assert(scope != null, 'AppToastScope가 위에 없다');
    return scope!.notifier!;
  }
}

/// 웹 `ToastViewport` + `Toast` 대응. 자식 위에 토스트를 겹쳐 그린다.
class AppToastHost extends StatelessWidget {
  const AppToastHost({required this.child, super.key});

  final Widget child;

  /// 웹 아이콘 래퍼의 `h-8 w-8` — 커스텀 스케일에서 8 = 24px이다
  /// (Tailwind 기본 32px이 아니다). `error.svg`의 고유 크기와도 같다.
  static const double iconSize = 24;

  /// 웹 `ToastDescription`의 `opacity-90`. 안쪽 `<p>`가 `text-white`로
  /// 색을 덮어도 이 불투명도는 부모에 걸려 있어 그대로 적용된다 —
  /// 아이콘까지 함께 90%가 된다.
  static const double contentOpacity = 0.9;

  /// 웹은 `data-[state=open]:slide-in-from-top-full`로 위에서 내려온다.
  /// Radix 기본 전환 길이에 맞춘 값이고 디자인 토큰이 아니다.
  static const Duration transitionDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final message = AppToastScope.of(context).current;

    return Stack(
      children: [
        child,
        // 웹 `ToastViewport`는 `fixed left-1/2 top-0 ... p-4`(= 10px,
        // 커스텀 스케일). 네이티브에서는 상태바를 피해야 하므로 SafeArea를
        // 한 겹 더 쓴다.
        //
        // `IgnorePointer`가 필수다. 이 영역은 토스트가 없을 때도 헤더 위를
        // 덮고 있어서, 그대로 두면 화면 상단의 닫기·뒤로가기 버튼이
        // 눌리지 않는다. 웹도 뷰포트 자체는 포인터를 받지 않고 토스트 본체만
        // `pointer-events-auto`다.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(spacing.s4),
                child: AnimatedSwitcher(
                  duration: transitionDuration,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: message == null
                      ? const SizedBox.shrink()
                      : _Toast(
                          key: ValueKey<int>(message.id),
                          text: message.text,
                          variant: message.variant,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text, required this.variant, super.key});

  final String text;
  final AppToastVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      width: double.infinity,
      // 웹 `p-6 pr-8` — 사방 16px, 오른쪽만 24px.
      padding: EdgeInsets.fromLTRB(
        spacing.s6,
        spacing.s6,
        spacing.s8,
        spacing.s6,
      ),
      decoration: BoxDecoration(
        // 웹 toast variant `default`: `border-none rounded-lg bg-gray-700`.
        color: colors.gray700,
        borderRadius: BorderRadius.circular(radius.l),
        // 웹 `shadow-lg` = Tailwind 기본 정의
        // `0 10px 15px -3px rgb(0 0 0 / .1), 0 4px 6px -4px rgb(0 0 0 / .1)`.
        // CSS blur-radius와 Flutter blurRadius의 환산이 정확히 1:1은
        // 아니므로 근사값이다 — 디자인 토큰이 아니라 그림자 정의다.
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 10),
            blurRadius: 15,
            spreadRadius: -3,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 4),
            blurRadius: 6,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Opacity(
        opacity: AppToastHost.contentOpacity,
        child: Row(
          children: [
            if (variant == AppToastVariant.error)
              SvgPicture.asset(
                // 웹 `IconError`(`error.svg`). 색을 덮지 않는다 — 자산이
                // 호박색 원(#FFB950) + gray700 느낌표로 고정돼 있고 웹도
                // `fill` 오버라이드 없이 그대로 쓴다(`successToast`만 덮는다).
                'assets/images/error.svg',
                width: AppToastHost.iconSize,
                height: AppToastHost.iconSize,
              )
            else
              SvgPicture.asset(
                // 웹 `<IconCheck fill={'var(--primary-500)'} />`.
                // `check.svg`는 첫 `<path>`가 `fill="current"`라 정규화해
                // 두었다(규율 #13) — 색을 주지 않으면 도형이 사라진다.
                'assets/images/check.svg',
                width: AppToastHost.iconSize,
                height: AppToastHost.iconSize,
                theme: SvgTheme(currentColor: colors.primary500),
              ),
            // 웹 `<p className='ml-6 ...'>` = 16px.
            SizedBox(width: spacing.s6),
            Expanded(
              child: Text(
                text,
                // 웹 `Typography.HEADING_5`(13px/150% semibold) + `text-white`.
                //
                // 예외(토큰화하지 않는 리터럴): `Colors.white`는 `AppColors`에
                // 대응 토큰이 없는 프레임워크 상수다(`AppButton`과 같은 예외).
                style: AppTypography.heading5.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
