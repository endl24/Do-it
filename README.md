# Do-it
2026-2 고급모바일 프로그래밍 프로젝트

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
    └── home/
        ├── home_screen.dart
        └── widgets/    # 이 화면에서만 쓰는 위젯
```

### 규칙
- 새 화면은 `screens/<화면이름>/<화면이름>_screen.dart`로 만들고, 클래스 이름은 `XxxScreen`으로 합니다.
- 한 화면에서만 쓰는 위젯은 그 화면 폴더의 `widgets/`에, 두 화면 이상에서 쓰면 `lib/widgets/`로 옮깁니다.
- 파일 이름은 `snake_case.dart`, 클래스 이름은 `PascalCase`로 씁니다.
- 화면 단위로 작업을 나누면 서로 다른 파일을 수정하게 되어 머지 충돌이 줄어듭니다.
- `app.dart`, `core/` 같은 공용 파일을 수정할 때는 팀원에게 먼저 알립니다.
