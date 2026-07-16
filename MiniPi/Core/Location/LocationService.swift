//
//  LocationService.swift
//  MiniPi
//
//  CoreLocation wrapper that resolves the device's current GPS coordinates for the
//  Weather Home tab (replacing IP-based `auto:ip`, which only resolves the ISP's
//  registered location). Falls back gracefully: if the user denies permission (or
//  the hardware fails), the consumer switches to WeatherAPI's `auto:ip`.
//
//  CLLocationManager delivers delegate callbacks on the main thread, so this is a
//  plain NSObject ObservableObject (not @MainActor) — published values update on
//  the main thread by default.
//

import Foundation
import CoreLocation

final class LocationService: NSObject, ObservableObject {

    @Published private(set) var coordinates: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var failed: Bool = false

    private let manager: CLLocationManager

    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    /// Kick off resolution: prompt for permission if undecided, otherwise request a
    /// one-shot fix. Safe to call repeatedly.
    func request() {
        failed = false
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            // Nothing to do — the consumer treats this as "use auto:ip".
            failed = true
        @unknown default:
            failed = true
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied
                || manager.authorizationStatus == .restricted {
                self.failed = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.coordinates = locations.last?.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.failed = true
        }
    }
}
