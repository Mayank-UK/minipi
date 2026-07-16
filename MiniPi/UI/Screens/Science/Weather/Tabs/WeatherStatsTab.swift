//
//  WeatherStatsTab.swift
//  MiniPi
//
//  The Stats tab: charts over the loaded forecast dataset. Built with Swift Charts
//  (iOS 16+), mirroring EarthquakeStatsTab — hourly temperature trend, 7-day
//  high/low range, precipitation, and humidity/wind. The card helper is copied from
//  the earthquake stats tab (niche to chart surfaces).
//

import SwiftUI
import Charts

struct WeatherStatsTab: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.forecast == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let forecast = viewModel.forecast {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        Text("Statistics")
                            .font(designSystem.types.headlineSmall)
                            .foregroundStyle(cs.onSpace)

                        temperatureTrendChart
                        dailyRangeChart(forecast.days)
                        precipChart(forecast.days)
                        humidityWindChart(forecast.days)
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            } else {
                emptyState
            }
        }
        .task {
            if viewModel.forecast == nil {
                await viewModel.loadForecast()
            }
        }
    }

    // MARK: - Charts

    /// Hourly temperature trend over the next ~24h.
    private var temperatureTrendChart: some View {
        let hours = viewModel.upcomingHours
        return card(title: "Temperature Trend (next 24h)") {
            Chart(hours) { hour in
                LineMark(
                    x: .value("Time", hour.time ?? .distantPast),
                    y: .value("Temp", hour.tempC ?? 0)
                )
                .foregroundStyle(cs.hazard)
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Time", hour.time ?? .distantPast),
                    y: .value("Temp", hour.tempC ?? 0)
                )
                .foregroundStyle(cs.hazard.opacity(0.18))
                .interpolationMethod(.monotone)
            }
            .frame(height: 200)
        }
    }

    /// 7-day high/low range.
    private func dailyRangeChart(_ days: [DayForecast]) -> some View {
        card(title: "Daily High / Low") {
            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.weekdayText),
                    yStart: .value("Low", day.minTempC ?? 0),
                    yEnd: .value("High", day.maxTempC ?? 0)
                )
                .foregroundStyle(cs.orbitPrimary)
                .opacity(0.85)
            }
            .frame(height: 200)
        }
    }

    /// Precipitation per day (mm).
    private func precipChart(_ days: [DayForecast]) -> some View {
        card(title: "Precipitation (mm)") {
            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.weekdayText),
                    y: .value("Precip", day.totalPrecipMm ?? 0)
                )
                .foregroundStyle(cs.distanceSafe)
            }
            .frame(height: 160)
        }
    }

    /// Humidity vs max wind per day.
    private func humidityWindChart(_ days: [DayForecast]) -> some View {
        card(title: "Humidity & Wind") {
            Chart(days) { day in
                LineMark(
                    x: .value("Day", day.weekdayText),
                    y: .value("Humidity", day.avgHumidity ?? 0)
                )
                .foregroundStyle(cs.orbitAccent)
                .interpolationMethod(.monotone)

                BarMark(
                    x: .value("Day", day.weekdayText),
                    y: .value("Wind", day.maxWindKph ?? 0)
                )
                .foregroundStyle(cs.orbitPrimary.opacity(0.35))
            }
            .frame(height: 180)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "chart.bar")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No data to chart yet")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
