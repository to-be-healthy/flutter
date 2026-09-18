import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/auth_state.dart';
import '../../entity/gym/api/gym_api.dart';
import '../../entity/home/api/home_api.dart';
import '../../entity/member/api/member_api.dart';
import '../../entity/schedule/api/schedule_api.dart';
import '../../entity/course/api/course_api.dart';
import '../../entity/point/api/point_api.dart';
import '../../entity/trainer/api/trainer_api.dart';
import '../../entity/notification/api/notification_api.dart';
import '../../page/protected/select_gym_page.dart';
import '../../page/protected/student_home_page.dart';
import '../../page/protected/student_my_page.dart';
import '../../page/protected/student_my_page_alarm_page.dart';
import '../../page/protected/student_my_page_trainer_info_page.dart';
import '../../page/protected/student_my_page_edit_email_page.dart';
import '../../page/protected/student_my_page_edit_name_page.dart';
import '../../page/protected/student_my_page_edit_password_page.dart';
import '../../page/protected/student_my_page_info_page.dart';
import '../../page/protected/student_my_page_last_reservation_page.dart';
import '../../page/protected/student_my_page_leave_page.dart';
import '../../page/protected/trainer_home_page.dart';
import '../../page/protected/trainer_manage_course_history_page.dart';
import '../../page/protected/trainer_manage_point_history_page.dart';
import '../../page/protected/trainer_manage_reservation_page.dart';
import '../../page/protected/trainer_manage_member_page.dart';
import '../../page/protected/trainer_manage_page.dart';
import '../../page/public/find_id_page.dart';
import '../../page/public/find_password_page.dart';
import '../../page/public/not_implemented_page.dart';
import '../../page/public/onboarding_page.dart';
import '../../page/public/policy_page.dart';
import '../../page/public/sign_up_complete_page.dart';
import '../../page/public/sign_in_page.dart';
import '../../page/public/splash_page.dart';

/// 웹 URL을 그대로 옮긴 라우트 표.
///
/// 경로 문자열을 화면 코드에 흩어놓지 않는 이유는 웹과의 대조 때문이다 —
/// 73개 라우트를 옮기는 동안 "웹의 어느 URL인가"를 한곳에서 확인할 수 있어야
/// 한다.
abstract final class AppRoutes {
  /// 복원 중 화면. 웹 `app/page.tsx`의 `role === undefined` 분기
  /// (스플래시 GIF) 대응. 웹은 URL 없이 같은 자리에서 분기하지만,
  /// go_router는 리다이렉트가 경로로 표현돼야 해서 자리를 하나 준다.
  static const String splash = '/splash';

  /// 웹 `/` — 온보딩. `?type=`이 붙으면 로그인 수단 선택 화면이 된다.
  static const String onboarding = '/';

  /// 웹 `/sign-in?type=student|trainer`.
  static const String signIn = '/sign-in';

  static const String signUp = '/sign-up';

  /// 웹 `(login-unrequired)/sign-up/complete?type=&name=`.
  ///
  /// 가입 자체는 `/sign-up`의 mutation이 끝냈고, 이 화면은 그 결과를
  /// 쿼리스트링으로 받아 보여주기만 한다.
  static const String signUpComplete = '/sign-up/complete';

  /// 웹 `(login-unrequired)/policy` 계열. `/policy`는 자체 콘텐츠가 없는
  /// 허브이고, 약관 두 화면으로 들어가는 유일한 경로다.
  static const String policy = '/policy';
  static const String policyTerms = '/policy/terms';
  static const String policyPrivacy = '/policy/privacy';

  /// 웹 `/cs` — 고객센터. 온보딩 하단 링크의 목적지.
  static const String customerService = '/cs';

  static const String findId = '/find/id';
  static const String findPassword = '/find/pw';

  /// 웹 `(login-required)/student`·`/trainer`.
  static const String studentHome = '/student';
  static const String trainerHome = '/trainer';

