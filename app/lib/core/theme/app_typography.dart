import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 폰트 패밀리. 파일은 `assets/fonts/`에 있고 `pubspec.yaml`에 등록되어 있다.
///
/// 굵기는 Regular(400)·Bold(700)·ExtraBold(800) 세 가지만 쓴다.
/// 이 폰트의 Bold는 가늘어서, 강조는 ExtraBold로 한다.
/// 500·600은 파일이 없어 iOS에서 굵기가 어긋나게 그려지므로 쓰지 않는다.
abstract final class AppFonts {
  static const base = 'NanumSquareRound';
}

/// 글자 스타일 토큰. 크기는 설계서(390pt 기준) 글자 높이를 실제 렌더링과 맞춰 정했다.
/// 색상은 [textTheme]에서 입히므로, 직접 쓸 때는 `copyWith(color: ...)`로 지정한다.
abstract final class AppTextStyles {
  // 제목
  /// 화면 대제목: 할 일, 사분면, 팀, 설정
  static const display = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  /// 할 일 상세 제목
  static const headline = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  /// 빈 상태·권한 안내·인식 실패 제목, 캘린더 월 제목
  static const headlineSmall = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.35,
  );

  /// 카드 제목: 팀 이름, 새 팀 만들기
  static const cardTitle = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.4,
  );

  /// 상단 앱 이름 "Do it"
  static const logo = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// 초대 코드
  static const inviteCode = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: 4,
    height: 1.3,
  );

  // 본문
  /// 상단바 제목: 할 일 등록, 할 일 상세
  static const appBarTitle = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.4,
  );

  /// 할 일 카드 제목, 설정 항목 제목
  static const itemTitle = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  /// 입력칸 글자
  static const input = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 본문, 빈 상태 설명, 상세 행 값
  static const body = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 날짜 요약, 배너, 안내 박스
  static const bodySmall = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 도움말, 마지막 동기화 시각 등 보조 설명
  static const caption = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 입력칸 위 라벨, 섹션 제목
  static const fieldLabel = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  /// 기본·보조 버튼
  static const button = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  /// 필터 칩, 선택 버튼, 상태 배지
  static const chip = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// 사분면 태그
  static const tag = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  /// 하단 탭 라벨
  static const navLabel = TextStyle(
    fontFamily: AppFonts.base,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Material 컴포넌트가 기본으로 참조하는 텍스트 테마
  static final textTheme = TextTheme(
    displaySmall: display.copyWith(color: AppColors.textPrimary),
    headlineMedium: headline.copyWith(color: AppColors.textPrimary),
    headlineSmall: headlineSmall.copyWith(color: AppColors.textPrimary),
    titleLarge: appBarTitle.copyWith(color: AppColors.textPrimary),
    titleMedium: itemTitle.copyWith(color: AppColors.textPrimary),
    titleSmall: fieldLabel.copyWith(color: AppColors.textLabel),
    bodyLarge: input.copyWith(color: AppColors.textPrimary),
    bodyMedium: body.copyWith(color: AppColors.textPrimary),
    bodySmall: caption.copyWith(color: AppColors.textSecondary),
    labelLarge: button,
    labelMedium: chip,
    labelSmall: navLabel,
  );
}
