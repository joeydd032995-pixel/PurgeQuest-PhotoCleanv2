//
//  PhotoAccessNotice.swift
//  PurgeQuest
//
//  Says that the app cannot see the whole photo library, why, and the one thing to do about it. It
//  sits at the top of the Library for as long as access is anything short of full, so a library the
//  app may not open is never mistaken for a clean one. The words come from PhotoAccess.
//

import SwiftUI

struct PhotoAccessNotice: View {
    let access: PhotoAccess
    /// Runs when the action is tapped. The caller decides what it means for each state: ask, or open Settings.
    let onAction: () -> Void

    private var tint: Color {
        switch access {
        case .denied, .restricted: return .combatCrimson
        case .limited, .notAsked:  return .questAmber
        case .full:                return .gemEmerald
        }
    }

    private var symbol: String {
        switch access {
        case .denied, .restricted: return "lock.fill"
        case .limited, .notAsked:  return "exclamationmark.triangle.fill"
        case .full:                return "checkmark.circle.fill"
        }
    }

    var body: some View {
        if access.needsAttention {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(access.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.textPrimary)
                    Text(access.message)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let actionTitle = access.actionTitle {
                    Button(action: onAction) {
                        Text(actionTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(DungeonPanelBackground(cornerRadius: DungeonRadius.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(DungeonPanelBackground(accent: tint))
            .accessibilityElement(children: .contain)
        }
    }
}
