# UIKit → SwiftUI 전환 준비

## 기본 원칙

UIKit 앱에서 쓰던 코드를 모두 폐기하는 작업이 아니다. 기능과 데이터는 보존하면서,
표현 기술에 묶인 부분을 찾아 화면·레이아웃·상태 연결을 단계적으로 교체한다.
SwiftUI도 UIKit 뷰/컨트롤러를 연결할 수 있다. UIKit 타입이 있다는 이유만으로 제거하지 않는다.

아래 표는 현재 소스를 확인한 **전환 계획**이다. 대체 구현과 정리는 아직 하지 않았다.
담당 배정과 새 마을 상세 기획은 별도 논의한다.

## 1. 현재 코드 분류

파일 경로는 `EveryDiary/EveryDiary/` 기준이다.

| 구분 | 기존 구성 / 근거 | 처리 방향 |
|---|---|---|
| 재사용 + 책임 분리 | Firebase SDK, `RemoteDB/FireStore.swift`·`PaginationManager.swift` | 서버와 문서 형식은 유지. 조회/저장 계약과 오류·구독 수명 분리 |
| 재사용 + 타입 분리 | `Model/DataModel.swift`의 `DiaryEntry`, 날짜 formatter | 저장 DTO와 순수 모델/날짜 유틸 분리. 같은 파일의 UIImage·셀 모델을 Domain에 넣지 않음 |
| 재사용 | `Assets.xcassets`의 colorset·감정/날씨/사진 등 이미지 | SwiftUI에서도 자산 사용 가능. 실제 사용처와 목업을 비교해 이름/의미를 정리 |
| 공통 기준 정리 | `Font/`, `Info.plist`의 UIAppFonts, 여러 VC의 `UIFont(name:size:)` | 표시 역할별 타이포 정의. 시스템 폰트/커스텀 폰트 선택과 Dynamic Type 기준 합의 |
| 교체 | UIViewController, UITableView/UICollectionView cell, delegate | SwiftUI View·List·LazyVGrid 등으로 기능별 전환. delegate의 비즈니스 로직은 먼저 분리 |
| 교체 후 제거 | 각 화면의 SnapKit·Auto Layout | SwiftUI stack/layout/modifier로 전환. UIKit 화면이 남아 있는 동안 SnapKit 유지 |
| 교체 | `TabBarController.swift`, 각 UINavigationController, `SceneDelegate.swift` | TabView·NavigationStack·sheet 경로 및 상태 소유권 설계. 기존 뒤로 가기/로그인 URL 연결 보존 |
| 분리 후 교체 | `WriteDiary/KeyboardManager.swift` | UIScrollView·SnapKit constraint 조작은 가져오지 않음. SwiftUI 키보드 회피·FocusState를 우선 검증 |
| 연결 후 단계적 교체 | `WriteDiary/ImagePickerManager.swift` | PhotosPicker 대체 가능성 검증. 기능 동등성이 부족하면 PHPicker를 representable로 연결 |
| 분리 후 연결 | `WriteDiary/MapManager.swift` | 위치/주소 조회와 권한 상태는 서비스로 분리. 지도 표현은 SwiftUI Map 또는 기존 MKMapView 연결 |
| 재사용 + 수명 정리 | `Service/SetFaceID.swift`, 알림 등록 및 인증 관련 코드 | LocalAuthentication·UserNotifications·Firebase/Google 로그인은 계속 사용. 표시/상태 전달만 분리 |
| 분리 후 교체 | `DiaryList/TemporaryAlert.swift`, VC의 UIAlertController | 오류·확인 메시지 데이터와 표시를 구분. alert/confirmationDialog/일시 메시지 컴포넌트로 연결 |
| 재사용 + 인터페이스 정리 | `DiaryList/ImageCacheManager.swift`의 NSCache·다운로드 | SwiftUI라고 캐시가 없어지지 않음. 캐시 정책·취소·오류를 분리. AsyncImage로 기계적으로 대체하지 않음 |
| 상태 연결 교체 | `AppEvents/NotificationName.swift`의 로그인 이벤트와 delegate 콜백 | 소유자가 있는 세션/화면 상태로 전달. 시스템 notification까지 무조건 제거하지 않음 |
| 후속 판단 | `Motivation/BuildingView.swift`, BezierPath/이미지 캐시 | 현재 조회/집계와 그리기 결합은 분리 대상. 새 마을 렌더링 기술/기능은 이번에 확정하지 않음 |
| 정리 후보 | `DiaryList/Extensions.swift` | 현재 import만 있는 파일. 타깃/사용 확인 후 별도 정리 |
| 공통으로 추출 후보 | `DiaryList/DiaryListVC.swift` 안의 `Array.safeFetch` | 실제 사용처와 의미를 확인해 필요한 경우 `Shared/Extensions/Collection+SafeAccess.swift`로 이동 |
| 의존성 정리 후보 | 프로젝트의 Lottie 패키지 연결 | 현재 앱 Swift 소스 검색에서 Lottie 사용을 찾지 못함. 전체 참조/리소스 확인과 빌드 후 제거 여부 결정 |

