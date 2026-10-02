# 사용자 문서 (`users/{UID}`)

Firestore의 `users` 아래 문서 이름은 Firebase 로그인 계정의 ID(UID)라서, 콘솔에서 누가 누구인지 알 수 없었다.
문서 이름과 일기 경로는 그대로 두고, `users/{UID}` 문서에 계정을 알아볼 수 있는 정보를 적는다.

## 저장하는 필드

기존에는 `users/{UID}` 문서에 아무것도 쓰지 않았다(그 아래 `diaries`만 썼다). 아래 필드가 **새로 생긴다.**
일기 문서(`users/{UID}/diaries/*`)의 경로·ID·필드는 바뀌지 않는다.

| 필드 | 값 | 비고 |
|---|---|---|
| `supportCode` | UID 앞 8자를 대문자로 바꾼 `XXXX-XXXX` | 모든 계정에 있다. 사용자가 문의할 때 알려 주는 코드 |
| `nickname` | 앱에서 정한 닉네임 | 없으면 필드를 지운다 |
| `provider` | `google` · `apple` · `guest` · `other` | `guest`는 로그인 없이 저장할 때 만들어지는 익명 계정 |
| `email` | 계정의 이메일 | Apple은 가림 주소(`…@privaterelay.appleid.com`)이거나 없을 수 있다. 없으면 필드를 지운다 |
| `lastSeenAt` | 마지막으로 기록한 시각 | 하루에 한 번 갱신 |

## 찾는 방법 (Firebase 콘솔)

- 사용자가 문의용 코드를 알려 준 경우: `users`에서 `supportCode == A3F9-27KD`로 거른다. 로그인 방식과 무관하게 통한다.
- 이메일을 아는 경우(주로 Google): `email == …`로 거른다.
- 닉네임을 아는 경우: `nickname == …`로 거른다. 겹칠 수 있다.

## 동작

- 앱이 켜져 있는 동안 `UserDirectoryUpdater`가 계정을 지켜보고(`AccountSession.observeAccount`), 로그인한 계정의 정보를 그 계정의 문서에 쓴다.
- `setData(merge: true)`로 써서 문서의 다른 필드는 건드리지 않는다.
- 같은 계정·같은 내용은 하루에 한 번만 쓴다. 닉네임·이메일·로그인 방식이 바뀌면 바로 쓴다. 마지막으로 쓴 내용은 기기에 기억한다
  (UserDefaults `userDirectory.lastWritten.{UID}`).
- 쓰기에 실패하면(오프라인, 보안 규칙이 막는 경우) 로그만 남기고 다음에 다시 시도한다. 앱의 다른 기능은 이 문서에 의존하지 않는다.
- 설정 화면 맨 아래에 "문의용 코드"를 보여 주고, 누르면 복사한다.
- 회원 탈퇴 때 일기와 사진을 지운 뒤 `users/{UID}` 문서도 지운다. 보안 규칙이 삭제를 막으면 그대로 두고 탈퇴를 계속한다
  (그 규칙에서는 쓰기도 되지 않았을 것이다). 그 밖의 실패는 탈퇴를 멈춰 다시 시도하게 한다.

## 필요한 보안 규칙

`users/{userId}` 문서 자체에 본인의 읽기·쓰기가 허용돼 있어야 한다. `diaries` 하위 경로만 허용돼 있으면 앱이 쓰지 못한다.

```
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
  match /diaries/{diaryId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
}
```

규칙 파일은 저장소에 없다. 콘솔에서 확인해야 한다.

## 한계

- 기존 사용자의 문서는 그 사용자가 이 버전의 앱을 켤 때 채워진다. 다시 켜지 않는 사용자의 문서는 비어 있다.
- 사용자가 먼저 연락하지 않은 Apple 계정이 실제로 누구인지는 알 수 없다(Apple이 이메일을 가린다).
- 문의용 코드는 UID 앞 8자라 이론상 겹칠 수 있다(36⁸가지). 겹치면 닉네임·로그인 방식으로 구분한다.

## 확인

- 로직: `UserDirectoryTests`(코드 만들기, 계정 종류별 내용, 하루 한 번·변경 시 쓰기, 실패 후 재시도, 설정의 코드 표시).
- 확인하지 못함: 운영 Firestore에 실제로 쓰이는 것과 보안 규칙, 탈퇴 때 문서가 지워지는 것, 설정 화면의 코드 표시와 복사.
