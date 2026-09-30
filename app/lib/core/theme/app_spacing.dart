/// 여백 토큰. 설계서는 390pt 너비 화면 기준이다.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// 화면 좌우 여백
  static const double screenHorizontal = lg;

  /// 카드 안쪽 여백
  static const double cardPadding = md;

  /// 목록 카드 사이 간격
  static const double listGap = sm;

  /// 폼 섹션 사이 간격
  static const double sectionGap = xl;
}

/// 모서리 둥글기 토큰.
abstract final class AppRadius {
  /// 태그
  static const double xs = 6;

  /// 사분면 안의 할 일 항목, 체크박스
  static const double sm = 8;

  /// 입력칸, 선택 버튼, 안내 박스, 배너
  static const double md = 12;

  /// 카드, 기본 버튼
  static const double lg = 14;

  /// 대화상자
  static const double xl = 20;

  /// 필터 칩, 상태 배지, 토글
  static const double pill = 999;
}

/// 컴포넌트 크기 토큰.
abstract final class AppSize {
  static const double buttonHeight = 52;
  static const double inputHeight = 52;
  static const double segmentHeight = 48;
  static const double chipHeight = 36;
  static const double badgeHeight = 32;
  static const double tagHeight = 24;
  static const double checkbox = 22;
  static const double fab = 56;
  static const double fabSmall = 48;
  static const double avatar = 48;
  static const double avatarSmall = 28;
  static const double iconMd = 24;
  static const double iconSm = 20;
  static const double statusDot = 8;
  static const double borderWidth = 1;
}
