import 'package:flutter/material.dart';

import '../../../core/date/korean_date_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../entity/schedule/model/last_reservation.dart';

/// 예약 카드 — 날짜 + 시간 + 오른쪽 슬롯.
///
/// 웹이 회원 지난 예약(`/student/mypage/last-reservation`)과 트레이너 예약
/// 내역(`/trainer/manage/[memberId]/reservation`)에서 **같은 마크업을 쓴다.**
/// 2026-09-18 실측에서 두 화면의 카드가 치수까지 같아 올렸다:
/// 패딩 `px-6 py-7`(16/20) · 라운드 12 · 날짜 `TITLE_3` gray-600 ·
/// `gap-y-2`(6) · 시간 `TITLE_1_BOLD` black · 오른쪽 슬롯 `ml-2`(6).
///
/// 오른쪽 슬롯만 화면마다 다르다 — 지난 예약은 [ReservationStatusBadge],
/// 트레이너 "다가오는 예약"은 체크 아이콘이다.
class ReservationCard extends StatelessWidget {
  const ReservationCard({
    required this.reservation,
    this.trailing,
    this.onTap,
    super.key,
  });

  final LastReservation reservation;

  /// 시간 오른쪽에 붙는 것. null이면 시간만 그린다.
  final Widget? trailing;

  /// null이면 누를 수 없는 카드다(트레이너 "다가오는 예약"이 그렇다).
  final VoidCallback? onTap;

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
      onTap: onTap,
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
                if (trailing != null) ...[
                  // 웹 `ml-2` = 6.
                  SizedBox(width: spacing.s2),
                  trailing!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 출석/미출석 배지. 웹 `reservationStatus === 'COMPLETED'` 하나로 갈린다.
class ReservationStatusBadge extends StatelessWidget {
  const ReservationStatusBadge({required this.isCompleted, super.key});

  /// 웹 상태 배지의 `w-[52px]`.
  static const double width = 52;

  /// 웹 상태 배지의 `py-[2px]`.
  static const double verticalPadding = 2;

  /// 웹 `bg-[#e2f1ff]`.
  ///
  /// 값은 `--primary-50`·`--blue-50`과 같지만 **웹이 임의값으로 적었다** —
  /// 토큰을 쓸지 임의값을 쓸지는 화면마다 제각각이다.
  static const Color attendedBackground = Color(0xFFE2F1FF);

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: verticalPadding),
      decoration: BoxDecoration(
        color: isCompleted ? attendedBackground : colors.gray100,
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
