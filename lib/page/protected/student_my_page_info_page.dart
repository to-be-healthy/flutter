import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/network/server_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/ui/auth_scope.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/member/model/member_info.dart';
import '../../shared/ui/app_toast.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/mypage/ui/EditMyInfoPage.tsx` 대응.
///
/// ## 요청 1건
///
/// 골든 `mypage-student-info`는 `GET /api/v1/members/me` 하나다. **하단
/// 네비가 없어** 허브(2건)와 다르다 — 헤더에 뒤로가기만 있다. 순서를 맞출
/// 상대가 없으므로 `addPostFrameCallback`도 필요 없다.
///
/// ## 화면 전체가 `{data && ...}`로 가려진다
///
/// 웹은 `Layout.Contents`를 통째로 `data`로 감싼다(`:110`). 데이터가 오기
/// 전에는 **헤더만 보인다** — 스켈레톤도 스피너도 없다. 허브는 프로필 카드만
/// 가렸는데 여기는 본문 전체다.
///
/// ## 계정 종류에 따라 카드가 통째로 갈린다
///
/// - 일반 계정: 이름·이메일·비밀번호 변경 **세 줄 다 링크**다(화살표 있음).
/// - 소셜 계정: 이름·이메일·계정 연동 설정 **세 줄 다 링크가 아니다**.
///   마지막 줄에는 값 대신 소셜 로고 배지가 붙는다.
///
/// 판정은 [MemberInfo.isSocialAccount] — `socialType !== 'NONE'`이라 **모르는
/// 값도 소셜로 친다**(서베이 BUG-5).
///
/// ## Phase A 범위
///
/// 진입 렌더 + 위 1건 + **로그아웃**까지다. 프로필 사진 업로드
/// (`PUT /api/v1/members/profile`, multipart)와 삭제(`DELETE`), 그리고 그
/// 둘을 여는 카메라 드롭다운은 Phase B다. **카메라 버튼은 그리되 눌러도
/// 아무 일도 하지 않는다** — 학생 홈의 식단 타일과 같은 경계다
/// (`docs/deferred-minors.md`에 기록).
///
/// 실측·근거는 `docs/student-mypage-survey.md`.
class StudentMyPageInfoPage extends StatefulWidget {
  const StudentMyPageInfoPage({
    required this.memberApi,
    required this.onNavigate,
    required this.onBack,
    super.key,
  });

  /// 프로필 **사진**의 크기. 웹 `h-[80px] w-[80px]`.
  static const double profileImageSize = 80;

  /// 사진이 없을 때 그리는 아바타 자산의 크기.
  ///
  /// **82다. 허브의 80과 다르다** — 웹이 여기서만
  /// `<IconAvatar width={82} height={82} />`를 쓴다(`:124`). 사진이 있을
  /// 때(80)와 없을 때(82)의 크기도 서로 다르다. 맞추면 웹과 달라진다.
  static const double avatarFallbackSize = 82;

  /// 웹 `<IconCamera />`(`camera.svg`)의 고유 크기.
  static const double cameraIconWidth = 24;
  static const double cameraIconHeight = 20;

  /// 웹 `-bottom-1 -right-1` — 카메라 버튼이 아바타 밖으로 나가는 거리.
  static const double cameraOffset = -4;

  /// 웹 `IconArrowRightSmall`의 고유 크기.
  static const double arrowWidth = 7;
  static const double arrowHeight = 10;

  /// 웹 `h-4 w-[1px] bg-gray-300` — 로그아웃과 탈퇴하기 사이의 세로선.
  static const double actionDividerWidth = 1;
  static const double actionDividerHeight = 10;

  /// 웹 `mb-[60px]` — 하단 액션 아래 여백.
  static const double actionBottomMargin = 60;

  final MemberApi memberApi;

  /// 라우터를 화면에 끼우지 않기 위한 이동 콜백(규율 #3).
  final ValueChanged<String> onNavigate;

  /// 웹 헤더의 `onClick={() => router.back()}`.
  final VoidCallback onBack;

