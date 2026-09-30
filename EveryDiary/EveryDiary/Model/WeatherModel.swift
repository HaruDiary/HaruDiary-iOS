//
//  WeatherModel.swift
//  EveryDiary
//
//  Created by Dahlia on 2/27/24.
//
import Foundation

struct WeatherResponse: Decodable, Equatable {
    let weather: [Weather]
    let main: Main
}

struct Main: Decodable, Equatable {
    let temp: Double
}

struct Weather: Decodable, Equatable {
    let description: String
}
