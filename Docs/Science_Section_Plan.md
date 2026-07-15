# MiniPi — Science section (planned modules)

> **Status:** Planned — not yet implemented. This document is the source of truth for the
> Science section of Home. It captures every decision made during planning, the exact data
> sources, the architecture mapping, and — critically — the shared exception-handling /
> offline-cache / error-UI pattern every module **must** follow to match the rest of MiniPi.
>
> **Modules in scope:**
> - **A. NASA Asteroids** — Eyes-style 3D revolving asteroids → `UI/Screens/NasaAsteroid/`
> - **B. USGS Earthquakes** — map of recent quakes with a time replay → `UI/Screens/Earthquakes/`
> - **C. Open-Meteo Weather** — current + hourly/daily forecast → `UI/Screens/Weather/`
>
> Each gets a tile in Home's **Science** section (`HomeViewModel.links`) and a `Router.routePaths` case.
> **Do not start coding until the owner says go.**
>
> **Shared pattern (applies to ALL three):** same clean-architecture layout (Domain model → DTO →
> Repository w/ cache fallback → UseCase → DI → View+ViewModel → Router tile) and the **exact**
> exception-handling / offline / error-UI pattern documented in **Module A §6**. Reuse `guardedApiCall`,
> `safeRepositoryCall`, `ExceptionMapper`, the `Failure` family, `ErrorView`/`ErrorSnackbar`/`ErrorBanner`,
> `ConnectivityService`. **Do not invent new error mechanisms.** All three APIs are keyless (NASA needs
> its key, stored in xcconfig; USGS + Open-Meteo need nothing).

---

---

# Module A — NASA Asteroids (Eyes-style, 3D)

## A.1 Vision

