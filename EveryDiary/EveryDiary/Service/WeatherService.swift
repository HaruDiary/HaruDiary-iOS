//
//  WeatherService.swift
//  EveryDiary
//
//  Created by Dahlia on 2/27/24.
//
import CoreLocation
import Foundation

/// Current weather at the device's location. Call from the main thread; the completion may run on any thread.
///
/// A fresh instance has no location yet, so a request waits for one (at most `locationTimeout`) instead of
/// failing at once. The service keeps itself alive until every waiting completion has been called, so a caller
/// that does not hold on to it (as saving a diary does) still gets an answer.
class WeatherService: NSObject, CLLocationManagerDelegate {
    static let locationTimeout: TimeInterval = 5

    private let locationManager = CLLocationManager()
    private let apiKey: String
    private let session: URLSession
    private var waiting: [(Result<WeatherResponse, WeatherError>) -> Void] = []
    private var keepAlive: WeatherService?
    private var timeout: DispatchWorkItem?

    init(apiKey: String = Bundle.main.apiKey, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }

    func getWeather(completion: @escaping (Result<WeatherResponse, WeatherError>) -> Void) {
        // Without a key the request can only fail; skip asking for a location.
        guard WeatherQuery.url(latitude: 0, longitude: 0, apiKey: apiKey) != nil else {
            return completion(.failure(.missingAPIKey))
        }
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
        guard let url = WeatherQuery.url(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, apiKey: apiKey) else {
            return completion(.failure(.missingAPIKey))
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = WeatherQuery.requestTimeout
        session.dataTask(with: request) { data, response, _ in
            let result = WeatherQuery.parse(data: data, statusCode: (response as? HTTPURLResponse)?.statusCode)
            if case .failure(let error) = result {
                // The error kind only; the request URL carries the key and is never logged.
                print("Load weather failed: \(error)")
            }
            completion(result)
        }.resume()
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
