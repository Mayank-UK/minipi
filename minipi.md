- Help me create a document for AI to read and build features accordingly

- Here are my generic instructions:
    - You have to build UI using the design system implemented in the application
    - You have to follow the proper architecture that is followed in the application, for example, having use cases, repositories, repositoriesImpl, remote, DTOs, local, DAOs, exception handling, and so on
    - You have to check if existing components can be reused instead of creating new ones. If a component is to be used in a single file, then better to make it a function inside that view. If a component is to be used in multiple files, then create it inside the global ui/components
    - If feeling confused about how to do things, you are free to check how it's done in other parts of this app; the goal is to maintain consistency throughout the app

- Some potential global components I can see:
    - Maybe there could be a core tab container or something, that is reused across feature screens, but I will let you decide for better implementation
    - Every feature seems to be having multiple tabs, the tab icon+text can be made a component
    - Buttons, input fields, checkboxes, etc used across the app will be made components

- Engineering notes for AI (read this before building any feature)
    - Implementation status
        - Done: NASA NEO (Asteroids), USGS Earthquake, Weather (WeatherAPI.com)
        - Next: Stocks, then Forex, Crypto, AI Models, Indicators, Library
    - Canonical template = the Asteroids feature. Every new feature should mirror it layer-for-layer. File map (earthquake is the second worked example):
        - Domain: Models/<Feature>.swift, RepositoryInterfaces/<Feature>Repository.swift, UseCases/<Feature>/*.swift
        - Data: Remote/DTOs/<Feature>Dto.swift (Codable + `to<Domain>()`), Remote/<Feature>RemoteDataSource.swift (protocol + Impl), RepositoryImpls/<Feature>RepositoryImpl.swift
        - Local: per-feature protocol added to `LocalDataStore` union in Data/Local/AppDatabase.swift (and a stub conformance on FakeAppDatabase for compilation); a UserDefaults `<Feature>WatchlistStore` / FavoritesStore for the saved tab
        - DI: one entry each in DI/{Network,Database,Repository,UseCase}Module.swift; the ViewModel factory in DI/ViewModelModule.swift (the Router + Home + asset are already wired for every feature — just fill in the stubs)
        - UI: Screens/<Section>/<Feature>/<Feature>View.swift (tab shell) + <Feature>ViewModel.swift + Tabs/*.swift + Scene/*SceneView.swift for any 3D; shared rows/sheets/badges in UI/Components
    - Repository pattern: remote-first, persist to local on success, fall back to cache on network/server error. Reuse the shared `safeRepositoryCall` + `ExceptionMapper` + the `Failure` family — never invent a new error mechanism. List fetches are cache-backed; single lookups/queries are one-shot.
    - Networking: every remote data source builds on `HTTPClient.get(_:as:)` (runs `guardedApiCall`, maps URLError/DecodingError). API keys/base URLs come from the per-environment xcconfig → Info.plist → AppConfiguration.shared (e.g. `nasaApiKey`). Hardcode a feature's own base URL constant in its remote data source (like `nasaBaseURL`/`usgsBaseURL`) when it doesn't need a key.
    - Reusable components already in UI/Components (check before creating new): PageScaffold, StatTile, Chip/ChipLabel, LiveDataBadge, ErrorView, ErrorSnackbar, AppDrawer, ResponsiveLayout, HazardBadge (asteroid), MagnitudeBadge + EarthquakeRow + EarthquakeDetailSheet (earthquake). Convention: single-file UI = private view in that file; multi-file = global component.
        - Row component convention: an optional `onToggleSaved` closure → shows a save/remove star; omit it → shows a detail chevron. Save from the detail sheet, not necessarily from every list.
    - 3D screens: SceneKit via `UIViewRepresentable` + `Coordinator` (see SolarSystemSceneView and EarthGlobeSceneView). Markers that must stay geographically fixed go UNDER the spinning globe node. An equirectangular Earth texture already exists at Assets.xcassets/earth_texture.imageset (reuse for any globe). To verify marker/texture alignment without manual taps, temporarily seed `Router.navigationStack` + set the tab default, screenshot via `xcrun simctl io`, then revert.
    - Search pattern (server-backed): filters apply automatically on change — no "Apply" button. Debounce in the VM via a cancellable `scheduleSearch(immediate:)` Task (350 ms) so rapid changes keep only the last query; first load + Home drill-downs pass `immediate: true`. Client-side text filter + numeric-id lookup sit on top.
    - Charts: Swift Charts (iOS 16+) — no third-party chart lib. First chart surface is EarthquakeStatsTab.
    - Weather feature specifics (provider keys, location, Map tab — read before touching Weather):
        - Two provider keys, both `xcconfig → Info.plist → AppConfiguration`: `WEATHER_API_KEY` (WeatherAPI.com — forecast/search/current) and `OWM_API_KEY` (OpenWeatherMap APPID — Map tile overlays). Mirror the `nasaApiKey` plumbing.
        - WeatherAPI.com `auto:ip` is IP-geolocation → resolves the ISP's hub, often the wrong city. For "current location" use CoreLocation: `Core/Location/LocationService.swift` (CLLocationManager wrapper, DI `locationService`) + `NSLocationWhenInUseUsageDescription` in Info.plist. VM `bootstrap()` polls the fix (with a timeout) then falls back to `auto:ip` if denied/failed. On the simulator, location is *simulated* (Features → Location; defaults to Cupertino) and `xcrun simctl privacy grant location-when-in-use` can fail with "Operation not permitted" in some environments — on a real device the GPS path works after the user taps Allow.
        - WeatherAPI.com errors: an invalid key returns HTTP 401 with `{"error":{...}}` (NOT 200-with-error), so it surfaces as a `ServerException` → critical `ServerFailure` → `ErrorView`. Don't special-case the error body.
        - Map tab = MapKit (first-party) `MKMapView` via `UIViewRepresentable` + `MKTileOverlay` from OWM (`temp_new`/`precipitation`/`clouds_new`/`wind_new`). NOT a 3D globe / not dots — a colour overlay covering the whole map. File: `UI/Screens/Science/Weather/Scene/WeatherMapOverlayView.swift`.
        - MKTileOverlay gotchas (all cost real debugging time): (1) an `urlTemplate` containing a `?query=…` string breaks tile-path substitution → loads ZERO tiles. Fix = a `MKTileOverlay` subclass overriding `url(forTilePath:)` (see `WeatherTileOverlay`) and fetching via its own `URLSession` with a real `User-Agent`. (2) Setting `preferredConfiguration` (e.g. `.muted`) triggers an async map reload that DROPS overlays added in `makeUIView` — add the overlay in `updateUIView` and re-attach inside `mapViewDidFinishLoadingMap`. (3) OWM tiles are semi-transparent (alpha < 200); use a `.muted` *light* base so colours stay bright — a dark base dims them to near-invisible. (4) `CLLocationCoordinate2D` is not `Equatable` — compare lat/lon manually.
    - Verifying rendered output: don't trust auto image-analysis blindly — sample screenshot pixels (PIL) to confirm a layer actually rendered (e.g. OWM overlay presence = reds/aqua pixels, absence = all grays). The "Locating…" state, error/empty states, and tab shells can all be screenshot-verified by temporarily seeding `Router.navigationStack` + the VM default tab, then reverting.
    - Design system (UI/DesignSystem/DesignSystem.swift): `@EnvironmentObject DesignSystem`, `cs = designSystem.colorScheme`. Semantic tokens include the "space" set (space, spaceSurface, orbitPrimary, orbitAccent, hazard, distanceSafe/Warn/Danger, onSpace). Fonts are Montserrat via `designSystem.types.*`. Sizes via `DesignSystem.Sizes.*`. `designSystem.shadow(for: .neoCard)`.
    - CRASH CLASS TO AVOID: never read an `@EnvironmentObject` off a throwaway view instance created outside the hierarchy (e.g. `SomeBadge(...).color` inside a computed property). It is nil → fatal/freeze. Expose a static helper that takes the `ColorScheme` explicitly (see `MagnitudeBadge.color(for:in:)`).
    - Build / verify
        - Project uses Xcode 16 synchronized file groups: new files on disk are auto-included — do NOT edit project.pbxproj.
        - There is NO `Debug`/`Release` config. Build with `-configuration Development` (the scheme's config). Using `-configuration Debug` makes the SPM `Factory` package emit into `Debug-*` while the app uses `Development-*`, which breaks the resource-bundle copy / FactoryKit module resolution. Simulator build also needs `CODE_SIGNING_ALLOWED=NO`.
        - Command: `xcodebuild -project MiniPi.xcodeproj -scheme MiniPi -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Development CODE_SIGNING_ALLOWED=NO build`
        - Run on the booted sim: `xcrun simctl install booted <APP>` then `xcrun simctl launch booted com.mayank-upadhyay.MiniPi`. Built app path: `~/Library/Developer/Xcode/DerivedData/MiniPi-*/Build/Products/Development-iphonesimulator/MiniPi.app`. Self-verify rendering via `xcrun simctl io booted screenshot`.
    - Do NOT modify FakeApiService.swift / add fake feature data (house rule; USE_FAKE_API=NO). Real data sources only. A minimal conformance on FakeAppDatabase is fine/required when a new local protocol is added to the `LocalDataStore` union, but no real fake data.

- Nasa NEO implementation instructions
    - Already implemented

- Earthquake implementation instructions
    - Already implemented (USGS). Mirrors the asteroids feature exactly. See "Engineering notes for AI" below for the patterns, reusable components, and build gotchas established while building it. Next feature to build is Weather.
    - Reference image
        ![Earthquake reference](/Users/mak/downloads/minipi/science/earthquake.png)


- Weather implementation instructions
    - Already implemented (WeatherAPI.com). Mirrors the earthquake feature, with two extra provider keys and a MapKit tile-overlay Map tab instead of a 3D globe. See "Engineering notes for AI" for the patterns and gotchas established while building it. Next feature to build is Stocks.
    - It also has tab structure like other implementations
    - It has 3 tabs:
        - Home
            - It shows by default current location weather
            - It also has search at the top
            - Look for reference image for getting better context
        - Map
            - Here different characteristics are shown on 3D globe based on selection like temperature, precipitation, etc
            - Data is represented with heat maps, etc
            - There is also a timing thing too to show details at different times and dates
            - Look for reference image for getting better context
        - Stats
            - It is showing data inside various graphs and charts
            - Look for reference image for getting better context
    - Reference image
        ![Weather reference](/Users/mak/downloads/minipi/science/weather.png)

- Stocks implementation instructions
    - It also has tab structure like other implementations
    - It has 5 tabs:
        - Home
            - It shows default for the country in which user is and can also change country
            - Show different indices in that country
            - Look for reference image for getting better context
        - Markets
            - It shows indices, stocks, FTFs, commodities, etc
            - Any of these can be tapped to view more details showing graph, charts, etc
            - Look for reference image for getting better context
        - Search
            - It allows search for indices, stocks, FTFs, commodities, etc
        - Watchlist
            - It shows saved indices, stocks, FTFs, commodities, etc
            - Look for reference image for getting better context
        - Stats
            - It shows data inside various graphs and charts
            - Look for reference image for getting better context
    - Reference image
        ![Stocks reference](/Users/mak/downloads/minipi/finance_section/stocks.png)

- Forex implementation instructions
    - It also has tab structure like other implementations
    - It has 5 tabs:
        - Home
            - It shows different currencies performance compared to dollar
            - Look for reference image for getting better context
        - Markets
            - It shows majors, minors, exotics, etc
            - Any of these can be tapped to view more details showing graph, charts, etc
            - Look for reference image for getting better context
        - Search
            - It allows search for forex
            - Any of these can be tapped to view more details showing graph, charts, etc
        - Watchlist
            - It shows saved ones
            - Look for reference image for getting better context
        - Stats
            - It shows data inside various graphs and charts
            - Look for reference image for getting better context
    - Reference image
        ![Forex reference](/Users/mak/downloads/minipi/finance_section/forex.png)

- Crypto implementation instructions
    - It also has tab structure like other implementations
    - It has 4 tabs:
        - Home
            - It shows different coins - all, top gainers, top losers, etc
            - Look for reference image for getting better context
        - Search
            - It allows for search for different cryptos
            - Any of these can be tapped to view more details showing graph, charts, etc
        - Watchlist
            - It shows saved ones
            - Look for reference image for getting better context
        - Stats
            - It shows data inside various graphs and charts
            - Look for reference image for getting better context
    - Reference image
        ![Crypto reference](/Users/mak/downloads/minipi/finance_section/crypto.png)

- AI model implementation instructions
    - It also has tab structure like other implementations
    - It has 4 tabs:
        - Home
            - It shows relevant information like how many models, providers, open source, etc
            - Look for reference image for getting better context
        - Ranking
            - It shows ranking of different models ranked
            - It has different filtering like overall, context, cheapest, etc
            - Any of these can be tapped to view more details
            - Look for reference image for getting better context
        - Search
            - It shows search for models, there are can be different filter options like context, cheapest, opensource, etc
            - Any of these can be tapped to view more details
            - Look for reference image for getting better context
        - Compare
            - This screens allows to compare multiple models on different parameters
            - Look for reference image for getting better context
    - Reference image
        ![AI models reference](/Users/mak/downloads/minipi/ai_section/ai_models.png)

- Indicators
    - It also has tab structure like other implementations
    - It has 5 tabs:
        - Home
            - Showing data like indicators, countries, data points, etc
            - Look for reference image for getting better context
        - Ranking
            - It shows ranking of different countries with different important filtering parameters applied like literacy, poverty, etc
            - Any of these can be tapped to view more details
            - Look for reference image for getting better context
        - Search
            - Search for indicators
            - Any of these can be tapped to view more details
        - Compare
            - This screens allows to compare multiple countries on different indicators
            - Look for reference image for getting better context
        - Stats
            - It shows data inside various graphs and charts
            - Look for reference image for getting better context
    - Reference image
        ![Indicators reference](/Users/mak/downloads/minipi/education_section/indicators.png)

- Library
    - It also has tab structure like other implementations
    - It has 5 tabs:
        - Home
            - Shows data like books, authors, subjects, etc
            - Look for reference image for getting better context
        - Search
            - Search based on important filters like books, author, etc
            - Any of these can be tapped to view more details
            - Look for reference image for getting better context
        - Ranking
            - Ranking based on different parameters like fiction, etc
            - Any of these can be tapped to view more details
            - Look for reference image for getting better context
        - Watchlist
            - It shows saved ones
    - Reference image
        ![Library reference](/Users/mak/downloads/minipi/education_section/open_library.png)
