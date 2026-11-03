//
//  WidgetColors.swift
//  PurgeQuestWidget
//
//  SwiftUI colors for the widget palette. Each one is dynamic: it resolves to the Light or Dark
//  value of the appearance it is drawn in, which for a widget is the system's.
//

import SwiftUI
import UIKit

extension Color {
    /// Resolves to `pair.light` or `pair.dark` with the appearance it is drawn in.
    init(_ pair: WidgetPair) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? pair.dark : pair.light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let widgetCanvasTop = Color(WidgetPalette.canvasTop)
    static let widgetSurface = Color(WidgetPalette.surface)
    static let widgetHairline = Color(WidgetPalette.hairline)
    static let widgetTextPrimary = Color(WidgetPalette.textPrimary)
    static let widgetTextSecondary = Color(WidgetPalette.textSecondary)
    static let widgetAmber = Color(WidgetPalette.amber)
    static let widgetSapphire = Color(WidgetPalette.sapphire)
    static let widgetCrimson = Color(WidgetPalette.crimson)
    static let widgetEmerald = Color(WidgetPalette.emerald)
}
