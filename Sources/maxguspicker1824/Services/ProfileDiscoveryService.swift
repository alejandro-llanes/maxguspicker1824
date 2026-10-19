import AppKit
import ApplicationServices
import Foundation

final class ProfileDiscoveryService {
    static let shared = ProfileDiscoveryService()

    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var cache: [String: [BrowserProfile]] = [:]

    private init() {}

    func profiles(for bundleID: String, forceRefresh: Bool = false) -> [BrowserProfile] {
        if !forceRefresh, let cached = cache[bundleID] {
            return cached
        }

        let discovered: [BrowserProfile]
        switch bundleID {
        case "com.google.Chrome":
            discovered = parseChromiumProfiles(relativePath: "Library/Application Support/Google/Chrome/Local State")
        case "com.brave.Browser":
            discovered = parseChromiumProfiles(relativePath: "Library/Application Support/BraveSoftware/Brave-Browser/Local State")
        case "com.microsoft.edgemac":
            discovered = parseChromiumProfiles(relativePath: "Library/Application Support/Microsoft Edge/Local State")
        case "com.vivaldi.Vivaldi":
            discovered = parseChromiumProfiles(relativePath: "Library/Application Support/Vivaldi/Local State")
        case "org.mozilla.firefox":
            discovered = parseFirefoxProfiles()
        case "company.thebrowser.Browser": // Arc's Bundle ID
            discovered = fetchArcSpaces()
        case "com.apple.Safari":
            discovered = fetchSafariProfiles()
        default:
            discovered = []
        }

        cache[bundleID] = discovered
        return discovered
    }

    // MARK: - Chrome & Brave (Chromium Local State JSON)
    func parseChromiumProfiles(relativePath: String) -> [BrowserProfile] {
        let fileURL = homeDir.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileDict = json["profile"] as? [String: Any],
              let infoCache = profileDict["info_cache"] as? [String: [String: Any]] else {
            return []
        }

        // infoCache keys are disk folder names ("Default", "Profile 1", "Profile 2")
        return infoCache.compactMap { (dirName, metadata) in
            let displayName = (metadata["name"] as? String) ?? dirName
            return BrowserProfile(id: dirName, displayName: displayName, engine: .chromium)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Firefox (profiles.ini)
    func parseFirefoxProfiles() -> [BrowserProfile] {
        let iniURL = homeDir.appendingPathComponent("Library/Application Support/Firefox/profiles.ini")
        guard let content = try? String(contentsOf: iniURL, encoding: .utf8) else {
            return []
        }

        var profiles: [BrowserProfile] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Name=") {
                let name = String(trimmed.dropFirst("Name=".count))
                if !name.isEmpty {
                    profiles.append(BrowserProfile(id: name, displayName: name, engine: .firefox))
                }
            }
        }
        return profiles
    }

    // MARK: - Arc (Spaces via AppleScript)
    func fetchArcSpaces() -> [BrowserProfile] {
        if let cached = cache["company.thebrowser.Browser"] {
            return cached
        }
        let isArcRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "company.thebrowser.Browser"
        }
        guard isArcRunning else { return [] }

        let scriptSource = """
        tell application "Arc"
            tell front window
                get title of every space
            end tell
        end tell
        """
        guard let script = NSAppleScript(source: scriptSource) else { return [] }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)

        guard error == nil, descriptor.numberOfItems > 0 else { return [] }

        var spaces: [BrowserProfile] = []
        for index in 1...descriptor.numberOfItems {
            if let title = descriptor.atIndex(index)?.stringValue, !title.isEmpty {
                spaces.append(BrowserProfile(id: title, displayName: title, engine: .arc))
            }
        }
        cache["company.thebrowser.Browser"] = spaces
        return spaces
    }

    // MARK: - Safari Profiles via Safari's "New Window" Menu
    func fetchSafariProfiles() -> [BrowserProfile] {
        if let cached = cache["com.apple.Safari"] {
            return cached
        }
        guard AXIsProcessTrusted() else { return [] }

        let scriptSource = """
        tell application "Safari" to launch
        tell application "System Events"
            tell process "Safari"
                try
                    set menuItems to name of every menu item of menu "New Window" of menu item "New Window" of menu "File" of menu bar 1
                    return menuItems
                on error
                    return {}
                end try
            end tell
        end tell
        """
        guard let script = NSAppleScript(source: scriptSource) else { return [] }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, result.numberOfItems > 0 else { return [] }

        var profiles: [BrowserProfile] = []
        for i in 1...result.numberOfItems {
            guard let title = result.atIndex(i)?.stringValue else { continue }
            // Match items like "New Work Window" or "New Personal Window", ignoring "New Private Window"
            if title.hasPrefix("New ") && title.hasSuffix(" Window") && title != "New Private Window" {
                let profileName = title
                    .replacingOccurrences(of: "New ", with: "")
                    .replacingOccurrences(of: " Window", with: "")
                profiles.append(BrowserProfile(id: profileName, displayName: profileName, engine: .safari))
            }
        }
        cache["com.apple.Safari"] = profiles
        return profiles
    }
}
