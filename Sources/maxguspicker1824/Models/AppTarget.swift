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
