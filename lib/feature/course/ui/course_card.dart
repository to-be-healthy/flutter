import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../entity/course/model/course.dart';
import '../../../entity/point/model/student_point.dart';
import '../../../shared/ui/app_card.dart';
import '../../../shared/ui/app_collapsible.dart';
import '../../../shared/ui/app_progress.dart';

/// 웹 `feature/course/ui/CourseCard.tsx` + `StudentHomePage.tsx:151-338`.
///
/// 수강권 카드는 화면에서 유일하게 **한 값이 카드 전체를 가르는** 구조다 —
/// `completedLessonCnt == totalLessonCnt`(만료)가 배경색·헤더 문구·진행바
/// 색·하단 영역(펼침형 vs 고정 바)을 한꺼번에 바꾼다.
class CourseCard extends StatelessWidget {
  const CourseCard({
    required this.course,
    required this.gymName,
    required this.point,
    required this.rank,
    required this.isPointOpen,
    required this.onTogglePoint,
    required this.onOpenCourseHistory,
    required this.onOpenPointHistory,
    this.pointBarHeight = defaultPointBarHeight,
    super.key,
  });

  /// 웹 포인트 바(`flex h-[54px] ...`)의 높이. 스케일에 없는 임의값.
  ///
  /// **화면마다 다르다.** 학생 홈은 `h-[54px]`로 못박지만,
  /// `/trainer/manage/[memberId]`는 그 클래스가 없어 **내용이 높이를
  /// 정한다**(`p-6` 16+16 + 가장 높은 자식). 두 화면의 `CourseCard` 블록을
  /// 클래스 단위로 대조한 결과 **다른 점은 이것 하나뿐이었다.**
  /// [pointBarHeight]에 null을 넘기면 후자가 된다.
  static const double defaultPointBarHeight = 54;

  /// 웹 포인트/랭킹 카드의 `w-[130px]`.
  static const double statCardWidth = 130;

  /// 웹 `<Image src='/images/point.png' width={21} height={21} />`.
  static const double pointIconSize = 21;

  /// 웹 `<IconArrowDown widht={14} height={14} />`.
  /// (오타 `widht`는 웹 원본 그대로다 — prop이 먹히지 않아 자산 고유
  /// 크기로 렌더되는데, 자산도 14×14라 결과가 같다.)
  static const double arrowSize = 14;

  /// 웹 진행바의 `h-[2px]`. 컴포넌트 기본값 4가 아니다.
  static const double progressHeight = 2;

  final Course course;
  final String gymName;
  final StudentPoint? point;
  final StudentRank? rank;
  final bool isPointOpen;
  final VoidCallback onTogglePoint;
  final VoidCallback onOpenCourseHistory;
  final VoidCallback onOpenPointHistory;

  /// 포인트 바 높이. 기본값은 학생 홈의 `h-[54px]`,
  /// null이면 내용이 정한다(`/trainer/manage/[memberId]`).
  final double? pointBarHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return AppCard(
      // 웹 `cn(expiration ? 'bg-gray-500' : 'bg-primary-500', 'w-full gap-y-0 p-0')`.
      backgroundColor: course.isExpired ? colors.gray500 : colors.primary500,
      padding: EdgeInsets.zero,
      gap: 0,
      children: [
        // 웹은 헤더+본문만 `<Link href='./student/course-history'>`로 감싼다.
        // 하단 포인트 영역은 그 링크 **밖**이다 — 거기를 누르면 펼쳐지지
        // 이동하지 않는다.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpenCourseHistory,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              CourseCardHeader(course: course, gymName: gymName),
              CourseCardContent(course: course),
            ],
          ),
        ),
        if (course.isExpired)
          // 웹 `<div className='w-full rounded-b-lg bg-gray-400 text-white'>`.
          // **접히지 않는 고정 바**다 — 만료된 수강권에는 포인트/랭킹 상세가
          // 없다.
          _PointBar(
            point: point,
            isExpired: true,
            isOpen: false,
            barHeight: pointBarHeight,
          )
        else
          AppCollapsible(
            isOpen: isPointOpen,
            onToggle: onTogglePoint,
            // 웹 `<Collapsible className='rounded-b-lg bg-primary-600'>`.
            trigger: _PointBar(
              point: point,
              isExpired: false,
              isOpen: isPointOpen,
              barHeight: pointBarHeight,
            ),
            content: _PointDetail(
              point: point,
              rank: rank,
              onOpenPointHistory: onOpenPointHistory,
            ),
          ),
      ],
    );
  }
}

