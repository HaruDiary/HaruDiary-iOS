# 설정·계정 리팩토링

설정 화면(`SettingVC`)의 계정 상태 표시·로그아웃·회원 탈퇴를 Firebase Auth 직접 호출에서 분리했다.
화면은 기존 UIKit 그대로 두고 상태와 결과만 `SettingsViewModel`에서 받는다. 로그인(`LoginVC`)의
Google·Apple 연결 흐름은 다음 PR 범위다.

## 기존 동작과 바뀐 점

| 기존 | 원인 | 변경 |
|---|---|---|
| 설정을 열 때와 로그인 알림마다 Auth 리스너를 새로 등록하고 해제하지 않음 | `observeAuthState()` 반복 호출 | 계정 구독 하나를 화면 수명에 묶고, 설정을 닫으면 해제 |
| 회원 탈퇴 실패(재로그인 필요·네트워크)에도 "회원 탈퇴가 완료되었습니다" 표시 | 삭제 결과를 기다리지 않음 | 삭제가 끝난 뒤 결과대로 완료/재로그인 안내/실패 표시 |
| 탈퇴 완료 알림을 로그인 화면을 띄운 뒤 표시해 알림이 보이지 않을 수 있음 | 표시 순서 | 알림 확인 후 로그인 화면 표시(로그아웃과 동일) |
| Apple 탈퇴 시 토큰 철회 후 계정 삭제 | 순서 | 계정 삭제 성공 후 토큰 철회. 삭제 실패 시 Apple 로그인 유지 |
| 로그아웃 실패에도 완료 알림 | 결과 미확인 | 실패 시 실패 알림 |
| 설정 진입마다 사용자 이름을 콘솔에 출력 | 디버그 출력 | 제거 |
| 휴지통이 `AppDependencies.live()`를 새로 생성 | 설정이 의존성을 받지 않음 | 탭에서 받은 의존성으로 설정·휴지통 생성 |
| 탈퇴해도 일기·사진이 서버에 남음(확인 문구는 삭제된다고 안내) | 계정만 삭제 | 사진 → 일기 문서 → 계정 순서로 삭제. 하나라도 실패하면 계정을 남기고 재시도 안내 |

## 보존한 동작

- 계정 분류: 로그인 안 함 / 손님(Google·Apple 연결 없음) / 회원. Google·Apple이 연결됐거나 이메일이 인증되면 회원이다.
  기존에는 이메일 인증만 봐서, 손님이 Apple을 연결한 뒤 이메일이 미인증으로 남으면 계속 손님으로 보였다.
- 프로필 문구·이미지, 메뉴 순서, 손님일 때 로그아웃·탈퇴 행 숨김, 탈퇴 확인 문구.
- 로그아웃·탈퇴 후 `.loginstatusChanged` 알림 발송(여정 화면이 아직 사용)과 로그인 화면 표시.

## 회원 탈퇴 순서

1. 토큰을 새로 받아 서버 시각 기준으로 마지막 로그인 후 3분이 지나지 않았는지 확인한다. 지났으면 아무것도 지우지 않고
   "로그아웃 후 다시 로그인" 안내를 표시한다. Firebase는 약 5분이 지난 로그인으로는 계정 삭제를 거부하므로,
   삭제 시간을 남겨 두고 시작한다. 기기 시계가 틀려도 영향을 받지 않는다.
2. 서버에서 `users/{uid}/diaries`를 읽어 사진 URL의 파일과 Storage `{uid}/` 폴더의 파일을 지운다.
   이미 없는 파일은 삭제된 것으로 본다. 폴더 목록 조회가 네트워크 등으로 실패하면 멈춘다(계정 유지).
   Storage 규칙이 목록 조회를 허용하지 않을 때만 일기에 연결된 사진만 지우고 계속한다. 이때 남는 파일은 관리 스크립트가 찾는다.