  /// 회원 홈에서 나가는 경로 전부.
  ///
  /// **전부 등록해야 한다.** go_router는 등록되지 않은 경로로 `go`하면 에러
  /// 화면을 띄우므로, 홈의 카드나 탭을 누르는 순간 앱이 에러 화면으로
  /// 빠진다. 아직 옮기지 않은 화면은 `NotImplementedPage`가 받는다
  /// (`/sign-up`·`/cs`·`/policy/terms`와 같은 관행).
  ///
  /// 하단 네비 3개(`schedule`·`community`·`mypage`)와 카드에서 나가는
  /// 6개다. `studentLessonLog`는 상세(`/student/log/:id`)를 자식으로 갖는다.
  static const String studentAlarm = '/student/alarm';
  static const String studentSchedule = '/student/schedule';
  static const String studentCommunity = '/student/community';
  static const String studentMyPage = '/student/mypage';

  /// 마이페이지 허브에서 나가는 경로 전부.
  ///
  /// 웹 `src/app/(login-required)/student/mypage/` 아래 8개 `page.tsx`다.
  /// 허브가 이 중 셋(`last-reservation`·`trainer-info`·`alarm`)으로 직접
  /// 링크하고, 나머지는 `info` 화면을 거쳐 들어간다.
  ///
  /// **허브가 링크하는 나머지 둘(`/policy`·`/cs`)은 마이페이지 밑이 아니다** —
  /// 공개 라우트라 이미 등록돼 있다.
  static const String studentMyPageInfo = '$studentMyPage/info';
  static const String studentMyPageAlarm = '$studentMyPage/alarm';
  static const String studentMyPageTrainerInfo = '$studentMyPage/trainer-info';
  static const String studentMyPageLastReservation =
      '$studentMyPage/last-reservation';
  static const String studentMyPageLeave = '$studentMyPage/leave';
  static const String studentMyPageEditName = '$studentMyPage/edit/name';
  static const String studentMyPageEditEmail = '$studentMyPage/edit/email';
  static const String studentMyPageEditPassword =
      '$studentMyPage/edit/password';
  static const String studentCourseHistory = '/student/course-history';
  static const String studentPointHistory = '/student/point-history';
  static const String studentLessonLog = '/student/log';
  static const String studentDiet = '/student/diet';
  static const String studentWorkout = '/student/workout';

  /// 트레이너 홈에서 나가는 경로 전부. 회원 쪽과 같은 이유로 **전부
  /// 등록해야 한다** — go_router는 등록되지 않은 경로로 `go`하면 에러
  /// 화면을 띄운다.
  ///
  /// `trainerManageMember`는 `/trainer/manage`의 자식(`:memberId`)이다.
  /// 오늘의 수업 카드와 우수 회원 이름이 그리로 들어간다.
  static const String trainerAlarm = '/trainer/alarm';
  static const String trainerSchedule = '/trainer/schedule';
  static const String trainerCommunity = '/trainer/community';
  static const String trainerMyPage = '/trainer/mypage';
  static const String trainerManage = '/trainer/manage';
  static const String trainerManageFeedback = '/trainer/manage/feedback';

  /// `/trainer/manage`의 형제 라우트 둘. **`:memberId`보다 먼저 선언해야
  /// 한다** — `feedback`과 같은 이유다.
  static const String trainerManageInvite = '/trainer/manage/invite';
  static const String trainerManageAppend = '/trainer/manage/append';

  /// 회원 상세와 그 하위 13개.
  ///
  /// 웹 `/trainer/manage/[memberId]/**`다. 경로에 id가 들어가므로 상수가
  /// 아니라 **함수**로 만든다 — `studentLessonLog`의 `:lessonHistoryId`가
  /// 자식 하나뿐이라 상수로 버틴 것과 다르다.
  static String trainerManageMember(Object memberId) =>
      '$trainerManage/$memberId';

  /// 웹은 이 링크에 **이름을 쿼리로 실어 보낸다**
  /// (`TrainerStudentDetailPage/index.tsx:133-136`의
  /// `query: {name: memberInfo.name}`). 화면이 헤더 제목
  /// `{name}님 수강권`에만 쓰고, 없으면 `님 수강권`이 된다.
  static String trainerManageMemberCourseHistory(
    Object memberId, {
    String? name,
  }) {
    final path = '${trainerManageMember(memberId)}/course-history';
    if (name == null || name.isEmpty) {
      return path;
    }
    return Uri(path: path, queryParameters: {nameQuery: name}).toString();
  }

