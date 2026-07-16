//
//  AppearanceManager.swift
//  MiniPi
//
//  Owns the user's in-app appearance preference (System / Light / Dark) and
//  persists it across launches. RootView consumes `swiftUIScheme` to drive
//  `.preferredColorScheme`, and the drawer binds to `preference` directly.
//

import SwiftUI

/// The user's chosen color-scheme override. `.system` follows the device.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    /// Human-readable label for the segmented picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// SF Symbol shown next to the option.
    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Value to pass to `.preferredColorScheme(_:)`. `nil` lets the app follow
    /// the system appearance.
    var swiftUIScheme: SwiftUI.ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Single source of truth for the manual appearance override. Persisted to
/// `UserDefaults` so the choice survives relaunch.
final class AppearanceManager: ObservableObject {

    private static let storageKey = "minipi.appearancePreference"

    @Published var preference: AppearancePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppearancePreference.system.rawValue
        self.preference = AppearancePreference(rawValue: stored) ?? .system
    }
}