3. 사진이 하나라도 남으면 멈춘다(계정 유지, 재시도 가능). 모두 지워졌으면 일기 문서를 400개씩 일괄 삭제한다.
4. 같은 계정으로 로그인된 다른 기기가 그사이 저장했을 수 있으므로, 다시 읽어 아무것도 없을 때까지 2~3단계를 반복한다
   (최대 3회). 계속 새 데이터가 생기면 멈추고 계정을 남긴다.
5. Firebase 계정을 삭제한다. Apple은 그 뒤 토큰을 철회하고 로그아웃한다.
   삭제가 오래 걸려 Firebase가 재로그인을 요구하면, 일기·사진은 이미 지워졌다고 알리고 다시 로그인 후 한 번 더
   누르도록 안내한다(재시도 시 빈 계정만 삭제).

진행 중에는 설정 화면에 진행 표시를 띄우고 다른 조작과 뒤로 가기를 막는다.

**남은 한계**: 앱만으로는 "데이터 삭제와 계정 삭제"를 한 번에 처리할 수 없다. 마지막 반복과 계정 삭제 사이에 다른
기기가 저장하면 그 기록이 남을 수 있고, 삭제가 매우 오래 걸리면 계정 삭제가 재로그인 요구로 한 번 실패할 수 있다.
완전히 막으려면 서버 측 삭제(Firebase "Delete User Data" 확장 또는 Cloud Function)가 필요하다. 남은 데이터는
`scripts/admin/withdrawn-account-data.mjs`로 확인·정리할 수 있다.

## 이미 탈퇴한 계정의 남은 데이터

Firestore에는 탈퇴 표시가 없다. 일기나 사진은 있는데 Firebase Auth에 더 이상 없는 사용자 ID를 탈퇴(또는
로그인 연결 시 삭제된 익명) 계정으로 판단한다. 앱은 다른 사용자의 데이터를 읽을 수 없으므로 프로젝트 소유자가
서비스 계정으로 `scripts/admin/withdrawn-account-data.mjs`를 실행한다.

- 기본은 개수만 출력하는 확인 실행이다. 사용자 ID는 앞 6자만, 일기 내용·이메일은 출력하지 않는다.
- `--delete`를 붙이면 확인 실행에서 나온 계정의 사진 파일과 일기 문서를 지운다. 지우기 직전에 계정이 여전히
  없는지 다시 확인한다. `UnknownUser/` 아래 파일은 개수만 알리고 지우지 않는다.
- 서비스 계정 키 파일은 커밋하지 않는다.
- 손님이 이미 가입된 Google·Apple 계정으로 전환하면 앱이 남은 손님 계정을 지우려 하지만, Firebase의 최근 로그인 요구로 실패하는
  경우가 많다(앱은 그 손님 계정으로 다시 로그인할 수 없다). 스크립트는 Google·Apple 연결이 없고 오래(기본 180일, `--guest-days=`)
  쓰지 않은 손님 계정도 개수로 보여 주고, `--delete-inactive-guests`를 붙이면 데이터와 Auth 계정을 함께 지운다. 지우기 직전에
  여전히 쓰지 않는 손님인지 다시 확인한다.

## 로그인 흐름 (Google·Apple)

로그인 화면은 Google·Apple 화면을 띄워 자격 증명만 받고, 계정 연결·전환은 `SocialSignIn`이 정한다.
설정 화면 자체도 목업 16번 기준 SwiftUI(`SettingsView`)로 교체했다. 프로필·알림·잠금·휴지통·로그아웃·탈퇴와 버전을 보여 주며,
알림·잠금 행에는 현재 설정(예: "매일 오후 9:00", "암호 · Face ID")을 표시한다.
개인정보 처리방침(노션 페이지, `AppLinks.privacyPolicy`)은 앱 안 Safari 화면으로 연다. 동작과 문구는 `SettingsViewModel`을 그대로 쓰고,
`SettingsHostingController`는 탭의 UIKit 내비게이션에 화면을 넣고 Apple 재확인·로그인 화면만 띄운다. 기존 `SettingVC`는 교체된 UIKit 탭에서만 참조한다.
설정에서 여는 로그인 화면은 SwiftUI(`Features/SignIn`)로 교체했다. `SignInView`는 표시만 하고,
`SignInViewModel`이 로그인 결과·닉네임 입력·실패 안내를 정하며, `SignInHostingController`가 Google·Apple 화면을 띄운다.
실패 문구는 게이트웨이가 Firebase 오류 코드를 `SignInFailure`로 분류해 정한다. 기존 `LoginVC`는 참조가 없으며 대체 흐름을
실제 계정으로 확인한 뒤 삭제한다.

