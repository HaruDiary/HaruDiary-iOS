import Foundation

@MainActor
protocol DiaryReadingRepository {
    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error>
}

@MainActor
protocol DiaryUserSession {
    func observeUserIDs() -> AsyncStream<String?>
}
