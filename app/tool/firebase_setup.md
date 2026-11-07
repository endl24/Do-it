# Firebase 기본 연결 (#75)

## 로컬 설정

`app` 폴더에서 `.env.example`을 `.env`로 복사한다. 파일은 JSON 형식이며 실제 값은 Firebase 프로젝트 설정에서 확인한다.

- `FIREBASE_PROJECT_ID`: 프로젝트 ID
- `FIREBASE_MESSAGING_SENDER_ID`: 프로젝트 번호
- `FIREBASE_ANDROID_API_KEY`: Android 앱의 API 키
- `FIREBASE_ANDROID_APP_ID`: Android Firebase 앱 ID (패키지 이름과 다름)
- `FIREBASE_IOS_API_KEY`: iOS 앱의 API 키
- `FIREBASE_IOS_APP_ID`: iOS Firebase 앱 ID
- `FIREBASE_IOS_BUNDLE_ID`: 등록한 iOS 번들 ID

Android와 iOS 앱은 같은 프로젝트를 사용해도 앱 ID가 다르므로 구분해서 입력한다. iOS 설정은 Mac 담당자가 채우고 실제 빌드를 확인한다. Android만 실행할 때 iOS 항목은 빈 문자열로 둘 수 있다.

```powershell
Copy-Item .env.example .env
flutter run --dart-define-from-file=.env
```

`.env`가 이미 있으면 복사해 덮어쓰지 않고 기존 파일을 편집한다. 설정을 변경한 뒤에는 앱을 완전히 종료하고 다시 실행한다.

## 설정 없이 실행

```powershell
flutter run
```

현재 플랫폼의 Firebase 설정이 전혀 없으면 Firebase를 초기화하지 않고 기존 SQLite 앱을 실행한다. 일부 설정만 입력했거나 초기화가 실패하면 오류를 알리며 성공한 것처럼 처리하지 않는다. 웹·데스크톱 Firebase 초기화는 이번 범위에서 제외한다.

현재 Android 최소 버전은 Flutter 기본 API 24, iOS 배포 대상은 15.0이다. 설치한 Firebase 패키지의 최소 버전(API 24, iOS 15.0)을 만족한다. iOS 실제 빌드 확인은 Mac에서 진행한다.

## 검증과 제출

```powershell
flutter analyze
flutter test
git check-ignore .env
git check-ignore .env.example
```

마지막 명령은 `.env.example`이 무시되지 않으므로 출력 없이 종료 코드 1을 반환하는 것이 정상이다. `.env`, `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`는 커밋하지 않는다. `.env.example`에는 빈 값만 남긴다.

이번 단계는 기본 초기화만 구현한다. 계정 인증(#76), Firestore 저장소·이관(#77), 화면 동기화(#78)는 후속 작업이다. 초기화만으로 기존 SQLite 할 일이 서버에 저장되지는 않는다.
