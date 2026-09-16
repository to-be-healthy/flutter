import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/date/korean_date_format.dart';

/// 웹 `StudentHomePage.tsx`가 dayjs로 만드는 문자열을 그대로 재현하는지 본다.
///
/// 웹은 모듈 스코프에서 `dayjs.locale('ko')` + `dayjs.extend(customParseFormat)`
/// 를 실행한다(`StudentHomePage.tsx:3-6`). 로케일이 전역이라 이 화면을 import
/// 하는 순간 앱 전체 dayjs가 ko가 된다 — Flutter에서는 `intl`의
/// `initializeDateFormatting('ko')`가 같은 자리를 맡는다.
void main() {
  setUpAll(KoreanDateFormat.ensureInitialized);

  group('KoreanDateFormat.reservationDay — 웹 `format(\'MM.DD (ddd)\')`', () {
    test('한 글자 요일로 적는다', () {
      // 2026-09-15는 화요일.
      expect(
        KoreanDateFormat.reservationDay(DateTime(2026, 9, 15)),
        '09.15 (화)',
      );
    });

    // dayjs의 `ddd`는 "3글자 약어"지만 ko 로케일에서는 한 글자다(`일`~`토`).
    // `intl`의 `E`도 ko에서 같은 한 글자를 준다 — 이 대응이 이 테스트의 요점이고,
    // `EEE`로 잘못 쓰면 여기서 깨진다.
    test('월요일도 한 글자다', () {
      expect(
        KoreanDateFormat.reservationDay(DateTime(2026, 9, 14)),
        '09.14 (월)',
      );
    });

    test('월·일을 두 자리로 0 채운다', () {
      expect(
        KoreanDateFormat.reservationDay(DateTime(2026, 1, 4)),
        '01.04 (일)',
      );
    });
  });

  group('KoreanDateFormat.reservationHour — 웹 `format(\'A hh:mm\')`', () {
    // 웹은 `dayjs(lessonStartTime, 'HH:mm:ss')`로 **시각 문자열만** 파싱한다
    // (customParseFormat 플러그인이 필요한 이유). 서버 `MyReservation`의
    // `lessonStartTime`이 `LocalTime`이라 `"14:30:00"` 모양으로 온다.
    test('오후를 12시간제로 적는다', () {
      expect(KoreanDateFormat.reservationHour('14:30:00'), '오후 02:30');
    });

    test('오전을 12시간제로 적는다', () {
      expect(KoreanDateFormat.reservationHour('09:05:00'), '오전 09:05');
    });

    // `hh`(1~12)라 자정은 12로 적힌다. `HH`(0~23)로 옮기면 여기서 깨진다.
    test('자정은 오전 12시다', () {
      expect(KoreanDateFormat.reservationHour('00:00:00'), '오전 12:00');
    });

    test('정오는 오후 12시다', () {
      expect(KoreanDateFormat.reservationHour('12:00:00'), '오후 12:00');
    });

    // 서버가 초를 떼고 보내는 경우가 섞여도 화면이 죽지 않아야 한다.
    test('초가 없어도 파싱한다', () {
      expect(KoreanDateFormat.reservationHour('14:30'), '오후 02:30');
    });

    // 파싱 실패는 **빈 문자열**이다. 웹은 잘못된 입력에 `Invalid Date`를
    // 그리지만, 앱에서 그 문자열이 카드에 박히면 디자인이 깨진 것처럼 보인다.
    test('파싱할 수 없으면 빈 문자열이다', () {
      expect(KoreanDateFormat.reservationHour('이상한값'), '');
    });
  });

  group('KoreanDateFormat.month — 웹 `format(\'YYYY-MM\')`', () {
    // 식단전체 링크의 `?month=` 쿼리(`StudentHomePage.tsx:54,428`).
    test('YYYY-MM으로 적는다', () {
      expect(KoreanDateFormat.month(DateTime(2026, 9, 15)), '2026-09');
    });

    test('10월 이상도 두 자리를 유지한다', () {
      expect(KoreanDateFormat.month(DateTime(2026, 12, 1)), '2026-12');
    });
  });
}