  @override
  State<StudentMyPageInfoPage> createState() => _StudentMyPageInfoPageState();
}

class _StudentMyPageInfoPageState extends State<StudentMyPageInfoPage> {
  MemberInfo? _me;

  /// 로그아웃 요청이 날아가는 중인지.
  ///
  /// **웹에는 이 가드가 없다.** `useMutation`을 그대로 부르므로 빠르게 두 번
  /// 누르면 `POST /members/logout`이 두 번 나간다. `/select-gym`에서 같은
  /// 이유로 `_isSubmitting`을 둔 선례를 따랐다 — 의도적 이탈이고
  /// `docs/deferred-minors.md`에 적었다.
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    // 허브와 달리 첫 프레임 뒤로 미루지 않는다 — 이 화면에는 하단 네비가
    // 없어 순서를 맞출 상대가 없고, 골든도 1건이다.
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.memberApi.me();
      if (mounted) {
        setState(() => _me = me);
      }
    } catch (_) {
      // 웹 `useMyInfoQuery`에 `isError` 분기가 없다. 실패하면 본문이 영영
      // 안 그려지고 헤더만 남는다 — 로딩 중과 **구분되지 않는다.**
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() => _isLoggingOut = true);

    try {
      await widget.memberApi.logout();
    } catch (error) {
      // 웹 `onError: errorToast(message ?? '문제가 발생했습니다.')`.
      // **실패하면 로그아웃하지 않는다** — 토큰이 그대로 남는다.
      if (mounted) {
        setState(() => _isLoggingOut = false);
        AppToastScope.read(context).showError(serverMessage(error));
      }
      return;
    }

    if (!mounted) {
      return;
    }
    // 웹 `deleteUserInfo()` + `localStorage.clear()`.
    //
    // 웹이 하는 나머지 둘은 옮기지 않는다:
    // - `localStorage.clear()` — 이 앱이 로컬에 두는 것은 토큰과 프로필뿐이고
    //   `signOut()`이 그 둘을 지운다. 지울 나머지가 없다.
    // - 서비스워커 `unregister()` — PWA 전용이라 네이티브에 대응물이 없다.
    await AuthScope.read(context).signOut();

    if (!mounted) {
      return;
    }
    // 웹 `router.push('/')`.
    //
    // **`signOut()`만으로는 화면이 넘어가지 않는다.** 라우터의 리다이렉트는
    // 이동이 일어날 때 계산되므로, 알림만으로는 여기 남는다
    // (`/select-gym`에서 이미 겪은 것 — `next-steps.md` §2-① 참고).
    widget.onNavigate('/');
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;

    return AppLayout(
      // 웹 `<Layout className='bg-white'>` — 루트 전체가 흰색이다.
      backgroundColor: Colors.white,
      header: AppLayoutHeader(onBack: widget.onBack),
      // 웹 `{data && <Layout.Contents .../>}` — 본문 전체가 가려진다.
      contents: me == null
          ? const SizedBox.shrink()
          : Column(
              // 웹은 마지막 섹션에 `mt-auto`를, 가운데 섹션에 `flex-grow`를
              // 줘서 하단 액션을 바닥에 붙인다. **`Expanded`는 쓸 수 없다**
              // (규율 #12 — 본문이 `SingleChildScrollView` 안이라 높이 상한이
              // 없다). 자식을 둘로 묶고 `spaceBetween`으로 같은 결과를 낸다.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProfileSection(me: me),
                    _AccountCard(me: me, onNavigate: widget.onNavigate),
                  ],
                ),
                _BottomActions(
                  onLogout: _logout,
                  // 웹 `<Link href={'./leave'}>` — 이 화면(`.../mypage/info`)
                  // 기준 상대 경로라 `/student/mypage/leave`다.
                  onLeave: () => widget.onNavigate('/student/mypage/leave'),
                ),
              ],
            ),
    );
  }
}

