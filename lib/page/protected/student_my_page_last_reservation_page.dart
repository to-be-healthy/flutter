import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/date/korean_date_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/schedule/api/schedule_api.dart';
import '../../entity/schedule/model/last_reservation.dart';
import '../../widget/app_layout.dart';
import '../../widget/app_month_picker.dart';

/// 웹 `src/page/mypage/ui/StudentLastReservationPage.tsx` 대응.
///
/// ## 요청 1건, 달을 바꿀 때마다 한 건 더
///
/// 골든 `mypage-student-last-reservation`은
/// `GET /api/v1/schedule/student/my-reservation/old?searchDate=2026-09`
/// 하나다. **쿼리스트링까지 골든이 고정한다.**
///
/// ## 빈 목록이 `null`이다
///
/// 서버가 빈 배열이 아니라 `reservations: null`을 준다
/// (`MyReservationResponse.java:16`). 웹이 `data?.reservations === null`로
/// 빈 상태를 고르므로 **모델에서 빈 목록으로 흡수하면 안 된다.**
/// 2026-09-15 실측: 2026-09는 `null`, 2026-04는 10건.
///
/// ## 웹 버그 셋을 그대로 옮겼다
///
/// 1. **`?month=`가 없으면 `searchDate=Invalid Date`를 보낸다**(BUG-8).
///    웹 `dayjs(null)`이 Invalid Date가 되고 `.format('YYYY-MM')`이 그
///    문자열을 만든다. 허브에서 들어오면 언제나 쿼리가 붙지만 **직접 URL로
///    들어오면** 그 요청이 나간다.
/// 2. **로딩 중에는 아무것도 안 보인다**(BUG-9). `data`가 `undefined`라
///    `=== null`이 거짓이고 목록도 비어, 빈 상태조차 뜨지 않는다.
/// 3. **날짜 포맷 함수가 화면마다 다르다.** 여기는
///    `convertTo12HourFormat`(한 자리 시, `오전 4:00`)를 쓴다 —
///    학생 홈의 `A hh:mm`(두 자리, `오후 02:30`)와 다르다.
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageLastReservationPage extends StatefulWidget {
  const StudentMyPageLastReservationPage({
    required this.scheduleApi,
    required this.initialMonth,
    required this.onMonthChanged,
    required this.onBack,
    super.key,
  });

  /// 웹 `pb-[52px]` — 본문 아래 여백.
  static const double contentBottomPadding = 52;

  /// 웹 빈 상태의 `py-28`.
  ///
  /// 커스텀 스페이싱 스케일은 12까지만 덮는다 — 28은 Tailwind 기본
  /// `7rem = 112px`다(트레이너 정보 빈 상태와 같다).
  static const double emptyVerticalPadding = 112;

  /// 웹 `IconNoSchedule`의 고유 크기.
  static const double emptyIconSize = 28;

  /// 웹 `mb-5` — 카드 사이 간격.
  static const double cardGap = 12;

  /// 웹 상태 배지의 `w-[52px]`.
  static const double badgeWidth = 52;

  /// 웹 상태 배지의 `py-[2px]`.
  static const double badgeVerticalPadding = 2;

  /// 웹 출석 배지 배경 `bg-[#e2f1ff]`.
  ///
  /// 값은 `--primary-50`·`--blue-50`과 같지만 **웹이 임의값으로 적었다** —
  /// 토큰을 쓸지 임의값을 쓸지는 화면마다 제각각이다.
  static const Color attendedBadgeBackground = Color(0xFFE2F1FF);

  /// 웹 상세 시트의 `h-12` 확인 버튼.
  static const double sheetConfirmHeight = 48;

  final ScheduleApi scheduleApi;

  /// `?month=` 쿼리에서 온 값(`YYYY-MM`). 없으면 null이다.
  ///
  /// **null일 때 오늘로 대체하지 않는다** — 웹이 `dayjs(null)`로
  /// Invalid Date를 만들어 그대로 보내기 때문이다(BUG-8).
  final String? initialMonth;

  /// 달을 고르면 웹이 `router.push(...?month=YYYY-MM)`를 한다.
  final ValueChanged<String> onMonthChanged;

  /// **웹 헤더는 `router.back()`이 아니라 `<Link href='/student/mypage'>`다.**
  /// 어디서 들어왔든 허브로 간다.
  final VoidCallback onBack;

  @override
  State<StudentMyPageLastReservationPage> createState() =>
      _StudentMyPageLastReservationPageState();
}

