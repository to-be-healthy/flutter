import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/date/korean_date_format.dart';
import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/schedule/api/schedule_api.dart';
import '../../entity/schedule/model/last_reservation.dart';
import '../../feature/schedule/ui/reservation_card.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';
import '../../widget/app_month_picker.dart';

/// 웹 `page/manage/ui/TrainerStudentReservationPage.tsx`(126줄)
/// + `feature/schedule/ui/TrainerStudentReservationSchedule.tsx`
/// + `TrainerStudentLastReservationSchedule.tsx`.
///
/// `/trainer/manage/[memberId]/reservation` — "{name}님 예약 내역".
/// 치수는 2026-09-18 실측이다(`docs/trainer-manage-s5-measurements.md`, 440×900).
///
/// ## 요청 2건 — **탭과 무관하게 둘 다 나간다**
///
/// ```
/// 1. GET /api/v1/trainers/reservation/new?memberId={id}
/// 2. GET /api/v1/trainers/reservation/old?searchDate={YYYY-MM}&memberId={id}
/// ```
///
/// 훅이 페이지 컴포넌트에 있어 Radix Tabs가 비활성 탭을 언마운트해도 둘 다
/// 발사된다. **하단바가 없어**(`<Layout>`에 `type` 없음) S4처럼 네비가 쏘는
/// 요청도 붙지 않는다.
///
/// ## 노쇼 토글 — **동사가 직관과 반대다**
///
/// `DELETE /schedule/no-show/{id}`가 **노쇼 처리**, `POST`가 **해제**다
/// (서베이 §4.3⑱). 웹이 올바르게 쓰고 있고 여기서도 같다 —
/// [ScheduleApi.markNoShow] / [ScheduleApi.revertNoShow] 주석 참고.
///
/// ## 옮기는 웹 버그
///
/// - **제목이 통째로 사라진다.** 웹이 `{name && `${name}님 예약 내역`}`이라
///   쿼리 `name`이 없으면 `님 예약 내역`조차 렌더되지 않는다(실측: h2가 0×0).
/// - **활성 탭이 굵어지지 않는다.** `twSelector('data-[state=active]',
///   HEADING_5)`가 **런타임에** 클래스 문자열을 조립해서 Tailwind JIT이
///   스캔하지 못하고, 결국 `font-semibold`가 생성되지 않는다. 같은 버튼의
///   `data-[state=active]:bg-primary-500`은 소스에 리터럴로 적혀 있어 먹는다
///   (실측: 배경·글자색은 바뀌는데 굵기는 400 그대로). **두 탭 다 400으로
///   그린다.**
/// - **시트 두 버튼의 폭이 다르다**(201.23 / 190.77). S2 환불 시트와 같은
///   원인(한쪽에만 패딩이 있어 flex 분배가 어긋난다)이고 그대로 옮긴다.
class TrainerManageReservationPage extends StatefulWidget {
  const TrainerManageReservationPage({
    required this.scheduleApi,
    required this.memberId,
    required this.name,
    required this.onBack,
    this.initialMonth,
    super.key,
  });

  /// 웹 `Layout.Contents className='p-7'`.
  static const double contentPadding = 20;

  /// 탭 목록 아래 `mb-6`.
  static const double tabListBottomGap = 16;

  /// 탭 사이 `gap-4`(커스텀 스케일 4 = 10).
  static const double tabGap = 10;

  /// 탭 트리거 `px-5 py-[5px]` — 실측 높이 29.5.
  static const double tabHorizontalPadding = 12;
  static const double tabVerticalPadding = 5;

  /// `TabsContent`의 `mt-2`.
  static const double tabContentTopGap = 6;

  /// 카드 사이 `mb-5`.
  static const double cardGap = 12;

  /// 빈 상태 `py-28`(Tailwind 기본) + 아이콘 + `mb-5`(커스텀 12).
  static const double emptyVerticalPadding = 112;
  static const double emptyIconBoxWidth = 35;
  static const double emptyIconSize = 28;
  static const double emptyIconBottomGap = 12;

  /// 다가오는 예약 카드의 체크 아이콘 — 웹 `width={17} height={17}`.
  ///
  /// **미실측**: 두 회원 다 다가오는 예약이 0건이라 카드를 띄우지 못했다.
  /// 웹 소스(`TrainerStudentReservationSchedule.tsx:57`)에서 읽은 값이다.
  static const double checkIconSize = 17;

  final ScheduleApi scheduleApi;
  final Object memberId;

