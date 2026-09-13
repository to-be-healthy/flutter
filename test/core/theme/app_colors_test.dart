import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/theme/app_colors.dart';

void main() {
  group('AppColors — 웹 global.css :root 변수 고정', () {
    const c = AppColors.light;

    test('primary 팔레트 10단이 웹 값과 일치한다', () {
      expect(c.primary50, const Color(0xFFE2F1FF));
      expect(c.primary100, const Color(0xFFBADCFF));
      expect(c.primary200, const Color(0xFF8EC7FF));
      expect(c.primary300, const Color(0xFF5FB1FF));
      expect(c.primary400, const Color(0xFF3BA0FF));
      expect(c.primary500, const Color(0xFF1990FF));
      expect(c.primary600, const Color(0xFF1F82F0));
      expect(c.primary700, const Color(0xFF206FDC));
      expect(c.primary800, const Color(0xFF205ECA));
      expect(c.primary900, const Color(0xFF1F3EAA));
    });

    test('gray 팔레트는 100~800 8단이다 (900은 웹 global.css에 없음)', () {
      expect(c.gray100, const Color(0xFFF2F3F5));
      expect(c.gray200, const Color(0xFFDEE1E6));
      expect(c.gray300, const Color(0xFFCBCFD3));
      expect(c.gray400, const Color(0xFFA7A9AE));
      expect(c.gray500, const Color(0xFF86888D));
      expect(c.gray600, const Color(0xFF5F6165));
      expect(c.gray700, const Color(0xFF4C4E52));
      expect(c.gray800, const Color(0xFF2E3134));
    });

    test('포인트·blue 색상이 웹 값과 일치한다', () {
      expect(c.point, const Color(0xFFFF4668));
      expect(c.blue10, const Color(0xFFF4FAFF));
      expect(c.blue50, const Color(0xFFE2F1FF));
    });
  });
}
