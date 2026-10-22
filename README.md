# Do-it
2026-2 고급모바일 프로그래밍 프로젝트

## 팀원 및 역할
| 이름 | GitHub | UI·기능 | 백엔드·AI |
| --- | --- | --- | --- |
| 고은재 | [@eunjaego](https://github.com/eunjaego) | 할일관리 A1–A11 | **공통 데이터 모델·로컬 저장소 (A7)** |
| 강두이 | [@endl24](https://github.com/endl24) | 이미지 등록 A14–A19, 알림 A27–A33, **공용 위젯**, 공통 화면(15 확인 대화상자·실행 취소, 16 상태 표시), **화면 연결**(01·02 → 06 사진 등록 진입, 10 일정에 할 일 데이터 연결) | 온디바이스 OCR, 알림 점수·스케줄 계산, 알림 예약·취소 |
| 김형철 | [@newuser1002-bot](https://github.com/newuser1002-bot) | 일정 A12–A13, 팀·계정 A34–A41 (설정 탭 포함) | **BaaS 연동·동기화 A20–A26**, 인증, 팀 공유 |

> - A 번호는 요구사항 명세서의 기능 ID이고, 01–16은 UI 설계서의 화면 번호입니다.
> - 여러 사람의 화면에 걸쳐 담당이 정해지지 않은 화면 연결은 강두이가 맡습니다. 다른 사람의 화면 파일을 고칠 때는 그 담당자와 먼저 상의합니다.
> - 공통 데이터 모델(A7)은 모두가 쓰는 기반이므로 가장 먼저 확정합니다. `lib/models/`를 수정할 때는 고은재와 먼저 상의해 주세요.
> - 여러 화면에서 쓰는 위젯(`lib/widgets/`)은 강두이가 관리합니다. 추가하거나 수정할 때는 강두이와 먼저 상의해 주세요.

## 디자인
[Figma — Do-it](https://www.figma.com/design/W8vL6iAoammK9XX3iNv7N2/Do-it)에 요구사항 명세서와 UI 설계서(v1.2)를 옮겨 두었습니다.

| 페이지 | 내용 |
| --- | --- |
| 01 요구사항 명세 | 기능 A1–A41, 비기능 B1–B18, 제약 C1–C12 |
| 02 디자인 시스템 | 색·크기 변수, 글자 스타일, 공용 컴포넌트 |
| 03 화면 설계 | 화면 01–16과 화면별 명세 |
| 04 흐름도·오류·검토표 | 화면 흐름도, 오류 메시지 E1–E14, 요구사항 반영 검토표 |

- 색·여백·글자 크기는 `app/lib/core/theme/`의 디자인 토큰과 같은 값입니다. 한쪽을 바꾸면 다른 쪽도 함께 맞춰 주세요.
- 피그마에는 나눔스퀘어라운드가 없어 Noto Serif KR·Noto Sans KR로 대신 표시합니다.

## 기술 스택
| 구분 | 선택 | 주요 패키지 | 쓰는 곳 |
| --- | --- | --- | --- |
| 크로스플랫폼 | Flutter (Dart) | — | Android·iOS 화면을 한 벌의 코드로 |
| 로컬 저장 | SQLite | `sqflite` | 할 일 로컬 저장 (A7) |
| 백엔드 | Firebase (Firestore, Authentication) | `firebase_core`, `cloud_firestore`, `firebase_auth` | 오프라인 작성·서버 동기화 (A20–A26), 인증, 팀 공유 |
| 온디바이스 AI | ML Kit | `google_mlkit_text_recognition` (한국어 모델) | 메모 사진 글자 인식 (A14–A19) |
| | | `google_mlkit_entity_extraction` | 할 일 문장에서 마감일 추출 |
| 클라우드 AI (선택) | Firebase AI Logic + Gemini Flash | `firebase_ai` | 사분면 제안, 인식 결과 다듬기 (필요할 때 추가) |

### 선택 이유
- **Flutter**: 하나의 UI 코드로 Android·iOS에 같은 화면이 나와 UI 설계서대로 만들기 쉽고, 화면 단위로 작업을 나누기 좋습니다. Firebase와 ML Kit 모두 Flutter 패키지를 제공합니다.
- **SQLite** (대안: shared_preferences): 할 일은 중요도·긴급도·마감일·동기화 상태 등 여러 필드를 가지고 완료 여부와 마감일 순으로 정렬해야 해서, 키-값 저장보다 표 형태로 저장·조회하는 SQLite가 알맞습니다.
- **Firebase** (대안: Supabase): Firestore가 기기 캐시와 대기 쓰기를 기본으로 제공해, 오프라인에서 쓴 할 일을 연결이 돌아오면 자동으로 서버에 반영합니다. 아직 반영되지 않은 항목은 `hasPendingWrites`로 구분해 '동기화 대기'로 표시할 수 있습니다. Supabase는 같은 동작을 위해 대기 큐와 재전송·병합 로직을 직접 만들어야 합니다.
- **ML Kit**: 글자 인식과 마감일 추출을 모두 지원하고 Android·iOS에서 동작합니다. 한국어 모델이 내장되어 있어 모델을 직접 넣을 필요가 없고, 기기 안에서 무료로 동작해 오프라인에서도 쓸 수 있습니다.
- **Firebase AI Logic**: 이미 쓰는 Firebase 프로젝트에 바로 연결되어 앱에 API 키를 넣지 않아도 되고, 이미지도 입력으로 보낼 수 있어 인식 실패 시 재인식까지 처리할 수 있습니다.

### 원칙
- 외부 서비스는 무료 요금제 안에서만 사용합니다.
- 사진 글자 인식은 기기 안에서 처리하고 사진을 외부로 보내지 않습니다.
- 클라우드 AI는 온라인이고 사용자가 요청했을 때만 호출하며, 실패하면 기기에서 처리한 결과를 그대로 씁니다.

## 실행
```bash
cd app
flutter pub get
flutter run
```

## 폴더 구조
```
app/lib/
├── main.dart           # 앱 시작점 (runApp만)
├── app.dart            # MaterialApp, 테마, 라우팅
├── core/
│   ├── constants/      # 상수 (색상 코드, 문자열, 키 값 등)
│   ├── theme/          # 앱 테마
│   └── utils/          # 공용 함수 (날짜 포맷 등)
├── models/             # 데이터 클래스 (예: todo.dart)
├── services/           # 외부 연동 (API, DB, 로컬 저장소)
├── widgets/            # 여러 화면에서 같이 쓰는 위젯
└── screens/            # 화면 단위 폴더
    ├── main/           # 하단 탭 틀 (할 일·일정·팀·설정)
    └── todo_list/
        ├── todo_list_screen.dart
        └── widgets/    # 이 화면에서만 쓰는 위젯
```

### 규칙
- 새 화면은 `screens/<화면이름>/<화면이름>_screen.dart`로 만들고, 클래스 이름은 `XxxScreen`으로 합니다.
- 한 화면에서만 쓰는 위젯은 그 화면 폴더의 `widgets/`에, 두 화면 이상에서 쓰면 `lib/widgets/`로 옮깁니다.
- 파일 이름은 `snake_case.dart`, 클래스 이름은 `PascalCase`로 씁니다.
- 화면 단위로 작업을 나누면 서로 다른 파일을 수정하게 되어 머지 충돌이 줄어듭니다.
- `app.dart`, `core/` 같은 공용 파일을 수정할 때는 팀원에게 먼저 알립니다.