  static String trainerManageMemberPointHistory(Object memberId) =>
      '${trainerManageMember(memberId)}/point-history';

  /// 웹도 이름을 쿼리로 실어 보낸다
  /// (`TrainerStudentDetailPage/index.tsx:98`의 `?name=${memberInfo?.name}`).
  /// **없으면 제목이 통째로 사라진다** — 화면이 `{name && ...}`이기 때문이다.
  static String trainerManageMemberReservation(
    Object memberId, {
    String? name,
  }) {
    final path = '${trainerManageMember(memberId)}/reservation';
    if (name == null || name.isEmpty) {
      return path;
    }
    return Uri(path: path, queryParameters: {nameQuery: name}).toString();
  }

  static String trainerManageMemberEditMemo(Object memberId) =>
      '${trainerManageMember(memberId)}/edit/memo';
  static String trainerManageMemberEditNickname(Object memberId) =>
      '${trainerManageMember(memberId)}/edit/nickname';
  static String trainerManageMemberLog(Object memberId) =>
      '${trainerManageMember(memberId)}/log';
  static String trainerManageMemberLogWrite(Object memberId) =>
      '${trainerManageMemberLog(memberId)}/write';
  static String trainerManageMemberLogDetail(Object memberId, Object logId) =>
      '${trainerManageMemberLog(memberId)}/$logId';
  static String trainerManageMemberLogEdit(Object memberId, Object logId) =>
      '${trainerManageMemberLogDetail(memberId, logId)}/edit';
  static String trainerManageMemberDiet(Object memberId) =>
      '${trainerManageMember(memberId)}/diet';
  static String trainerManageMemberDietDetail(Object memberId, Object dietId) =>
      '${trainerManageMemberDiet(memberId)}/$dietId';
  static String trainerManageMemberWorkout(Object memberId) =>
      '${trainerManageMember(memberId)}/workout';
  static String trainerManageMemberWorkoutDetail(
    Object memberId,
    Object workoutHistoryId,
  ) => '${trainerManageMemberWorkout(memberId)}/$workoutHistoryId';
  static String trainerManageAppendMember(Object memberId) =>
      '$trainerManageAppend/$memberId';

  /// 웹 `(login-required)/trainer/class-time-setting`.
  ///
  /// **트레이너가 헬스장 등록을 마치면 `/trainer`가 아니라 여기로 간다**
  /// (웹 `SelectGymPage`의 `router.push('/trainer/class-time-setting')`).
  /// `/trainer`로 보내면 웹과 다른 화면이 된다.
  static const String trainerClassTimeSetting = '/trainer/class-time-setting';

  /// 웹 `(login-required)/select-gym` — 헬스장 미선택 사용자가 홈 대신 먼저
  /// 보는 화면. `UserRoleMiddleware`가 `gymId === null`이면 여기로 튕긴다.
  static const String selectGym = '/select-gym';

  /// 웹 `?name=` 쿼리 이름. 가입완료 화면이 인사말에 쓴다.
  static const String nameQuery = 'name';

  /// 웹 `?type=` 쿼리 이름. 온보딩과 로그인이 공유한다.
  static const String memberTypeQuery = 'type';

  /// 복원이 끝난 뒤 되돌아갈 곳을 스플래시가 들고 있는 쿼리 이름.
  ///
  /// 이게 없으면 **복원 중에 들어온 경로가 통째로 버려진다** — 스플래시로
  /// 리다이렉트된 뒤 복원이 끝나면 온보딩이나 홈으로만 가기 때문이다.
  /// Phase 3의 푸시 알림 딥링크가 정확히 이 경로로 들어온다.
  static const String returnToQuery = 'from';
}

