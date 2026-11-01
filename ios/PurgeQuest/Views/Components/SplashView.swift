//
//  SplashView.swift
//  PurgeQuest
//
//  Launch splash: wordmark, gold emblem, spinner and tagline on the themed
//  canvas (cream in Light, green-black in Dark).
//

import SwiftUI

struct SplashView: View {
    static let tagline = "Clean your Digital Dungeon\nand Tidy Your Digital Keep!"

    var body: some View {
        ZStack {
            DungeonBackgroundView()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                WordmarkView()
                Spacer(minLength: 24)
                EmblemView()
                    .frame(maxWidth: 230)
                Spacer(minLength: 24)
                GoldSpinner(size: 48)
                Spacer(minLength: 28)
                Text(Self.tagline)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 48)
            }
            .padding(.horizontal, 32)
        }
    }
}
