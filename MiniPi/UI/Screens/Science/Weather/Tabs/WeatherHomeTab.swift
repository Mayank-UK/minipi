//
//  WeatherHomeTab.swift
//  MiniPi
//
//  The Home tab of the weather screen set. Built on the shared PageScaffold (header
//  with an embedded city search + responsive ScrollView), mirroring
//  EarthquakeHomeTab. Loading / error / refresh states wrap PageScaffold since they
//  are feature-specific. Error routing follows the same severity rules (critical +
//  no cache → full ErrorView; warning with cached data → non-blocking snackbar).
//

import SwiftUI

struct WeatherHomeTab: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if isLoadingCritical {
                ErrorView(failure: viewModel.currentFailure!,
                          onRetry: { Task { await viewModel.bootstrap() } })
            } else if viewModel.locating {
                locatingState
            } else if viewModel.isLoading && viewModel.forecast == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let forecast = viewModel.forecast {
                PageScaffold(
                    title: forecast.location.displayName,
                    mobile: { AnyView(content(forecast, columns: 1)) },
                    tablet: { AnyView(content(forecast, columns: 2)) },
                    background: cs.space,
                    onRefresh: { await viewModel.loadForecast(force: true) },
                    trailing: { AnyView(locationToggle) }
                )
            } else {
                emptyState
            }

            if showsSnackbar, let failure = viewModel.currentFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearError() })
                    .padding(.bottom, 56)
            }
        }
        .task {
            if viewModel.forecast == nil && viewModel.currentFailure == nil {
                await viewModel.bootstrap()
            }
        }
    }

    private var locatingState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "location.fill")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitPrimary)
            Text("Locating…")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace.opacity(0.7))
            Text("Finding your current location")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State helpers

    private var isLoadingCritical: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity == .critical && viewModel.forecast == nil
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || viewModel.forecast != nil
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ forecast: WeatherForecast, columns: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.lg) {
            searchBar

            if !viewModel.searchResults.isEmpty || viewModel.isSearching {
                searchResultsList
            }

            currentCard(forecast.current)
            statGrid(forecast.current, columns: columns)
            highlightsRow(forecast)
            hourlySection
            dailySection(forecast.days)
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.bottom, DesignSystem.Sizes.xxl)
    }

    // MARK: - Header toggle (current location vs chosen city)

    /// When a manual city is selected, tapping re-resolves the device location;
    /// when already on the current location, the icon just reads as a status indicator.
    private var locationToggle: some View {
        Button {
            if !viewModel.isAutoLocation {
                viewModel.resetToAutoLocation()
            }
        } label: {
            Image(systemName: viewModel.isAutoLocation ? "location.fill" : "location")
                .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                .foregroundStyle(cs.orbitPrimary)
                .padding(DesignSystem.Sizes.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search bar + results

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Search city or location…", text: $viewModel.searchQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.scheduleSearch()
                }
            if viewModel.isSearching {
                ProgressView().tint(cs.orbitPrimary).scaleEffect(0.8)
            } else if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface)
        .clipShape(Capsule())
    }

    private var searchResultsList: some View {
        VStack(spacing: DesignSystem.Sizes.xs) {
            if viewModel.isSearching && viewModel.searchResults.isEmpty {
                Text("Searching…")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Sizes.sm)
            }
            ForEach(viewModel.searchResults) { city in
                Button {
                    viewModel.selectCity(city)
                } label: {
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(cs.orbitAccent)
                        Text(city.displayName)
                            .font(designSystem.types.titleSmall)
                            .foregroundStyle(cs.onSpace)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: DesignSystem.Sizes.iconSm))
                            .foregroundStyle(cs.onSpace.opacity(0.3))
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.vertical, DesignSystem.Sizes.sm)
                    .background(cs.spaceSurface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
                }
                .buttonStyle(.plain)
            }
            if let failure = viewModel.searchFailure {
                Text(failure.message)
                    .font(designSystem.types.labelSmall)
                    .foregroundStyle(cs.distanceDanger)
                    .padding(DesignSystem.Sizes.sm)
            }
        }
    }

    // MARK: - Current conditions

    private func currentCard(_ current: CurrentWeather) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Sizes.sm) {
                Text(current.tempText)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(cs.hazard)
                Spacer()
                WeatherIconView(code: current.conditionCode, isDay: current.isDay, size: DesignSystem.Sizes.iconXl)
            }
            Text(current.conditionText ?? "—")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)
            Text("Feels like \(current.feelsLikeText)")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    private func statGrid(_ current: CurrentWeather, columns: Int) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: max(columns, 2))
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "Humidity", value: current.humidityText, icon: "humidity", accent: cs.orbitAccent)
            StatTile(title: "Wind", value: current.windText, icon: "wind", accent: cs.orbitPrimary)
            StatTile(title: "Pressure", value: current.pressureText, icon: "gauge", accent: cs.distanceSafe)
            StatTile(title: "Visibility", value: current.visibilityText, icon: "eye", accent: cs.orbitAccent)
        }
    }

    private func highlightsRow(_ forecast: WeatherForecast) -> some View {
        let today = forecast.today
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "Max Temp", value: today?.maxTempText ?? "—", icon: "thermometer.sun", accent: cs.hazard)
            StatTile(title: "Min Temp", value: today?.minTempText ?? "—", icon: "thermometer.snowflake", accent: cs.orbitPrimary)
            StatTile(title: "Precipitation", value: today.map { _ in forecast.current.precipText } ?? "—", icon: "cloud.rain", accent: cs.distanceSafe)
            StatTile(title: "UV Index", value: forecast.current.uvText, icon: "sun.max", accent: cs.hazard)
        }
    }

    // MARK: - Hourly

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Hourly Forecast")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if viewModel.homeHourly.isEmpty {
                Text("No hourly data")
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Sizes.md) {
                        ForEach(viewModel.homeHourly) { hour in
                            hourCell(hour)
                        }
                    }
                }
            }
        }
    }

    private func hourCell(_ hour: HourForecast) -> some View {
        VStack(spacing: DesignSystem.Sizes.xs) {
            Text(hourTimeText(hour.time))
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.6))
            WeatherIconView(code: hour.conditionCode, isDay: true, size: DesignSystem.Sizes.iconMd)
            Text(hour.tempText)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
            Text(hour.rainChanceText)
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.orbitPrimary.opacity(0.8))
        }
        .frame(width: 56)
        .padding(.vertical, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }

    private func hourTimeText(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f.string(from: date).lowercased()
    }

    // MARK: - Daily

    private func dailySection(_ days: [DayForecast]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("7-Day Forecast")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if days.isEmpty {
                Text("No daily data")
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))
            } else {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(days) { day in
                        dayRow(day)
                    }
                }
            }
        }
    }

    private func dayRow(_ day: DayForecast) -> some View {
        HStack(spacing: DesignSystem.Sizes.md) {
            Text(day.weekdayText)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
                .frame(width: 44, alignment: .leading)
            WeatherIconView(code: day.conditionCode, isDay: true, size: DesignSystem.Sizes.iconMd)
                .frame(width: 28)
            Text(day.minTempText)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            rangeBar(lowTemp: day.minTempC, highTemp: day.maxTempC)
            Text(day.maxTempText)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace)
            Spacer()
            Text(day.dailyChanceOfRain.map { "\(Int($0))%" } ?? "—")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.orbitPrimary.opacity(0.8))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }

    /// A tiny temperature-range bar normalised to the week's min/max.
    private func rangeBar(lowTemp: Double?, highTemp: Double?) -> some View {
        let week = viewModel.weekTempRange
        let lo = week?.min ?? 0
        let hi = week?.max ?? (lo + 1)
        let span = Swift.max(hi - lo, 1)
        let low = lowTemp ?? lo
        let high = highTemp ?? hi
        let start = Swift.max(0, Swift.min(1, (low - lo) / span))
        let end = Swift.max(start, Swift.min(1, (high - lo) / span))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(cs.onSpace.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [cs.orbitPrimary, cs.hazard],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * (end - start))
                    .offset(x: geo.size.width * start)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "cloud.sun")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No weather data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadForecast(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
