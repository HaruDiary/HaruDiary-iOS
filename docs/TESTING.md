# 테스트와 CI

## 현재 실행되는 검증

| 검사 | 실제 범위 | 포함하지 않는 것 |
|---|---|---|
| Logic tests | 운영 일기 모델 6개, Calendar 날짜/그리드 10개, fake 기반 상태·사용자 전환·구독 수명 11개: 총 27개 XCTest | Firestore SDK의 Codable 동작, 서버 읽기/쓰기, 실제 로그인, 마을 규칙, 실제 UI 동작 |
| Simulator build | `EveryDiary` 앱의 Debug 시뮬레이터 컴파일·링크·번들 검증 | 앱 실행, 운영 Firebase 연결, 실기기 서명, App Store archive |

`EveryDiaryLogicTests`는 hostless XCTest 타깃이다. 앱을 실행하지 않고 운영 소스 파일을
직접 컴파일하므로 Firebase 설정 파일이 필요 없다. 테스트용 모델 사본은 없다.
실제 `Domain/DiaryEntry.swift`, Calendar 로직, Repository 프로토콜, 날짜 formatter와
`CalendarViewModel.swift`를 컴파일하며 UIKit 모델 파일의 기존 테스트 타깃 연결은 제거했다.
새 파일을 폴더에 추가하는 것만으로 Xcode 타깃에 자동 연결되지는 않는다.

## 로컬 실행

필요 도구: Xcode 26.6, 설치된 iOS 시뮬레이터, macOS 기본 bash/ruby/rsync.

```sh
bash scripts/ci.sh test
bash scripts/ci.sh build
```

활성 개발자 경로가 CommandLineTools라면 전역 설정을 바꾸지 않고 명령 앞에
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 지정할 수 있다.

Calendar의 화면 동작과 오프라인 검증 범위는 [Calendar 리팩토링](CALENDAR_REFACTORING.md)을 참고한다.

- test: 부팅된 iPhone 시뮬레이터 우선, 없으면 설치된 iPhone을 선택한다.
- 특정 기기는 `HARUDIARY_SIMULATOR_ID=<UDID> bash scripts/ci.sh test`로 지정한다.
- 결과 기본 위치: `${TMPDIR:-/tmp}/harudiary-ci`.
- `HARUDIARY_CI_OUTPUT=/tmp/harudiary-check`로 결과 폴더를 지정할 수 있다.
  결과 폴더는 저장소 밖에 둔다.
- `.xcresult`를 Xcode에서 열면 테스트별 결과를 볼 수 있다.
- build: 임시 프로젝트 복사본에 작동하지 않는 CI용 Firebase plist를 만들고 컴파일한다.
  실제 로컬 설정 파일을 덮어쓰지 않으며, 해당 빌드의 앱을 실행하거나 배포하지 않는다.
- 처음 실행하면 Swift 패키지를 다운로드한다. `Package.resolved`의 버전만 사용한다.
- 기존 DerivedData에 다른 SDK 버전이 남아 이상이 발생하면 해당 결과 폴더의 DerivedData만
  정리한 뒤 다시 실행한다. 다른 프로젝트의 캐시는 지우지 않는다.

## GitHub Actions

`.github/workflows/ci.yml`은 `dev` 대상 PR, `dev` push, 수동 실행에서 동작한다.
macOS 26 / Xcode 26.6에서 두 job을 독립 실행한다. 저장소 secrets와 운영 Firebase 없이
fork PR에서도 실행할 수 있다. 토큰은 contents 읽기 권한만 사용한다.
실패 시에도 로그와 XCTest 결과를 7일간 artifact로 보관한다. 빌드 앱과 실제 설정 파일은 업로드하지 않는다.

확인 위치: GitHub → Actions → iOS CI. PR 검사명은 `Logic tests`, `Simulator build`다.
두 job의 성공은 앱 전체 기능 검증을 뜻하지 않는다. 현재 테스트 범위를 위 표에 명시했다.

## 앞으로 추가할 테스트 순서

1. 날짜/월 경계 및 기존 저장 DTO fixture.
2. fake Repository 기반 조회·검색·페이지 전환·오류 처리.
3. 저장/수정·사진 일부 실패·휴지통 복원·중복 요청.
4. 화면 상태의 로딩·오류·입력 보존·취소.
5. Firebase Emulator 기반 저장·인증 전환·동시 쓰기 통합 테스트.
6. SwiftUI 전환 후 작성 → 조회 → 캘린더 등 기존 UI 흐름.\n\n마을 관련 테스트는 후속 기획 확정 후 추가한다.

월 전환은 기기의 실제 날짜를 변경하지 않고 고정 시각/달력 주입으로 검증한다.
서버가 필요한 검증은 테스트 프로젝트/Emulator로 분리하고 운영 일기를 변경하지 않는다.

## 참고

- [GitHub macOS 26 runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
- [Workflow 구문](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
