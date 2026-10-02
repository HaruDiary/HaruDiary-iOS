# 홈 화면 위젯

"오늘의 일기" 위젯은 오늘 날짜와 오늘 일기를 썼는지, 그에 맞는 글귀 한 줄, 이번 달에 며칠 썼는지를 보여 준다.
작은 크기와 중간 크기가 있고, 중간 크기는 최근 7일을 함께 보여 준다. 서버 저장 스키마와는 관계없다.

## 보여 주는 것과 보여 주지 않는 것

- 위젯에는 **일기를 쓴 날짜만** 전달한다. 제목·내용·기분·사진은 전달하지 않는다. 홈 화면은 남이 볼 수 있고 앱에는 잠금이 있기 때문이다.
- 전달하는 값(`DiaryWidgetSnapshot`): 최근 62일 중 일기를 쓴 날의 목록(예: 20261002)과 그 날들이 누구의 것인지(사용자 ID, 화면에 보이지 않음).
- 휴지통의 일기와 날짜를 읽을 수 없는 일기는 세지 않는다.

## 구성

| 파일 | 타깃 | 역할 |
|---|---|---|
| `Domain/Widget/DiaryWidgetSnapshot.swift` | 앱·위젯·테스트 | 쓴 날 목록, 오늘·이번 달·최근 7일 계산(`status(on:)`), App Group 이름 |
| `Domain/Widget/DiaryWidgetSnapshot+Entries.swift` | 앱·테스트 | 일기 목록에서 쓴 날 목록 만들기. 위젯은 일기를 모른다 |
| `Data/UserDefaultsDiaryWidgetStore.swift` | 앱·위젯·테스트 | App Group의 UserDefaults에 보관(키 `diaryWidgetSnapshot.v1`) |
| `Features/Widget/DiaryWidgetUpdater.swift` | 앱·테스트 | 로그인한 사용자의 일기를 따라가며 쓴 날이 바뀔 때만 위젯을 다시 그리게 한다 |
| `Features/Widget/DiaryWidgetModule.swift` | 앱 | 조립과 `WidgetCenter` 호출 |
| `EveryDiaryWidget/` | 위젯 | 위젯 화면과 타임라인(`DiaryStatusWidget`), Info.plist, 권한 |

- 위젯은 `DiaryTheme`과 색상 자산(`Assets.xcassets`)을 앱과 함께 쓴다. 색을 따로 복제하지 않는다.
- 위젯은 iPhone의 화면 모드를 따른다. 앱 설정의 화면 모드(라이트·다크 고정)는 위젯에 적용되지 않는다.

## 동작

- 앱이 켜져 있는 동안 `DiaryWidgetUpdater`가 일기 구독을 하나 유지한다(장면이 만들고, 장면 해제 때 끝낸다).
- 쓴 날이 바뀔 때만 보관하고 위젯을 다시 그린다. 같은 날의 두 번째 일기나 수정은 위젯을 다시 그리지 않는다.
- 로그아웃하거나 다른 계정으로 바뀌면 쓴 날을 바로 비운다. 앱을 켰을 때 보관된 날들이 지금 계정의 것이 아니어도 비운다.
  같은 계정이면 일기를 다시 받을 때까지 그대로 둔다.
- "오늘"은 위젯이 스스로 계산한다. 타임라인에 지금과 앞으로 사흘 동안 글귀가 바뀌는 시각(0·6·12·18시)을 넣는다.
  자정이 그 안에 있어, 앱을 켜지 않아도 자정에 날짜가 넘어가고 "아직 쓰지 않았어요"로 바뀐다.
- 글귀(`DiaryWidgetPhrases`)는 아직 안 쓴 날용 12개와 쓴 날용 12개다. 6시간마다 바뀌고, 일기를 쓰면 쓴 날용으로 바뀐다.
  무작위처럼 보이지만 날짜와 시각에서 정해진다. 같은 시간대에 위젯이 다시 그려져도 글귀가 바뀌지 않게 하기 위해서다.
- 위젯을 누르면 앱이 열린다. 바로 일기 쓰기로 가지는 않는다.

## 설정 (개발자 계정)

- App Group `group.com.HexaDiary.EveryDiary`를 앱(`com.HexaDiary.EveryDiary`)과 위젯(`com.HexaDiary.EveryDiary.Widget`) 식별자에 연결했다.
- 두 타깃 모두 자동 서명이다. 위젯의 버전·빌드 번호는 앱과 같아야 한다(`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
- App Group이 없는 빌드(CI의 서명 없는 빌드)에서는 보관소가 비어 있는 것으로 동작하고, 아무것도 보관하지 않는다.

## 확인

- 로직: `DiaryWidgetTests`(쓴 날 목록, 오늘·월·주 계산, 자정과 월 넘김, 보관, 계정 전환 시 비우기).
- 서명: 기기용 빌드에서 앱과 위젯 모두 App Group 권한으로 서명되는 것을 확인했다.
- 화면: 위젯의 내용을 앱 안에 임시로 띄워 작은 크기와 중간 크기, 쓴 날과 안 쓴 날의 모습을 확인했다(라이트).
- 확인하지 못함: 홈 화면에 올린 위젯의 실제 모습과 다크 모드, 자정에 바뀌는 것, Xcode Cloud 배포 빌드의 서명.