| 현재 상태 | 동작 |
|---|---|
| 로그인 안 함 / 회원 | 해당 Google·Apple 계정으로 로그인 |
| 손님(익명) | 손님 계정에 Google·Apple을 연결해 일기를 그대로 유지하고 이름을 저장 |
| 손님인데 그 Google·Apple 계정이 이미 가입됨 | 기존 계정으로 로그인한 뒤 남은 손님 계정 삭제(기존과 동일, 손님 일기는 옮기지 않음) |

| 기존 | 변경 |
|---|---|
| Google 연결이 네트워크 오류 등으로 실패해도 손님 계정을 삭제해 손님 일기에 다시 접근할 수 없게 됨 | 이미 가입된 계정일 때만 전환. 그 외 실패는 손님 계정 유지 |
| 손님 계정을 먼저 지운 뒤 기존 계정 로그인. 로그인이 실패하면 로그아웃 상태로 남음 | 기존 계정 로그인이 성공한 뒤 손님 계정 삭제 |
| Apple 연결이 실패해도 성공으로 처리하고 화면을 닫음 | 실패로 표시 |
| 로그인 실패 시 아무 안내 없음(버튼을 눌러도 반응이 없는 것처럼 보임) | 실패 알림과 오류 코드 표시. 같은 이메일의 다른 로그인 방식, 네트워크 오류는 안내 문구 구분 |
| Apple 응답이 예상과 다르면 앱 종료(`fatalError`) | 실패 알림 |
| 로그인 중 버튼을 다시 누를 수 있음 | 진행 표시, 버튼 비활성화 |

### 닉네임과 로그인 방식 표시

- 프로필 카드: 닉네임, 그 아래 로그인 방식(`Google로 로그인`/`Apple로 로그인`)과 이메일 두 줄. Apple "이메일 가리기" 주소는
  `이메일 가림`, 이메일이 없으면 로그인 방식 한 줄만 표시. 닉네임이 없으면 `닉네임을 설정해주세요`.
- 로그인 상태에서 프로필 카드(연필 아이콘)를 누르면 "프로필 편집" 화면에서 프로필 이미지와 닉네임을 함께 바꾼다.
  닉네임은 앞뒤 공백을 빼고 1~20자(보이는 글자 기준). 잘못된 닉네임이면 저장 버튼이 꺼지고 이유를 표시한다.
- 기본 프로필은 처음 만든 Google·Apple 로그인 프로필 그림(남색 테두리, 노란 머리)을 24×24 격자 그대로 벡터로 다시 그리고,
  배경·몸 색만 다른 6종(라벤더·민트·살구·분홍·하늘·보라)을 더한 8종이다. 사진을 고르지 않으면 Google 로그인은 초록(Google),
  Apple 로그인은 파랑(Apple) 기본 프로필이 보인다. 손님은 회색.
  선택값은 Firebase Auth 사진 URL(`harudiary-avatar://…`)에 저장하고, 앞선 테스트 빌드의 저장값(purple·moon 등)도 가까운 색으로 읽는다.
- 사진·기본 프로필만 바꾸면 계정 정보(닉네임·이메일)는 그대로라, 계정만 관찰하던 설정 화면이 갱신되지 않았다(Swift 6.2
  Observation은 같은 값이면 알리지 않음). 프로필 사진도 관찰하고, 방금 올린 사진은 다시 받지 않고 바로 표시한다.
