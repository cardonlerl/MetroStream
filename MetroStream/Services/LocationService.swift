import CoreLocation
import Foundation
import Observation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func nearbyStations(repository: MetroRepository, fallbackName: String = "人民广场") -> [LocatedStation] {
        if let coordinate = lastLocation?.coordinate {
            let nearby = repository.nearbyStations(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: 2_000
            )
            if !nearby.isEmpty {
                return nearby
            }
        }

        guard let fallback = repository.station(named: fallbackName) else { return [] }
        return repository.nearbyStations(
            latitude: fallback.latitude,
            longitude: fallback.longitude,
            radiusMeters: 2_000
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastLocation = nil
    }
}