**정리 후보는 곧바로 삭제할 목록이 아니다.** 폰트·이미지·패키지는 Xcode 타깃,
Info.plist, 문자열 기반 자산 참조까지 확인한다. 대체 호출부가 동작한 후 별도 커밋으로 제거한다.

## 2. 첫 단계에서 준비할 공통 기반

화면 완성은 마지막이지만, 아래 기준은 로직 작업과 화면 전환의 공통 출발점이다.
전체 UI 라이브러리를 미리 만들지 않고 실제로 필요한 최소 집합부터 만든다.

| 항목 | 현재 상태 | 준비할 결과 |
|---|---|---|
| 색상 | mainTheme, mainBackground, mainCell, mainText, SubText 등 자산은 존재 | 브랜드/배경/표면/본문/보조/오류처럼 역할별 이름과 기존 자산 매핑. UIKit/SwiftUI에서 같은 자산 사용 |
| 타이포 | SFPro 이름과 크기를 화면별 직접 지정 | 제목/본문/보조/버튼 기준, 굵기, Dynamic Type. 폰트 파일은 사용 여부 확인 후 정리 |
| 여백·형태 | 화면별 layout/shadow 설정 | 공통 spacing·radius·아이콘 크기·터치 영역 기준. 목업에 근거해 값 결정 |
| 날짜·시간 | DataModel의 formatter와 화면 내부 날짜 함수 | 저장용 parse/encode와 표시용 포맷을 구분. Calendar·TimeZone·현재 시각을 테스트에서 지정 가능하게 함 |
| 공통 함수 | helper가 VC 내부에 있거나 여러 책임의 파일에 섞임 | 사용처가 있는 작은 함수만 책임별 파일로 이동. 거대한 Utils/Extensions.swift는 만들지 않음 |
| 오류·입력 | callback, nil, alert가 혼재 | 오류 전달과 사용자 메시지 분리. 필수 입력·중복 저장·취소 기준을 테스트 가능하게 정의 |
| 설정·의존성 | Bundle.apiKey, singleton, SDK 접근 | 설정 읽기와 누락 오류, 필요한 서비스 주입 경계. 실제 키는 로컬에 유지 |
| 상태 소유권 | VC와 delegate/NotificationCenter 중심 | 로컬 UI 상태 / 기능 상태 / 앱 세션의 소유자를 구분. 화면마다 ViewModel을 의무 생성하지 않음 |
| 검증용 데이터 | 현재 6개 모델 테스트 | 개인정보 없는 정상/빈/오류 fixture. 나중에 같은 데이터로 Preview와 화면 검증 |

색상은 이미 있다고 해서 정리 완료가 아니다. `SubText`처럼 이름 규칙이 섞여 있고,
라이트/다크 항목 존재와 실제 대비·표현 품질은 별도로 확인해야 한다.
SwiftUI용 색상 값을 새로 복사하지 않고 같은 Asset Catalog를 공유하는 방향을 우선한다.

