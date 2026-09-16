import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 웹 `src/widget/month-picker.tsx` 대응.
///
/// 트리거(`2026년 9월 ▾`)와 그것이 여는 바텀시트(연도 이동 + 12칸 격자 +
/// 선택 버튼)가 한 묶음이다.
///
/// ## 치수 (2026-09-15 브라우저 실측)
///
/// | 요소 | 값 |
/// |---|---|
/// | 트리거 | 높이 **51.5** (`py-6` 16 + 줄 높이 19.5 + 16) |
/// | 트리거 글꼴 | `HEADING_5` 13 / 19.5 / 600 |
/// | 삼각형 | 12 × 13, 글자와 간격 **4**(`space-x-1`) |
/// | 시트 | 패딩 `48 / 20 / 28`, 상단 라운드 12, **자식 간격 20** |
/// | 격자 칸 | 폭 1/4, 높이 **72** |
/// | 월 원 | **56 × 56** |
/// | 선택 버튼 | 높이 **58.41**(`py-[18px]` + `TITLE_1_BOLD` 22.4) |
///
/// **시트의 자식 간격 20은 `gap-7`이다.** 시트 기본 클래스의 `gap-4`(10)를
/// 이긴다 — 그 기본값이 `flex`가 아닌 상세 시트에서는 아예 무력하다는 점과
/// 함께 실측으로 확인했다.
class AppMonthPicker extends StatelessWidget {
  const AppMonthPicker({
    required this.date,
    required this.onChanged,
    super.key,
  });

  /// 웹 `py-6` — 트리거의 상하 패딩.
  static const double triggerVerticalPadding = 16;

  /// 웹 `space-x-1` — 글자와 삼각형 사이.
  static const double triggerGap = 4;

  /// 웹 `IconTriangleDown`의 고유 크기.
  static const double triangleWidth = 12;
  static const double triangleHeight = 13;

  /// 웹 `h-[72px] w-1/4` — 격자 한 칸.
  static const double cellHeight = 72;

  /// 웹 `h-[56px] w-[56px] rounded-full` — 월 원.
  static const double monthCircleSize = 56;

  /// 웹 `bg-black/80` — 시트 뒤를 덮는 막.
  static const Color barrier = Color(0xCC000000);

  /// 웹 `max-w-[var(--max-width)]`.
  static const double sheetMaxWidth = 440;

  /// 웹 `pt-[48px]` — 시트 위 패딩(닫기 버튼 자리).
  static const double sheetTopPadding = 48;

  /// 웹 `space-x-8` — 연도 좌우 화살표 사이.
  static const double yearArrowGap = 24;

  /// 선택된 달.
  final DateTime date;

  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: triggerVerticalPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // 웹 `dayjs(date).format('YYYY년 M월')` — **월에 0을 붙이지
              // 않는다**(`9월`이지 `09월`이 아니다).
              '${date.year}년 ${date.month}월',
              style: AppTypography.heading5,
            ),
            const SizedBox(width: triggerGap),
            SvgPicture.asset(
              'assets/images/icon_triangle_down.svg',
              width: triangleWidth,
              height: triangleHeight,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radius = Theme.of(context).extension<AppRadius>()!;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: barrier,
      // **`isScrollControlled`가 필요하다.** 기본값은 시트 높이를 화면의
      // 9/16으로 묶는데, 웹 시트는 `fixed bottom-0`이라 그런 상한이 없다.
      // 월 선택 시트는 내용이 457이라 좁은 화면에서 그 상한에 걸려 잘린다.
      isScrollControlled: true,
      // 웹 `rounded-t-lg` = 12.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.l)),
      ),
      constraints: const BoxConstraints(maxWidth: sheetMaxWidth),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          // 웹 `pt-[48px] px-7 pb-9`.
          padding: EdgeInsets.fromLTRB(
            spacing.s7,
            sheetTopPadding,
            spacing.s7,
            spacing.s9,
          ),
          child: _MonthlyCalendar(date: date),
        ),
      ),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }
}

/// 웹 `MonthlyCalendar`.
class _MonthlyCalendar extends StatefulWidget {
  const _MonthlyCalendar({required this.date});

  final DateTime date;

