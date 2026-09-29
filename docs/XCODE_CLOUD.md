# Xcode Cloud · TestFlight 배포

Xcode Cloud가 저장소를 받아 앱을 아카이브하고 TestFlight 내부 테스트로 올린다.
테스터는 iPhone의 TestFlight 앱에서 새 빌드를 받는다.

## 저장소에 들어 있는 것

- `EveryDiary/ci_scripts/ci_post_clone.sh`: 클론 직후 비밀 환경 변수 `GOOGLE_SERVICE_INFO_PLIST_BASE64`를
  `GoogleService-Info.plist`로 복원한다. 값은 로그에 출력하지 않고, plist 형식과 번들 ID를 확인한다.
- 앱 타깃의 자동 서명 팀: `UP9KCDW7ZZ`(HexaDiary). 팀원은 이 팀에 멤버로 초대돼 있어야 실기기 빌드가 된다.
- `GoogleService-Info.plist`는 계속 git에 올리지 않는다. 저장소는 공개 저장소다.

## 처음 한 번 설정 (App Store Connect / Xcode)

1. **Firebase 설정 값 등록**
   - 터미널에서 실제 파일을 base64로 바꿔 클립보드에 복사한다(화면에 출력되지 않음).
     `base64 -i EveryDiary/EveryDiary/GoogleService-Info.plist | pbcopy`
   - Xcode › Report Navigator › Cloud › 워크플로 편집 › **Environment › Environment Variables**에
     이름 `GOOGLE_SERVICE_INFO_PLIST_BASE64`, 값 붙여넣기, **Secret** 체크.
2. **워크플로**
   - Start Conditions: `dev` 브랜치 변경 시(또는 수동 시작).
   - Actions: **Archive – iOS**, Scheme `EveryDiary`, Deployment Preparation **TestFlight (Internal Testing Only)**.
   - Post-Actions: **TestFlight Internal Testing** → 내부 테스트 그룹 선택.
   - (선택) Actions에 **Test – iOS**(Scheme `EveryDiaryLogicTests`, iPhone 시뮬레이터) 추가.
3. **App Store Connect › TestFlight**
   - 내부 테스트 그룹을 만들고 본인과 팀원 Apple 계정을 추가한다(App Store Connect 사용자여야 함).
   - 처음 올라온 빌드는 수출 규정(암호화) 질문에 답해야 테스트할 수 있다.
4. **iPhone**: App Store에서 TestFlight 앱을 설치하고, 테스터로 등록한 Apple 계정으로 로그인한다.

## 빌드 번호

Xcode Cloud가 빌드마다 번호를 자동으로 올린다(`CI_BUILD_NUMBER`). 앱 버전(`MARKETING_VERSION`)은 프로젝트에서 올린다.

## 문제 해결

- `GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set`: 1번 환경 변수가 없거나 다른 워크플로에만 있다.
- `different bundle identifier`: 다른 앱의 Firebase 설정 파일을 넣었다.
- 서명 오류: App Store Connect에 `com.HexaDiary.EveryDiary` 앱이 팀 `UP9KCDW7ZZ`로 등록돼 있는지,
  Apple 로그인·푸시 기능이 켜져 있는지 확인한다.
