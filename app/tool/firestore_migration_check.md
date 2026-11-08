# Firestore 저장소·SQLite 이관 확인 (#77)

## 적용 범위와 저장 구조

- 로그인 전: 기존 `SqliteTodoRepository`와 `do_it.db`를 사용한다.
- 로그인 후: `users/{uid}/todos/{id}`의 Firestore 저장소와 Android·iOS SDK의 기본 영구 오프라인 캐시를 사용한다.
- `Todo` 모델, 기존 SQLite 표와 `TodoListScreen` 파일은 변경하지 않는다. 새 연결 화면 `AccountTodoScreen`에서 저장소를 준비하고 기존 화면에 주입한다.
- 이관 상태는 별도 `do_it_migration.db`에 저장한다. 이관 중에만 원본 스냅샷을 보관하며, 서버 확인과 원본 정리가 끝나면 스냅샷을 비우고 완료 표시만 남긴다.
- 첫 로그인에 기존 로컬 데이터를 같은 ID로 이관한다. 재로그인 때 이미 정리한 데이터는 다시 이관하지 않는다. 로그아웃 후 새로 작성한 로컬 항목이 있으면 다음 로그인에 그 항목만 이관한다.

## 이관 실패와 계정 변경

1. 대상 계정과 원본 스냅샷을 로컬에 기록한다.
2. 한 건씩 서버 트랜잭션으로 같은 ID에 저장한다. 기존 서버의 더 최신 값이나 삭제 기록은 보존한다.
3. 모든 서버 요청이 확인된 뒤 완료 표시를 기록한다.
4. 스냅샷과 동일한 SQLite 원본만 삭제하고 이관 스냅샷을 비운다.

중간 실패 시 원본과 진행 기록은 보존하고 같은 계정에서 재개한다. 계정이 바뀌면 이전 계정의 이관을 중단하며, 미완료 원본을 다른 계정에 옮기지 않는다. 최초 이관은 서버 확인을 위해 온라인이어야 한다. 이미 이관을 마친 계정은 오프라인 캐시를 사용할 수 있다.

## 충돌과 삭제

- Firestore `updatedAt`(Timestamp)으로 비교한다. 모델의 `updated_at`은 조회 시 이 값으로 맞춘다.
- 일반 수정은 더 오래된 시각이면 클라이언트 캐시 검사와 서버 규칙에서 거부한다. 동일 시각이면 서버에 나중에 반영된 쓰기를 허용한다.
- 시각은 기기에서 생성하므로 기기 시계가 크게 다르면 최신 수정 판단에 영향을 준다. 테스트 기기는 자동 날짜·시간을 사용한다.
- 삭제는 물리 삭제하지 않고 `deleted: true`와 삭제 토큰을 남긴다. 따라서 더 늦게 도착한 일반 수정으로 되살아나지 않는다.
- 기존 실행 취소 기능은 같은 저장소 세션에서 발급한 삭제 토큰을 `restoredFrom`으로 전달할 때만 복구한다. 다른 삭제로 토큰이 바뀌면 이전 실행 취소는 거부한다.
- 오프라인 저장은 SDK의 로컬 반영 확인 후 반환한다. 아직 서버에 반영되지 않은 문서는 `pending`, 서버 확인 후에는 `synced`로 읽는다. 나중에 서버에서 거절한 쓰기는 다음 조회에서 실패 상태로 표시한다.

## 보안 규칙 적용 — 실제 프로젝트에서는 아직 별도 진행

저장소 루트의 `firestore.rules`를 Firebase 콘솔 → Firestore Database → 규칙에 적용한다. 기존 규칙이 있다면 먼저 비교하며, 다른 서비스의 규칙을 임의로 덮어쓰지 않는다. 이번 규칙은 본인 UID의 `todos`만 허용하고 다른 경로는 기본 거부한다. 로그인 기능만으로는 다른 계정의 문서에 접근할 수 없다.

CLI로 적용할 경우 프로젝트 선택을 명시한다. 실제 프로젝트 ID는 문서나 Git에 적지 않는다.

```powershell
firebase deploy --only firestore:rules --project 실제프로젝트ID
```

로컬 규칙 검사에는 실제 프로젝트를 사용하지 않는다. Python 3, Firebase CLI와 Java 21 환경에서 저장소 루트에서 실행한다.

```powershell
firebase emulators:exec --only firestore --project demo-do-it-rules "python app/tool/firestore_rules_check.py"
```

## 앱 확인

```powershell
cd app
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
```

1. 로그아웃 상태에서 구분할 수 있는 할 일을 추가하고 앱을 종료·재시작한다. 로컬 할 일이 유지되는지 확인한다.
2. 온라인으로 로그인한다. 할 일 탭에서 같은 항목이 보이고 콘솔의 해당 UID 아래 같은 ID의 문서가 생기는지 확인한다.
3. 로그아웃 시 기존 계정의 서버 목록이 보이지 않는지 확인한다. 다시 로그인하면 서버 목록이 보이고 중복 문서가 생기지 않아야 한다.
4. 이관 완료 후 네트워크를 끄고 추가·수정·완료·삭제한다. 입력이 서버 응답을 기다리며 멈추지 않아야 한다.
5. 오프라인 상태로 앱을 재시작해 캐시가 유지되는지 확인한다. 연결을 복구하고 콘솔에서 반영을 확인한다.
6. 삭제 기록과 오래된 수정의 충돌 및 실행 취소를 확인한다. 물리 삭제 대신 `deleted: true` 문서가 남는 것이 정상이다.

## 아직 이 작업으로 완료하지 않는 부분

- 실제 프로젝트 보안 규칙 적용과 Android 실기기·에뮬레이터의 오프라인 재전송 확인은 자동 단위 테스트와 별도다.
- 화면의 실시간 구독·당겨서 서버 새로고침·오프라인 감지·대기 배지 갱신은 #78에서 연결한다. 두 기기 전체 검증과 제출용 스크린샷은 #79에서 진행한다.
- 팀 공유·회원 탈퇴의 전체 데이터 삭제는 이번 범위가 아니다.
- Firebase 설정 값과 로컬 데이터 파일은 커밋하지 않는다. 도구 실행으로 생긴 `*-debug.log`도 커밋하지 않는다.

## 참고

- 모바일앱주제.pdf 5쪽: #2109 미니프로젝트 #3
- prompts_log.md 51번: 로그인 전 SQLite, 첫 로그인 이관, 이후 Firestore 캐시 사용
- Firebase 오프라인 캐시: https://firebase.google.com/docs/firestore/manage-data/enable-offline
- 트랜잭션: https://firebase.google.com/docs/firestore/manage-data/transactions
- 보안 규칙: https://firebase.google.com/docs/firestore/security/rules-conditions
