//
//  SeasonalEventBanner.swift
//  PurgeQuest
//

import SwiftUI

struct SeasonalEventBanner: View {
    let event: SeasonalEvent
    @State private var shimmer: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [event.primary, event.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .blur(radius: shimmer ? 6 : 2)
                Image(systemName: event.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("LIMITED EVENT")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(event.primary.opacity(0.25)))
                        .foregroundStyle(event.primary)
                    Text(event.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Text(event.tagline)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [event.primary.opacity(0.25), event.secondary.opacity(0.18)], startPoint: .leading, endPoint: .trailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(event.primary.opacity(0.55), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                shimmer.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.name). \(event.tagline)")
    }
}