/// 웹 `CourseCardHeader`.
class CourseCardHeader extends StatelessWidget {
  const CourseCardHeader({
    required this.course,
    required this.gymName,
    super.key,
  });

  final Course course;
  final String gymName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    // 웹 `totalLessonCnt === completedLessonCnt ? '${total}회 PT수강 만료'
    //      : '${remain}회 예약할 수 있어요!'`
    final status = course.isExpired
        ? '${course.totalLessonCnt}회 PT수강 만료'
        : '${course.remainLessonCnt}회 예약할 수 있어요!';

    return Padding(
      // 웹 `px-6 pb-8 pt-7` = 16 / 24 / 20.
      padding: EdgeInsets.fromLTRB(
        spacing.s6,
        spacing.s7,
        spacing.s6,
        spacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 헬스장 이름이 길면 줄어들 수 있게 감싼다. 웹은 flex 자식이라
              // 자동으로 줄어들지만 Flutter Row는 넘친다.
              Flexible(
                child: Text(
                  gymName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body3.copyWith(color: colors.gray100),
                ),
              ),
              Text(
                'PT ${course.totalLessonCnt}회 수강권',
                style: AppTypography.body3.copyWith(color: colors.gray100),
              ),
            ],
          ),
          // 웹 `mb-1` = 4.
          SizedBox(height: spacing.s1),
          Text(
            status,
            style: AppTypography.heading3.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 웹 `CourseCardContent`.
class CourseCardContent extends StatelessWidget {
  const CourseCardContent({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    // 웹 `completedLessonCnt === totalLessonCnt ? 'text-gray-300' : 'text-[#8EC7FF]'`.
    // `#8EC7FF`는 이 팔레트의 `primary200`이다 — 리터럴로 두지 않는다.
    final totalColor = course.isExpired ? colors.gray300 : colors.primary200;

    return Padding(
      // 웹 `px-6 pb-7` = 16 / 20. 위쪽 패딩은 없다(헤더의 `pb-8`이 간격을 낸다).
      padding: EdgeInsets.fromLTRB(spacing.s6, 0, spacing.s6, spacing.s7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'PT 진행 횟수 ${course.completedLessonCnt}'),
                TextSpan(
                  text: '/${course.totalLessonCnt}',
                  style: AppTypography.body3.copyWith(color: totalColor),
                ),
              ],
            ),
            style: AppTypography.heading5.copyWith(color: Colors.white),
          ),
          // 웹 `mb-2` = 6.
          SizedBox(height: spacing.s2),
          AppProgress(
            value: course.progress,
            height: CourseCard.progressHeight,
            // 웹 `progressClassName={cn(completed === total && 'bg-gray-400')}`.
            // 기본(미만료)은 `bg-white`.
            barColor: course.isExpired ? colors.gray400 : null,
          ),
        ],
      ),
    );
  }
}

/// 카드 하단의 "N월 활동 포인트" 바.
///
/// 만료면 gray400 고정 바, 아니면 primary600 펼침 트리거다. 두 분기가 웹에서
/// **거의 같은 마크업을 복붙**한 것이라(`StudentHomePage.tsx:173-212` vs
/// `311-334`) 여기서는 하나로 합치고 차이만 분기한다.
class _PointBar extends StatelessWidget {
  const _PointBar({
    required this.point,
    required this.isExpired,
    required this.isOpen,
    required this.barHeight,
  });

  final StudentPoint? point;
  final bool isExpired;
  final bool isOpen;

