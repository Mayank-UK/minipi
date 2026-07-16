//
//  WeatherMapTab.swift
//  MiniPi
//
//  The Map tab: an Apple MapKit map with an OpenWeatherMap weather tile overlay
//  colouring the whole map by the selected metric (Temperature / Precipitation /
//  Cloud / Wind), plus a heat-map legend and a layer selector. The legend + layer
//  selector are niche to this tab, so they live here.
//

import SwiftUI

struct WeatherMapTab: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            WeatherMapOverlayView(
                layer: viewModel.selectedLayer,
                coordinate: viewModel.activeCoordinate
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    legend
                    Spacer()
                    layerSelector
                }
                .padding(.horizontal, DesignSystem.Sizes.md)
                .padding(.top, DesignSystem.Sizes.sm)

                Spacer()

                if AppConfiguration.shared.owmApiKey.isEmpty {
                    missingKeyHint
                }
            }
        }
    }

    // MARK: - Layer selector (chip row)

    private var layerSelector: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Sizes.xs) {
            ForEach(WeatherMetric.mapLayers) { layer in
                Chip(
                    label: layer.title,
                    icon: layer.icon,
                    isSelected: viewModel.selectedLayer == layer
                ) {
                    viewModel.selectedLayer = layer
                }
            }
        }
        .padding(DesignSystem.Sizes.sm)
        .background(cs.spaceSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.pillRadius))
    }

    // MARK: - Heat-map legend

    /// A vertical gradient strip with the layer's range bounds. Colours are sampled
    /// from `WeatherMetric.color(forValue:metric:)` so the legend tracks the overlay.
    private var legend: some View {
        let metric = viewModel.selectedLayer
        return VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            Text(metric.title)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.85))
            HStack(spacing: DesignSystem.Sizes.sm) {
                LinearGradient(
                    colors: (0...5).map { i in
                        let t = Double(i) / 5
                        let lo = metric.range.lowerBound
                        let hi = metric.range.upperBound
                        return WeatherMetric.color(forValue: lo + (hi - lo) * t, metric: metric)
                    },
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 10, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 0) {
                    Text(legendLabel(for: metric.range.upperBound, metric: metric))
                    Spacer()
                    Text(legendLabel(for: metric.range.lowerBound, metric: metric))
                }
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.75))
                .frame(height: 96, alignment: .center)
            }
        }
        .padding(DesignSystem.Sizes.sm)
        .background(cs.spaceSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.pillRadius))
    }

    private func legendLabel(for value: Double, metric: WeatherMetric) -> String {
        switch metric {
        case .temperature, .wind, .humidity, .cloud:
            return "\(Int(value.rounded()))\(metric.unit)"
        case .precipitation:
            return String(format: "%.0f%@", value, metric.unit)
        }
    }

    // MARK: - Missing key hint

    private var missingKeyHint: some View {
        HStack(spacing: DesignSystem.Sizes.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(cs.hazard)
            Text("Add an OpenWeatherMap key to see the colour overlay")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.8))
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.xs + 2)
        .background(cs.spaceSurface.opacity(0.9))
        .clipShape(Capsule())
        .padding(.bottom, DesignSystem.Sizes.md)
    }
}