- 앨범 사진: 편집 화면의 "앨범에서 사진 선택"으로 1장을 고르면 가운데 정사각형으로 잘라 최대 512px JPEG로 다시 저장해
  (위치 등 원본 메타데이터 제거) 미리보기에만 반영하고, "저장"을 누를 때 올린다.
  순서: `{uid}/profile-<고유값>.jpg` 업로드 → Auth 프로필 변경 → 예전에 올린 프로필 사진 삭제. 업로드나 프로필 변경이
  실패하면 새 파일을 지우고 이전 프로필을 유지하며, 편집 화면을 닫지 않고 다시 시도하게 한다. 저장 중에는 버튼·닫기를 막는다.
  사진 파일은 일기 사진과 같은 `{uid}/` 폴더 바로 아래에 두어 탈퇴 시 함께 지워진다.
- 사진 URL 중 앱 Storage의 `{uid}/profile-…` 파일만 "올린 사진"으로 본다. Google 계정 사진이나 일기 사진 주소는 기본 이미지로 본다.
  사진 주소에는 접근 토큰이 있어 기록하지 않는다.
- 올린 프로필 사진은 기기에도 둔다(`ProfilePhotoFiles`, 캐시 폴더의 `ProfilePhoto/`, 한 장만). 설정을 열 때 내려받지 않고 바로 그린다.
  - 방금 올린 사진은 올린 JPEG를 그대로 보관한다. 다른 기기에서 올렸거나 캐시가 비워졌으면 한 번 내려받아 보관한다.
  - 파일 이름은 사진의 Storage 경로다. 사진을 바꾸면 경로가 달라져 이전 파일을 읽지 않는다. 접근 토큰은 이름에 쓰지 않는다.
  - 로그아웃·탈퇴하거나 기본 프로필로 바꾸면 보관한 사진을 지운다. 설정이 닫혀 있는 동안의 자동 로그아웃(Apple 자격 증명 폐기)에서도
    지워지도록, 앱이 켜져 있는 동안 계정을 지켜보는 `ProfilePhotoKeeper`가 지운다.
  - 설정 화면은 열릴 때의 계정(`AccountSession.currentAccount`)으로 바로 그린다. 이전에는 첫 관찰 값이 오기 전까지
    로그인 전 모습이 잠깐 보였다.
- 기존 `googleProfile`·`appleProfile` 이미지 자산은 참조를 없앴고, 앱 확인 후 별도로 삭제한다.
- 손님에서 가입(연결)한 직후에는 항상, 그 외 로그인은 닉네임이 없을 때 닉네임 입력을 묻는다. "나중에"로 건너뛸 수 있다.
- 닉네임은 Firebase Auth 표시 이름에 저장한다. 일기 데이터·스키마는 바뀌지 않는다.

프로필 이름·이메일은 계정 값이 비어 있으면 연결된 Google·Apple 로그인 정보의 값을 사용한다. 손님에 Apple을 연결하면
계정 자체에는 이메일이 없을 수 있다. Apple은 이름을 처음 로그인할 때만 전달하므로, 이미 이 앱에 Apple 로그인을 허용한 적이
있으면 이름이 없어 "사용자"로 표시된다(iPhone 설정 → Apple 계정 → 로그인 및 보안 → Apple로 로그인에서 앱 연결을 해제하면
다음 로그인 때 다시 전달된다).

같은 이메일로 Google·Apple 계정을 하나씩 만들 수 없는 Firebase 설정("이메일당 계정 하나")에서는, Apple 계정을 탈퇴한 뒤
같은 이메일의 Google 계정이 남아 있으면 Apple로 새로 가입할 수 없다. 이때 안내 문구로 기존 방식 로그인을 요청한다.

## 보안 보강

| 항목 | 이전 | 변경 |
|---|---|---|
| Apple refresh token 보관 | `UserDefaults` 평문(`refreshToken`) | 보관하지 않음(Firebase가 탈퇴 시 새 인증 코드로 철회). 남은 토큰은 앱 시작 시 삭제 |
| 탈퇴 시 Apple 연결 해제 | URL 쿼리로 토큰을 직접 만든 함수에 전송 | Apple 재확인 후 Firebase `revokeToken`, 탈퇴 후 Apple 사용자 ID 삭제 |
| iPhone 설정에서 Apple 로그인 "삭제" | 앱은 계속 로그인 상태 | 앱 활성화·해제 알림 시 Apple에 확인해 "해제됨"이면 로그아웃. 개발팀 서명이 없는 시뮬레이터 빌드는 Apple이 항상 "해제됨"으로 답해 건너뜀 |
| 푸시 기기 토큰 | 콘솔 출력 | 출력하지 않음 |

