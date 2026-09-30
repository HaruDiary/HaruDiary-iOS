//
//  EveryDiary++Bundle.swift
//  EveryDiary
//
//  Created by Dahlia on 2/28/24.
//
import Foundation

extension Bundle {
    /// The OpenWeather key from `Api.plist`, which is kept out of git (see docs/XCODE_CLOUD.md).
    /// Empty when the file or key is missing; weather then reports `.missingAPIKey` instead of crashing.
    var apiKey: String {
        guard let file = self.path(forResource: "Api", ofType: "plist"),
              let resource = NSDictionary(contentsOfFile: file),
              let key = resource["OPENWEATHERMAP_KEY"] as? String else { return "" }
        return key
    }
}
