import CoreLocation
import Combine

// MARK: - LocationManager
//
// Thin async wrapper around CLLocationManager.
// Requests when-in-use permission and vends the current location once.

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var location: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authStatus = manager.authorizationStatus
    }

    // Returns the current location, requesting permission if needed.
    func currentLocation() async -> CLLocation? {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return await requestOneShot()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Wait for auth callback then retry once
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard manager.authorizationStatus == .authorizedWhenInUse ||
                  manager.authorizationStatus == .authorizedAlways else { return nil }
            return await requestOneShot()
        default:
            return nil
        }
    }

    private func requestOneShot() async -> CLLocation? {
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < 60 {
            return cached
        }
        return await withCheckedContinuation { cont in
            continuation = cont
            manager.requestLocation()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            self.location = loc
            self.continuation?.resume(returning: loc)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authStatus = manager.authorizationStatus
        }
    }
}