남은 항목:
- Firestore·Storage 보안 규칙은 2026-09-29 "자기 uid 경로만 허용, 나머지 차단"으로 게시하고 규칙 플레이그라운드에서
  자기 경로 허용·다른 사용자 경로 거부를 확인했다(이전 규칙은 로그인한 누구나 모든 데이터 접근 가능).
- Apple 토큰 철회는 Firebase 기본 기능으로 바꿨다. Apple 회원이 탈퇴하면 Apple 로그인 창으로 한 번 더 확인하고
  (Firebase 재인증), 받은 일회용 인증 코드로 `Auth.auth().revokeToken(withAuthorizationCode:)`를 호출해 Apple 연결을 끊은 뒤
  일기·사진·계정을 삭제한다. 철회가 실패하면 아무것도 지우지 않는다. 기존 Cloud Function(`getRefreshToken`·`revokeToken`) 호출과
  기기의 refresh token 보관은 없앴다(남아 있던 토큰은 앱 시작 시 삭제). Apple 사용자 ID만 Keychain에 보관한다.
  필요한 설정: Apple Developer의 Sign in with Apple 키(.p8)와 Firebase Authentication › Apple › "OAuth 코드 흐름 구성".
  2026-09-29 휴대폰에서 Apple 계정 탈퇴·연결 해제를 확인한 뒤 기존 함수 두 개를 Google Cloud 콘솔에서 삭제했다(주소가 404 응답).
- 프로젝트에는 Firebase "Delete User Data" 확장(`ext-delete-user-data-*`, asia-northeast3)이 설치돼 있다. 계정 삭제 시 서버에서
  사용자 데이터를 정리하므로, 앱의 탈퇴 전 삭제와 겹쳐도 문제가 없다. 확장의 삭제 대상 경로 설정은 콘솔 Extensions에서 확인한다.

## 구성

| 파일 | 책임 |
|---|---|
| `Domain/Account/AccountState.swift` | Firebase 사용자 정보를 Foundation 값(`AccountSnapshot`)으로 받고 계정 상태로 분류 |
| `Domain/Account/AccountSession.swift` | 계정 구독·로그아웃·탈퇴 인터페이스와 탈퇴 오류 |
| `Data/FirebaseAccountSession.swift` | Auth 리스너(해제 포함), 로그아웃, 계정 삭제·Apple 토큰 철회 |
| `Domain/Account/AccountDeletion.swift` | 최근 로그인 확인 → 데이터 삭제 → 계정 삭제 순서와 단계별 실패 구분 |
| `Data/FirebaseUserDataEraser.swift` | 사용자 일기 문서·사진 파일 삭제 |
| `Data/FirebasePhotoFiles.swift` | 사진 파일 삭제(휴지통 영구 삭제와 공유) |
| `Domain/Account/SocialSignIn.swift` | 로그인·손님 연결·기존 계정 전환 규칙 |
| `Data/FirebaseSocialSignInGateway.swift` | Firebase 로그인·연결·전환·이름 저장 |
| `Domain/Account/Nickname.swift` | 닉네임 규칙(공백 제거, 1~20자) |
| `Setting/NicknameAlert.swift` | 로그인 직후 닉네임 입력 창 |
| `Domain/Account/ProfileAvatar.swift` | 기본 프로필 색상과 저장 값(이전 값 호환) |
| `Domain/Account/ProfilePicture.swift` | 기본 아바타/올린 사진 구분, 편집 화면 선택값 |
| `Features/Settings/ProfilePhotoPreparation.swift` | 앨범 사진 정사각형·크기 제한·JPEG 재인코딩 |
| `Domain/Account/ProfilePhotoStoring.swift`, `Data/ProfilePhotoFiles.swift` | 올린 프로필 사진의 기기 보관 |
| `Features/Settings/ProfilePhotoLoader.swift` | 보관한 사진을 바로 주고, 없으면 한 번 내려받아 보관 |
| `DesignSystem/ProfileAvatarView.swift` | 프로필 이미지 그림(SwiftUI, 설정 셀용 이미지 변환) |
| `Features/Settings/ProfileEditView.swift` | 프로필 이미지·닉네임 편집 화면(SwiftUI) |
| `Domain/Account/AppleRefreshTokenStore.swift` | Apple 사용자 ID 보관 규칙(`AppleSignInSecrets`), 예전 토큰 삭제 |
| `Data/KeychainSecretStore.swift` | Keychain 저장 |
| `Setting/AppleAuthorizationRequest.swift` | Apple 로그인 창(로그인·탈퇴 확인 공용, nonce 1회 사용) |
| `Data/AppleSignInRecords.swift` | Apple 사용자 ID 보관·삭제, 예전 refresh token 정리 |
| `Data/AppleCredentialMonitor.swift` | Apple 로그인 해제 감지와 로그아웃 |
| `Features/Settings/SettingsViewModel.swift` | 프로필 표시, 로그아웃·탈퇴 결과, 중복 탈퇴 방지 |
| `Features/Settings/SettingsModule.swift`, `+UIKit.swift` | 설정 상태와 휴지통 생성 연결 |