  /// 웹은 쿼리스트링에서만 읽는다(`searchParams.get('name')`). **이 화면은
  /// 이름을 요청하지 않는다** — S4가 `trainers/members`를 한 번 더 부르는 것과
  /// 다르다.
  final String name;

  /// 웹 `router.back()`.
  final VoidCallback onBack;

  /// `YYYY-MM`. 테스트가 골든의 `searchDate`를 고정하려고 넘긴다.
  final String? initialMonth;

  @override
  State<TrainerManageReservationPage> createState() =>
      _TrainerManageReservationPageState();
}

enum _Tab { upcoming, past }

class _TrainerManageReservationPageState
    extends State<TrainerManageReservationPage> {
  _Tab _tab = _Tab.upcoming;
  LastReservationList? _upcoming;
  LastReservationList? _past;
  late DateTime _month;
  bool _isPastPending = true;

  String get _searchDate => KoreanDateFormat.month(_month);

  @override
  void initState() {
    super.initState();
    _month = DateTime.tryParse('${widget.initialMonth}-01') ?? DateTime.now();
    _load();
  }

  /// **개시 순서만 골든이고 기다리는 것은 함께다**(학생 홈과 같은 판단).
  Future<void> _load() async {
    final upcoming = _loadUpcoming();
    final past = _loadPast();
    await Future.wait(<Future<void>>[upcoming, past]);
  }

  Future<void> _loadUpcoming() async {
    try {
      final list = await widget.scheduleApi.trainerStudentUpcoming(
        widget.memberId,
      );
      if (mounted) {
        setState(() => _upcoming = list);
      }
    } on Object {
      // 웹에 에러 분기가 없다 — `data`가 undefined로 남아 빈 상태가 된다.
      if (mounted) {
        setState(
          () => _upcoming = const LastReservationList(reservations: null),
        );
      }
    }
  }

  Future<void> _loadPast() async {
    setState(() => _isPastPending = true);
    try {
      final list = await widget.scheduleApi.trainerStudentPast(
        searchDate: _searchDate,
        memberId: widget.memberId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _past = list;
        _isPastPending = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _past = const LastReservationList(reservations: null);
        _isPastPending = false;
      });
    }
  }

  /// 웹은 월이 바뀌면 `old`만 다시 받는다(실측). `new`는 그대로다.
  void _onMonthChanged(DateTime month) {
    setState(() => _month = month);
    _loadPast();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      header: AppLayoutHeader(
        // 웹 `{name && `${name}님 예약 내역`}` — 이름이 없으면 제목이 통째로
        // 사라진다(실측: h2가 0×0). null을 넘겨 같은 결과를 만든다.
        title: widget.name.isEmpty ? null : '${widget.name}님 예약 내역',
        onBack: widget.onBack,
      ),
      contents: Padding(
        padding: const EdgeInsets.all(
          TrainerManageReservationPage.contentPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabBar(
              current: _tab,
              onSelect: (tab) => setState(() => _tab = tab),
            ),
            const SizedBox(
              height: TrainerManageReservationPage.tabContentTopGap,
            ),
            if (_tab == _Tab.upcoming)
              _UpcomingList(list: _upcoming)
            else
              _PastSection(
                list: _past,
                month: _month,
                isPending: _isPastPending,
                onMonthChanged: _onMonthChanged,
                onToggleNoShow: _toggleNoShow,
              ),
          ],
        ),
      ),
    );
  }

  /// 시트 좌측 버튼. **현재 출석이면 노쇼로 만들고(DELETE), 아니면 되돌린다(POST).**
  Future<void> _toggleNoShow(LastReservation reservation) async {
    final toast = AppToastScope.read(context);
    try {
      final message = reservation.isCompleted
          ? await widget.scheduleApi.markNoShow(reservation.scheduleId)
          : await widget.scheduleApi.revertNoShow(reservation.scheduleId);
      if (!mounted) {
        return;
      }
      // 웹 `successToast(data.message)` — 서버 문구를 그대로 띄운다.
      if (message != null && message.isNotEmpty) {
        toast.showSuccess(message);
      }
      // 웹 `refetchQueries(['TrainerStudentLastReservationList'])`.
      await _loadPast();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      toast.showError(serverMessage(error));
    }
  }
}

