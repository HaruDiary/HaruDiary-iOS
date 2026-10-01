# 화면 모드 (라이트·다크)

앱은 iPhone의 화면 모드를 따르고, 설정 › 화면 모드에서 라이트나 다크로 고정할 수 있다. 저장 스키마와는 관계없다.

## 구성

| 파일 | 역할 |
|---|---|
| `Domain/Appearance/AppAppearance.swift` | 시스템 설정·라이트·다크와 그 이름 |
| `Data/UserDefaultsAppearanceStore.swift` | 선택 보관(키 `appAppearance`). 모르는 값은 시스템 설정으로 본다 |
| `Features/Appearance/AppAppearanceController.swift` | 선택을 앱의 창에 적용(`overrideUserInterfaceStyle`). 나중에 만들어지는 잠금 화면 창에도 적용 |
| `Features/Appearance/AppearanceSettingsView.swift` | 설정 화면(`AppRoute.appearance`) |

창에 적용하므로 시트·전체 화면 표시·알림창이 모두 같은 모드로 보인다.

## 색

- 색은 색상 자산(`Assets.xcassets/color`)의 다크 값으로 바뀐다. 라이트 값은 그대로다.
  | 자산 | 쓰임 | 다크 값 |
  |---|---|---|
  | `mainBackground` | 화면 배경 | `#121014` |
  | `mainCell` | 카드 | `#1F1C24` |
  | `mainText` | 본문 | `#ECE9F1` |
  | `SubText` | 보조 글자 | `#A6A1AD` |
  | `mainTheme` | 제목·아이콘·강조 | `#CDB8FF` |
  | `subTheme` | 옅은 채움 | `#3D3946` |
  | `mainError` | 오류 | `#F2B8B5` |
  | `onTheme` | `mainTheme` 위의 글자 | `#21005D` (라이트는 흰색) |
- 강조색이 다크에서는 밝은 보라가 되므로, 강조색 위의 글자는 흰색 대신 `DiaryTheme.Colors.onBrand`(`onTheme`)를 쓴다.
- 쓰기 버튼은 다크에서 밝은 그림(`writeLight`)을 쓴다. 어두운 그림은 어두운 화면에서 묻힌다.
- 캘린더의 일기 줄 날씨는 `DiaryWeatherIcon`으로 그린다(검은 선 그림 자산은 다크에서 보이지 않는다).

## 라이트로 두는 화면

- 온보딩과 로그인 화면은 삽화가 밝은 배경으로 그려진 불투명 이미지라 라이트로 고정한다(`preferredColorScheme(.light)`).
- 여정의 그림(월별 그림·연도별 도시)은 자체 색을 써서 모드와 관계없이 같다.

## 확인

- 로직: `AppTextSizeTests`의 화면 모드 테스트(보관, 창 적용).
- 화면: 시뮬레이터에서 앱 설정을 다크로 두고 일기 목록을 확인했다. 나머지 화면과 시스템 모드를 따르는 경우는
  실기기에서 확인한다(시뮬레이터 iOS 26.5는 시스템 화면 모드가 바뀌지 않았다).
