//
//  DesignSystem2.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 21/08/24.
//

import SwiftUI

// Dark scheme colors
struct DarkColors {
    static let primary = Color(red: 0.238, green: 325, blue: 0.687)
    static let primaryVariant = Color(red: 0.0, green: 0.373, blue: 0.698)
    static let secondary = Color(red: 0.4, green: 0.733, blue: 0.416)
    static let background = Color(red: 0.129, green: 0.129, blue: 0.129)
    static let surface = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let error = Color(red: 0.69, green: 0.0, blue: 0.125)
    static let onPrimary = Color.black
    static let onSecondary = Color.white
    static let onBackground = Color.white
    static let onSurface = Color.white
    static let onError = Color.white
}

// Light scheme colors
struct LightColors {
    static let primary = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let primaryVariant = Color(red: 0.0, green: 0.373, blue: 0.698)
    static let secondary = Color(red: 0.611, green: 0.8, blue: 0.396)
    static let background = Color.white
    static let surface = Color(red: 0.969, green: 0.969, blue: 0.969)
    static let error = Color(red: 0.835, green: 0.0, blue: 0.0)
    static let onPrimary = Color.white
    static let onSecondary = Color.black
    static let onBackground = Color.black
    static let onSurface = Color.black
    static let onError = Color.black
}

//
// Define custom fonts
extension Font {
    static let displayLarge = Font.custom("Montserrat-Regular", size: 57)
    static let displayMedium = Font.custom("Montserrat-Regular", size: 45)
    static let displaySmall = Font.custom("Montserrat-Regular", size: 36)

    static let headlineLarge = Font.custom("Montserrat-Regular", size: 32)
    static let headlineMedium = Font.custom("Montserrat-Regular", size: 28)
    static let headlineSmall = Font.custom("Montserrat-Regular", size: 24)

    static let titleLarge = Font.custom("Montserrat-Bold", size: 22)
    static let titleMedium = Font.custom("Montserrat-Bold", size: 16)
    static let titleSmall = Font.custom("Montserrat-Medium", size: 14)

    static let bodyLarge = Font.custom("Montserrat-Regular", size: 16)
    static let bodyMedium = Font.custom("Montserrat-Regular", size: 14)
    static let bodySmall = Font.custom("System-Regular", size: 12)

    static let labelLarge = Font.custom("Montserrat-Medium", size: 14)
    static let labelMedium = Font.custom("Montserrat-Medium", size: 12)
    static let labelSmall = Font.custom("Montserrat-Medium", size: 11)
}

// Group all typography styles into a single object
struct FontScheme {
    let displayLarge = Font.displayLarge
    let displayMedium = Font.displayMedium
    let displaySmall = Font.displaySmall
    let headlineLarge = Font.headlineLarge
    let headlineMedium = Font.headlineMedium
    let headlineSmall = Font.headlineSmall
    let titleLarge = Font.titleLarge
    let titleMedium = Font.titleMedium
    let titleSmall = Font.titleSmall
    let bodyLarge = Font.bodyLarge
    let bodyMedium = Font.bodyMedium
    let bodySmall = Font.bodySmall
    let labelLarge = Font.labelLarge
    let labelMedium = Font.labelMedium
    let labelSmall = Font.labelSmall
}

class DesignSystem: ObservableObject {
    @Published var colorScheme: ColorScheme
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }
    
    func updateColorScheme(_ colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }
    
    var types: FontScheme {
        return FontScheme()
    }
    
    struct Sizes {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 32
        static let xl: CGFloat = 64
        static let xxl: CGFloat = 128
    }
    
    enum shadows {
        case buttonCard
        case buttonCardHover
        case navigationMenu
        case modal
        case bottomSheet
    }
    
    func shadow(for type: shadows) -> DSShadowComponent {
        switch type {
        case .buttonCard:
            return DSShadowComponent(color: .gray, radius: 2, x: 0, y: 1)
        case .buttonCardHover:
            return DSShadowComponent(color: .gray, radius: 4, x: 0, y: 4)
        case .navigationMenu:
            return DSShadowComponent(color: .gray, radius: 19, x: 0, y: 19)
        case .modal:
            return DSShadowComponent(color: .gray, radius: 8, x: 7, y: 14)
        case .bottomSheet:
            return DSShadowComponent(color: .gray, radius: 8, x: -2, y: 4)
        }
    }
}

struct ColorScheme {
    let primary: Color
    let primaryVariant: Color
    let secondary: Color
    let background: Color
    let surface: Color
    let error: Color
    let onPrimary: Color
    let onSecondary: Color
    let onBackground: Color
    let onSurface: Color
    let onError: Color

    init(dark: DarkColors.Type, light: LightColors.Type) {
        let currentStyle = UITraitCollection.current.userInterfaceStyle
        if currentStyle == .dark {
            self.primary = dark.primary
            self.primaryVariant = dark.primaryVariant
            self.secondary = dark.secondary
            self.background = dark.background
            self.surface = dark.surface
            self.error = dark.error
            self.onPrimary = dark.onPrimary
            self.onSecondary = dark.onSecondary
            self.onBackground = dark.onBackground
            self.onSurface = dark.onSurface
            self.onError = dark.onError
        } else {
            self.primary = light.primary
            self.primaryVariant = light.primaryVariant
            self.secondary = light.secondary
            self.background = light.background
            self.surface = light.surface
            self.error = light.error
            self.onPrimary = light.onPrimary
            self.onSecondary = light.onSecondary
            self.onBackground = light.onBackground
            self.onSurface = light.onSurface
            self.onError = light.onError
        }
    }
}

struct DSShadowComponent: ViewModifier {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}


extension View {
    @ViewBuilder
    func designSystemShadow(for type: DesignSystem.shadows) -> some View {
        self.modifier(DSShadowComponent(color: .gray, radius: 4, x: 0, y: 4))
    }
}