class _StudentMyPageLastReservationPageState
    extends State<StudentMyPageLastReservationPage> {
  /// 화면이 보여주는 달. `null`이면 웹의 Invalid Date 상태다.
  DateTime? _selectedMonth;

  LastReservationList? _list;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.tryParse('${widget.initialMonth}-01');
    _load();
  }

  /// 서버에 보낼 `searchDate`.
  ///
  /// 웹 `dayjs(selectedMonth).format('YYYY-MM')` — 달을 못 읽었으면
  /// **`Invalid Date`라는 문자열**이 그대로 나간다(BUG-8).
  String get _searchDate {
    final month = _selectedMonth;
    if (month == null) {
      return 'Invalid Date';
    }
    return KoreanDateFormat.month(month);
  }

  Future<void> _load() async {
    try {
      final list = await widget.scheduleApi.studentLastReservations(
        _searchDate,
      );
      if (mounted) {
        setState(() => _list = list);
      }
    } catch (_) {
      // 웹 쿼리에 `isError` 분기가 없다. 실패하면 로딩 중과 같은 빈 화면이다.
    }
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      // 새 달을 조회하는 동안에는 이전 목록이 남는다 — 웹도 같다
      // (TanStack Query가 키가 바뀌면 `undefined`가 되지만 화면에
      // 로딩 분기가 없어 결과적으로 빈 화면이다).
      _list = null;
    });
    _load();
    widget.onMonthChanged(KoreanDateFormat.month(month));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final month = _selectedMonth;
    final reservations = _list?.reservations;

    return AppLayout(
      header: AppLayoutHeader(title: '지난 예약', onBack: widget.onBack),
      contents: Container(
        color: colors.gray100,
        // 웹 `px-7 pb-[52px] pt-7` = 좌우 20, 위 20, 아래 52.
        padding: EdgeInsets.fromLTRB(
          spacing.s7,
          spacing.s7,
          spacing.s7,
          StudentMyPageLastReservationPage.contentBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 웹 `{selectedMonth && ...}` — 달을 못 읽으면 선택기 자체가 없다.
            if (month != null)
              Align(
                alignment: Alignment.centerLeft,
                child: AppMonthPicker(date: month, onChanged: _changeMonth),
              ),
            // 웹 `{data?.reservations === null && <NoReservation />}` —
            // **`=== null`이라 로딩 중(undefined)에는 뜨지 않는다**(BUG-9).
            if (_list != null && reservations == null) const _NoReservation(),
            if (reservations != null)
              for (final reservation in reservations)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: StudentMyPageLastReservationPage.cardGap,
                  ),
                  child: _ReservationCard(reservation: reservation),
                ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `NoReservation` (`:29~42`).
class _NoReservation extends StatelessWidget {
  const _NoReservation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: StudentMyPageLastReservationPage.emptyVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/no_schedule.svg',
            width: StudentMyPageLastReservationPage.emptyIconSize,
            height: StudentMyPageLastReservationPage.emptyIconSize,
          ),
          // 웹 `mb-5` = 12.
          SizedBox(height: spacing.s5),
          Text(
            '지난 예약이 없습니다.',
            style: AppTypography.title1.copyWith(color: colors.gray700),
          ),
        ],
      ),
    );
  }
}

