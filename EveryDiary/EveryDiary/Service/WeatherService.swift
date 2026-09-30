//
//  WeatherService.swift
//  EveryDiary
//
//  Created by Dahlia on 2/27/24.
//
import CoreLocation
import Foundation
import WeatherKit

/// Current weather at the device's location from Apple WeatherKit (needs the WeatherKit capability on the App ID).
/// Call from the main thread; the completion may run on any thread.
///
/// A fresh instance has no location yet, so a request waits for one (at most `locationTimeout`) instead of
/// failing at once. The service keeps itself alive until every waiting completion has been called, so a caller
/// that does not hold on to it (as saving a diary does) still gets an answer.
class WeatherService: NSObject, CLLocationManagerDelegate {
    static let locationTimeout: TimeInterval = 5

    private let locationManager = CLLocationManager()
    private var waiting: [(Result<WeatherResponse, WeatherError>) -> Void] = []
    private var keepAlive: WeatherService?
    private var timeout: DispatchWorkItem?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }

    /// Answers `.notToday` at once for any other day, without waiting for a location.
    func getWeather(forDiaryOn date: Date, completion: @escaping (Result<WeatherResponse, WeatherError>) -> Void) {
        guard WeatherError.appliesToDiary(on: date) else { return completion(.failure(.notToday)) }
        getWeather(completion: completion)
    }

    func getWeather(completion: @escaping (Result<WeatherResponse, WeatherError>) -> Void) {
        if let location = locationManager.location, abs(location.timestamp.timeIntervalSinceNow) < 600 {
            return fetch(at: location, completion: completion)
        }
        waiting.append(completion)
        keepAlive = self
        locationManager.requestLocation()
        if timeout == nil {
            let work = DispatchWorkItem { [weak self] in self?.finishWaiting(with: nil) }
            timeout = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.locationTimeout, execute: work)
        }
    }

    private func fetch(at location: CLLocation, completion: @escaping (Result<WeatherResponse, WeatherError>) -> Void) {
        Task {
            do {
                let current = try await WeatherKit.WeatherService.shared.weather(for: location, including: .current)
                let description = WeatherConditionText.description(condition: current.condition.rawValue, fallback: current.condition.description)
                completion(.success(WeatherResponse(description: description, celsius: current.temperature.converted(to: .celsius).value)))
            } catch {
                let kind = WeatherError.kind(of: error)
                // The kind and error type only; no location is logged.
                print("Load weather failed: \(kind) (\(type(of: error)))")
                completion(.failure(kind))
            }
        }
    }

    /// Answers every waiting request with `location`, or with `.noLocation` when there is none.
    private func finishWaiting(with location: CLLocation?) {
        timeout?.cancel()
        timeout = nil
        let completions = waiting
        waiting = []
        keepAlive = nil
        for completion in completions {
            if let location {
                fetch(at: location, completion: completion)
            } else {
                completion(.failure(.noLocation))
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !waiting.isEmpty else { return }
        finishWaiting(with: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
        guard !waiting.isEmpty else { return }
        finishWaiting(with: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !waiting.isEmpty else { return }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            finishWaiting(with: nil)
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}
