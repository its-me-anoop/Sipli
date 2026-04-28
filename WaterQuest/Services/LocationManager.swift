import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?

    private var pendingAuthContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Async wrapper around `requestWhenInUseAuthorization`. Returns immediately
    /// if the user has already answered the system dialog; otherwise suspends
    /// until `didChangeAuthorization` fires with a non-`.notDetermined` status.
    func requestWhenInUseAuthorizationAsync() async -> CLAuthorizationStatus {
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
            pendingAuthContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestLocation() {
        // startUpdatingLocation is a no-op if not yet authorized;
        // didChangeAuthorization will call it again once permission is granted.
        manager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
            if status != .notDetermined, let cont = self.pendingAuthContinuation {
                self.pendingAuthContinuation = nil
                cont.resume(returning: status)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.lastLocation = locations.last
            // One location is all we need — stop to conserve battery
            self.manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("Location error: \(error)")
        #endif
    }
}
