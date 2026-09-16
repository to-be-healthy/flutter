import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// 웹 dayjs(ko 로케일 + `customParseFormat`) 대응.
///
/// 웹 `StudentHomePage.tsx:3-6`은 **모듈 스코프에서** `dayjs.locale('ko')`와
/// `dayjs.extend(customParseFormat)`를 실행한다 — 그 화면을 import하는 순간
/// 앱 전체 dayjs가 ko가 되는 전역 부작용이다. `intl`은 로케일 데이터를
/// 명시적으로 적재해야 하므로 그 자리를 [ensureInitialized]가 맡는다.
///
/// **서버가 이미 포맷해 주는 값과 섞지 말 것.** `lessonHistory.lessonDt`·
/// `lessonTime`은 백엔드 `LessonTimeFormatter`가 `MM월 dd일 E요일` /
/// `HH:mm - HH:mm`로 만들어 보내는 **문자열**이라 그대로 쓴다. 여기서 다루는
/// 것은 원시 `LocalDate`/`LocalTime`으로 오는 `myReservation`뿐이다.
abstract final class KoreanDateFormat {
  /// 웹 `dayjs.locale('ko')`에 해당. `main()`과 테스트 `setUpAll`에서 부른다.
  ///
  /// `intl`은 ko 심볼이 적재되지 않은 상태에서 `DateFormat(..., 'ko')`를
  /// 만들면 예외를 던진다 — 앱 진입점에서 한 번 부르지 않으면 예약 카드가
  /// 있는 계정에서만 홈이 죽는다(데이터가 있어야 드러나는 종류의 실패다).
  static void ensureInitialized() {
    initializeDateFormatting(_locale);
  }

  static const String _locale = 'ko';

  /// 웹 `dayjs(lessonDt).format('MM.DD (ddd)')` → `09.15 (화)`.
  ///
  /// dayjs의 `ddd`는 "3글자 약어"지만 ko 로케일에서는 한 글자다(`일`~`토`).
  /// `intl`의 `E`가 ko에서 같은 한 글자를 주므로 `EEE`가 아니라 `E`다.
  static String reservationDay(DateTime date) =>
      DateFormat('MM.dd (E)', _locale).format(date);

  /// 웹 `dayjs(lessonStartTime, 'HH:mm:ss').format('A hh:mm')` → `오후 02:30`.
  ///
  /// 입력은 서버 `MyReservation.lessonStartTime`(`LocalTime`)의 문자열이다.
  /// 날짜가 없는 시각만 파싱하는 것이 웹에서 `customParseFormat` 플러그인이
  /// 필요했던 이유고, 여기서는 [DateFormat.parse]가 같은 일을 한다.
  ///
  /// `hh`(1~12)라 자정이 `오전 12:00`, 정오가 `오후 12:00`이다.
  /// `HH`로 바꾸면 웹과 달라진다.
  ///
  /// 파싱 실패는 **빈 문자열**을 돌려준다. 웹은 `Invalid Date`를 그대로
  /// 그리지만, 앱에서 그 문자열이 카드 본문에 박히면 화면이 깨진 것처럼
  /// 보인다 — 값이 없는 것과 같이 취급하는 편이 낫다.
  static String reservationHour(String lessonStartTime) {
    for (final pattern in const ['HH:mm:ss', 'HH:mm']) {
      try {
        final parsed = DateFormat(pattern).parseStrict(lessonStartTime);
        return DateFormat('a hh:mm', _locale).format(parsed);
      } on FormatException {
        continue;
      }
    }
    return '';
  }

  /// 웹 `dayjs(lessonDt).format('MM월 DD일 dddd')` → `04월 13일 월요일`.
  ///
  /// 지난 예약 카드의 머리글이다. 위 [reservationDay]와 **같은 값에서
  /// 다른 모양**을 만든다 — 한 화면은 `09.15 (화)`, 여기는 `04월 13일 월요일`.
  ///
  /// 입력은 서버 `MyReservation.lessonDt`(`LocalDate`) 문자열
  /// (`2026-04-13`). 파싱 실패는 빈 문자열이다([reservationHour]과 같은 이유).
  static String lastReservationDay(String lessonDt) {
    final date = DateTime.tryParse(lessonDt);
    if (date == null) {
      return '';
    }
    return DateFormat('MM월 dd일 EEEE', _locale).format(date);
  }

  /// 웹 `dayjs(lessonDt).format('MM.DD (dd)')` → `04.13 (월)`.
  ///
  /// 지난 예약 상세 시트가 쓴다. [reservationDay]와 결과 모양이 같지만
  /// 입력이 `DateTime`이 아니라 **서버 문자열**이라 따로 둔다.
  static String lastReservationSheetDay(String lessonDt) {
    final date = DateTime.tryParse(lessonDt);
    if (date == null) {
      return '';
    }
    return DateFormat('MM.dd (E)', _locale).format(date);
  }

  /// 웹 `convertTo12HourFormat` (`shared/utils/date.ts:64~72`).
  ///
  /// `['4:00', '오전']`처럼 **시:분과 오전/오후를 따로** 돌려준다.
  ///
  /// **[reservationHour]과 결과가 다르다.** 그쪽은 `DateFormat('a hh:mm')`라
  /// 두 자리 시(`오후 02:30`)인데, 이 함수는 한 자리다(`오전 4:00`).
  /// 웹이 화면마다 다른 함수를 쓰기 때문이고, 섞으면 한쪽이 틀린다.
  ///
  /// **파싱하지 않는다.** 웹이 `time.split(':')`로 문자열만 자르므로 여기서도
  /// 같게 한다 — 시각 파싱은 이 프로젝트에서 이미 여러 번 함정이었고
  /// (트레이너 홈 BUG-1), 자르기만 하면 실패할 자리가 없다.
  ///
  /// 시가 숫자가 아니면 빈 값 두 개를 돌려준다. 웹은 `NaN`이 섞인 문자열을
  /// 그대로 그리지만 앱에서는 값이 없는 것으로 친다.
  static (String time, String period) twelveHour(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      return ('', '');
    }
    final hour = int.tryParse(parts[0]);
    if (hour == null) {
      return ('', '');
    }
    // 웹 `hourNumber < 12 ? '오전' : '오후'`.
    final period = hour < 12 ? '오전' : '오후';
    // 웹 `hourNumber % 12 || 12` — 0시와 12시가 모두 `12`가 된다.
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    // 분은 **자르기만 한다** — 서버가 이미 두 자리로 준다.
    return ('$displayHour:${parts[1]}', period);
  }

  /// 웹 `dayjs(new Date()).format('YYYY-MM')` → `2026-09`.
  ///
  /// 식단전체 링크의 `?month=` 쿼리에 쓴다(`StudentHomePage.tsx:54`).
  /// 로케일과 무관한 숫자 포맷이라 `_locale`을 넘기지 않는다.
  static String month(DateTime date) => DateFormat('yyyy-MM').format(date);
}
