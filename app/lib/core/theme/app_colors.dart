import 'package:flutter/material.dart';

/// UI 설계서(v1.2) 화면에서 추출한 색상 토큰.
abstract final class AppColors {
  // 브랜드
  static const primary = Color(0xFF2F6F61);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE1EDE7);
  static const onPrimaryContainer = Color(0xFF275346);

  // 배경·면
  static const background = Color(0xFFF6F2E9);
  static const surface = Color(0xFFFEFDF8);
  static const surfaceSubtle = Color(0xFFF3EFE4);
  static const surfaceMuted = Color(0xFFEFE9DA);
  static const surfaceTrack = Color(0xFFEAE3D3);

  // 선
  static const border = Color(0xFFE2DCCE);
  static const borderStrong = Color(0xFFD9D2C0);
  static const divider = Color(0xFFEEE7DD);

  // 글자
  static const textPrimary = Color(0xFF1D1A14);
  static const textLabel = Color(0xFF48443B);
  static const textSecondary = Color(0xFF6B675C);
  static const textTertiary = Color(0xFF8A867C);

  // 상태: 경고(동기화 대기 등)
  static const warning = Color(0xFFB07B1D);
  static const warningContainer = Color(0xFFF6F0DB);
  static const onWarningContainer = Color(0xFF755A1E);

  // 상태: 위험(삭제·오류·오늘 마감)
  static const danger = Color(0xFFA53C33);
  static const dangerText = Color(0xFF994237);
  static const dangerContainer = Color(0xFFF9F0ED);
  static const onDangerContainer = Color(0xFF84372B);
  static const dangerBorder = Color(0xFFE1C8C4);

  // 캘린더 주말
  static const calendarSunday = Color(0xFF9C5F55);
  static const calendarSaturday = Color(0xFF5F7079);

  // 어두운 면(촬영 화면, 스낵바, 모달 배경)
  static const cameraBackground = Color(0xFF181815);
  static const cameraSurface = Color(0xFF2A2724);
  static const snackBar = Color(0xFF27211E);
  static const snackBarAction = Color(0xFF8FC9B6);
  static const scrim = Color(0x661D1A14);
}

/// 사분면(중요도 × 긴급도) 영역별 색상 묶음. 태그, 사분면 영역, 아바타에 함께 쓴다.
@immutable
class QuadrantColors {
  const QuadrantColors({
    required this.foreground,
    required this.tagBackground,
    required this.areaBackground,
    required this.areaBorder,
  });

  /// 태그 글자, 사분면 영역 제목·개수
  final Color foreground;
  final Color tagBackground;
  final Color areaBackground;
  final Color areaBorder;

  /// 중요 · 긴급 — 지금 한다
  static const importantUrgent = QuadrantColors(
    foreground: Color(0xFF83372F),
    tagBackground: Color(0xFFF6E1DE),
    areaBackground: Color(0xFFFBF1EF),
    areaBorder: Color(0xFFE5D8D2),
  );

  /// 중요 · 비긴급 — 계획한다
  static const importantNotUrgent = QuadrantColors(
    foreground: Color(0xFF275346),
    tagBackground: Color(0xFFE1EDE7),
    areaBackground: Color(0xFFEEF4F2),
    areaBorder: Color(0xFFD8E3DB),
  );

  /// 비중요 · 긴급 — 빨리 끝낸다
  static const notImportantUrgent = QuadrantColors(
    foreground: Color(0xFF745518),
    tagBackground: Color(0xFFF3EAD5),
    areaBackground: Color(0xFFF8F1E1),
    areaBorder: Color(0xFFE9DDC7),
  );

  /// 비중요 · 비긴급 — 미뤄둔다
  static const notImportantNotUrgent = QuadrantColors(
    foreground: Color(0xFF475058),
    tagBackground: Color(0xFFE7EAED),
    areaBackground: Color(0xFFF2F3F5),
    areaBorder: Color(0xFFE2E2E0),
  );

  static QuadrantColors of({
    required bool isImportant,
    required bool isUrgent,
  }) {
    if (isImportant) return isUrgent ? importantUrgent : importantNotUrgent;
    return isUrgent ? notImportantUrgent : notImportantNotUrgent;
  }
}
