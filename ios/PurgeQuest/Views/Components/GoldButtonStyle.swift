//
//  GoldButtonStyle.swift
//  PurgeQuest
//
//  The brand gold plate button ("CONTINUE"): a vertical gold gradient with a
//  bronze rim and a thin bevel line just inside it, set in engraved Cinzel with
//  dark brown ink. The plate is the same in Light and Dark.
//
//      Button("Continue") { ... }.buttonStyle(.gold)
//      Button { ... } label: { Label("Enter", systemImage: "shield") }.buttonStyle(.gold(fullWidth: true))
//

import SwiftUI

/// The gold plate itself, usable as a background for non-button surfaces too.
struct GoldPlate: View {
    var cornerRadius: CGFloat = 12
    var pressed: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient.goldPlate)
            shape.inset(by: 3).stroke(Color.goldBevel.opacity(0.55), lineWidth: 1)
            shape.strokeBorder(Color.goldRim, lineWidth: 1.5)
            if pressed {
                shape.fill(Color.goldInk.opacity(0.12))
            }
        }
        .shadow(color: Color.goldRim.opacity(0.35), radius: 3, x: 0, y: 2)
    }
}

struct GoldButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GoldButtonBody(configuration: configuration, fullWidth: fullWidth)
    }
}

private struct GoldButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var maxWidth: CGFloat? { fullWidth ? CGFloat.infinity : nil }
    private var dimming: Double { isEnabled ? 1.0 : 0.45 }
    private var pressScale: CGFloat { configuration.isPressed ? 0.98 : 1.0 }

    var body: some View {
        label
            .background(GoldPlate(pressed: configuration.isPressed))
            .opacity(dimming)
            .scaleEffect(pressScale)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    /// Engraved ink on the plate; padding makes the whole plate the tap target.
    private var label: some View {
        configuration.label
            .font(.dungeonButton)
            .tracking(0.4)
            .foregroundStyle(Color.goldInk)
            .tint(Color.goldInk)
            .frame(maxWidth: maxWidth)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == GoldButtonStyle {
    /// Gold plate sized to its label.
    static var gold: GoldButtonStyle { GoldButtonStyle() }

    /// Gold plate, optionally stretched to the full available width.
    static func gold(fullWidth: Bool) -> GoldButtonStyle { GoldButtonStyle(fullWidth: fullWidth) }
}