/// 웹 `TabsList` + 트리거 2개.
///
/// **활성 탭도 글꼴이 400이다** — 클래스 주석의 `twSelector` 버그 참고.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onSelect});

  static const Key upcomingKey = ValueKey(
    'TrainerManageReservationPage.tabUpcoming',
  );
  static const Key pastKey = ValueKey('TrainerManageReservationPage.tabPast');

  final _Tab current;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: TrainerManageReservationPage.tabListBottomGap,
      ),
      child: Row(
        children: [
          _TabButton(
            buttonKey: upcomingKey,
            label: '다가오는 예약',
            isActive: current == _Tab.upcoming,
            onTap: () => onSelect(_Tab.upcoming),
          ),
          const SizedBox(width: TrainerManageReservationPage.tabGap),
          _TabButton(
            buttonKey: pastKey,
            label: '지난 예약',
            isActive: current == _Tab.past,
            onTap: () => onSelect(_Tab.past),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.buttonKey,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      key: buttonKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TrainerManageReservationPage.tabHorizontalPadding,
          vertical: TrainerManageReservationPage.tabVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.primary500 : Colors.white,
          // 웹 `rounded-full`.
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          // 웹 `BODY_3`(13/150/**400**). 활성도 같다 — `twSelector`가 만든
          // `data-[state=active]:font-semibold`는 생성되지 않는다.
          style: AppTypography.body3.copyWith(
            color: isActive ? Colors.white : colors.gray500,
          ),
        ),
      ),
    );
  }
}

/// 다가오는 예약 탭.
class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.list});

  final LastReservationList? list;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final reservations = list?.reservations;

    if (reservations == null || reservations.isEmpty) {
      return const _EmptyState(message: '예약된 수업이 없습니다.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final reservation in reservations)
          Padding(
            padding: const EdgeInsets.only(
              bottom: TrainerManageReservationPage.cardGap,
            ),
            child: ReservationCard(
              reservation: reservation,
              // 웹 `<IconCheck fill='var(--primary-500)' width={17} height={17} />`.
              // **미실측 분기다**(다가오는 예약이 0건이었다).
              trailing: SvgPicture.asset(
                'assets/images/check.svg',
                width: TrainerManageReservationPage.checkIconSize,
                height: TrainerManageReservationPage.checkIconSize,
                theme: SvgTheme(currentColor: colors.primary500),
              ),
            ),
          ),
      ],
    );
  }
}

/// 지난 예약 탭 — 월 선택 + 목록.
class _PastSection extends StatelessWidget {
  const _PastSection({
    required this.list,
    required this.month,
    required this.isPending,
    required this.onMonthChanged,
    required this.onToggleNoShow,
  });

  /// 웹 로딩 자리 `h-[500px]`.
  static const double loadingHeight = 500;

  final LastReservationList? list;
  final DateTime month;
  final bool isPending;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<LastReservation> onToggleNoShow;

  @override
  Widget build(BuildContext context) {
    final reservations = list?.reservations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // **좌측 정렬이다**(실측) — S3 수강권 화면과 반대.
        Align(
          alignment: Alignment.centerLeft,
          child: AppMonthPicker(date: month, onChanged: onMonthChanged),
        ),
        if (isPending)
          const SizedBox(
            height: loadingHeight,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reservations == null || reservations.isEmpty)
          const _EmptyState(message: '완료한 수업이 없습니다.')
        else
          for (final reservation in reservations)
            Padding(
              padding: const EdgeInsets.only(
                bottom: TrainerManageReservationPage.cardGap,
              ),
              child: ReservationCard(
                reservation: reservation,
                trailing: ReservationStatusBadge(
                  isCompleted: reservation.isCompleted,
                ),
                onTap: () => _openSheet(context, reservation),
              ),
            ),
      ],
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    LastReservation reservation,
  ) async {
    final radius = Theme.of(context).extension<AppRadius>()!;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: AppMonthPicker.barrier,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.l)),
      ),
      constraints: const BoxConstraints(maxWidth: AppMonthPicker.sheetMaxWidth),
      builder: (context) => _LessonSheet(reservation: reservation),
    );
    if (confirmed == true) {
      onToggleNoShow(reservation);
    }
  }
}

/// 웹 `IconNoSchedule` 빈 상태.
///
/// **S3·S4의 빈 상태와 색·아이콘이 다르다** — 문구가 gray-400이고 아이콘은
/// `no_schedule.svg`(28×28)다.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TrainerManageReservationPage.emptyVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: TrainerManageReservationPage.emptyIconBoxWidth,
            child: SvgPicture.asset(
              'assets/images/no_schedule.svg',
              width: TrainerManageReservationPage.emptyIconSize,
              height: TrainerManageReservationPage.emptyIconSize,
            ),
          ),
          const SizedBox(
            height: TrainerManageReservationPage.emptyIconBottomGap,
          ),
          Text(
            message,
            // 웹 `TITLE_1_BOLD` + `text-gray-400`.
            style: AppTypography.title1.copyWith(color: colors.gray400),
          ),
        ],
      ),
    );
  }
}

