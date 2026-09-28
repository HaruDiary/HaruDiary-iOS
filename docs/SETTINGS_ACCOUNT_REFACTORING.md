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

## 보존한 동작

- 계정 분류: 로그인 안 함 / 손님(익명 등 이메일 미인증) / 회원(Google·Apple). 기존처럼 `isEmailVerified`로 구분한다.
- 프로필 문구·이미지, 메뉴 순서, 손님일 때 로그아웃·탈퇴 행 숨김, 탈퇴 확인 문구.
- 로그아웃·탈퇴 후 `.loginstatusChanged` 알림 발송(여정 화면이 아직 사용)과 로그인 화면 표시.
- 탈퇴 시 삭제하는 것은 Firebase 계정뿐이다. 저장된 일기·사진은 기존과 같이 삭제하지 않는다.

## 구성

| 파일 | 책임 |
|---|---|
| `Domain/Account/AccountState.swift` | Firebase 사용자 정보를 Foundation 값(`AccountSnapshot`)으로 받고 계정 상태로 분류 |
| `Domain/Account/AccountSession.swift` | 계정 구독·로그아웃·탈퇴 인터페이스와 탈퇴 오류 |
| `Data/FirebaseAccountSession.swift` | Auth 리스너(해제 포함), 로그아웃, 계정 삭제·Apple 토큰 철회 |
| `Features/Settings/SettingsViewModel.swift` | 프로필 표시, 로그아웃·탈퇴 결과, 중복 탈퇴 방지 |
| `Features/Settings/SettingsModule.swift`, `+UIKit.swift` | 설정 상태와 휴지통 생성 연결 |

로그인 화면은 표시 이름 변경을 `.loginstatusChanged`로만 알린다. Auth 상태 리스너가 이 변경을 받지 못하므로
`FirebaseAccountSession`이 알림을 받아 현재 계정을 다시 전달한다. 로그인 흐름을 옮기면 제거한다.

교체 전 목록·캘린더 UIKit 화면(`DiaryListVC`, `CalendarVC`)은 의존성 없이 `SettingVC()`를 만들므로
해당 편의 생성자만 `AppDependencies.live()`를 사용한다. 두 화면을 정리할 때 함께 제거한다.

## 검증

- 로직 테스트 103개 통과: 계정 분류·프로필 문구 2개, 구독·로그아웃·탈퇴 결과 5개 추가.
- 실제 앱(시뮬레이터, 로그인된 Google 계정)에서 확인: 나의 일기·여정 탭에서 설정 진입, 프로필 표시,
  최근 삭제한 항목 → 휴지통 표시, 뒤로 가기.
- 확인하지 못한 것: 실제 계정의 로그아웃·회원 탈퇴(운영 계정 변경), 손님·로그아웃 상태의 설정 화면.
