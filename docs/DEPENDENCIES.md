# 공통 의존성 관리

## 목적과 범위

앱이 사용할 서비스의 생성 위치를 앱 진입 계층으로 모으고, 기능은 필요한 인터페이스를 주입받는다.
첫 적용 대상은 Calendar의 일기 조회·사용자 세션·이미지 로더·날짜 환경이다.
기존 Firebase 저장 형식·쿼리·인증 동작과 UIKit 탐색을 보존한다.

## 생성과 전달 경로

`SceneDelegate` → `AppDependencies.live()` → `TabBarController` → `CalendarModule` → `CalendarHostingController`

| 구성 | 책임 |
|---|---|
| `App/AppDependencies.swift` | 조회·세션·이미지 로더·Calendar·현재 시각 의존성을 보관하고 기능을 생성 |
| `App/AppDependencies+Live.swift` | 운영 Firebase 및 기존 이미지 캐시를 연결 |
| `Features/Calendar/CalendarModule.swift` | 전달받은 서비스로 독립적인 화면 상태 생성 |
| `Features/Calendar/CalendarModule+UIKit.swift` | 생성한 상태와 이미지 로더를 UIKit hosting controller에 연결 |

운영 의존성은 `AppDelegate`의 Firebase 초기화 이후 scene 연결 시 생성한다.
같은 의존성으로 여러 모듈을 만들더라도 화면 상태는 각각 새로 생성된다.
서비스 생성은 구독 시작이 아니다. 관찰 시작·종료 책임은 기존 화면 상태에 남는다.

## 적용 원칙

- 운영 Firebase와 이미지 캐시 연결은 앱 조립 지점에서 생성한다.
- 기능 내부에서 Firebase 기본 인스턴스나 전역 의존성 컨테이너를 다시 조회하지 않는다.
- 화면에는 필요한 의존성만 전달한다. 화면 상태와 구독 작업 자체를 전역으로 공유하지 않는다.
- 테스트에는 같은 생성 경로로 fake 서비스와 고정 날짜를 전달한다.
- 기존 SDK singleton을 감싸는 새 전역 singleton이나 DI 프레임워크를 추가하지 않는다.
- 다음 기능을 분리할 때 기존 읽기·세션 계약을 재사용하고, 쓰기·사진·날씨는 실제 사용처가 생길 때 경계를 추가한다.

## 후속 범위

일기 목록·작성·여정 등 기존 UIKit의 서비스 직접 접근, 이미지 다운로드 취소,
날씨 설정과 오류 처리, 데이터 쓰기 경계는 후속 작업이다.
공통 색상·타이포 기준은 기존 `DiaryTheme`를 출발점으로 별도 정리한다.

Calendar의 Firebase 디코딩은 현재 문서 하나가 실패하면 전체 구독을 실패시키는 문제가
기존 PR 리뷰에서 지적되었다. 의존성 생성 위치 변경과 별도로 동작 재현과 회귀 테스트가 필요하다.
[기존 리뷰](https://github.com/HaruDiary/HaruDiary-iOS/pull/1#discussion_r4016577753)

## 검증

- 변경 전 기존 테스트 27개 통과, 변경 후 30개 통과.
- 운영 조립 경로에 고정 시각·시간대·이미지 로더가 전달되는지 확인한다.
- 모듈 생성만으로 구독하지 않고, 모듈별 화면 상태가 독립적인지 확인한다.
- 주입된 사용자/저장소의 기록 조회·로그아웃과 사용자 변경 후 현재 시각 재평가를 검증한다.
- 이 검증은 fake 서비스를 사용한다. 운영 Firebase의 인증·저장·사진 통합 검증을 대신하지 않는다.
- 실제 로컬 Firebase 설정으로 iPhone 17 Pro / iOS 26.5 앱 빌드·실행을 확인했다. 캘린더 탭 진입, 빈 상태, 2026년 9월 → 8월 이동을 확인했다. 로그인·저장·실사진 흐름은 이번 실행 검증에 포함하지 않았다.
