//
//  UITestSupport.swift
//  PurgeQuest
//
//  Launch-argument hooks for the screenshot tour (AppearanceTourUITests). All of
//  it is compiled out of Release builds: `isTour` is a constant false there.
//
//    -UITestTour            in-memory store, no photo-permission prompt
//    -UITestPhase <phase>   splash | onboarding | main (default main)
//

import Foundation

enum UITestSupport {
    static var isTour: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("-UITestTour")
        #else
        return false
        #endif
    }

    /// The screen a tour launch should stop on, or nil outside a tour.
    static var requestedPhase: AppPhase? {
        #if DEBUG
        guard isTour else { return nil }
        switch UserDefaults.standard.string(forKey: "UITestPhase") {
        case "splash":     return .launching
        case "onboarding": return .onboarding
        default:           return .main
        }
        #else
        return nil
        #endif
    }
}
