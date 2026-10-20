import AppKit
import Foundation

enum BrowserEngine: String, Codable, Hashable {
    case chromium // Chrome, Brave, Edge, Vivaldi
    case firefox
    case arc
    case safari   // macOS 14+ Profiles
    case standard // Standard browsers & Mail clients
}

struct BrowserProfile: Identifiable, Hashable, Codable {
    var id: String          // Directory name ("Profile 1") or Profile/Space name ("Work")
    var displayName: String // User-visible name ("Work - Alice")
    var engine: BrowserEngine
}

struct AppTarget: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let appURL: URL
    let icon: NSImage
    var profile: BrowserProfile? = nil
    var isRunning: Bool = false
    var isNativeAppHandoff: Bool = false
    var openInPrivateMode: Bool = false

    var id: String {
        if let profile = profile {
            return "\(bundleID)::\(profile.id)"
        }
        return bundleID
    }

    var displayTitle: String {
        var base = name
        if let profile = profile {
            base += " (\(profile.displayName))"
        }
        if openInPrivateMode {
            base += " [Private]"
        }
        return base
    }

    static func == (lhs: AppTarget, rhs: AppTarget) -> Bool {
        lhs.id == rhs.id &&
        lhs.appURL == rhs.appURL &&
        lhs.openInPrivateMode == rhs.openInPrivateMode
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(appURL)
        hasher.combine(openInPrivateMode)
    }
}

struct SourceAppInfo: Codable, Equatable, Hashable, Identifiable {
    let bundleID: String
    let name: String

    var id: String { bundleID }
}

/// Global identity/workspace context mode for multi-account users.
enum IdentityContext: String, CaseIterable, Codable, Identifiable, Hashable {
    case all = "All Contexts"
    case work = "Work"
    case personal = "Personal"
    case client = "Client / Dev"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:
            return "square.stack.3d.up.fill"
        case .work:
            return "briefcase.fill"
        case .personal:
            return "person.fill"
        case .client:
            return "laptopcomputer"
        }
    }
}

/// Represents a specific Browser + Profile combination pinned as a top-level tile in the Floating Chooser.
struct PinnedProfileIdentity: Codable, Equatable, Hashable, Identifiable {
    var bundleID: String
    var appName: String
    var profile: BrowserProfile

    var id: String {
        "\(bundleID)::\(profile.id)"
    }

    var displayTitle: String {
        "\(appName) • \(profile.displayName)"
    }
}

/// Centralized user-configurable toggles for Chooser UX and advanced routing features.
struct FeatureSettings: Codable, Equatable {
    // Floating Chooser UX Toggles
    var showNumberShortcutsInChooser: Bool = true
    var showRunningIndicatorInChooser: Bool = true
    var prioritizeRunningBrowsers: Bool = true
    var showRememberDomainInChooser: Bool = true
    var showPrivateModeInChooser: Bool = true
    var showKeyboardHintsInChooser: Bool = true
    var showPinnedProfilesInChooser: Bool = true

    // Smart Routing & Advanced Engine Toggles
    var sanitizeURLsEnabled: Bool = true
    var nativeAppHandoffEnabled: Bool = true
    var expandShortlinksEnabled: Bool = true
    var enableContextModeFiltering: Bool = true
    var enableWorkHoursSchedules: Bool = true
    var enableURLRewriteRules: Bool = true
    var trackRuleHitStats: Bool = true

    var enableTimeScheduledRules: Bool {
        get { enableWorkHoursSchedules }
        set { enableWorkHoursSchedules = newValue }
    }

    var showRuleHitStats: Bool {
        get { trackRuleHitStats }
        set { trackRuleHitStats = newValue }
    }
}

