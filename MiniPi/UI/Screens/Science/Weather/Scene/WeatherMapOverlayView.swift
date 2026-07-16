//
//  WeatherMapOverlayView.swift
//  MiniPi
//
//  Map tab surface: Apple MapKit (first-party) with an OpenWeatherMap weather tile
//  overlay draped over the base map, colouring the whole map by the selected metric
//  (Temperature / Precipitation / Cloud / Wind). Pan + zoom are handled by MapKit.
//  A UIViewRepresentable + Coordinator, mirroring the app's other SceneKit
//  representables.
//
//  The OWM APPID comes from AppConfiguration.shared.owmApiKey (per-environment
//  xcconfig → Info.plist). Until a key is provided the base map renders without an
//  overlay.
//

import SwiftUI
import MapKit

struct WeatherMapOverlayView: UIViewRepresentable {

    let layer: WeatherMetric
    let coordinate: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.showsCompass = false
        // Declutter the base map so the colour overlay reads clearly.
        map.showsBuildings = false
        map.showsTraffic = false
        map.showsScale = false
        map.pointOfInterestFilter = .excludingAll
        // iOS 17+: a "muted" base map desaturates the greens/blues/roads so the
        // semi-transparent weather tiles are the dominant visual (Apple's intended
        // mode for data overlays). OWM tiles are themselves semi-transparent, so a
        // muted *light* base keeps their colours bright — a dark base would dim them.
        if #available(iOS 17.0, *) {
            let config = MKStandardMapConfiguration(emphasisStyle: .muted)
            map.preferredConfiguration = config
        }
        // World view until a city coordinate resolves.
        map.setRegion(Self.worldRegion(), animated: false)
        // NOTE: the overlay is added in `updateUIView`, not here — assigning
        // `preferredConfiguration` reconfigures the map asynchronously and drops any
        // overlay added during makeUIView.
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Always ensure the overlay is present (the config reconfiguration can drop
        // it), then handle layer/region changes.
        context.coordinator.ensureOverlay(layer, on: map)
        context.coordinator.updateRegion(coordinate: coordinate, on: map)
    }

    static func worldRegion() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {

        private var currentLayer: WeatherMetric?
        private var desiredLayer: WeatherMetric = .temperature
        private var overlay: MKTileOverlay?
        private var regionSetFor: CLLocationCoordinate2D?

        /// Ensure the correct overlay for `layer` is attached. (Re)builds it when the
        /// layer changes or when the map has lost it (e.g. after the `preferredConfiguration`
        /// / dark-mode reconfiguration). Idempotent, so safe to call on every `updateUIView`.
        func ensureOverlay(_ layer: WeatherMetric, on map: MKMapView) {
            desiredLayer = layer
            let attached = overlay != nil && map.overlays.contains { $0 === overlay }
            if attached && layer == currentLayer { return }
            applyLayer(layer, on: map)
        }

        func updateRegion(coordinate: CLLocationCoordinate2D?, on map: MKMapView) {
            if let coordinate, !Coordinator.isEqual(coordinate, regionSetFor) {
                let region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                )
                map.setRegion(region, animated: true)
                regionSetFor = coordinate
            }
        }

        /// Swap the OWM tile overlay for the given layer (or remove it when no key).
        func applyLayer(_ layer: WeatherMetric, on map: MKMapView) {
            let key = AppConfiguration.shared.owmApiKey
            if let old = overlay {
                map.removeOverlay(old)
            }
            overlay = nil
            // Only add an overlay when a key + a matching OWM layer exist.
            if !key.isEmpty, let owm = layer.owmLayer {
                let tile = WeatherTileOverlay(layer: owm, apiKey: key)
                tile.canReplaceMapContent = false
                map.addOverlay(tile, level: .aboveRoads)
                overlay = tile
            }
            currentLayer = layer
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(overlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// Re-attach the overlay once the map has finished loading. The dark-mode +
        /// `preferredConfiguration` setup triggers an async reload that drops overlays
        /// added earlier, so this is where the overlay reliably sticks.
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            ensureOverlay(desiredLayer, on: mapView)
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            // A failed base-map load still leaves the map usable; re-attach regardless.
            ensureOverlay(desiredLayer, on: mapView)
        }

        /// CLLocationCoordinate2D isn't Equatable — compare lat/lon directly.
        fileprivate static func isEqual(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Bool {
            switch (a, b) {
            case (nil, nil): return true
            case let (x?, y?): return abs(x.latitude - y.latitude) < 0.0001 && abs(x.longitude - y.longitude) < 0.0001
            default: return false
            }
        }
    }
}

// MARK: - OWM tile overlay

/// A tile overlay that builds each tile URL itself (via `url(forTilePath:)`) rather
/// than relying on an `urlTemplate` with a query string — MKTileOverlay's template
/// substitution breaks on `?appid=…` query strings, so no tiles load. Building the
/// URL per tile path sidesteps that. The tiles are fetched through a URLSession that
/// sends a standard User-Agent (MapKit's default UA can be rejected by some servers).
final class WeatherTileOverlay: MKTileOverlay {

    private let layer: String
    private let apiKey: String
    private let session: URLSession

    init(layer: String, apiKey: String) {
        self.layer = layer
        self.apiKey = apiKey
        self.session = URLSession(configuration: .ephemeral)
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = false
        // OWM tiles use the standard XYZ scheme (Y origin top-left) — MKTileOverlay's
        // default — so no vertical flip is needed.
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 0
        self.maximumZ = 19
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let raw = "https://tile.openweathermap.org/map/\(layer)/\(path.z)/\(path.x)/\(path.y).png?appid=\(apiKey)"
        return URL(string: raw) ?? URL(fileURLWithPath: "/dev/null")
    }

    /// Fetch the tile through our own session with a normal User-Agent, then hand the
    /// PNG data back to MapKit for rendering.
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        var request = URLRequest(url: url(forTilePath: path))
        request.setValue("MiniPi/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let task = session.dataTask(with: request) { data, _, error in
            result(data, error)
        }
        task.resume()
    }
}