  /// null이면 내용이 높이를 정한다(웹에 `h-[54px]`가 없는 화면).
  final double? barHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isExpired ? colors.gray400 : colors.primary600,
        // 웹 `rounded-bl-lg rounded-br-lg`. 카드 아래 모서리를 카드와 맞춘다.
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius.l)),
      ),
      child: SizedBox(
        // null이면 높이를 정하지 않는다 — `p-6`과 내용이 정한다.
        height: barHeight,
        child: Padding(
          // 웹 `p-6` = 16.
          padding: EdgeInsets.symmetric(horizontal: spacing.s6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // 웹 `{searchDate.split('-')[1].split('')[1]}월 활동 포인트` —
                // **버그를 그대로 옮긴 자리**다. 10~12월에 "0월/1월/2월"이
                // 된다. 근거와 결정은 `StudentPoint.webMonthLabel` 주석에.
                '${point?.webMonthLabel ?? ''}월 활동 포인트',
                style: AppTypography.heading5.copyWith(color: Colors.white),
              ),
              // 만료 바에는 화살표가 없다(펼칠 것이 없으므로). 웹도
              // 복붙된 두 분기 중 고정 바 쪽에만 화살표를 빼 놨다.
              if (isExpired)
                _PointAmount(point: point)
              else if (isOpen)
                // 웹 `<IconArrowDown className='rotate-180' />` —
                // 열렸으면 화살표만 보이고 점수는 숨는다.
                RotatedBox(
                  quarterTurns: 2,
                  child: SvgPicture.asset(
                    'assets/images/arrow_down.svg',
                    width: CourseCard.arrowSize,
                    height: CourseCard.arrowSize,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PointAmount(point: point),
                    // 웹 `mr-2` = 6 (점수 블록 오른쪽 여백).
                    SizedBox(width: spacing.s2),
                    SvgPicture.asset(
                      'assets/images/arrow_down.svg',
                      width: CourseCard.arrowSize,
                      height: CourseCard.arrowSize,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 포인트 아이콘 + 이번 달 점수. 바의 두 분기가 공유한다.
class _PointAmount extends StatelessWidget {
  const _PointAmount({required this.point});

  final StudentPoint? point;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PointIcon(),
        // 웹 `ml-[3px]` — 스케일에 없는 임의값.
        const SizedBox(width: 3),
        Text(
          '${point?.monthPoint ?? 0}',
          style: AppTypography.title1.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// 웹 `/images/point.png` 21×21 `rounded-full`.
class _PointIcon extends StatelessWidget {
  const _PointIcon();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/point.png',
        width: CourseCard.pointIconSize,
        height: CourseCard.pointIconSize,
      ),
    );
  }
}

/// 펼쳤을 때의 포인트·랭킹 카드 두 장.
class _PointDetail extends StatelessWidget {
  const _PointDetail({
    required this.point,
    required this.rank,
    required this.onOpenPointHistory,
  });

  final StudentPoint? point;
  final StudentRank? rank;
  final VoidCallback onOpenPointHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      // 웹 `p-6 pt-3` = 사방 16, 위 8.
      padding: EdgeInsets.fromLTRB(
        spacing.s6,
        spacing.s3,
        spacing.s6,
        spacing.s6,
      ),
      // 웹은 `<ul className='flex'>` 안에서 두 카드가 `h-full`이라 flex
      // 기본값(`align-items: stretch`)으로 **높이가 같아진다.** Flutter의
      // `CrossAxisAlignment.stretch`는 부모 높이가 유한할 때만 쓸 수 있고,
      // 여기는 `AppLayout`의 `SingleChildScrollView` 아래라 무한이다
      // (`BoxConstraints forces an infinite height`로 터진다 — 규율 #12와
      // 같은 뿌리). `IntrinsicHeight`가 두 자식의 자연 높이 중 큰 쪽으로
      // Row 높이를 먼저 확정해 준다.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: CourseCard.statCardWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenPointHistory,
                child: _StatCard(
                  title: const _PointTitle(),
                  value: _StatValue(
                    main: '${point?.monthPoint ?? 0}',
                    unit: '점',
                  ),
                  caption: '누적 ${point?.totalPoint ?? 0}',
                ),
              ),
            ),
            // 웹 `ml-3` = 8.
            SizedBox(width: spacing.s3),
            SizedBox(
              width: CourseCard.statCardWidth,
              child: _StatCard(
                title: const Text('랭킹', style: AppTypography.heading5),
                value: _RankValue(rank: rank),
                caption: '총 ${rank?.totalMemberCnt ?? 0}명',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 포인트 카드의 제목 — 아이콘과 글자가 한 줄이다.
class _PointTitle extends StatelessWidget {
  const _PointTitle();

  @override
  Widget build(BuildContext context) {
    // 카드가 `w-[130px]`에 `p-6`(16)이라 내용 폭이 98px뿐이고, 아이콘
    // 21px + "이번달 포인트"가 그보다 넓다. 웹에서는 이 글자가 flex 자식이라
    // **줄바꿈된다**(`flex-shrink: 1` 기본값). `Flexible` 없이 두면 Flutter는
    // 줄이지 않고 `RenderFlex overflowed`로 터진다.
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PointIcon(),
        Flexible(child: Text('이번달 포인트', style: AppTypography.heading5)),
      ],
    );
  }
}

/// 웹 `<Card className='h-full w-full gap-y-7 p-6'>` 두 장의 공통 틀.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.caption,
  });

  final Widget title;
  final Widget value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return AppCard(
      // 웹 `gap-y-7 p-6` = 20 / 16.
      gap: spacing.s7,
      padding: EdgeInsets.all(spacing.s6),
      children: [
        // 카드 안의 글자는 전부 검정이다(`text-black`) — 바깥 수강권 카드가
        // 흰 글자라 상속받으면 흰 배경에 흰 글자가 된다.
        DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.black),
          child: title,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.black),
              child: value,
            ),
            // 웹 `mb-7` = 20 (숫자 아래).
            SizedBox(height: spacing.s7),
            Text(
              caption,
              style: AppTypography.body4.copyWith(color: colors.gray400),
            ),
          ],
        ),
      ],
    );
  }
}

