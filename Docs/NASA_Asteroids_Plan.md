# MiniPi — NASA Asteroids (Eyes-style) module

> **Status:** Planned — not yet implemented. This document is the source of truth for
> resuming development. It captures every decision made during planning, the exact data
> source, the physics, the architecture mapping, and — critically — the exception-handling
> / offline-cache / error-UI patterns this module **must** follow to match the rest of MiniPi.
>
> **Target screen:** `UI/Screens/NasaAsteroid/NasaAsteroidView.swift`
> **Do not start coding until the owner says go.**

---

## 1. Vision

A 3D, NASA-["Eyes on Asteroids"](https://eyes.nasa.gov/apps/asteroids/#/home)-style screen
where real near-Earth asteroids **revolve around the Sun in real time** along their true
orbits. The Sun sits at the centre; planets are shown as reference; the user can drag to
orbit the camera, pinch to zoom, scale time (live → up to 7 days/sec), and tap any body for a
detail card.

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Motion | Real-time revolution computed **client-side** from orbital elements (no per-frame network) |
| Render | **3D — SceneKit** (ships with iOS; no engine dependency) |
| Time control | **Live "now" by default**, scrubber up to **max 7 days/sec**. Presets: Live · 1 min/s · 1 hr/s · 1 day/s · 3 days/s · 7 days/s |
| Sun + planets | **Stylized colored spheres** (Earth blue-green, Mars rust, Saturn tan+ring, …). *(Confirm: photoreal textures also possible if desired.)* |
| Real photo | Shown **only in the detail card** when a body is tapped (NASA imagery) |
| Asteroids | Glowing dots/sprites gliding along faint orbit rings |
| Data source | **NASA NeoWs** (one free key) — gives orbital elements **and** close-approach stats |

## 3. Data source & auth

**API:** NASA NeoWs — `https://api.nasa.gov/neo/rest/v1/...`

- `…/neo/browse?api_key=KEY` — paginated list of all asteroids (each with `orbital_data`)
- `…/neo/{id}?api_key=KEY` — full lookup for a specific body (e.g. 433 Eros, 4179 Toutatis,
  25143 Itokawa, 99942 Apophis, 101955 Bennu)
- `…/feed?start_date=…&end_date=…&api_key=KEY` — asteroids approaching in a date window
- `DEMO_KEY` works for dev but is rate-limited (~30 req/hr/IP). Use the real key for real use.

**Where the key is stored:** in the per-environment xcconfig files under
`Config/{Development,Staging,Production}.xcconfig` as `NASA_API_KEY=…`, surfaced into the app
via `Info.plist` (`NASA_API_KEY` → `$(NASA_API_KEY)`), and read at runtime by
`AppConfiguration` (same pattern as the existing `API_BASE_URL`). **Key (kept here for the
dev):** see the xcconfig files. *Security note: if this repo ever goes public, move the key
into a git-ignored local xcconfig instead of committing it.*

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

## 4. The physics (pure Swift, Domain layer)

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

## 5. Architecture mapping (follow existing MiniPi style)

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

## 6. Exception handling, offline cache & error UI — **MANDATORY pattern**

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

## 7. Build phases (order, when greenlit)

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

## 8. Open decisions (resolve before/during build)

- **Planet look:** stylized spheres (default) vs photoreal texture maps. *(Awaiting confirm.)*
- **Asteroid set:** a curated famous-asteroid list, or all of "today's close approaches," or both.
- **Reference planets:** include all 8, or just Earth (so close approaches read in context)?
- **Key handling:** real key vs `DEMO_KEY`.

## 9. Reference files (copy the patterns, don't reinvent)

- Repository + offline cache: `MiniPi/MiniPi/Data/RepositoryImpls/PostRepositoryImpl.swift`
- Guards: `Core/Guards/{GuardedApiCall,SafeRepositoryCall}.swift`
- Exception→Failure mapping: `Core/Mapping/ExceptionMapper.swift`, `Core/Failures/*`, `Core/Exceptions/*`
- ViewModel error state: `IosDevelopersGuide/.../PostView/PostViewModel.swift`
- View severity routing: `IosDevelopersGuide/.../PostView/PostView.swift`
- Error UI: `UI/Components/{ErrorView.swift (Screens/Error),ErrorBanner.swift,ErrorSnackbar.swift}`
