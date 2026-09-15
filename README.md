# HaruDiary iOS

기존 [HexaDiary](https://github.com/NBC-HexaDiary/HexaDiary)의 `dev` 브랜치
(`082f53ae2c85d9b6762490f4c5c15def3cfee5ca`)를 기반으로 하는 리팩토링 출발점입니다.
기존 UIKit 화면과 Firebase 데이터 흐름을 유지합니다.

## 빌드

1. Xcode에서 `EveryDiary/EveryDiary.xcodeproj`를 엽니다.
2. 아래 Firebase 설정 파일을 준비하고 Swift Package Manager 의존성 다운로드를 기다립니다.
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
3. 프로젝트에 파일 참조와 Copy Bundle Resources 연결은 이미 등록되어 있습니다.
   위 경로에 파일을 저장하면 빌드에 포함됩니다.

설정 파일은 빌드와 실행에 필요하며 `.gitignore`로 공개 저장소에서 제외됩니다.
기존 Google 로그인 URL scheme은 유지했습니다. 다른 Firebase 앱의 설정을 사용하지 마세요.
날씨 기능을 사용하려면 `Api.plist`의 빈 `OPENWEATHERMAP_KEY`도 로컬에서 설정해야 합니다.
키를 채운 파일을 커밋하지 마세요.

실기기 빌드는 Signing & Capabilities에서 본인의 Apple Development Team을 선택해야 합니다.

## 협업과 리팩토링

- [로직 우선 리팩토링 로드맵](docs/REFACTORING_ROADMAP.md)
- [UIKit → SwiftUI 전환 준비](docs/UIKIT_SWIFTUI_MIGRATION.md)
- [개발 컨벤션](docs/CONVENTIONS.md)
- [AI 공통 지침](AGENTS.md)
- [테스트 실행과 CI 범위](docs/TESTING.md)

```sh
bash scripts/ci.sh test
bash scripts/ci.sh build
```

PR과 dev push에서 일기 모델 테스트 및 시뮬레이터 빌드를 실행합니다.
CI는 운영 Firebase 설정이나 GitHub secrets 없이 동작합니다.