/// 웹 `EditMyInfoPage.tsx:112~155`.
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.me});

  final MemberInfo me;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Padding(
      // 웹 `pt-6` = 16.
      padding: EdgeInsets.only(top: spacing.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            // 카메라 버튼이 아바타 **밖으로** 나간다(`-bottom-1 -right-1`).
            clipBehavior: Clip.none,
            children: [
              _ProfileImage(fileUrl: me.profileFileUrl),
              const Positioned(
                bottom: StudentMyPageInfoPage.cameraOffset,
                right: StudentMyPageInfoPage.cameraOffset,
                child: _CameraButton(),
              ),
            ],
          ),
          // 웹 `gap-6` = 16.
          SizedBox(height: spacing.s6),
          Text(me.name, style: AppTypography.heading2),
        ],
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.fileUrl});

  final String? fileUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    Widget fallback() => SvgPicture.asset(
      'assets/images/avatar.svg',
      width: StudentMyPageInfoPage.avatarFallbackSize,
      height: StudentMyPageInfoPage.avatarFallbackSize,
    );

    if (fileUrl == null) {
      return fallback();
    }

    return ClipOval(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.gray300),
        ),
        child: Image.network(
          // **`&=q=90`은 오타다**(서베이 BUG-4). 허브(`&q=90`)와 다르고,
          // 웹이 이 화면에서만 이렇게 쓴다(`:116`). 그대로 옮긴다.
          '$fileUrl?w=300&h=300&=q=90',
          width: StudentMyPageInfoPage.profileImageSize,
          height: StudentMyPageInfoPage.profileImageSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback(),
        ),
      ),
    );
  }
}

/// 웹 `DropdownMenuTrigger` (`:135~137`).
///
/// **Phase A에서는 눌러도 아무 일도 하지 않는다.** 여는 드롭다운
/// (`앨범에서 선택` / `사진 삭제`)과 그 너머의 multipart 업로드가 Phase B다.
class _CameraButton extends StatelessWidget {
  const _CameraButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return Container(
      // 웹 `p-2` = 6.
      padding: EdgeInsets.all(spacing.s2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: colors.gray300),
      ),
      child: SvgPicture.asset(
        'assets/images/camera.svg',
        width: StudentMyPageInfoPage.cameraIconWidth,
        height: StudentMyPageInfoPage.cameraIconHeight,
        // 웹 `<IconCamera fill={'var(--gray-500)'} />`. 자산의 렌즈 원이
        // `fill="current"`(유효하지 않은 값)였던 것을 `currentColor`로
        // 정규화했다 — 그대로 두면 flutter_svg가 그 도형을 **안 그린다**
        // (규율 #13).
        theme: SvgTheme(currentColor: colors.gray500),
      ),
    );
  }
}

