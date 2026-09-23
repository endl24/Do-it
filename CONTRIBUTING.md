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

## PR 올리기 전
```bash
cd app
flutter analyze
flutter test
```
