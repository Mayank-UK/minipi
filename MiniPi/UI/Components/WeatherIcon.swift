//
//  WeatherIcon.swift
//  MiniPi
//
//  Maps a WeatherAPI.com condition `code` (and day/night) to an SF Symbol, with a
//  themable view. Used across the Weather Home, Stats and Map detail — so it lives
//  in global components (single source of truth, mirroring HazardBadge /
//  MagnitudeBadge). No network image dependency: rendering is offline-friendly.
//

import SwiftUI

enum WeatherIcon {

    /// SF Symbol name for a WeatherAPI condition code. Day/night variants are picked
    /// for clear + partly-cloudy so the icon reads correctly at night.
    static func symbol(for code: Int?, isDay: Bool) -> String {
        guard let code else { return "questionmark" }
        switch code {
        // Clear / sunny
        case 1000:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        // Partly cloudy
        case 1003:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        // Cloudy / overcast
        case 1006: return "cloud.fill"
        case 1009: return "smoke.fill"
        // Mist / fog
        case 1030, 1135, 1147: return "cloud.fog.fill"
        // Drizzle / rain
        case 1063, 1150, 1153, 1168, 1171, 1180, 1183, 1186, 1189, 1192, 1195, 1240, 1243, 1246:
            return "cloud.rain.fill"
        // Snow
        case 1066, 1114, 1117, 1210, 1213, 1216, 1219, 1222, 1225, 1255, 1258, 1261, 1264:
            return "cloud.snow.fill"
        // Sleet / ice
        case 1069, 1072, 1198, 1201, 1204, 1207, 1237, 1249, 1252:
            return "cloud.sleet.fill"
        // Thunder / thunder-rain
        case 1087, 1273, 1276, 1279, 1282:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }
}

/// A themable weather symbol sized for a given point size.
struct WeatherIconView: View {
    let code: Int?
    var isDay: Bool = true
    var size: CGFloat = DesignSystem.Sizes.iconLg
    var color: Color? = nil

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        Image(systemName: WeatherIcon.symbol(for: code, isDay: isDay))
            .font(.system(size: size))
            .foregroundStyle(color ?? cs.hazard)
    }
}