로그인 화면은 표시 이름 변경을 `.loginstatusChanged`로만 알린다. Auth 상태 리스너가 이 변경을 받지 못하므로
`FirebaseAccountSession`이 알림을 받아 현재 계정을 다시 전달한다. 로그인 흐름을 옮기면 제거한다.

교체 전 목록·캘린더 UIKit 화면(`DiaryListVC`, `CalendarVC`)은 의존성 없이 `SettingVC()`를 만들므로
해당 편의 생성자만 `AppDependencies.live()`를 사용한다. 두 화면을 정리할 때 함께 제거한다.

## 검증

- 로직 테스트 130개 통과: 계정 분류·프로필 문구 2개, 구독·로그아웃·탈퇴 결과 5개, 탈퇴 순서 4개, 로그인 흐름 6개, 손님 Apple 연결 분류 1개, 닉네임·로그인 방식 표시 5개, 프로필 이미지·사진 6개, 토큰 보관·응답·Apple 상태 5개 추가.
- 실제 앱(시뮬레이터, 로그인된 Google 계정)에서 확인: 나의 일기·여정 탭에서 설정 진입, 프로필 표시,
  최근 삭제한 항목 → 휴지통 표시, 뒤로 가기.
- 확인하지 못한 것: 실제 계정의 로그아웃·회원 탈퇴와 데이터 삭제(운영 계정 변경), 손님·로그아웃 상태의 설정 화면,
  Storage 규칙에서 폴더 목록 조회·프로필 사진 업로드 허용 여부, 실제 사진 업로드·교체·재시작 후 표시·다른 기기 표시, 관리 스크립트 실행(서비스 계정 필요).

## 일기 내보내기

설정 › 일기 내보내기(`AppRoute.export`, `DiaryExportScreen`)는 로그인한 계정의 일기를 텍스트 파일 하나로 만들어 시스템 공유 시트에 넘긴다.

- 형식(`DiaryExport`): 오래된 일기부터, 날짜·시각, 기분·날씨 이름, 제목, 내용. 사진은 넣지 않고 몇 장인지만 적는다.
  사진 주소는 접근 토큰이 있어 넣지 않는다. 휴지통의 일기와 날짜를 읽을 수 없는 일기는 빠진다.
- 파일은 임시 폴더에 `하루일기-yyyyMMdd.txt`로 만들고(파일 보호 적용), 화면을 나가거나 계정이 바뀌면 지운다.
- 서버에는 아무것도 쓰지 않는다.
