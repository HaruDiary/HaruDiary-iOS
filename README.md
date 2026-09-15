# HaruDiary iOS

기존 [HexaDiary](https://github.com/NBC-HexaDiary/HexaDiary)의 `dev` 브랜치
(`082f53ae2c85d9b6762490f4c5c15def3cfee5ca`)를 기반으로 하는 리팩토링 출발점입니다.
기존 UIKit 화면과 Firebase 데이터 흐름을 유지합니다.

## 빌드

1. Xcode에서 `EveryDiary/EveryDiary.xcodeproj`를 엽니다.
2. Swift Package Manager 의존성 다운로드를 기다립니다.
3. `EveryDiary` 스킴과 iOS 시뮬레이터를 선택하고 빌드합니다.

```sh
xcodebuild -project EveryDiary/EveryDiary.xcodeproj \
  -scheme EveryDiary -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/harudiary-derived-data \
  build CODE_SIGNING_ALLOWED=NO
```

Firebase 10.21의 오래된 바이너리 프레임워크는 최근 Xcode의 번들 검증에 실패합니다.
Firebase와 Google Sign-In을 갱신하고, FirebaseFirestore로 통합된
FirebaseFirestoreSwift 패키지 참조를 제거했습니다.
정확한 의존성 버전은 `Package.resolved`에 저장됩니다.

## 기존 Firebase 연결

Firebase 설정 파일은 공개 저장소에 포함하지 않습니다. 앱 실행에는 실제 설정이 필요합니다.

1. 기존 Firebase 콘솔 → 프로젝트 설정 → 내 앱에서 번들 ID
   `com.HexaDiary.EveryDiary`인 iOS 앱을 선택합니다.
2. `GoogleService-Info.plist`를 다운로드해 `EveryDiary/EveryDiary/`에 저장합니다.
3. Xcode에서 해당 파일을 추가하고 `EveryDiary` Target Membership을 체크합니다.
   Build Phases → Copy Bundle Resources에 파일이 포함되어야 합니다.

설정 파일 없이 빌드할 수 있지만 `FirebaseApp.configure()`에서 앱 실행이 중단됩니다.
기존 Google 로그인 URL scheme은 유지했습니다. 다른 Firebase 앱의 설정을 사용하지 마세요.
날씨 기능을 사용하려면 `Api.plist`의 빈 `OPENWEATHERMAP_KEY`도 로컬에서 설정해야 합니다.
키를 채운 파일을 커밋하지 마세요.

실기기 빌드는 Signing & Capabilities에서 본인의 Apple Development Team을 선택해야 합니다.
