# 안 쓰는 코드 정리

SwiftUI 화면으로 교체가 끝난 뒤, 앱 시작 지점(`AppDelegate`, `SceneDelegate`)에서 닿지 않는 코드와 자원을 삭제했다.
다른 문서에 남아 있는 아래 이름들은 당시 기록이며, 현재 코드에는 없다.

## 삭제한 것

| 구분 | 내용 |
|---|---|
| 옛 UIKit 화면 | 작성(`WriteDiaryVC`와 날짜·감정 선택, 사진·지도 셀, `KeyboardManager`, `ImagePickerManager`, `DiaryWriteRetention`), 목록(`DiaryListVC`와 셀·헤더), 캘린더(`CalendarVC`, `CalendarListVC`), 휴지통(`TrashVC`), 설정(`SettingVC`, `LoginVC`와 셀), 알림(`NotificationVC`와 셀), 잠금(`LockVC`, `SetFaceID`), 온보딩(`StartVC`, `PageVC`, `ContentVC`), 여정(`HonorVC`, `DetailVC`, `BuildingView`와 창문·경로 캐시) |
| 안 쓰는 로직 | `DiaryPhotoReplacement`(과 테스트), `PaginationManager`, `MapManager`, `Model/DataModel.swift`의 셀·사진 모델, `DiaryManager`의 조회·검색·삭제 메서드 |
| 패키지 | SnapKit, Lottie. 나머지 패키지 버전은 그대로다 |
| 자원 | 번들 폰트(`Font/` 20개, 110MB)와 `UIAppFonts`, 안 쓰는 이미지·색상 45개(약 64MB) |

## 함께 고친 것

- 일기를 저장할 때마다 전체 일기 구독이 하나씩 추가되고 해제되지 않던 것을 없앴다(`DiaryManager.storeNewDiary`).
- 썸네일(`ImageCacheManager`)은 원본 대신 320px로 줄여 디코딩하고, 캐시에 24MB 상한을 두며, 같은 주소의 동시 요청을 한 번의 다운로드로 합친다. 실패 로그에 사진 주소를 남기지 않는다.
- 여정 화면은 SnapKit 대신 기본 오토레이아웃, 번들 폰트 대신 시스템 폰트를 쓴다.
- 주소 조회는 `CLGeocoder`를 직접 쓴다.

## 결과

- Swift 소스 약 7774줄 감소. 시뮬레이터 Debug 빌드의 앱 크기 96MB → 39MB.
- 저장 스키마와 화면 동작은 바꾸지 않았다.
