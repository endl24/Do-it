/// 사진에서 인식한 한 줄. 후보 검토 화면(07)에서 할 일로 등록할지 고른다.
class TodoCandidate {
  const TodoCandidate({required this.text, this.isLikelyTitle = false});

  final String text;

  /// `이번 주 할 일`처럼 제목으로 보이는 줄. 기본으로 선택하지 않는다.
  final bool isLikelyTitle;
}

/// 글머리표(`-`, `•`, `1.` 등)를 떼고 빈 줄을 뺀 뒤 후보로 바꾼다.
///
/// 글머리표가 있는 줄이 하나라도 있으면, 글머리표 없는 첫 줄은 제목으로 본다.
List<TodoCandidate> candidatesFromLines(List<String> lines) {
  final bulletPattern = RegExp(r'^\s*([-–—•·*□☐▪]|\d+[.)])\s*');
  final bulleted = <bool>[];
  final texts = <String>[];
  for (final line in lines) {
    final text = line.replaceFirst(bulletPattern, '').trim();
    if (text.isEmpty) continue;
    bulleted.add(bulletPattern.hasMatch(line));
    texts.add(text);
  }
  final hasBullets = bulleted.contains(true);

  return [
    for (var i = 0; i < texts.length; i++)
      TodoCandidate(
        text: texts[i],
        isLikelyTitle: i == 0 && hasBullets && !bulleted[i],
      ),
  ];
}
