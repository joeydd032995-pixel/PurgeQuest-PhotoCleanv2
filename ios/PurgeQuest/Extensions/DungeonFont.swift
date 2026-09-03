//
//  DungeonFont.swift
//  PurgeQuest
//
//  Cinzel, the engraved-capitals display face used only in dungeon-crawler
//  zones. The TTFs ship as data assets in the asset catalog and are registered
//  at launch, so no Info.plist entry is needed.
//

import SwiftUI
import UIKit

enum DungeonFont {
    /// Registers every bundled Cinzel face. Call once at app start.
    static func registerAll() {
        for assetName in ["Cinzel-Regular", "Cinzel-SemiBold", "Cinzel-Bold"] {
            guard let asset = NSDataAsset(name: assetName) else { continue }
            guard let provider = CGDataProvider(data: asset.data as CFData),
                  let font = CGFont(provider) else { continue }
            CTFontManagerRegisterGraphicsFont(font, nil)
        }
    }
}

extension Font {
    /// Engraved display face for dungeon-zone panel titles.
    static let dungeonTitle = Font.custom("Cinzel-Bold", size: 24, relativeTo: .title2)
    /// Section headers inside dungeon-crawler panels.
    static let dungeonHeader = Font.custom("Cinzel-SemiBold", size: 17, relativeTo: .headline)
    /// Small caps-style labels in dungeon-crawler panels.
    static let dungeonCaption = Font.custom("Cinzel-Regular", size: 12, relativeTo: .caption)

    static func dungeon(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        Font.custom("Cinzel-SemiBold", size: size, relativeTo: style)
    }
}