## 3. 지금 준비할 것 / 화면 전환 때 만들 것

**먼저:** 전환 목록, 데이터 계약 테스트, 역할별 색상·타이포·여백 기준,
공통 날짜/설정/오류 책임, 상태 소유권, fixture, 기존 자산 매핑.
필요한 최소 토큰 구현과 검증용 Preview는 공통 기반 작업이며 앱 화면 교체와 구분한다.

**화면 전환 시:** ButtonStyle·일기 카드·입력 sheet·빈/오류 표시 등 실제 반복 요소,
탐색과 모달 연결, 기능별 View. 첫 사용처와 함께 만들고 실제 두 번째 사용처에서 공통성을 검증한다.

이 구분으로 “로직 먼저, 뷰 마지막”을 지키면서도 화면 개발 직전에 색상·폰트부터
각자 다르게 만드는 상황을 피한다.

## 4. 일반적인 진행 방식

1. **현황과 의존성 분류:** 무엇이 UI 기술에 묶여 있고 무엇이 재사용 가능한지 확인한다.
2. **최소 공통 기반과 동작 고정:** 자산/규칙/테스트를 맞춘다. 전체 폴더를 미리 재편하지 않는다.
3. **기능 단위로 로직 분리:** 기존 UIKit이 새 로직을 사용하게 연결한다.
4. **작은 기능에서 연결 방식 검증:** 화면 교체 단계가 되면 목록/상세부터 SwiftUI로 전환한다.
5. **나머지 화면에 확대:** 사진·작성·키보드처럼 복잡한 입력 흐름은 동등성 확인 후 전환한다.
6. **사용하지 않는 코드 정리:** 기존 화면, delegate, constraint, 패키지를 참조 확인 후 제거한다.

공통 규칙과 기존 동작은 유지하되, UI 기술의 차이를 무시하고 VC 메서드를 그대로 View에
복사하지 않는다. UIKit 연결이 필요하면 작고 명시적인 adapter로 한정한다.

## 5. 기능을 잃기 쉬운 지점

- 사진: 현재 최대 3장, 선택 순서, 재선택 ID, 촬영 날짜/위치와 사용 동의 흐름이 있다.
  피커 변경 시 각각 확인한다. 메타데이터가 없는 사진/제한된 권한도 검증한다.
- 키보드: 포커스 이동, 작성 중 스크롤, 저장 버튼 가림, 화면 이탈 후 초안.
- 이미지: 캐시/프리페치, 느린 네트워크, 취소 후 잘못된 셀 이미지 표시.
- 인증: 익명 데이터, 기존 로그인, 콜백 URL, 로그아웃 후 listener와 화면 상태.
- 날짜: 기존 저장 offset, 월 경계, 표시 지역 설정과 저장 포맷 분리.
- 잠금/알림: 앱 복귀와 인증 취소, 권한 거부 후 화면, 알림 시간 유지.

## 준비 단계 완료 기준

- [ ] 재사용·분리·교체·연결·정리 후보를 구분했다.
- [ ] 공통 색상/타이포/여백과 자산 이름의 기준을 합의했다.
- [ ] 공통 함수가 실제 사용처와 책임별로 분류됐다.
- [ ] 데이터 계약 테스트와 플랫폼 기능의 검증 항목이 있다.
- [ ] UIKit/SwiftUI 공존 중 중복 상태·중복 저장을 만들지 않을 연결 방식을 정했다.

## 근거

- [Apple: UIKit integration](https://developer.apple.com/documentation/swiftui/uikit-integration)
- [Apple: UIKit 색상을 SwiftUI Color로 연결](https://developer.apple.com/documentation/swiftui/color/init(uicolor:))
- [Apple: Observation 전환](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Apple: SwiftUI Photos picker](https://developer.apple.com/documentation/photokit/bringing-photos-picker-to-your-swiftui-app)