/// 숫자 + 작은 단위 글자(`120` + `점`).
class _StatValue extends StatelessWidget {
  const _StatValue({required this.main, required this.unit});

  final String main;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: main),
          TextSpan(
            // 웹 `ml-[2px]` — 임의값.
            text: ' $unit',
            style: AppTypography.heading5.copyWith(color: colors.gray700),
          ),
        ],
      ),
      style: AppTypography.heading2.copyWith(color: Colors.black),
    );
  }
}

/// 랭킹 숫자 + 추세 화살표.
class _RankValue extends StatelessWidget {
  const _RankValue({required this.rank});

  /// 웹 `<IconArrowFilledDown />` — 자산 고유 크기 12×12.
  static const double trendArrowSize = 12;

  final StudentRank? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final current = rank;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (current == null || !current.hasRanking)
          // 웹 `data?.rank.ranking === 999 ? '-' : ...`. 999는 순위가 아니라
          // "순위 없음" 표식이다.
          Text('-', style: AppTypography.heading2.copyWith(color: Colors.black))
        else
          _StatValue(main: '${current.ranking}', unit: '위'),
        if (current != null && current.trend != RankTrend.flat)
          SvgPicture.asset(
            current.trend == RankTrend.down
                ? 'assets/images/arrow_filled_down.svg'
                : 'assets/images/arrow_filled_up.svg',
            width: trendArrowSize,
            height: trendArrowSize,
            // 웹 `fill='var(--primary-500)'` / `fill='var(--point-color)'`.
            // 자산이 `currentColor`라 여기서 주입한다 — 주입하지 않으면
            // `SvgTheme` 기본값(검정)으로 그려진다.
            theme: SvgTheme(
              currentColor: current.trend == RankTrend.down
                  ? colors.primary500
                  : colors.point,
            ),
          ),
      ],
    );
  }
}
