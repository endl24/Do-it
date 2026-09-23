# 협업 규칙

## 작업 흐름
1. 이슈 생성 (템플릿 사용)
2. `main`에서 브랜치 생성: `git switch -c feat/12-login main`
3. 작업 후 커밋 & 푸시 → PR 생성 (본문에 `close #12`)
4. CI 통과 + 팀원 1명 승인 후 **Squash and merge**
5. 머지 후 로컬 `main` 최신화: `git switch main && git pull`

`main`에 직접 push하지 않습니다.

## 브랜치 이름
`타입/이슈번호-간단한-설명` 예) `feat/12-login`, `fix/20-list-crash`

## 커밋 메시지
`타입: 내용` 예) `feat: 로그인 화면 추가`

| 타입 | 용도 |
| --- | --- |
| feat | 기능 추가 |
| fix | 버그 수정 |
| refactor | 동작 변화 없는 코드 개선 |
| style | 포맷팅 등 |
| docs | 문서 |
| test | 테스트 |
| chore | 설정, 패키지 등 기타 |

## 코드 컨벤션
[Effective Dart](https://dart.dev/effective-dart/style)를 기본으로 따릅니다. 아래 규칙 중 대부분은 `flutter analyze`와 `dart format`이 자동으로 검사하고, CI에서 걸리면 머지할 수 없습니다.

### 포맷
- 모든 코드는 `dart format`으로 정렬합니다. 에디터에서 **저장할 때 자동 포맷**을 켜 두세요.
  - VS Code: 설정에서 `Editor: Format On Save` 켜기
  - Android Studio: Settings → Tools → Actions on Save → `Reformat code` 체크
- 문자열은 작은따옴표(`'`)를 씁니다.

### 이름 짓기
| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 파일, 폴더 | snake_case | `todo_list_screen.dart` |
| 클래스, enum | PascalCase | `TodoListScreen` |
| 변수, 함수, 상수 | camelCase | `todoCount`, `maxLength` |
| private 멤버 | `_` 접두사 | `_controller` |
| bool | `is`, `has`, `can`으로 시작 | `isDone`, `hasError` |
| 화면 위젯 | `Screen`으로 끝남 | `HomeScreen` |

- 상수도 `MAX_LENGTH`가 아니라 `maxLength`로 씁니다 (Dart 스타일).
- 줄임말은 피합니다: `btn` → `button`, `idx` → `index`.

### 위젯
- 바뀌지 않는 위젯에는 `const`를 붙입니다.
- `build` 메서드가 길어지면(100줄 정도) `Widget _buildXxx()` 함수보다는 **별도 위젯 클래스**로 분리합니다.
- 상태가 필요 없으면 `StatelessWidget`을 씁니다.
- 색상, 글자 크기는 직접 쓰지 말고 `Theme.of(context)`나 `core/`에 정의된 값을 씁니다.

### import
- `lib/` 안의 파일끼리는 상대 경로(`'../models/todo.dart'`)로 import합니다.
- 순서: `dart:` → `package:` → 상대 경로. 그룹 사이에 빈 줄 하나.

### 기타
- `print` 대신 `debugPrint`를 씁니다.
- 안 쓰는 코드, 주석 처리한 코드는 지우고 올립니다 (Git에 기록이 남아 있습니다).
- 주석은 코드만 봐서는 이유를 알 수 없을 때만 씁니다.
- 나중에 할 일은 `// TODO(이름): 내용` 형식으로 남깁니다.
- 새 패키지를 추가할 때는 팀원에게 먼저 알립니다.

## PR 올리기 전
```bash
cd app
dart format .
flutter analyze
flutter test
```
