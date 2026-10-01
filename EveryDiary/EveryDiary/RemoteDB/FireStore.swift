//
//  FireStore.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/23/24.
//
import Foundation

import FirebaseAuth
import FirebaseFirestore

/// Writes diaries for `LiveDiarySaving`. Reading is done by `FirebaseDiaryReadingRepository`.
class DiaryManager {
    static let shared = DiaryManager()
    let db = Firestore.firestore()

    //MARK: 익명으로 사용자 인증하기
    func authenticateAnonymouslyIfNeeded(completion: @escaping (Error?) -> Void) {
        if Auth.auth().currentUser != nil {
            completion(nil)
        } else {
            Auth.auth().signInAnonymously { (authResult, error) in
                if let error = error {
                    print("Error signing in anonymously: \(error)")
                    completion(error)
                } else {
                    NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
                    completion(nil)
                }
            }
        }
    }

    //MARK: 일기 추가
    func addDiary(diary: DiaryEntry, userID: String, completion: @escaping (Error?) -> Void) {
        // The editor already looked the weather up while the diary was written; only look it up when it could not.
        if diary.weatherDescription != nil {
            storeNewDiary(diary, userID: userID, completion: completion)
            return
        }
        let weatherService = WeatherService()

        weatherService.getWeather(forDiaryOn: diary.date) { result in
            var weatherDescription = "Unknown"
            var weatherTemp = 0.0

            if case .success(let weatherResponse) = result {
                weatherDescription = weatherResponse.weather.first?.description ?? "Unknown"
                weatherTemp = weatherResponse.main.temp
            }

            var diaryWithWeather = diary
            diaryWithWeather.weatherDescription = weatherDescription
            diaryWithWeather.weatherTemp = weatherTemp

            if !Calendar.current.isDate(diary.date, inSameDayAs: Date()) {
                diaryWithWeather.weatherDescription = "Unknown"
                diaryWithWeather.weatherTemp = 0
            }

            self.storeNewDiary(diaryWithWeather, userID: userID, completion: completion)
        }
    }

    private func storeNewDiary(_ diary: DiaryEntry, userID: String, completion: @escaping (Error?) -> Void) {
        var newDiaryWithUserID = diary
        newDiaryWithUserID.userID = userID
        let documentReference = db.collection("users").document(userID).collection("diaries").document()
        newDiaryWithUserID.id = documentReference.documentID

        do {
            // The screens' own subscription shows the new diary; no second listener is started here.
            try documentReference.setData(from: newDiaryWithUserID) { error in
                if let error = error {
                    print("Error adding document: \(error)")
                }
                completion(error)
            }
        } catch {
            print("Error adding document: \(error)")
            completion(error)
        }
    }

    //MARK: 다이어리 업데이트
    func updateDiary(diaryID: String, newDiary: DiaryEntry, userID: String,
                     completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("users").document(userID).collection("diaries").document(diaryID).setData(from: newDiary) { error in
                if let error = error {
                    print("Error updating document: \(error)")
                }
                completion(error)
            }
        } catch {
            print("Error updating document: \(error)")
            completion(error)
        }
    }
}
