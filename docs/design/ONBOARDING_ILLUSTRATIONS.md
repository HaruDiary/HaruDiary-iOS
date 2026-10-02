# 온보딩 목업 이미지

> 이 문서의 이미지 자산은 더 쓰지 않는다. 온보딩 그림은 `OnboardingIllustration`이 앱의 색으로 그리며
> ([온보딩](../ONBOARDING_REFACTORING.md)의 "내용과 그림 갱신"), `Assets.xcassets/OnboardingMockup`은 삭제했다.
> 아래는 이전 이미지를 만든 기록이다.

사용자 요청에 따라 새 목업 `redesign-v2/05-onboarding.png`의 중앙 그림 5장을 그대로 사용한다.
새 그림을 생성하거나 기존 앱 스크린샷으로 바꾸지 않았다. 이전에 생성했던 토끼 일러스트는 앱 자산에서 제거했다.

## 추출 기준

원본 PNG는 2073 × 758 픽셀이다. CoreGraphics `CGImage.cropping(to:)`로 각 페이지의 중앙 그림 영역만 추출했다.
색상·내용을 수정하거나 확대 재생성하지 않았다. 상태 막대·기기 테두리·제목·하단 버튼은 포함하지 않는다.

모든 crop은 상단 기준 y=170, width=334, height=320이며 x 좌표는 다음과 같다.

| 페이지 | 자산 이름 | x |
|---|---|---|
| 기록 | onboarding-mockup-record | 60 |
| 불빛 | onboarding-mockup-light | 468 |
| 여정 | onboarding-mockup-journey | 877 |
| 캘린더 | onboarding-mockup-revisit | 1285 |
| 보관 | onboarding-mockup-keep | 1694 |

저장 경로는 `EveryDiary/EveryDiary/Assets.xcassets/OnboardingMockup/<자산 이름>.imageset/scene.png`다.
화면에서는 원본 비율을 유지하며 표시한다. 원본이 합쳐진 목업 PNG라서 독립 고해상도 자산보다 선명도에 한계가 있다.
기존 UIKit의 `onBoarding1`~`onBoarding5`는 해당 화면의 참조가 남아 있어 유지한다.
