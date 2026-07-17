//
//  ExplainContent.swift
//  MiniPi
//
//  The structured, data-driven documentation shown on the Explain screen.
//  Each MiniPi feature and cross-cutting concern is described as an
//  `ExplainSection` made of typed `ExplainBlock`s, so the view layer only has
//  to render — all of the "how it's implemented" detail lives here and can be
//  updated without touching the view.
//
//  Everything below reflects the actual implementation in this repo (Data →
//  Domain → UI layers, FactoryKit DI, the HTTPClient interceptor chain, the
//  Result/Failure error model, SceneKit 3D scenes, Swift Charts, etc.).
//

import SwiftUI

// MARK: - Content model

/// One documentation block. Ordered so a section can mix prose, key/value
/// facts, bullet lists, monospaced code/math, and nested subsections.
enum ExplainBlock {
    case text(String)
    case bullets([String])
    case keyValue(String, [(String, String)])   // header label + (key, value) rows
    case code(label: String, text: String)
    case flow(String)                            // a multi-line data-flow diagram (monospaced)
    case nested(title: String, blocks: [ExplainBlock])
}

/// A top-level documentation section — one feature or one architectural concern.
struct ExplainSection: Identifiable {
    /// Stable identity (the title) so re-recomputing the section list between
    /// renders doesn't invalidate which sections are expanded.
    var id: String { title }
    let title: String
    let subtitle: String
    let icon: String                  // SF Symbol
    let accent: Color                 // resolved per section at render time
    let blocks: [ExplainBlock]
}

// MARK: - Accent palette

/// Per-section accent colors. Some sections borrow the Science "space" tokens
/// (asteroids / earthquakes) and the Finance orbit tokens; the rest use the
/// brand primary so the page reads as one system.
enum ExplainContent {

    static func sections(cs: ColorScheme) -> [ExplainSection] {
        [
            architecture(cs),
            networking(cs),
            persistence(cs),
            nasaAsteroids(cs),
            earthquakes(cs),
            weather(cs),
            stocks(cs),
            crypto(cs),
            forex(cs),
            library(cs),
            indicators(cs),
            aiModels(cs),
            posts(cs),
            platform(cs),
        ]
    }

    // MARK: Architecture

