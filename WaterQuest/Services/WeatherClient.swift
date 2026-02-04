import Foundation
import CoreLocation
import WeatherKit

@MainActor
final class WeatherClient: ObservableObject {
    enum Status {
        case idle
        case loading
        case failed
    }

    @Published var currentWeather: WeatherSnapshot?
    @Published var status: Status = .idle

    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    func refresh() async {
        guard let location = locationManager.lastLocation else {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.requestLocation()
            }
            status = .loading
            return
        }
        status = .loading
        do {
            let weather = try await weatherService.weather(for: location)
            let tempC = weather.currentWeather.temperature.converted(to: .celsius).value
            let humidity = weather.currentWeather.humidity * 100
            let condition = weather.currentWeather.condition
            let snapshot = WeatherSnapshot(temperatureC: tempC, humidityPercent: humidity, condition: condition.description, conditionKey: String(describing: condition))
            currentWeather = snapshot
            status = .idle
        } catch {
            status = .failed
            print("Weather fetch failed: \(error)")
        }
    }
}