A 3D, NASA-["Eyes on Asteroids"](https://eyes.nasa.gov/apps/asteroids/#/home)-style screen
where real near-Earth asteroids **revolve around the Sun in real time** along their true
orbits. The Sun sits at the centre; planets are shown as reference; the user can drag to
orbit the camera, pinch to zoom, scale time (live → up to 7 days/sec), and tap any body for a
detail card.

## A.2 Locked decisions

| Topic | Decision |
|---|---|
| Motion | Real-time revolution computed **client-side** from orbital elements (no per-frame network) |
| Render | **3D — SceneKit** (ships with iOS; no engine dependency) |
| Time control | **Live "now" by default**, scrubber up to **max 7 days/sec**. Presets: Live · 1 min/s · 1 hr/s · 1 day/s · 3 days/s · 7 days/s |
| Sun + planets | **Stylized colored spheres** (Earth blue-green, Mars rust, Saturn tan+ring, …). *(Confirm: photoreal textures also possible if desired.)* |
| Real photo | Shown **only in the detail card** when a body is tapped (NASA imagery) |
| Asteroids | Glowing dots/sprites gliding along faint orbit rings |
| Data source | **NASA NeoWs** (one free key) — gives orbital elements **and** close-approach stats |

## A.3 Data source & auth

**API:** NASA NeoWs — `https://api.nasa.gov/neo/rest/v1/...`

- `…/neo/browse?api_key=KEY` — paginated list of all asteroids (each with `orbital_data`)
- `…/neo/{id}?api_key=KEY` — full lookup for a specific body (e.g. 433 Eros, 4179 Toutatis,
  25143 Itokawa, 99942 Apophis, 101955 Bennu)
- `…/feed?start_date=…&end_date=…&api_key=KEY` — asteroids approaching in a date window
- `DEMO_KEY` works for dev but is rate-limited (~30 req/hr/IP). Use the real key for real use.

**Where the key is stored:** in the per-environment xcconfig files under
`Config/{Development,Staging,Production}.xcconfig` as `NASA_API_KEY=…`, surfaced into the app
via `Info.plist` (`NASA_API_KEY` → `$(NASA_API_KEY)`), and read at runtime by
`AppConfiguration` (same pattern as the existing `API_BASE_URL`).

> **Key (kept here so it isn't lost):** `NASA_API_KEY = WpBEEDBBLnblaEiaxi5DVs0pM8Dh2bGXITktsQpn`
> — already present in all three xcconfig files and already wired through `Info.plist`.
> **Remaining one-line code change:** add `let nasaApiKey = info["NASA_API_KEY"] as? String ?? "DEMO_KEY"`
> to `AppConfiguration.init` (next to `apiBaseURL`) so the `ApiService` can append `?api_key=…`.
>
> *Security note: if this repo ever goes public, move the key into a git-ignored local xcconfig
> instead of committing it.*

**Verified JSON shape (NeoWs `browse` item) — model the DTO from this:**

```
neo_reference_id, name, designation, nasa_jpl_url
absolute_magnitude_h
estimated_diameter.{kilometers,meters,...}.estimated_diameter_min/max
is_potentially_hazardous_asteroid
is_sentry_object
close_approach_data: [
  { close_approach_date, miss_distance.{kilometers,lunar}, relative_velocity.{kilometers_per_hour,kilometers_per_second} }
]
orbital_data: {
  semi_major_axis          // a   (AU)            ← orbit size
  eccentricity             // e                    ← orbit shape
  inclination              // i   (deg)            ← tilt
  ascending_node_longitude // Ω   (deg)            ← orientation
  perihelion_argument      // ω   (deg)            ← orientation
  mean_anomaly             // M   (deg)            ← "where on the orbit now"
  epoch_osculation         //     Julian Date      ← instant elements are valid for
  orbital_period           //     days             ← one revolution duration
  first_observation_date, orbit_id, orbit_determination_date
}
```

The six orbital quantities (a, e, i, Ω, ω, M) + epoch are the **complete Keplerian set** —
enough to compute each asteroid's heliocentric (x,y,z) at any instant and revolve it.
Close-approach + magnitude/diameter fields feed the detail card.

## A.4 The physics (pure Swift, Domain layer)

`GetAsteroidPositionsUseCase` takes `[OrbitalElements]` + a `Date` and returns
`[(id, SCNVector3 / simd_double3)]` in **heliocentric ecliptic coordinates, in AU**:

1. From `epoch` and the target `Date`, compute elapsed days → advance mean anomaly:
   `M(t) = M₀ + n·Δt`, where `n = 360 / orbital_period` (deg/day).
2. Solve **Kepler's equation** `E − e·sin E = M` for the eccentric anomaly E (Newton-Raphson, ~5 iters).
3. True anomaly ν from E; heliocentric distance `r = a(1 − e·cos E)`.
4. Position in the orbital plane, then rotate by ω, i, Ω into ecliptic XYZ.

This is pure, deterministic, trivially unit-testable (known-body checks), and has **no
network and no SceneKit dependency** — keep it out of the UI layer. The View just reads
`(x,y,z)` each frame and moves the corresponding node.

## A.5 Architecture mapping (follow existing MiniPi style)

| Layer | New files |
|---|---|
| `Domain/Models/` | `Asteroid.swift`, `OrbitalElements.swift` (and `Planet` reference data if added) |
| `Domain/RepositoryInterfaces/` | `AsteroidRepository.swift` (`func fetchAsteroids() async -> Result<[Asteroid]>`) |
| `Domain/UseCases/NasaAsteroids/` | `GetAsteroidPositionsUseCase.swift` (Kepler math), `FetchAsteroidsUseCase.swift` |
| `Data/Remote/DTOs/` | `AsteroidDto.swift` (+ nested `OrbitalDataDto`, `CloseApproachDto`, `EstimatedDiameterDto`) |
| `Data/Remote/` | `ApiService` gains `fetchAsteroids() async throws -> [AsteroidDto]` (via `HTTPClient`/interceptors like `fetchPosts`) |
| `Data/RepositoryImpls/` | `AsteroidRepositoryImpl.swift` — mirrors `PostRepositoryImplementation` (see §6) |
| `Data/Local/` | Extend `DatabaseServiceProtocol` + `AppDatabase`/`FakeAppDatabase` with asteroid cache (`fetchAsteroids()/replaceAsteroids(_:)`) |
| `DI/` | `RepositoryModule` → `asteroidRepository`; `UseCaseModule` → `fetchAsteroidsUseCase`, `getAsteroidPositionsUseCase`; `ViewModelModule` → `nasaAsteroidViewModel` |
| `UI/Screens/NasaAsteroid/` | `NasaAsteroidView.swift` (SceneKit scene + controls + time scrubber + detail card), `NasaAsteroidViewModel.swift`, optional `SceneKit/` helpers |
| `UI/Navigation/Router.swift` | add `case nasaAsteroids` + resolve to `NasaAsteroidView` |
| `UI/Screens/Home/HomeViewModel.swift` | add a `LinkData` tile routing to `.nasaAsteroids` |

## A.6 Exception handling, offline cache & error UI — SHARED PATTERN (read first; B & C reuse it)

This module **must** behave exactly like the existing Post flow. Concretely:

**Repository (`AsteroidRepositoryImpl.fetchAsteroids()`) — copy the structure of
`PostRepositoryImplementation.fetchPosts()`:**

- Wrap the whole op in `safeRepositoryCall(call:onNetworkError:onServerError:...)`.
- `call`: fetch via `apiService`, then **persist to the local DB** (`database.replaceAsteroids(...)`),
  then map DTOs → domain `Asteroid`s and return.
- `onNetworkError` / `onServerError`: **fall back to the cache** — `database.fetchAsteroids()`;
  if non-empty → `.success(cached)` (stale-but-usable orbits, since elements change slowly);
  if empty → `.failure(ExceptionMapper.mapExceptionToFailure(exception))`. If the cache read
  itself throws, build a **chained failure** (e.g. `NetworkFailure("Network failed - cache also
  unavailable", severity: .warning, cause: cacheFailure)`) — exactly as the Post repo does.
- All `URLError`/`DecodingError` are auto-mapped to `AppException`s by `guardedApiCall`
  (already used inside `ApiService`). Do not bypass it.

**ViewModel (`NasaAsteroidViewModel`) — copy `PostViewModel`:**

- `@Published var asteroids: [Asteroid]`, `currentFailure: Failure?`, `isLoading: Bool`,
  plus `simulatedDate: Date`, `timeScale: TimeScale` (live … 7 days/sec).
- `func loadAsteroids() async` guards re-entrancy, sets `isLoading`, runs the use case,
  switches on `Result`, sets `currentFailure` on failure. A `Timer`/`TimelineView` advances
  `simulatedDate` by `timeScale` per frame and feeds positions to the scene.

**View (`NasaAsteroidView`) — copy `PostView` severity routing:**

- `isLoading` → `ProgressView`.
- `currentFailure` **&amp;&amp; `severity == .critical`** → full-screen `ErrorView(failure:onRetry:)`
  (retry re-runs `loadAsteroids()`).
- `currentFailure` **&amp;&amp; severity warning/info** → render the **cached** scene **plus** an
  overlay `ErrorSnackbar(failure:onDismiss:)` (non-blocking, because cached orbits are still valid).
- otherwise → the 3D scene.
- `.task` loads once when empty and no failure present.

**Components to reuse as-is:** `ErrorView`, `ErrorSnackbar`, `ErrorBanner`, `PageScaffold`,
`guardedApiCall`, `safeRepositoryCall`, `ExceptionMapper`, the `Failure` family
(`NetworkFailure`/`ServerFailure`/`CacheFailure`), `ConnectivityService`. **Do not invent a
new error mechanism.**

## A.7 Build phases

1. **Domain models** — `Asteroid`, `OrbitalElements`; add asteroid methods to
   `DatabaseServiceProtocol` + `AppDatabase`/`FakeAppDatabase`.
2. **Data** — `AsteroidDto` (+ nested DTOs) from the verified shape; `ApiService.fetchAsteroids()`.
3. **Repository** — `AsteroidRepositoryImpl` with cache fallback (§6).
4. **UseCases** — `FetchAsteroidsUseCase`; `GetAsteroidPositionsUseCase` (Kepler) + unit tests.
5. **DI** — Factory registrations.
6. **UI** — `NasaAsteroidView` SceneKit scene (Sun, orbit rings, asteroid sprites, planet
   reference spheres, camera drag/zoom), time scrubber (live→7 days/sec), live-now, detail
   card; `NasaAsteroidViewModel` with severity-based error states.
7. **Router + Home** — `.nasaAsteroids` route + a Home tile.

## A.8 Open decisions (RESOLVED 2026-07-15)

- **Planet look:** ✅ **Photoreal texture maps** (Sun + 8 planets). Needs texture assets bundled
  in `Assets.xcassets`; use `SCNMaterial.diffuse.contents` per planet.
- **Asteroid set:** ✅ **Curated famous bodies + today's close approaches** — Apophis, Bennu,
  Eros, Toutatis, Itokawa (via `neo/{id}` lookups) merged with the current day's `feed` results.
- **Reference planets:** ✅ **All 8** (so close approaches read in context), Sun at centre.
- **Key handling:** ✅ **Real key already in xcconfig + Info.plist**; just add `nasaApiKey` to
  `AppConfiguration` (see §A.3). `DEMO_KEY` remains the fallback default.

## A.9 Reference files (copy the patterns, don't reinvent)

- Repository + offline cache: `MiniPi/MiniPi/Data/RepositoryImpls/PostRepositoryImpl.swift`
- Guards: `Core/Guards/{GuardedApiCall,SafeRepositoryCall}.swift`
- Exception→Failure mapping: `Core/Mapping/ExceptionMapper.swift`, `Core/Failures/*`, `Core/Exceptions/*`
- ViewModel error state: `IosDevelopersGuide/.../PostView/PostViewModel.swift`
- View severity routing: `IosDevelopersGuide/.../PostView/PostView.swift`
- Error UI: `UI/Components/{ErrorView.swift (Screens/Error),ErrorBanner.swift,ErrorSnackbar.swift}`

---

## A.10 Screen set (RESOLVED 2026-07-15 — 5 screens, matches the reference mockup)

Module A is implemented as a small screen set under `UI/Screens/Science/Asteroids/`
(existing stub folder — the plan's earlier `UI/Screens/NasaAsteroid/` name is dropped in favour
of what's already wired in `Router`/DI/Home). All screens consume the MiniPi design tokens
(`DarkColors`/`LightColors`, `FontScheme`, `DesignSystem.Sizes`) plus new semantic asteroid
tokens added to `DesignSystem.swift` (§A.11). **No hardcoded colors anywhere.**

Routing: `.asteroidScreen` (hub/3D) already exists; add `.asteroidDetail(Asteroid)`,
`.asteroidOrbit(Asteroid)`, `.asteroidSearch`, `.asteroidFavorites` to `Router.routePaths`.

| # | Screen | File(s) created | Shows | Design tokens |
|---|---|---|---|---|
| 1 | **3D Universe** (hub) | `AsteroidView.swift` (replace stub) + `Scene/AsteroidSceneView.swift`, `Scene/TimeScaleScrubber.swift`, `Scene/OrbitControlsOverlay.swift` | Sun centre + 8 textured planets + asteroid sprites revolving in real time (Kepler); drag/pinch; time scrubber Live→7 days/sec; tap body → Detail | `space`, `orbitPrimary`, `orbitAccent`; `DesignSystem.Sizes` for orbit radii |
| 2 | **Object Detail** | `AsteroidDetailView.swift`, `Components/AsteroidOverviewGrid.swift`, `Components/HazardBadge.swift` | Hero NASA image, name + "Near Earth Asteroid", hazard/confirmed badges, Overview grid (diameter, closest approach, distance LD+km, velocity, orbit type, discovered, H mag), About, "View Orbit" | `hazard` (amber), `orbitPrimary`, `surface` |
| 3 | **Orbit View** | `AsteroidOrbitView.swift`, `Scene/OrbitSceneBuilder.swift` | That asteroid's orbit + Earth reference (SceneKit, reuses Screen-1 builder), info panel (semi-major axis, period, eccentricity, velocity, aphelion) | `orbitAccent` rings, `spaceSurface` panel |
| 4 | **Search & Filters** | `AsteroidSearchView.swift`, `AsteroidSearchViewModel.swift`, `Components/FilterChipBar.swift` | Search field (name/designation), filter chips (hazardous, min diameter, max distance, date range), Apply → results list (hits `neo/{id}` + `feed`) | `orbitPrimary` actions, `surface` chips |
| 5 | **Favorites** | `AsteroidFavoritesView.swift`, `AsteroidFavoritesViewModel.swift` | NEOs/Planets tabs, saved objects persisted via existing `DatabaseServiceProtocol` (no new mechanism) | `secondary` accent, `surface` cards |

Error UI per screen follows §A.6: `isLoading`→`ProgressView`; critical failure→full-screen
`ErrorView(retry:)`; warning/info→screen of cached data + `ErrorSnackbar`.

## A.11 Design-system additions (do first, used by all 5 screens)

Additive to `MiniPi/UI/DesignSystem/DesignSystem.swift` — extend `DarkColors` AND `LightColors`
with semantic asteroid tokens, and mirror them in the `ColorScheme` initializer:
`space` (deep bg), `spaceSurface` (panels), `orbitPrimary` (#3B82F6), `orbitAccent` (#8B5CF6),
`hazard` (#F59E0B), `distanceSafe`/`distanceWarn`/`distanceDanger`. Add `DesignSystem.Sizes`
orbit radii + a `.neoCard` case to the existing `shadows` enum. Optional
`UI/DesignSystem/AsteroidPalette.swift` reads from `ColorScheme` so screens never touch raw colors.

---

# Module B — USGS Earthquakes (map + time replay)

## B.1 Vision
A **map** of recent earthquakes with **circles sized + colored by magnitude** at each epicenter.
Tap a quake → detail (magnitude, depth, place, time, tsunami flag, USGS event link). Filters:
time range (today / past week / past month) and a min-magnitude slider. An optional **time
scrubber replays** the selected period's quakes appearing on the map chronologically (ties to
the same "control time" idea as the asteroids — "watch a week of earthquakes unfold").

## B.2 Locked decisions
| Topic | Decision |
|---|---|
| Render | **2D map — SwiftUI `Map` (MapKit)**, iOS 17+, no dependency. Magnitude = circle size + color ramp (green→yellow→red). |
| Time control | **Live "now" feed by default**; optional replay scrubber plays the period chronologically up to max ~7 days/sec (match Module A's cap). |
| Filters | Time range (day/week/month) + min-magnitude slider; optional geographic bounds via the FDSN query API. |
| Data source | **USGS** — keyless. Ready-made GeoJSON feeds **and** the FDSN query API for filters. |

## B.3 Data source (KEYLESS, verified)
- Feeds: `https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/{all|significant}_{day|week|month}.geojson`
- Query (filters): `https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&starttime=…&endtime=…&minmagnitude=…&minlatitude=…&maxlatitude=…&minlongitude=…&maxlongitude=…&orderby=time`
- **Verified shape:** GeoJSON `FeatureCollection` → `features[].geometry = Point [lon, lat, depth]`; `features[].properties = { mag, place, time (epoch ms), tsunami, alert, url, type, sig, … }`. No auth, no key.

## B.4 Architecture mapping (existing MiniPi style)
| Layer | New files |
|---|---|
| `Domain/Models/` | `Earthquake.swift` (id, mag, depth, place, date, tsunami, detailURL, coordinate) |
| `Domain/RepositoryInterfaces/` | `EarthquakeRepository.swift` (`func fetchEarthquakes(query:) async -> Result<[Earthquake]>`) |
| `Domain/UseCases/Earthquakes/` | `FetchEarthquakesUseCase.swift` |
| `Data/Remote/DTOs/` | `EarthquakeFeedDto.swift` (GeoJSON FeatureCollection; nested `FeatureDto`/`PropertiesDto`/`GeometryDto`) |
| `Data/Remote/` | `ApiService.fetchEarthquakes(range:minMagnitude:bounds:) async throws -> EarthquakeFeedDto` |
| `Data/RepositoryImpls/` | `EarthquakeRepositoryImpl.swift` — cache fallback (see B.6) |
| `Data/Local/` | Extend `DatabaseServiceProtocol` + `AppDatabase`/`FakeAppDatabase` with `fetchEarthquakes()/replaceEarthquakes(_:)` |
| `DI/` | register repo + use case + `earthquakesViewModel` |
| `UI/Screens/Earthquakes/` | `EarthquakesView.swift` (`Map` + filter bar + optional replay scrubber + detail sheet), `EarthquakesViewModel.swift` |
| `Router` + Home | `case earthquakes` + a Science tile |

## B.5 The "motion" / replay
On the replay scrubber, the ViewModel keeps the fetched list (already sorted by `time`) and
advances a cutoff timestamp; the map shows only quakes with `time <= cutoff`, newly-revealed
ones fading/popping in. Pure UI timing; no extra network.

## B.6 Exception handling, offline cache & error UI — reuse Module A §6 exactly
- `EarthquakeRepositoryImpl` wraps in `safeRepositoryCall`; on network/server error → read
  cached feed from the DB; non-empty cache → `.success(cached)` with the **map still drawn**;
  empty cache → mapped `Failure`; cache-read failure → chained failure.
- ViewModel mirrors `PostViewModel` (`isLoading`, `currentFailure`, data array).
- View severity-routes: critical → full-screen `ErrorView(retry:)`; warning/info → **map of
  cached quakes + `ErrorSnackbar`** (stale quakes are genuinely useful offline).

---

# Module C — Open-Meteo Weather (current + forecast charts)

## C.1 Vision
A weather screen: **current-conditions card** (temp, apparent temp, condition, wind, humidity,
UV, day/night), an **hourly chart** (temp curve + precipitation-probability bars) and a
**multi-day forecast list** (high/low + condition icon) using **SwiftUI Charts** (native, no
dependency), plus a sunrise/sunset strip. Location from **device GPS** or **city search**.

## C.2 Locked decisions
| Topic | Decision |
|---|---|
| Render | **SwiftUI + SwiftUI Charts**, no dependency. Hourly = `LineMark` temp + `BarMark` precip; daily = list/`BarMark` high-low range. |
| Location | Device location via **CoreLocation** (with graceful permission handling) **or** city search via Open-Meteo geocoding. Default to a sensible city if permission denied. |
| Time control | None needed (it's a data-viz module, not a motion module). Optional hourly-timeline scrubber later. |
| Data source | **Open-Meteo** — keyless (forecast + geocoding). |

## C.3 Data source (KEYLESS, verified)
- Forecast: `https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,uv_index&hourly=temperature_2m,precipitation_probability,weather_code&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,weather_code&timezone=auto&forecast_days=7`
- Geocoding: `https://geocoding-api.open-meteo.com/v1/search?name=City&count=1`
- **Verified shape:** top-level `latitude/longitude/timezone`; `current{}` + `current_units{}`;
  `hourly{ time:[], temperature_2m:[], … }` + `hourly_units`; `daily{…}` + `daily_units`.
  `weather_code` (WMO code) maps to condition + SF Symbol. No auth, no key.

## C.4 Architecture mapping (existing MiniPi style)
| Layer | New files |
|---|---|
| `Domain/Models/` | `Weather.swift`, `HourlyForecast.swift`, `DailyForecast.swift`, `WeatherLocation.swift`, `WeatherCondition` (WMO code → enum) |
| `Domain/RepositoryInterfaces/` | `WeatherRepository.swift` (`func fetchWeather(at:) async -> Result<Weather>`) |
| `Domain/UseCases/Weather/` | `FetchWeatherUseCase.swift` |
| `Data/Remote/DTOs/` | `WeatherDto.swift` (+ nested `CurrentDto`/`HourlyDto`/`DailyDto`), `GeocodingDto.swift` |
| `Data/Remote/` | `ApiService.fetchWeather(lat:lon:) async throws -> WeatherDto`; `fetchGeocoding(_:)` |
| `Data/RepositoryImpls/` | `WeatherRepositoryImpl.swift` — cache fallback (see C.6) |
| `Data/Local/` | Extend `DatabaseServiceProtocol` + `AppDatabase`/`FakeAppDatabase` with `fetchWeather()/replaceWeather(_:)` |
| `DI/` | register repo + use case + `weatherViewModel` |
| `UI/Screens/Weather/` | `WeatherView.swift` (current card + Charts + daily list + sunrise/sunset + city search), `WeatherViewModel.swift` |
| `Router` + Home | `case weather` + a Science tile |

## C.5 CoreLocation handling (new wrinkle, not in posts/asteroids)
Permission/denial is a **non-error, non-blocking state**: if denied or unavailable, surface a
small info banner and default to a chosen city (or the city search). Do **not** treat it as a
`critical` failure. Represent it as an `info`-severity `Failure` (or a dedicated enum state)
shown via the existing `ErrorBanner`/`ErrorSnackbar`, so it still flows through the same UI.

## C.6 Exception handling, offline cache & error UI — reuse Module A §6
- `WeatherRepositoryImpl` wraps in `safeRepositoryCall`; on network/server error → return last
  cached forecast (short-term valid); empty cache → mapped `Failure`; cache-read failure →
  chained failure.
- ViewModel mirrors `PostViewModel`; View severity-routes (critical → `ErrorView`; warning/info
  → cached forecast + `ErrorSnackbar`).

---

# Build order across the Science section (when greenlit)
1. Module A (Asteroids) — most novel/3D; do first per its §A.7 phases.
2. Module B (Earthquakes) — `Map` is straightforward; reuses the cache/error pattern cleanly.
3. Module C (Weather) — Charts + CoreLocation; introduces permission handling.

Each module is independent and can ship separately. Add its Home tile + Router case only when
its screen lands.