    static func architecture(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Architecture",
            subtitle: "Clean Architecture, DI & the Result/Failure model",
            icon: "square.stack.3d.up.fill",
            accent: cs.primary,
            blocks: [
                .text("MiniPi is a SwiftUI app built with explicit Clean Architecture layers. Each feature is a vertical slice that keeps its UI, domain and data concerns separate — the same pattern repeats across every screen in the app."),
                .keyValue("Layers", [
                    ("UI", "SwiftUI Views + @MainActor ObservableObject ViewModels. State is @Published; ViewModels hold use cases and stores."),
                    ("Domain", "Pure Swift: value-type Models, Repository protocols (interfaces), and thin UseCases. No SwiftUI / networking imports here."),
                    ("Data", "Remote data sources (URL + DTOs), Repository implementations (DTO→domain mapping, caching), and the local data store."),
                ]),
                .nested(title: "Dependency injection (FactoryKit)", blocks: [
                    .text("Every collaborator is resolved through FactoryKit containers in MiniPi/DI. Modules register singletons per concern:"),
                    .bullets([
                        "NetworkModule — HTTPClient + interceptor chain, one remote-data-source factory per feature.",
                        "DatabaseModule — the shared LocalDataStore, handed out as 10 narrow per-feature protocols.",
                        "RepositoryModule — wires each *RepositoryImplementation to its domain protocol.",
                        "ViewModelModule — @MainActor Factory<XxxViewModel> per screen, plus every UserDefaults *Store.",
                        "UseCaseModule / LoggingModule — use cases and six OSLog loggers by category.",
                    ]),
                    .text("ViewModels are fetched from the container in Router.view(for:) (e.g. Container.shared.explainViewModel()), so the whole graph is resolved at navigation time."),
                ]),
                .nested(title: "Result + Failure error model", blocks: [
                    .text("Data calls return a custom Result<T> (Core/ResultType.swift) whose failure case is hard-bound to the app's Failure protocol — never a raw Error. The flow is:"),
                    .flow("""
                      throw (data layer)
                        AppException  ──►  ExceptionMapper  ──►  Failure  ──►  Result<T>
                        Network • Server • Database • Decoding        (UI severity + message)
                      """),
                    .bullets([
                        "Exceptions (Network/Server/Database/Decoding) are technical and thrown by Data.",
                        "Failures are user-facing, carry a Severity (.info/.warning/.critical), an icon and a chained cause.",
                        "Result<T> offers map / flatMap / recover / get() (throws) / onSuccess / onFailure.",
                    ]),
                ]),
                .nested(title: "Guards", blocks: [
                    .keyValue("Core/Guards", [
                        ("guardedApiCall", "Wraps a throwing API call and normalizes URLError / DecodingError / AppException into the four exception types (see Networking)."),
                        ("safeRepositoryCall", "Runs the repo call and catches typed exceptions; per-type async fallback closures let repos return cached data instead of failing (the cache-fallback strategy)."),
                    ]),
                ]),
                .nested(title: "Navigation", blocks: [
                    .text("Centralized, type-safe navigation. Router (an ObservableObject) owns a SwiftUI NavigationPath and an enum of routes."),
                    .bullets([
                        "routePaths enum — home, asteroidScreen, earthquakeScreen, weatherScreen, stocks, crypto, forex, aiModels, indicators, library, explain, about.",
                        "navigateTo / navigateBack / popToRoot append / removeLast on the path.",
                        "view(for:) resolves each route to its screen, fetching the ViewModel from the container.",
                    ]),
                ]),
            ]
        )
    }

    // MARK: Networking

    static func networking(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Networking",
            subtitle: "HTTPClient, the interceptor chain & error pipeline",
            icon: "network",
            accent: cs.primary,
            blocks: [
                .text("All remote calls funnel through one engine — HTTPClient (Data/Remote/Networking/HTTPClient.swift) — and an OkHttp/Dio-style interceptor chain. It is GET + JSON only; per-feature data sources build the full URL string and decode into their DTOs."),
                .nested(title: "HTTPClient.send(_:)", blocks: [
                    .bullets([
                        "Public API: send(_ request: URLRequest) async throws -> HTTPResponse.",
                        "Runs URLSession.data(for:), validates HTTPURLResponse, and throws ServerException when status ∉ 200..<300.",
                        "Hosts an [Interceptor] chain folded around an inner core() closure, reversed so index 0 is outermost.",
                    ]),
                    .text("The typed entry point most data sources use is HTTPClient.get(_:as:) (+ a headers overload): it validates the URL, wraps the work in guardedApiCall, builds a GET URLRequest, sends it, and JSONDecodes the response."),
                ]),
                .nested(title: "Interceptor chain", blocks: [
                    .keyValue("Order (dev)", [
                        ("1. AuthTokenInterceptor", "Sets Accept: application/json and, if a token is present, Authorization: Bearer <token>."),
                        ("2. FailureInjectionInterceptor", "Dev-only chaos engineering — may short-circuit or forge a response per the ApiScenario."),
                        ("3. RetryInterceptor", "Retries transient failures with linear backoff."),
                    ]),
                    .text("In production, FailureInjection is dropped, so the chain is simply Auth → Retry. FailureInjection is placed inside Auth (sees the auth header) but outside Retry (retries happen on real failures, not simulated ones)."),
                    .code(
                        label: "RetryInterceptor — transient retry + linear backoff",
                        text: """
                        maxRetries = 2          // 3 total attempts
                        baseDelay  = 300ms      // linear, not exponential

                        for attempt in 0...maxRetries {
                            do { return try await next(request) }
                            catch {
                                if attempt < maxRetries, isTransient(error) {
                                    sleep(baseDelay * (attempt + 1))   // 300ms, 600ms
                                    continue
                                }
                                throw error
                            }
                        }
                        """
                    ),
                    .text("Transient = URLError(.timedOut/.networkConnectionLost/.notConnectedToInternet/.cannotConnectToHost) or any ServerException with status 500…599."),
                ]),
                .nested(title: "Failure injection (ApiScenario)", blocks: [
                    .text("The dev interceptor (Core/Scenario/ApiScenario.swift) flips the network into deterministic failure modes so the whole error pipeline is testable from a debug menu:"),
                    .bullets([
                        "success · networkError · timeout · serverError · notFound · unauthorized · invalidJson",
                    ]),
                    .text("invalidJson is the interesting one: it returns a 200 with garbage body so JSONDecoder throws a DecodingError — exercising the full URLError/DecodingError → Exception → Failure mapping."),
                ]),
                .nested(title: "End-to-end request flow", blocks: [
                    .flow("""
                      ViewModel → UseCase → Repository.safeRepositoryCall
                        → RemoteDataSource → HTTPClient.get(_:as:)
                          → guardedApiCall { URLRequest → send(request) → decode }
                            → Auth → (FailureInjection, dev) → Retry → core (URLSession)
                          URLError/DecodingError  ──►  AppException
                        per-type cache fallback OR ExceptionMapper ──► Failure
                        Result<T> ──► @Published ──► View (ErrorView / ErrorSnackbar)
                      """),
                ]),
                .nested(title: "Configuration & secrets", blocks: [
                    .text("AppConfiguration.shared (Core/Config) reads everything from Bundle.main.infoDictionary — values come from per-environment .xcconfig files into Info.plist."),
                    .keyValue("Keys", [
                        ("API_BASE_URL", "Generic base used only by the demo Posts feature. validate() fatal-errors if empty."),
                        ("NASA_API_KEY", "Falls back to DEMO_KEY (~30 req/hr/IP)."),
                        ("WEATHER_API_KEY / OWM_API_KEY", "WeatherAPI.com data + OpenWeatherMap map tiles."),
                        ("USE_FAKE_API / USE_FAKE_DATABASE", "Toggle FakeApiService / FakeAppDatabase. Must be false in production (validated)."),
                    ]),
                ]),
            ]
        )
    }

    // MARK: Persistence

    static func persistence(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Local persistence",
            subtitle: "AppDatabase (cache) vs UserDefaults stores (user lists)",
            icon: "internaldrive.fill",
            accent: cs.primary,
            blocks: [
                .text("Two distinct persistence mechanisms, deliberately separated. The header in AppDatabase.swift states it plainly: 'a database is one engine, not one per feature'."),
                .nested(title: "AppDatabase — the cache engine", blocks: [
                    .bullets([
                        "Plain in-memory Swift (private var cachedX…). No SQLite/CoreData/SwiftData yet — the engine is swappable while the DAO protocols stay fixed.",
                        "LocalDataStore is a composition of 10 feature-narrow protocols (PostLocalDataSource, AsteroidLocalDataSource, … LibraryLocalDataSource) — Interface Segregation: each repo only sees its own slice.",
                        "Repositories call replaceX(_:) on success (write-through cache) and fetchX() on network/server error (cache fallback).",
                    ]),
                    .keyValue("FakeAppDatabase", [
                        ("DbScenario", "success · empty · readError · writeError · connectionFailed"),
                        ("Effect", "Lets read vs write vs connection failures be exercised independently, producing real DatabaseExceptions."),
                    ]),
                ]),
                .nested(title: "*Store — persistent user lists (UserDefaults)", blocks: [
                    .text("User-curated lists survive relaunch via small ObservableObject stores. Each owns a UserDefaults key, a Codable Snapshot slice of the domain model (with a savedEpoch), and contains / toggle / remove API. ViewModels subscribe to their @Published snapshots via Combine."),
                    .keyValue("Stores", [
                        ("FavoritesStore", "minipi.asteroid.favorites  — favorited NEOs."),
                        ("EarthquakeWatchlistStore", "minipi.earthquake.watchlist"),
                        ("CryptoWatchlistStore", "minipi.crypto.watchlist  (+ updateQuote for refresh)"),
                        ("ForexWatchlistStore", "minipi.forex.watchlist"),
                        ("StocksWatchlistStore", "minipi.stocks.watchlist  (+ symbols projection for re-quoting)"),
                        ("LibraryWatchlistStore", "minipi.library.watchlist"),
                        ("WeatherCityStore", "minipi.weather.cityQuery  (single query string, default auto:ip)"),
                        ("StocksCountryStore", "minipi.stocks.countryCode  (market region)"),
                    ]),
                ]),
            ]
        )
    }

    // MARK: NASA Asteroids

    static func nasaAsteroids(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "NASA NEO — Asteroids",
            subtitle: "NeoWs Feed/Lookup/Browse · Kepler orbital math · 3D solar system",
            icon: "circle.grid.3x3.fill",
            accent: cs.orbitAccent,
            blocks: [
                .text("The Science → Asteroids screen pulls Near-Earth Objects from NASA's NeoWs REST v1 API, renders the week's close approaches on a dashboard, and plots a live 3D solar system driven by real Kepler orbital elements."),
                .keyValue("Provider & endpoints", [
                    ("Base", "https://api.nasa.gov/neo/rest/v1  (key from AppConfiguration.nasaApiKey, default DEMO_KEY)"),
                    ("feed", "GET feed?start_date&end_date&api_key — 7-day close-approach window (max 7 days)."),
                    ("neo/{id}", "GET neo/{id}?api_key — single-body lookup including orbital_data."),
                    ("neo/browse", "GET neo/browse?page&size&api_key — paged full catalog (each body includes orbital data)."),
                ]),
                .nested(title: "DTO layer (AsteroidDto.swift)", blocks: [
                    .text("NASA returns many numeric fields as JSON strings, so they decode as String? and convert to Double via an Optional<String>.double extension. Key structs:"),
                    .bullets([
                        "NeoFeedDTO { element_count, near_earth_objects:[String:[AsteroidDTO]] } (date-keyed).",
                        "AsteroidDTO → id, name, designation, absoluteMagnitudeH, estimatedDiameter, isPotentiallyHazardousAsteroid, closeApproachData, orbitalData.",
                        "OrbitalDataDTO — the Keplerian set (all String?): semi_major_axis, eccentricity, inclination, ascending_node_longitude, perihelion_argument, mean_anomaly, epoch_osculation (Julian Date), orbital_period.",
                        "Mappers: toAsteroid(), toCloseApproach(), toOrbitalElements() (yyyy-MM-dd, en_US_POSIX).",
                    ]),
                ]),
                .nested(title: "Repository & use cases", blocks: [
                    .bullets([
                        "fetchAsteroids() — builds a 7-day window, flattens the date-keyed feed, persists to cache, maps to domain; falls back to cache on network/server error.",
                        "fetchOrbitalAsteroids() — 5 pages × size 20 (≤100 bodies) concurrently via withTaskGroup, filters bodies with orbitalData, dedupes by id.",
                        "lookupAsteroid(id:) — single neo/{id} call.",
                    ]),
                    .text("Use cases in Domain/UseCases/NasaAsteroids/: FetchAsteroids, FetchOrbitalAsteroids, LookupAsteroid, and GetAsteroidPositions (pure — the orbital-math core, below)."),
                ]),
                .nested(title: "Orbital mechanics — GetAsteroidPositionsUseCase", blocks: [
                    .text("Pure Swift: computes heliocentric ecliptic positions from orbital elements. Distances in AU, angles in radians (input elements are degrees)."),
                    .code(
                        label: "Julian Day + Kepler's equation (Newton–Raphson, 6 iters)",
                        text: """
                        JD = 2440587.5 + timeIntervalSince1970 / 86400
                        n = 2π / period                         // mean motion
                        M = normalize(M0 + n·dt)                // [-π, π]
                        solve M = E − e·sin E  by Newton–Raphson:
                          E = M
                          repeat 6×: E -= (E - e·sinE - M) / max(|1 - e·cosE|, 1e-9)
                        ν = 2·atan2(√(1+e)·sin(E/2), √(1−e)·cos(E/2))   // true anomaly
                        """
                    ),
                    .code(
                        label: "Heliocentric ecliptic coordinates",
                        text: """
                        r  = a(1 − e²) / (1 + e·cos ν)
                        xp = r·cos ν;  yp = r·sin ν            // perifocal frame
                        // rotate by argument of perihelion ω:
                        x1 = cos ω·xp − sin ω·yp
                        y1 = sin ω·xp + cos ω·yp
                        // rotate by ascending node Ω + inclination i:
                        X = cos Ω·x1 − sin Ω·cos i·y1
                        Y = sin Ω·x1 + cos Ω·cos i·y1
                        Z = sin i·y1
                        // returns Vec3(X, Y, Z) — heliocentric ecliptic, in AU
                        """
                    ),
                    .text("orbitVertices(steps:128) samples the full ellipse by sweeping ν 0→2π to draw each orbit path."),
                ]),
                .nested(title: "3D solar system (SolarSystemSceneView)", blocks: [
                    .text("A UIViewRepresentable wrapping SceneKit (SCNView). Motion is driven by TimelineView(.animation) feeding viewModel.displayedDate(at:) — so bodies advance per frame at the selected time scale."),
                    .bullets([
                        "Sun (emissive yellow, omni light) at origin; inner planets Mercury/Venus/Earth/Mars with SCNTorus orbit rings.",
                        "Planets use simple circular motion θ = 2π·days_since_J2000/period; J2000 anchor = 946728000 (2000-01-01).",
                        "Asteroids positioned per-frame from GetAsteroidPositionsUseCase; hazardous = orange, others = light blue.",
                        "Each asteroid has an invisible-but-hittable child sphere so taps register on tiny fast-moving bodies.",
                        "Orbit ellipses drawn only for hazardous bodies (128-sample line strips).",
                        "Camera: orbitTurntable + inertia, target re-asserted to origin every frame so gestures can't drift the Sun.",
                        "Scene units = AU (auScale 1.0). eclipticToScene maps (X,Y,Z) → (X, Z, Y).",
                    ]),
                    .keyValue("Time playback", [
                        ("TimeScaleScrubber", "Capsule buttons over AsteroidTimeScale: live · minute · hour · day · 3-days · week."),
                        ("displayedDate(at:)", "Anchors sim/real time on each scale change so switching speed is seamless."),
                    ]),
                    .keyValue("Tabs", [
                        ("Home", "Dashboard: stat tiles (week / today / hazardous / closest LD) + close-approach list."),
                        ("Explore", "The 3D scene with selection detail card + time scrubber."),
                        ("Search", "Name/id filter, filters (hazardous, min-diameter, sort), numeric-id lookup pinned on top."),
                        ("Favorites", "Saved NEOs via FavoritesStore."),
                    ]),
                ]),
            ]
        )
    }

    // MARK: Earthquakes

    static func earthquakes(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "USGS — Earthquakes",
            subtitle: "GeoJSON feed/query/lookup · 3D globe · lat/long projection",
            icon: "globe.americas.fill",
            accent: cs.distanceDanger,
            blocks: [
                .text("The Science → Earthquake screen consumes the USGS earthquake API (no key) as GeoJSON, shows the week's events on a dashboard, and plots them on a spinning 3D earth globe."),
                .keyValue("Provider & endpoints", [
                    ("Base", "earthquake.usgs.gov — no API key required."),
                    ("fetchFeed", "GET /earthquakes/feed/v1.0/summary/{all_hour|all_day|all_week|all_month}.geojson"),
                    ("query", "GET /fdsnws/event/1/query?format=geojson&orderby&starttime&endtime&minmagnitude&maxmagnitude&mindepth&maxdepth"),
                    ("lookup", "GET /earthquakes/feed/v1.0/detail/{id}.geojson"),
                ]),
                .nested(title: "DTO layer (EarthquakeDto.swift)", blocks: [
                    .text("GeoJSON-shaped; no CodingKeys needed (USGS returns JSON numbers, unlike NASA's string fields)."),
                    .bullets([
                        "GeoJSONFeatureCollectionDTO { metadata, features:[Feature] }.",
                        "GeoJSONPropertiesDTO { mag, magType, place, title, time(ms), updated(ms), url, alert, tsunami, sig, … }.",
                        "GeoJSONGeometryDTO { type, coordinates:[lon, lat, depthKm] } — GeoJSON Point order.",
                        "toEarthquake(): coords[1]→lat, coords[0]→lon, coords[2]→depth; epoch ms → Date(/1000); id = id ?? (net+code) ?? UUID.",
                    ]),
                ]),
                .nested(title: "Repository & use cases", blocks: [
                    .bullets([
                        "fetchEarthquakes(feed:) — cache-backed; replaceEarthquakes on success, cache fallback on error.",
                        "queryEarthquakes(_:) — one-shot server query (no list cache).",
                        "lookupEarthquake(id:) — one-shot detail.",
                    ]),
                    .text("The ViewModel debounces search 350ms, runs a client-side place filter, and detects USGS event ids (digits, or letter-prefix + ≥5 chars like us7000me69) to fire a lookup pinned at the top."),
                ]),
                .nested(title: "3D globe (EarthGlobeSceneView)", blocks: [
                    .text("UIViewRepresentable + SceneKit. SCNSphere(radius 1.0) textured with the earth_texture asset (equirectangular NASA Blue Marble), .blinn lighting, 90s axial spin. Directional sun (intensity 1200) + ambient fill + a translucent atmosphere halo. Markers are children of the earth node so they rotate with the texture."),
                    .keyValue("Markers", [
                        ("Pre-filter", "magnitude ≥ 2.5, sorted by magnitude desc, capped at 300 events."),
                        ("Size", "radius = 0.010 + max(0, mag−2)·0.006, clamped 0.035 (×1.8 up to 0.05 when selected)."),
                        ("Color", "by MagnitudeBand: green / yellow / amber / red."),
                        ("Hit target", "invisible SCNSphere(radius 0.06) child so small markers stay tappable."),
                    ]),
                    .code(
                        label: "Lat/long → sphere projection (verbatim)",
                        text: """
                        func surfacePosition(lat, lon, radius) -> SCNVector3 {
                            phi   = lat * π / 180        // latitude → radians
                            theta = lon * π / 180        // longitude → radians
                            r = radius * 1.01            // sit just above surface (no z-fight)
                            x = r·cos(phi)·cos(theta)
                            y = r·sin(phi)              // Y = polar axis
                            z = r·cos(phi)·sin(theta)
                        }
                        // Prime meridian (lon 0) at +X; east wraps toward +Z,
                        // matching how SceneKit lays out the equirectangular texture.
                        """
                    ),
                    .keyValue("Tabs", [
                        ("Home", "Stat tiles (feed count / today / largest / notable ≥4.5) + recent list + mini distribution chart."),
                        ("Map", "The 3D globe with magnitude legend + feed-window selector."),
                        ("Search", "Place / event-id search, filter chips (min-mag, depth, time window, sort)."),
                        ("Stats", "Swift Charts: magnitude donut, events-over-time line, depth + region bars."),
                        ("Watchlist", "Saved quakes (EarthquakeWatchlistStore)."),
                    ]),
                ]),
            ]
        )
    }

    // MARK: Weather

    static func weather(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Weather",
            subtitle: "WeatherAPI.com forecast · MapKit + OpenWeatherMap tiles",
            icon: "cloud.sun.fill",
            accent: cs.orbitPrimary,
            blocks: [
                .text("The Science → Weather screen uses WeatherAPI.com for current + 7-day forecast (Celsius/kph/mm/hPa natively, no conversion) and overlays OpenWeatherMap raster tiles on an Apple MapKit map."),
                .keyValue("Provider & endpoints", [
                    ("Data", "api.weatherapi.com/v1 — key from AppConfiguration.weatherApiKey."),
                    ("forecast.json", "key, q, days (clamped 1…14), aqi=yes, alerts=no."),
                    ("search.json", "key, q — city autocomplete."),
                    ("Map tiles", "tile.openweathermap.org/map/{layer}/{z}/{x}/{y}.png?appid=  (owmApiKey)."),
                ]),
                .nested(title: "DTO layer (WeatherDto.swift)", blocks: [
                    .text("WeatherAPI returns snake_case, so DTOs carry explicit CodingKeys (temp_c→tempC, wind_kph→windKph, pressure_mb→pressureMb, us-epa-index→usEpaIndex …). Mappers toLocation/toCurrent/toHour/toDay assemble the WeatherForecast envelope; epoch seconds are preferred over string date parsing."),
                ]),
                .nested(title: "Repository & use cases", blocks: [
                    .bullets([
                        "fetchForecast(_:) — cache-backed (single-forecast cache); fallback on error.",
                        "searchCities(query:) — one-shot; returns [] for empty query.",
                    ]),
                ]),
                .nested(title: "Location resolution (WeatherViewModel.bootstrap)", blocks: [
                    .text("The Home tab locates the user before loading:"),
                    .bullets([
                        "If a city was manually picked, skip GPS and load it.",
                        "Otherwise call locationService.request() and poll up to 25 seconds for a fix.",
                        "On a fix: persist \"%.4f,%.4f\" to WeatherCityStore and load.",
                        "On denied / restricted / failed / timeout: fall back to auto:ip (WeatherAPI IP geolocation).",
                    ]),
                ]),
                .nested(title: "Map overlay (WeatherMapOverlayView)", blocks: [
                    .text("MKMapView via UIViewRepresentable (not MapKit-SwiftUI). Decluttered: rotation/compass/buildings/traffic/POIs off, MKStandardMapConfiguration(emphasisStyle: .muted) on iOS 17+ so the colored tiles dominate."),
                    .bullets([
                        "WeatherTileOverlay subclasses MKTileOverlay and overrides url(forTilePath:) because the template substitution breaks on the ?appid= query — the URL is built manually.",
                        "Overrides loadTile(at:) to fetch via a private ephemeral URLSession with User-Agent: MiniPi/1.0 (iOS) (MapKit's default UA is rejected by OWM).",
                        "256×256 tiles, Z 0…19, canReplaceMapContent = false (base map shows through).",
                        "Layer selector: temperature / precipitation / cloud / wind (WeatherMetric.mapLayers). The legend uses WeatherMetric.color(forValue:) RGB-stop interpolation; no annotations are placed.",
                    ]),
                ]),
            ]
        )
    }

    // MARK: Stocks

    static func stocks(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Stocks",
            subtitle: "Yahoo Finance chart/search · fan-out overview · sparklines",
            icon: "chart.line.uptrend.xyaxis",
            accent: cs.secondary,
            blocks: [
                .text("Note: some stale file headers still mention 'Finnhub', but the live implementation is Yahoo Finance. Each request sends a browser User-Agent header to bypass Yahoo's Cloudflare 999 block. No API key."),
                .keyValue("Provider & endpoints", [
                    ("Base", "query1.finance.yahoo.com — no key, browser UA header."),
                    ("Chart", "GET /v8/finance/chart/{symbol}?range=&interval= — returns BOTH a quote (meta) and an OHLCV series."),
                    ("Search", "GET /v1/finance/search?q=&quotesCount=20&newsCount=0"),
                ]),
                .nested(title: "DTO layer (StocksDto.swift)", blocks: [
                    .text("No CodingKeys — Yahoo's field names are used verbatim."),
                    .bullets([
                        "YahooChartEnvelopeDTO { chart:{ result:[{ meta, timestamp, indicators }], error } }.",
                        "meta: regularMarketPrice/High/Low/Open/Volume, previousClose, chartPreviousClose …",
                        "indicators.quote[0]: { open, high, low, close, volume } arrays aligned to timestamp.",
                        "toQuote(): change = price − prevClose (falls back to chartPreviousClose); percent = change/prevClose·100.",
                        "toCandle(): zips timestamp × quote[0], drops points whose close is null.",
                    ]),
                ]),
                .nested(title: "Universe + repository", blocks: [
                    .text("StockUniverse is a curated per-region symbol table (US/IN/GB/DE/JP/CA — indices/stocks/etfs/commodities). Not a price generator."),
                    .bullets([
                        "marketOverview(country:) — fan-out chart per symbol via withTaskGroup, drop per-symbol failures.",
                        "Movers split by sign: changePercent > 0 → gainers, < 0 → losers, top 5 each.",
                        "bulkQuoteSymbols — range '1mo'/daily; sparkline = the daily close series. Preserves input order via index.",
                        "range(forDays:) ladder: ≤1→1d, 2–7→5d, 8–30→1mo, 31–90→3mo, 91–180→6mo, 181–365→1y, else max.",
                        "profile(_:) returns .success(nil) — Yahoo assetProfile needs a crumb/cookie that's never fetched.",
                    ]),
                    .keyValue("Persistence", [
                        ("StocksWatchlistStore", "minipi.stocks.watchlist — StockSnapshot slice, symbols projection for re-quoting."),
                        ("StocksCountryStore", "minipi.stocks.countryCode — market region (defaults from Locale.current.region)."),
                    ]),
                ]),
                .nested(title: "Chart (StocksDetailView)", blocks: [
                    .text("Swift Charts. Despite full OHLCV being decoded, the chart plots a close-price LineMark + AreaMark (monotone interpolation), titled '3-Month Daily Close'. opens/highs/lows/volumes are carried but not plotted; no moving-average or indicator math exists in the finance code."),
                ]),
            ]
        )
    }

    // MARK: Crypto

    static func crypto(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Crypto",
            subtitle: "Yahoo Finance · adaptive price precision · USD quotes",
            icon: "bitcoinsign.circle.fill",
            accent: cs.secondary,
            blocks: [
                .text("Same Yahoo engine and DTO shape as Stocks (BTC-USD dash-form symbols). CryptoDto.swift only adds extensions (toCryptoQuote/toCryptoCandle/toCoin) so it can't collide with the Stocks/Forex mappers."),
                .keyValue("Specifics", [
                    ("Universe", "CryptoUniverse.homeCoins — 15 USD-quoted coins (BTC, ETH, BNB, SOL …); CryptoCoinNames maps tickers to full names."),
                    ("toCoin()", "Keeps only quoteType == CRYPTOCURRENCY; splits 'BTC-USD' on '-', requires both halves all-letters."),
                    ("Sparkline range", "3mo / daily (vs Stocks' 1mo) — a month moved too little to read."),
                    ("Watchlist", "minipi.crypto.watchlist — CryptoSnapshot; updateQuote refreshes a saved price in place."),
                ]),
                .nested(title: "Adaptive price precision (CryptoPricePrecision)", blocks: [
                    .text("Sub-dollar coins like SHIB/PEPE need more decimals to be meaningful. The precision loop:"),
                    .code(
                        label: "decimals(for price)",
                        text: """
                        if price >= 1 { return 2 }       // e.g. 1,234.56
                        var dp = 2; var v = price
                        while v < 0.1, dp < 8 {          // ~4 significant digits
                            v *= 10; dp += 1
                        }
                        return dp                        // so 0.00001234 shows enough places
                        """
                    ),
                ]),
            ]
        )
    }

    // MARK: Forex

    static func forex(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Forex",
            subtitle: "Yahoo Finance · JPY vs 5-decimal precision · =X symbols",
            icon: "arrow.left.arrow.right.circle.fill",
            accent: cs.secondary,
            blocks: [
                .text("Same Yahoo engine as Stocks/Crypto, with =X-form symbols (e.g. EURUSD=X). ForexDto.swift adds toForexQuote/toForexCandle/toPair."),
                .keyValue("Specifics", [
                    ("Universe", "ForexUniverse — majors (7 USD pairs), minors (10 crosses), exotics (USD/TRY, USD/ZAR …)."),
                    ("toPair()", "Keeps only quoteType == CURRENCY; strips trailing =X; requires exactly 6 chars; splits base(3)/quote(3)."),
                    ("Precision", "ForexRatePrecision: JPY pairs → 3 dp, everything else → 5 dp (points, not money — never a currency symbol)."),
                    ("Overview", "baseLabel 'USD'; same fan-out + sign-split gainer/loser pattern as Stocks/Crypto."),
                ]),
            ]
        )
    }

    // MARK: Library

    static func library(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Open Library",
            subtitle: "Search / subject / trending / works · covers",
            icon: "books.vertical.fill",
            accent: cs.primary,
            blocks: [
                .text("Education → Library uses the Open Library public API (openlibrary.org) — no key, clean JSON. Covers come from covers.openlibrary.org."),
                .keyValue("Endpoints (inline base URL)", [
                    ("Search", "GET /search.json?q=|author=|subject=  + limit + curated fields list."),
                    ("Subject", "GET /subjects/{slug}.json?limit="),
                    ("Trending", "GET /trending/{period}.json?limit=  (now/daily/weekly/monthly/yearly)."),
                    ("Work detail", "GET /works/{OLID}.json"),
                ]),
                .nested(title: "DTO quirks", blocks: [
                    .bullets([
                        "DescriptionDTO is polymorphic: decodes from either a plain String or an object {type, value}.",
                        "Subject items use cover_id + authors:[{name,key}] — a different shape from search items (cover_i + author_name/author_key).",
                        "toLibraryWork() drops rows with empty title or un-parseable OLID; bareOlid extracts the last /-segment of key.",
                        "Home overview fans out subject lookups via withTaskGroup (drop-on-failure, order preserved).",
                    ]),
                    .keyValue("Persistence", [
                        ("LibraryWatchlistStore", "minipi.library.watchlist — LibrarySnapshot slice (cover + author + year)."),
                    ]),
                ]),
            ]
        )
    }

    // MARK: Indicators

    static func indicators(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "World Bank — Indicators",
            subtitle: "BOM-tolerant decode · [meta,[rows]] envelope · per-indicator fan-out",
            icon: "chart.bar.doc.horizontal.fill",
            accent: cs.primary,
            blocks: [
                .text("Education → Indicators pulls curated macro/health/education/environment series from the World Bank Open Data API (api.worldbank.org/v2) — no key."),
                .keyValue("Endpoints", [
                    ("Countries", "GET /country?format=json&per_page=10000"),
                    ("Observations", "GET /country/all/indicator/{code}?format=json&per_page=10000&date=2015:2023"),
                ]),
                .nested(title: "Decode details", blocks: [
                    .bullets([
                        "World Bank sometimes emits a UTF-8 BOM (EF BB BF) — the data source strips it before JSONDecoder (custom GET, not the shared one).",
                        "WorldBankResponseDTO<T> reads an unkeyed container: element 0 = page meta (discarded), element 1 = [T].",
                        "toCountry() drops aggregate entries (region empty or 'Aggregates'); toObservation() drops null values and rows missing countryiso3code/year.",
                        "catalog() fans out one observations() call per CuratedIndicators.all (10 series) via withTaskGroup, drop-on-failure.",
                    ]),
                    .text("CuratedIndicators.all: life expectancy, GDP per capita, poverty, population, under-5 mortality, basic water, adult literacy, primary enrollment, electricity access, forest area. Country.flag = emoji from ISO2 via regional indicator symbols."),
                ]),
            ]
        )
    }

    // MARK: AI Models

    static func aiModels(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "AI Models — OpenRouter",
            subtitle: "Catalog /models · benchmark + pricing mapping",
            icon: "cpu",
            accent: cs.primary,
            blocks: [
                .text("AI → AI Models reads the OpenRouter public model catalog (openrouter.ai) — no key. A single GET /api/v1/models returns { data:[…] }."),
                .nested(title: "Mapping (AIModelDto.swift)", blocks: [
                    .bullets([
                        "CodingKeys map snake_case: context_length, hugging_face_id, supported_parameters, artificial_analysis …",
                        "provider derived from the id prefix before the first '/' (e.g. openai/gpt-4o → 'openai').",
                        "isOpenWeight = non-blank huggingFaceId; supportsTools if supported_parameters contains 'tools'; supportsReasoning if 'reasoning'/'include_reasoning'.",
                        "pricing legs are string-encoded decimals (parsed tolerantly); isFree when both legs are 0.",
                        "Benchmarks: intelligence_index, coding_index, agentic_index → AIModel fields.",
                        "AIModelRank sorts overall/context/cheapest/coding/agentic (nils last where applicable).",
                    ]),
                    .text("Derived text helpers: contextText ('1.0M'/'200K'/'8K'), promptPriceText/completionPriceText (USD per million tokens, 'Free' when 0), modalityLabel ('In → Out')."),
                ]),
            ]
        )
    }

    // MARK: Posts

    static func posts(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "Posts (demo)",
            subtitle: "JSONPlaceholder-style /posts · cache-fallback reference",
            icon: "doc.text.fill",
            accent: cs.primary,
            blocks: [
                .text("The simplest feature and the reference implementation of the cache-fallback pattern. The base URL is the only one read from AppConfiguration.apiBaseURL; the {id,title,body} shape matches JSONPlaceholder."),
                .keyValue("Pipeline", [
                    ("Endpoint", "GET {apiBaseURL}/posts → [PostDTO]"),
                    ("Mapping", "Inline in the repository: PostDTO → Post."),
                    ("Cache", "remote-first; replacePosts on success; on network/server error returns cached [PostDTO] if non-empty, else the mapped Failure."),
                    ("Chained failure", "If the cache read itself throws: NetworkFailure('Network failed - cache also unavailable', cause:)."),
                ]),
            ]
        )
    }

    // MARK: Platform

    static func platform(_ cs: ColorScheme) -> ExplainSection {
        ExplainSection(
            title: "UI platform",
            subtitle: "DesignSystem · PageScaffold · SceneKit · Swift Charts",
            icon: "paintbrush.fill",
            accent: cs.primary,
            blocks: [
                .nested(title: "Design system", blocks: [
                    .bullets([
                        "DesignSystem (ObservableObject) holds a @Published ColorScheme resolved dark/light via a Palette value type.",
                        "Tokens: Material-style primary/surface/onBackground… plus Science semantic tokens (space, orbitPrimary #3B82F6, orbitAccent #8B5CF6, hazard #F59E0B, distance safe/warn/danger).",
                        "Typography: Montserrat (Regular/Bold/Medium) across the Material type scale; bodySmall uses System-Regular.",
                        "Sizes scale (xxs 2 … xxl 128), cardRadius 14, pillRadius 10, icon sizes 14…44. shadow(for:) → DSShadowComponent.",
                        "AppearanceManager persists system/light/dark to minipi.appearancePreference.",
                    ]),
                ]),
                .nested(title: "PageScaffold & ResponsiveLayout", blocks: [
                    .text("Every screen is wrapped in PageScaffold (a faithful port of a Flutter scaffold): themed header (title + optional trailing) over a ScrollView + ResponsiveLayout. Each screen supplies mobile (required), and optionally tablet/desktop."),
                    .bullets([
                        "ResponsiveLayout breakpoints: tablet ≥ 600, desktop ≥ 1100 (width tracked via onGeometryChange).",
                        "Optional pull-to-refresh via RefreshableModifier (paid for only when supplied).",
                    ]),
                ]),
                .nested(title: "3D & charts", blocks: [
                    .bullets([
                        "SceneKit (SCNView via UIViewRepresentable) powers both 3D scenes — the solar system and the earthquake globe — with a defaultCameraController (orbitTurntable + inertia).",
                        "Swift Charts powers every Stats tab and the finance price charts (LineMark/AreaMark, monotone interpolation).",
                        "All science screens route errors by severity: critical + no cache → full-screen ErrorView; warning/info with cached data → non-blocking ErrorSnackbar.",
                    ]),
                ]),
            ]
        )
    }
}