/// 웹 `:156~236`. 계정 종류에 따라 세 줄의 성격이 통째로 갈린다.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.me, required this.onNavigate});

  final MemberInfo me;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      // 웹 `mx-7 mt-11` = 좌우 20, 위 36.
      margin: EdgeInsets.only(
        left: spacing.s7,
        right: spacing.s7,
        top: spacing.s11,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius.l),
        border: Border.all(color: colors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: me.isSocialAccount
            ? <Widget>[
                // 소셜 계정은 **세 줄 다 링크가 아니다** — 화살표도 없다.
                _InfoRow(label: '이름', value: me.name, hasBorder: true),
                _InfoRow(label: '이메일', value: me.email, hasBorder: true),
                _InfoRow(
                  label: '계정 연동 설정',
                  // 아는 셋(카카오·구글·네이버) 외에는 배지가 없다 — 웹도
                  // `APPLE`에 분기가 없어 그 자리가 빈다.
                  trailing: _SocialBadge(socialType: me.socialType),
                ),
              ]
            : <Widget>[
                _InfoRow(
                  label: '이름',
                  value: me.name,
                  hasBorder: true,
                  trailing: const _RightArrow(),
                  onTap: () => onNavigate('/student/mypage/edit/name'),
                ),
                _InfoRow(
                  label: '이메일',
                  value: me.email,
                  hasBorder: true,
                  trailing: const _RightArrow(),
                  onTap: () => onNavigate('/student/mypage/edit/email'),
                ),
                // **값이 없는 유일한 줄이다** — 라벨과 화살표뿐이다.
                _InfoRow(
                  label: '비밀번호 변경',
                  trailing: const _RightArrow(),
                  onTap: () => onNavigate('/student/mypage/edit/password'),
                ),
              ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    this.value,
    this.trailing,
    this.hasBorder = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;

  /// 웹 `border-b border-gray-100`. **마지막 줄에는 없다.**
  final bool hasBorder;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final currentValue = value;

    return GestureDetector(
      onTap: onTap,
      // 값이 없는 자리도 눌려야 한다 — 웹은 `<Link>`가 행 전체를 감싼다.
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 웹 `px-6 py-7` = 좌우 16, 상하 20.
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s6,
          vertical: spacing.s7,
        ),
        decoration: hasBorder
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.gray100)),
              )
            : null,
        child: Row(
          children: [
            Text(label, style: AppTypography.title1SemiBold),
            // 값이 길면(긴 이메일) 줄어야 한다. 웹은 flex 자식이라 저절로
            // 줄지만 Flutter `Row`의 `Text`는 `Flexible` 없이 넘친다.
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (currentValue != null)
                    Flexible(
                      child: Text(
                        currentValue,
                        style: AppTypography.body3.copyWith(
                          color: colors.gray500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  if (currentValue != null && trailing != null)
                    // 웹 `gap-3` = 8.
                    SizedBox(width: spacing.s3),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 `<IconArrowRightSmall />`.
///
/// 허브와 달리 **`stroke` prop을 넘기지 않는다**(`:211` 등). 자산 자체가
/// `stroke="#A7A9AE"`(= `--gray-400`)라 결과는 같다.
class _RightArrow extends StatelessWidget {
  const _RightArrow();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/arrow_right_small.svg',
      width: StudentMyPageInfoPage.arrowWidth,
      height: StudentMyPageInfoPage.arrowHeight,
    );
  }
}

/// 웹 `:181~195`의 소셜 로고 배지 셋.
class _SocialBadge extends StatelessWidget {
  const _SocialBadge({required this.socialType});

  /// 웹 `bg-[#FEE500]` — 카카오 브랜드 노랑.
  static const Color kakaoBackground = Color(0xFFFEE500);

  /// 웹 `bg-[#03C75A]` — 네이버 브랜드 초록.
  static const Color naverBackground = Color(0xFF03C75A);

  final String socialType;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final (String asset, double size, Color background) = switch (socialType) {
      'KAKAO' => ('kakao_logo', 18.0, kakaoBackground),
      'GOOGLE' => ('google_logo', 14.0, Colors.white),
      'NAVER' => ('naver_logo', 18.0, naverBackground),
      // **`APPLE`에는 분기가 없다** — 웹도 없어서 그 자리가 빈다.
      _ => ('', 0.0, Colors.transparent),
    };

    if (asset.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      // 웹 `p-1` = 4.
      padding: EdgeInsets.all(spacing.s1),
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: SvgPicture.asset(
        'assets/images/$asset.svg',
        width: size,
        height: size,
      ),
    );
  }
}

/// 웹 `:237~247`. 화면 바닥에 붙는 로그아웃 · 탈퇴하기.
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onLogout, required this.onLeave});

  final VoidCallback onLogout;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final style = AppTypography.body2.copyWith(color: colors.gray500);

    return Padding(
      // 웹 `mb-[60px]`.
      padding: const EdgeInsets.only(
        bottom: StudentMyPageInfoPage.actionBottomMargin,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onLogout,
            child: Text('로그아웃', style: style),
          ),
          // 웹 `gap-3` = 8.
          SizedBox(width: spacing.s3),
          Container(
            width: StudentMyPageInfoPage.actionDividerWidth,
            height: StudentMyPageInfoPage.actionDividerHeight,
            color: colors.gray300,
          ),
          SizedBox(width: spacing.s3),
          GestureDetector(
            onTap: onLeave,
            child: Text('탈퇴하기', style: style),
          ),
        ],
      ),
    );
  }
}