/// 앱 라우터를 만든다.
///
/// [authState]는 `refreshListenable`로 물린다 — 로그인·로그아웃·복원 완료가
/// 곧 리다이렉트 재평가다. 이 배선이 없으면 로그인에 성공해도 화면이 그대로
/// 남는다.
GoRouter createRouter({
  required AuthState authState,
  required AuthApi authApi,
  required GymApi gymApi,
  required HomeApi homeApi,
  required NotificationApi notificationApi,
  required MemberApi memberApi,
  required ScheduleApi scheduleApi,
  required TrainerApi trainerApi,
  required CourseApi courseApi,
  required PointApi pointApi,
  String initialLocation = AppRoutes.onboarding,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authState,
    redirect: (context, state) => _redirect(authState, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingPage(
          memberType: state.uri.queryParameters[AppRoutes.memberTypeQuery],
          authApi: authApi,
        ),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => SignInPage(
          authApi: authApi,
          // 웹 `SignInPage.tsx`는 type이 student/trainer가 아니면
          // `throw new Error('잘못된 접근입니다.')`로 에러 화면을 띄운다.
          // 앱에서 같은 상황은 아래 `_redirect`가 온보딩으로 돌려보내므로,
          // 여기까지 왔다면 값이 유효하다.
          memberType: _memberTypeOf(state)!.toUpperCase(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) =>
            const NotImplementedPage(title: '회원가입', webRoute: '/sign-up'),
      ),
      GoRoute(
        path: AppRoutes.signUpComplete,
        builder: (context, state) => SignUpCompletePage(
          // 아래 `_redirect`가 둘 다 있는 경우만 통과시키므로 여기서는 유효하다.
          name: state.uri.queryParameters[AppRoutes.nameQuery]!,
          memberType: _memberTypeOf(state)!,
          onConfirm: (memberType) => context.go(
            Uri(
              path: AppRoutes.signIn,
              queryParameters: {AppRoutes.memberTypeQuery: memberType},
            ).toString(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.policy,
        builder: (context, state) => PolicyPage(
          onBack: () => _backOr(context, AppRoutes.onboarding),
          onOpen: context.go,
        ),
      ),
      GoRoute(
        path: AppRoutes.policyTerms,
        builder: (context, state) => const NotImplementedPage(
          title: '서비스 이용약관',
          webRoute: '/policy/terms',
        ),
      ),
      GoRoute(
        path: AppRoutes.policyPrivacy,
        builder: (context, state) => const NotImplementedPage(
          title: '개인정보 처리방침',
          webRoute: '/policy/privacy',
        ),
      ),
      GoRoute(
        path: AppRoutes.customerService,
        builder: (context, state) =>
            const NotImplementedPage(title: '고객센터', webRoute: '/cs'),
      ),
      GoRoute(
        path: AppRoutes.findId,
        builder: (context, state) => FindIdPage(authApi: authApi),
      ),
      GoRoute(
        path: AppRoutes.findPassword,
        builder: (context, state) => FindPasswordPage(authApi: authApi),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) => StudentHomePage(
          homeApi: homeApi,
          notificationApi: notificationApi,
          memberApi: memberApi,
          onNavigate: context.go,
        ),
      ),
      // 홈에서 나가는 자리표시자들. 웹 경로를 그대로 적어 다음에 옮길 때
      // 무엇을 보면 되는지 화면에서 바로 보이게 한다.
      GoRoute(
        path: AppRoutes.studentAlarm,
        builder: (context, state) =>
            const NotImplementedPage(title: '알림', webRoute: '/student/alarm'),
      ),
      GoRoute(
        path: AppRoutes.studentSchedule,
        builder: (context, state) => const NotImplementedPage(
          title: '수업예약',
          webRoute: '/student/schedule',
        ),
      ),
      GoRoute(
        path: AppRoutes.studentCommunity,
        builder: (context, state) => const NotImplementedPage(
          title: '커뮤니티',
          webRoute: '/student/community',
        ),
      ),
      GoRoute(
        path: AppRoutes.studentMyPage,
        builder: (context, state) =>
            StudentMyPage(memberApi: memberApi, onNavigate: context.go),
        routes: [
          // 웹의 `mypage/` 하위 8개. **`edit/*` 셋을 `edit` 부모 없이 두
          // 단계 경로로 둔다** — 웹에 `edit/page.tsx`가 없어서 `/edit` 자체는
          // 화면이 아니다. go_router는 중간 세그먼트에 라우트가 없어도
          // 자식 경로에 슬래시를 포함시키면 매칭한다.
          GoRoute(
            path: 'info',
            builder: (context, state) => StudentMyPageInfoPage(
              memberApi: memberApi,
              onNavigate: context.go,
              // 웹 헤더의 `router.back()`. 이 라우트는 `/student/mypage`의
              // **자식**이라 부모 페이지가 늘 스택에 함께 서 있고, 따라서
              // `pop()`이 언제나 허브로 돌아간다 — 딥링크로 바로 들어와도
              // 그렇다.
              onBack: context.pop,
            ),
          ),
          GoRoute(
            path: 'alarm',
            builder: (context, state) => StudentMyPageAlarmPage(
              memberApi: memberApi,
              onBack: context.pop,
            ),
          ),
          GoRoute(
            path: 'trainer-info',
            builder: (context, state) => StudentMyPageTrainerInfoPage(
              memberApi: memberApi,
              onBack: context.pop,
            ),
          ),
          GoRoute(
            path: 'last-reservation',
            builder: (context, state) => StudentMyPageLastReservationPage(
              scheduleApi: scheduleApi,
              // 웹 `useSearchParams().get('month')` — **없으면 null 그대로
              // 넘긴다.** 오늘로 대체하면 웹의 `Invalid Date` 동작이 사라진다.
              initialMonth: state.uri.queryParameters['month'],
              onMonthChanged: (month) => context.go(
                '${AppRoutes.studentMyPageLastReservation}?month=$month',
              ),
              // 웹 헤더는 `<Link href='/student/mypage'>`다 — `pop`이 아니다.
              onBack: () => context.go(AppRoutes.studentMyPage),
            ),
          ),
          GoRoute(
            path: 'leave',
            builder: (context, state) => StudentMyPageLeavePage(
              memberApi: memberApi,
              onNavigate: context.go,
              onBack: context.pop,
            ),
          ),
          GoRoute(
            path: 'edit/name',
            builder: (context, state) => StudentMyPageEditNamePage(
              memberApi: memberApi,
              onNavigate: context.go,
              onBack: context.pop,
            ),
          ),
          GoRoute(
            path: 'edit/email',
            builder: (context, state) => StudentMyPageEditEmailPage(
              authApi: authApi,
              memberApi: memberApi,
              onNavigate: context.go,
              onBack: context.pop,
            ),
          ),
          GoRoute(
            path: 'edit/password',
            builder: (context, state) => StudentMyPageEditPasswordPage(
              memberApi: memberApi,
              onNavigate: context.go,
              onBack: context.pop,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.studentCourseHistory,
        builder: (context, state) => const NotImplementedPage(
          title: '수강내역',
          webRoute: '/student/course-history',
        ),
      ),
      GoRoute(
        path: AppRoutes.studentPointHistory,
        builder: (context, state) => const NotImplementedPage(
          title: '포인트 내역',
          webRoute: '/student/point-history',
        ),
      ),
      GoRoute(
        path: AppRoutes.studentLessonLog,
        builder: (context, state) =>
            const NotImplementedPage(title: '수업 일지', webRoute: '/student/log'),
        routes: [
          // 웹 `/student/log/[lessonHistoryId]`. 홈의 수업일지 카드가
          // `/student/log/{id}`로 직접 들어간다.
          GoRoute(
            path: ':lessonHistoryId',
            builder: (context, state) => const NotImplementedPage(
              title: '수업 일지',
              webRoute: '/student/log/[lessonHistoryId]',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.studentDiet,
        builder: (context, state) =>
            const NotImplementedPage(title: '식단', webRoute: '/student/diet'),
      ),
      GoRoute(
        path: AppRoutes.studentWorkout,
        builder: (context, state) => const NotImplementedPage(
          title: '개인 운동 기록',
          webRoute: '/student/workout',
        ),
      ),
      GoRoute(
        path: AppRoutes.trainerHome,
        builder: (context, state) => TrainerHomePage(
          homeApi: homeApi,
          memberApi: memberApi,
          notificationApi: notificationApi,
          onNavigate: context.go,
        ),
      ),
      // 트레이너 홈에서 나가는 자리표시자들.
      GoRoute(
        path: AppRoutes.trainerAlarm,
        builder: (context, state) =>
            const NotImplementedPage(title: '알림', webRoute: '/trainer/alarm'),
      ),
      GoRoute(
        path: AppRoutes.trainerSchedule,
        builder: (context, state) => const NotImplementedPage(
          title: '스케줄',
          webRoute: '/trainer/schedule',
        ),
      ),
      GoRoute(
        path: AppRoutes.trainerCommunity,
        builder: (context, state) => const NotImplementedPage(
          title: '커뮤니티',
          webRoute: '/trainer/community',
        ),
      ),
      GoRoute(
        path: AppRoutes.trainerMyPage,
        builder: (context, state) => const NotImplementedPage(
          title: '마이페이지',
          webRoute: '/trainer/mypage',
        ),
      ),
      GoRoute(
        path: AppRoutes.trainerManage,
        builder: (context, state) =>
            TrainerManagePage(trainerApi: trainerApi, onNavigate: context.go),
        routes: [
          // **`feedback`이 `:memberId`보다 먼저다.** go_router는 형제
          // 라우트를 선언 순서로 매칭하므로, 반대로 두면
          // `/trainer/manage/feedback`이 `memberId = 'feedback'`으로
          // 잡힌다.
          GoRoute(
            path: 'feedback',
            builder: (context, state) => const NotImplementedPage(
              title: '피드백 작성',
              webRoute: '/trainer/manage/feedback',
            ),
          ),
          GoRoute(
            path: 'invite',
            builder: (context, state) => const NotImplementedPage(
              title: '회원 초대',
              webRoute: '/trainer/manage/invite',
            ),
          ),
          GoRoute(
            path: 'append',
            builder: (context, state) => const NotImplementedPage(
              title: '회원 추가',
              webRoute: '/trainer/manage/append',
            ),
            routes: [
              GoRoute(
                path: ':memberId',
                builder: (context, state) => const NotImplementedPage(
                  title: '회원 추가 상세',
                  webRoute: '/trainer/manage/append/[memberId]',
                ),
              ),
            ],
          ),
          // **위 셋(`feedback`·`invite`·`append`)이 `:memberId`보다 먼저다.**
          GoRoute(
            path: ':memberId',
            builder: (context, state) => TrainerManageMemberPage(
              trainerApi: trainerApi,
              memberId: state.pathParameters['memberId'] ?? '',
              onNavigate: context.go,
              // 웹 `router.back()` — 이 화면만은 홈 고정이 아니다.
              onBack: () => context.pop(),
            ),
            routes: [
              GoRoute(
                path: 'course-history',
                builder: (context, state) => TrainerManageCourseHistoryPage(
                  courseApi: courseApi,
                  memberId: state.pathParameters['memberId'] ?? '',
                  // 웹도 없으면 `님 수강권`이 된다 — 빈 문자열이 그 상태다.
                  name: state.uri.queryParameters[AppRoutes.nameQuery] ?? '',
                  onBack: () => context.pop(),
                  onNavigate: context.go,
                ),
              ),
              GoRoute(
                path: 'point-history',
                builder: (context, state) => TrainerManagePointHistoryPage(
                  trainerApi: trainerApi,
                  pointApi: pointApi,
                  // 학생 하단바가 `trainer-mapping`을 쏜다(BUG-1) — 화면
                  // 본체가 아니라 네비가 쓰는 의존이다.
                  memberApi: memberApi,
                  memberId: state.pathParameters['memberId'] ?? '',
                  onNavigate: context.go,
                ),
              ),
              GoRoute(
                path: 'reservation',
                builder: (context, state) => TrainerManageReservationPage(
                  scheduleApi: scheduleApi,
                  memberId: state.pathParameters['memberId'] ?? '',
                  // 웹도 없으면 제목이 통째로 사라진다.
                  name: state.uri.queryParameters[AppRoutes.nameQuery] ?? '',
                  onBack: () => context.pop(),
                ),
              ),
              // 웹에 `edit/page.tsx`가 없어 `/edit` 자체는 화면이 아니다 —
              // 마이페이지의 `edit/name`과 같은 두 세그먼트 자식이다.
              GoRoute(
                path: 'edit/memo',
                builder: (context, state) => const NotImplementedPage(
                  title: '메모 수정',
                  webRoute: '/trainer/manage/[memberId]/edit/memo',
                ),
              ),
              GoRoute(
                path: 'edit/nickname',
                builder: (context, state) => const NotImplementedPage(
                  title: '닉네임 수정',
                  webRoute: '/trainer/manage/[memberId]/edit/nickname',
                ),
              ),
              GoRoute(
                path: 'log',
                builder: (context, state) => const NotImplementedPage(
                  title: '수업 일지',
                  webRoute: '/trainer/manage/[memberId]/log',
                ),
                routes: [
                  // **`write`가 `:logId`보다 먼저다.** 반대로 두면
                  // `.../log/write`가 `logId = 'write'`로 잡힌다 —
                  // `feedback` / `:memberId`와 같은 함정이 한 단계 아래에서
                  // 반복된다.
                  GoRoute(
                    path: 'write',
                    builder: (context, state) => const NotImplementedPage(
                      title: '수업 일지 작성',
                      webRoute: '/trainer/manage/[memberId]/log/write',
                    ),
                  ),
                  GoRoute(
                    path: ':logId',
                    builder: (context, state) => const NotImplementedPage(
                      title: '수업 일지 상세',
                      webRoute: '/trainer/manage/[memberId]/log/[logId]',
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => const NotImplementedPage(
                          title: '수업 일지 수정',
                          webRoute:
                              '/trainer/manage/[memberId]/log/[logId]/edit',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'diet',
                builder: (context, state) => const NotImplementedPage(
                  title: '식단',
                  webRoute: '/trainer/manage/[memberId]/diet',
                ),
                routes: [
                  GoRoute(
                    path: ':dietId',
                    builder: (context, state) => const NotImplementedPage(
                      title: '식단 상세',
                      webRoute: '/trainer/manage/[memberId]/diet/[dietId]',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'workout',
                builder: (context, state) => const NotImplementedPage(
                  title: '운동 기록',
                  webRoute: '/trainer/manage/[memberId]/workout',
                ),
                routes: [
                  GoRoute(
                    path: ':workoutHistoryId',
                    builder: (context, state) => const NotImplementedPage(
                      title: '운동 기록 상세',
                      webRoute:
                          '/trainer/manage/[memberId]/workout/[workoutHistoryId]',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.trainerClassTimeSetting,
        builder: (context, state) => const NotImplementedPage(
          title: '수업시간 설정',
          webRoute: '/trainer/class-time-setting',
        ),
      ),
      GoRoute(
        path: AppRoutes.selectGym,
        builder: (context, state) => SelectGymPage(gymApi: gymApi),
      ),
    ],
  );
}

/// 돌아갈 곳이 있으면 pop, 없으면 [fallback]으로 보낸다.
///
/// 딥링크·푸시로 화면에 바로 진입하면 스택이 비어 있어 pop이 아무 일도 하지
/// 않는다 — 그러면 뒤로가기 버튼이 죽은 것처럼 보인다.
void _backOr(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// 유효한 `?type=` 값만 돌려준다. 그 외(없음·오타)는 null.
String? _memberTypeOf(GoRouterState state) {
  final type = state.uri.queryParameters[AppRoutes.memberTypeQuery];
  return (type == 'student' || type == 'trainer') ? type : null;
}

/// 웹 `app/page.tsx` + `_providers/UserRoleMiddleware.tsx`의 리다이렉트 체인.
String? _redirect(AuthState auth, GoRouterState state) {
  final location = state.matchedLocation;

  // ① 복원 전에는 어떤 판단도 하지 않는다. 여기서 로그인 여부를 따지면
  //    로그인 상태인 사용자가 매번 온보딩을 스치고 지나간다
  //    (웹의 `role === undefined` → 스플래시 분기와 같은 이유).
  if (auth.isRestoring) {
    if (location == AppRoutes.splash) {
      return null;
    }
    // 가려던 곳을 들고 간다. 복원이 끝나면 그리로 되돌려 보낸다.
    return Uri(
      path: AppRoutes.splash,
      queryParameters: {AppRoutes.returnToQuery: state.uri.toString()},
    ).toString();
  }
  if (location == AppRoutes.splash) {
    final returnTo = state.uri.queryParameters[AppRoutes.returnToQuery];
    // 스플래시로 되돌아오는 값은 받지 않는다 — 무한 리다이렉트가 된다.
    if (returnTo != null &&
        returnTo.isNotEmpty &&
        !returnTo.startsWith(AppRoutes.splash)) {
      // 그 경로에 대한 인증 규칙은 이 반환값으로 이동한 **다음 평가**에서
      // 적용된다(로그인 상태로 `/sign-in`에 가면 홈으로 다시 튕긴다).
      return returnTo;
    }
    return auth.isSignedIn ? auth.user!.homeLocation : AppRoutes.onboarding;
  }

  // ② 경로 자체의 유효성(인증과 무관). 웹 `SignInPage.tsx`는 type이
  //    student/trainer가 아니면 `throw new Error('잘못된 접근입니다.')`로
  //    에러 화면을 띄운다. 앱에서 화면을 던지는 것은 과하므로 온보딩으로
  //    돌려보낸다 — 이 규칙이 없으면 아래 builder의 `!`가 터진다.
  if (location == AppRoutes.signIn && _memberTypeOf(state) == null) {
    return AppRoutes.onboarding;
  }

  // 웹 `SignUpCompletePage`는 `type`·`name`이 없으면 화면 안에서 인자 없는
  // `throw new Error()`를 던져 `app/error.tsx`에 떨어진다. **앱에서 크래시는
  // 부적절하므로** 그 판단을 여기로 올렸다 — 바로 위 `/sign-in` 게이트와
  // 같은 패턴이고, 이 규칙이 없으면 위 builder의 `!`가 터진다.
  if (location == AppRoutes.signUpComplete) {
    final name = state.uri.queryParameters[AppRoutes.nameQuery];
    if (_memberTypeOf(state) == null || name == null || name.isEmpty) {
      return AppRoutes.onboarding;
    }
  }

  final isHome =
      location == AppRoutes.studentHome || location == AppRoutes.trainerHome;

  if (!auth.isSignedIn) {
    // 웹 `UserRoleMiddleware`: `role === null` → `redirect('/')`.
    //
    // `/select-gym`도 함께 막는다. **웹에는 이 가드가 없다** —
    // `(login-required)` 그룹에 `layout.tsx`가 없어서 그룹 이름과 달리
    // 실제로 막는 것이 아무것도 없고, 미로그인 상태로 열면 토큰 없는
    // 요청이 나간다(웹 쪽 결함이다). 앱에서는 그 화면이
    // `auth.user!.memberType`으로 제목을 갈라서 그대로 두면 null 역참조로
    // 죽는다. 명시적 이탈로 온보딩에 돌려보낸다.
    return (isHome || location == AppRoutes.selectGym)
        ? AppRoutes.onboarding
        : null;
  }

  // 웹 `app/page.tsx`: 로그인 상태로 `/`에 오면 자기 홈으로 보낸다.
  // `?type=`이 붙어 있어도 마찬가지다 — 그 분기가 OnboardingPage보다 먼저다.
  if (location == AppRoutes.onboarding) {
    return auth.user!.homeLocation;
  }

  // 웹 `UserRoleMiddleware`: `role !== memberType` → 자기 홈으로.
  if (isHome && location != auth.user!.homeLocation) {
    return auth.user!.homeLocation;
  }

  // 웹 `UserRoleMiddleware`: `gymId === null` → `/select-gym`.
  //
  // 역할 확인 **다음**에 온다(웹의 순서 그대로). 헬스장을 아직 고르지 않은
  // 계정은 홈을 볼 수 없다 — 신규 가입자가 처음 보는 화면이 홈이 아니라
  // 여기다. 이 규칙이 빠지면 그 계정이 데이터 없는 홈을 보게 된다.
  if (isHome && auth.user!.gymId == null) {
    return AppRoutes.selectGym;
  }

  // 로그인 상태로 로그인 화면에 오면 홈으로. 웹은 `(login-unrequired)`라
  // 막지 않지만, 앱에서는 뒤로가기로 도달할 수 있어 같은 규칙을 적용한다.
  if (location == AppRoutes.signIn) {
    return auth.user!.homeLocation;
  }

  return null;
}