  @override
  State<_MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<_MonthlyCalendar> {
  late int _year = widget.date.year;
  late int _month = widget.date.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final now = DateTime.now();

    // 웹 `unselectabled = year >= currentYear` — **올해보다 뒤로 못 간다.**
    final cannotGoForward = _year >= now.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('월 선택하기', style: AppTypography.title1SemiBold),
        // 웹 `gap-7` = 20. 시트 기본 `gap-4`(10)를 이긴다(실측).
        SizedBox(height: spacing.s7),
        _YearRow(
          year: _year,
          cannotGoForward: cannotGoForward,
          onPrevious: () => setState(() => _year -= 1),
          onNext: cannotGoForward ? null : () => setState(() => _year += 1),
        ),
        SizedBox(height: spacing.s7),
        _MonthGrid(
          year: _year,
          selectedMonth: _month,
          now: now,
          onSelect: (month) => setState(() => _month = month),
        ),
        SizedBox(height: spacing.s7),
        _SelectButton(
          year: _year,
          month: _month,
          // 웹 `dayjs(year + month, 'YYYYM').toDate()` — 그 달의 1일이다.
          onPressed: () => Navigator.of(context).pop(DateTime(_year, _month)),
        ),
      ],
    );
  }
}

/// 웹 `<div className='flex justify-between'>` — 연도와 좌우 화살표.
class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.year,
    required this.cannotGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final bool cannotGoForward;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$year년', style: AppTypography.heading4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onPrevious,
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                'assets/images/icon_arrow_left.svg',
                width: 16,
                height: 17,
                // 웹 `stroke={'var(--primary-500)'}` — 왼쪽은 언제나 파랗다.
                theme: SvgTheme(currentColor: colors.primary500),
              ),
            ),
            const SizedBox(width: AppMonthPicker.yearArrowGap),
            GestureDetector(
              onTap: onNext,
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                'assets/images/icon_arrow_right.svg',
                width: 10,
                height: 17,
                // 웹은 **색으로만** 비활성을 알린다 — 흐려지지 않는다.
                theme: SvgTheme(
                  currentColor: cannotGoForward
                      ? colors.gray500
                      : colors.primary500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 웹 `<div className='flex flex-wrap'>` — 12칸 격자.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.selectedMonth,
    required this.now,
    required this.onSelect,
  });

  final int year;
  final int selectedMonth;
  final DateTime now;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            children: [
              for (var column = 0; column < 4; column++)
                Expanded(child: _cell(colors, row * 4 + column + 1)),
            ],
          ),
      ],
    );
  }

  Widget _cell(AppColors colors, int month) {
    // 웹 `isCurrent` — 올해의 이번 달이면 글자가 파랗다.
    final isCurrent = year == now.year && month == now.month;
    // 웹 `isFuture` — 올해의 다음 달부터는 회색이고 **눌러도 안 먹는다.**
    final isFuture = year == now.year && month > now.month;
    final isSelected = month == selectedMonth;

    // **선택이 `isCurrent`를 이긴다** — 웹에서 뒤에 오는 클래스가 이긴다.
    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isFuture) {
      textColor = colors.gray500;
    } else if (isCurrent) {
      textColor = colors.primary500;
    } else {
      textColor = colors.gray800;
    }

    return SizedBox(
      height: AppMonthPicker.cellHeight,
      child: Center(
        child: GestureDetector(
          onTap: isFuture ? null : () => onSelect(month),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: AppMonthPicker.monthCircleSize,
            height: AppMonthPicker.monthCircleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? colors.primary500 : null,
            ),
            child: Text(
              '$month월',
              style: AppTypography.title1SemiBold.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// 웹 `<Button size='full' className={Typography.TITLE_1_BOLD}>`.
///
/// `AppButton`을 쓰지 않는 이유는 라벨 글꼴이 `TITLE_1_BOLD`(16/700)라
/// 기본값(`title1SemiBold`)과 다르고, 높이도 패딩으로 만들어지는
/// **58.41**이라 고정 높이 API와 맞지 않아서다.
class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.year,
    required this.month,
    required this.onPressed,
  });

  /// 웹 `size='full'`의 `py-[18px] px-4`.
  static const double verticalPadding = 18;

  final int year;
  final int month;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s4,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: colors.primary500,
          borderRadius: BorderRadius.circular(radius.l),
        ),
        child: Text(
          '$year년 $month월 선택',
          style: AppTypography.title1.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