/// 웹 `<Card className='w-full px-6 py-7 text-left'>` + 그것을 여는 `Sheet`.
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation});

  final LastReservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    final (start, period) = KoreanDateFormat.twelveHour(
      reservation.lessonStartTime,
    );
    final (end, _) = KoreanDateFormat.twelveHour(reservation.lessonEndTime);

    return GestureDetector(
      onTap: () => _openDetail(context, start: start, end: end, period: period),
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 웹 Card base의 `rounded-lg bg-white p-6` 위에 `px-6 py-7`.
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s6,
          vertical: spacing.s7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              KoreanDateFormat.lastReservationDay(reservation.lessonDt),
              style: AppTypography.title3.copyWith(color: colors.gray600),
            ),
            // 웹 Card base의 `gap-y-2` = 6.
            SizedBox(height: spacing.s2),
            Row(
              children: [
                Text(
                  '$period $start - $end',
                  // 웹 `text-black` — gray800이 아니다.
                  style: AppTypography.title1.copyWith(color: Colors.black),
                ),
                // 웹 `ml-2` = 6.
                SizedBox(width: spacing.s2),
                _StatusBadge(isCompleted: reservation.isCompleted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context, {
    required String start,
    required String end,
    required String period,
  }) {
    final radius = Theme.of(context).extension<AppRadius>()!;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: AppMonthPicker.barrier,
      // 웹 시트에는 높이 상한이 없다 — 기본값(화면의 9/16)을 풀어 준다
      // (`AppMonthPicker`와 같은 이유).
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.l)),
      ),
      constraints: const BoxConstraints(maxWidth: AppMonthPicker.sheetMaxWidth),
      builder: (context) => _DetailSheet(
        day: KoreanDateFormat.lastReservationSheetDay(reservation.lessonDt),
        time: '$period $start - $end',
        isCompleted: reservation.isCompleted,
      ),
    );
  }
}

/// 웹 상태 배지 (`:108~117`).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      width: StudentMyPageLastReservationPage.badgeWidth,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        vertical: StudentMyPageLastReservationPage.badgeVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: isCompleted
            ? StudentMyPageLastReservationPage.attendedBadgeBackground
            : colors.gray100,
        // 웹 `rounded-sm` = 4.
        borderRadius: BorderRadius.circular(radius.s),
      ),
      child: Text(
        isCompleted ? '출석' : '미출석',
        style: AppTypography.body4Medium.copyWith(
          color: isCompleted ? colors.primary500 : colors.gray700,
        ),
      ),
    );
  }
}

/// 웹 `<SheetContent headerType='close'>` — 수업 정보 시트.
///
/// **자식 사이에 `gap`이 없다.** 시트 기본 클래스의 `gap-4`는 이 시트가
/// `flex`가 아니라 무력하고, 간격은 자식의 `mb-8`(24)·`mb-11`(36)만
/// 만든다(실측). 월 선택 시트는 `flex gap-7`이라 반대다.
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.day,
    required this.time,
    required this.isCompleted,
  });

  final String day;
  final String time;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;
    final status = isCompleted ? ' 출석' : ' 미출석';

    return SafeArea(
      top: false,
      child: Padding(
        // 웹 `pt-[48px] px-7 pb-9`.
        padding: EdgeInsets.fromLTRB(
          spacing.s7,
          AppMonthPicker.sheetTopPadding,
          spacing.s7,
          spacing.s9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '수업 정보',
              style: AppTypography.heading4.copyWith(color: Colors.black),
              textAlign: TextAlign.left,
            ),
            // 웹 `mb-8` = 24.
            SizedBox(height: spacing.s8),
            Container(
              // 웹 `rounded-md bg-gray-100 p-6 text-center`.
              padding: EdgeInsets.all(spacing.s6),
              decoration: BoxDecoration(
                color: colors.gray100,
                borderRadius: BorderRadius.circular(radius.m),
              ),
              child: Text.rich(
                TextSpan(
                  text: '$day $time',
                  children: <InlineSpan>[
                    TextSpan(
                      text: status,
                      // 웹은 **미출석일 때만** point 색이다.
                      style: isCompleted
                          ? null
                          : TextStyle(color: colors.point),
                    ),
                  ],
                ),
                style: AppTypography.heading3.copyWith(color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            // 웹 `mb-11` = 36.
            SizedBox(height: spacing.s11),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: StudentMyPageLastReservationPage.sheetConfirmHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary500,
                  // 웹 `rounded-md` = 8. 월 선택 버튼(12)과 다르다.
                  borderRadius: BorderRadius.circular(radius.m),
                ),
                child: Text(
                  '확인',
                  style: AppTypography.title1SemiBold.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
