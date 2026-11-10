//
//  CaptureSignals.swift
//  PurgeQuest
//
//  What Photos says about how an item was captured, as plain values. PhotoLibraryService reads the
//  PhotoKit flags and file names; anything that needs judgment (what counts as a screen recording)
//  is decided here, in Foundation only, so the Linux harness tests it.
//

import Foundation

/// The capture facts the classifier reads. Every field is one PhotoKit flag or one rule below.
struct CaptureSignals: Sendable, Equatable {
    var isScreenshot = false
    var hasEdits = false
    var isScreenRecording = false
    var isLivePhoto = false
    var isLooping = false
    var isHighFrameRate = false
    var isTimelapse = false
    var isPanorama = false
}

enum CaptureSignalRules {

    /// True when Photos flags the video as a screen recording, or one of its files is named like one.
    ///
    /// The flag is `PHAssetMediaSubtype.videoScreenRecording`, the one the Photos app's own Screen
    /// Recordings album is built from. The name is the fallback for a recording that arrives without
    /// the flag: sent from a Mac, or saved back out of another app.
    static func isScreenRecording(flagged: Bool, filenames: [String]) -> Bool {
        flagged || filenames.contains(where: namesAScreenRecording)
    }

    /// Names the system gives its own recordings: `RPReplay_Final1699999999.MP4` (ReplayKit, older
    /// iOS), `ScreenRecording_11-10-2026 14-00-00_1.MP4` (newer iOS) and
    /// `Screen Recording 2026-11-10 at 14.00.00.mov` (macOS). Spacing, case and punctuation vary
    /// between them, so only the letters and digits are compared.
    static func namesAScreenRecording(_ filename: String) -> Bool {
        let name = String(filename.lowercased().filter { $0.isLetter || $0.isNumber })
        return name.contains("screenrecording") || name.hasPrefix("rpreplay")
    }
}
