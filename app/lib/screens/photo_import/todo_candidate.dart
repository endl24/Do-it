/// 사진에서 인식한 한 줄. 후보 검토 화면(07)에서 할 일로 등록할지 고른다.
class TodoCandidate {
  const TodoCandidate({required this.text, this.isLikelyTitle = false});

  final String text;

  /// `이번 주 할 일`처럼 제목으로 보이는 줄. 기본으로 선택하지 않는다.
  final bool isLikelyTitle;
}
