//
//  PhotoAccess.swift
//  PurgeQuest
//
//  What the app can do with the photo library, in the terms the screens need, and the words that
//  go with each state. Foundation only: it meets PHAuthorizationStatus as the raw value that status
//  carries (0 not determined, 1 restricted, 2 denied, 3 authorized, 4 limited), so every rule here
//  runs in the Linux harness. AppState.swift builds one from the real status.
//
//  The rule it exists to keep: when the app cannot see the library, no screen may say the library
//  is clean. "All clear" and "All reviewed" mean "I looked and found nothing", which is not true
//  of a library the app was never allowed to open.
//

import Foundation

nonisolated enum PhotoAccess: Equatable, Sendable {
    /// The system prompt has not been shown yet.
    case notAsked
    /// The whole library.
    case full
    /// Only the photos the user picked.
    case limited
    /// The user said no. Settings is the only way back.
    case denied
    /// Screen Time or device management blocks it; the user cannot change it from here.
    case restricted

    /// Reads a `PHAuthorizationStatus` raw value. Anything unknown is treated as denied: the safe
    /// reading is the one that tells the user, not the one that pretends all is well.
    init(rawStatus: Int) {
        switch rawStatus {
        case 0: self = .notAsked
        case 1: self = .restricted
        case 2: self = .denied
        case 3: self = .full
        case 4: self = .limited
        default: self = .denied
        }
    }

    /// A dive can only deal with the photos the library shows. Limited access shows the chosen subset.
    var canReview: Bool { self == .full || self == .limited }

    /// Anything short of full access deserves a notice on the Library.
    var needsAttention: Bool { self != .full }

    /// True when the user can turn it on in Settings (an unasked state is answered by the prompt instead).
    var canFixInSettings: Bool { self == .denied || self == .limited }

    /// The label of the one thing the user can do about it, if there is one.
    var actionTitle: String? {
        switch self {
        case .notAsked:   return "Allow access"
        case .denied:     return "Open Settings"
        case .limited:    return "Manage"
        case .full, .restricted: return nil
        }
    }

    var title: String {
        switch self {
        case .full:       return "Full access"
        case .limited:    return "Photo access is limited"
        case .notAsked:   return "Photo access is needed"
        case .denied:     return "Photo access is off"
        case .restricted: return "Photo access is restricted"
        }
    }

    /// One sentence that says what is wrong and, where there is a remedy, what to do.
    var message: String {
        switch self {
        case .full:       return "PurgeQuest can see your whole library."
        case .limited:    return "Only the photos you allowed will appear."
        case .notAsked:   return "Allow access so PurgeQuest can find clutter in your library."
        case .denied:     return "PurgeQuest can't see your library until you allow it in Settings."
        case .restricted: return "Screen Time or device management is blocking photo access, so PurgeQuest can't open your library."
        }
    }

    /// The short status shown beside the allow button during onboarding.
    var chipText: String {
        switch self {
        case .full:       return "Full access"
        case .limited:    return "Limited access. Some items won't appear"
        case .notAsked:   return "Awaiting permission"
        case .denied:     return "Access is off"
        case .restricted: return "Access is restricted"
        }
    }

    /// What a dive that finds nothing to review says. With access it is the truth; with limited access
    /// it names the reason the pool is small; without access it never claims the library is clean.
    var emptyDiveTitle: String {
        switch self {
        case .limited: return "Nothing left in the photos you allowed"
        case .full:    return "All clear"
        default:       return title
        }
    }

    var emptyDiveMessage: String {
        switch self {
        case .limited: return "You have reviewed every photo you allowed.\nAllow more in Settings to keep going."
        case .full:    return "Your library has nothing to review right now.\nReturn another day."
        default:       return message
        }
    }
}