/// 수업 정보 시트. **`true`를 돌려주면 노쇼 토글을 진행한다.**
///
/// 회원 지난 예약 화면의 시트와 **합치지 않았다** — 그쪽은 상단 패딩이 48이고
/// (`pt-[48px]`, 닫기 버튼이 위에 따로 있다) 버튼이 `확인` 하나다.
/// 여기는 `pt-7`(20)에 X가 제목 줄 오른쪽이고 버튼이 둘이다(실측).
class _LessonSheet extends StatelessWidget {
  const _LessonSheet({required this.reservation});

  static const Key toggleKey = ValueKey(
    'TrainerManageReservationPage.toggleNoShow',
  );
  static const Key confirmKey = ValueKey(
    'TrainerManageReservationPage.sheetConfirm',
  );
  static const Key closeKey = ValueKey(
    'TrainerManageReservationPage.sheetClose',
  );

  /// 웹 `pt-7 px-7 pb-9` — 실측 20 / 20 / 28.
  static const double horizontalPadding = 20;
  static const double topPadding = 20;
  static const double bottomPadding = 28;

  /// 제목 아래 `mb-8`.
  static const double titleBottomGap = 24;

  /// 본문 상자 `rounded-md bg-gray-100 p-6` — 실측 400 × 58, 패딩 16.
  static const double bodyPadding = 16;

  /// 본문 아래 `mb-11`.
  static const double bodyBottomGap = 36;

  /// 버튼 `h-12`, 사이 `gap-x-3`.
  static const double buttonHeight = 48;
  static const double buttonGap = 8;

  /// 닫기 X.
  static const double closeIconSize = 14;

  final LastReservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    final (start, period) = KoreanDateFormat.twelveHour(
      reservation.lessonStartTime,
    );
    final (end, _) = KoreanDateFormat.twelveHour(reservation.lessonEndTime);
    final day = KoreanDateFormat.lastReservationSheetDay(reservation.lessonDt);
    // 웹 `<span> 출석</span>` — **앞에 공백이 들어 있다**(실측).
    final status = reservation.isCompleted ? ' 출석' : ' 미출석';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          horizontalPadding,
          topPadding,
          horizontalPadding,
          bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '수업 정보',
                  // 웹 `HEADING_4_BOLD`(18/130/700).
                  style: AppTypography.heading4.copyWith(color: Colors.black),
                ),
                GestureDetector(
                  key: closeKey,
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(
                    'assets/images/close.svg',
                    width: closeIconSize,
                    height: closeIconSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: titleBottomGap),
            Container(
              padding: const EdgeInsets.all(bodyPadding),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.gray100,
                // 웹 `rounded-md`.
                borderRadius: BorderRadius.circular(radius.m),
              ),
              child: Text.rich(
                TextSpan(
                  text: '$day $period $start - $end',
                  children: [
                    TextSpan(
                      text: status,
                      style: TextStyle(
                        // 웹: 출석은 `text-black`, 미출석은 `text-point`.
                        color: reservation.isCompleted
                            ? Colors.black
                            : colors.point,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                // 웹 `HEADING_3`(20/130/700).
                style: AppTypography.heading3.copyWith(color: Colors.black),
              ),
            ),
            const SizedBox(height: bodyBottomGap),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    buttonKey: toggleKey,
                    // 현재 출석이면 "미출석"으로 만드는 버튼이다.
                    label: reservation.isCompleted ? '미출석' : '출석',
                    background: reservation.isCompleted
                        ? colors.gray100
                        : ReservationStatusBadge.attendedBackground,
                    foreground: reservation.isCompleted
                        ? colors.point
                        : colors.primary500,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: buttonGap),
                Expanded(
                  child: _SheetButton(
                    buttonKey: confirmKey,
                    label: '확인',
                    background: colors.primary500,
                    foreground: Colors.white,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.buttonKey,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = Theme.of(context).extension<AppRadius>()!;

    return GestureDetector(
      key: buttonKey,
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _LessonSheet.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          // 웹 `rounded-md`.
          borderRadius: BorderRadius.circular(radius.m),
        ),
        child: Text(
          label,
          // 웹 `TITLE_1_SEMIBOLD`(16/140/600).
          style: AppTypography.title1SemiBold.copyWith(color: foreground),
        ),
      ),
    );
  }
}
