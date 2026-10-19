import AppKit
import Foundation

final class AppDiscoveryService {
    static let shared = AppDiscoveryService()

    private init() {}

    func getAvailableHandlers(for scheme: String) -> [AppTarget] {
        let probeString = (scheme.lowercased() == "mailto") ? "mailto:user@example.com" : "\(scheme)://example.com"
        guard let probeURL = URL(string: probeString) ?? URL(string: "\(scheme)://") ?? URL(string: "\(scheme):") else {
            return []
        }

        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.maxguspicker1824.app"

        var seenBundleIDs = Set<String>()
        return appURLs.compactMap { appURL in
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != myBundleID,
                  bundleID != "com.maxguspicker1824.app",
                  !seenBundleIDs.contains(bundleID) else {
                return nil
            }
            seenBundleIDs.insert(bundleID)

            let rawName = FileManager.default.displayName(atPath: appURL.path)
            let name = rawName.hasSuffix(".app") ? String(rawName.dropLast(4)) : rawName
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return AppTarget(bundleID: bundleID, name: name, appURL: appURL, icon: icon)
        }
    }

    func open(_ targetURL: URL, withAppBundleID bundleID: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.open([targetURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error = error {
                print("Failed to open URL: \(error.localizedDescription)")
            }
        }
    }

    func open(_ targetURL: URL, with target: AppTarget) {
        guard let profile = target.profile else {
            // Standard launch without profile
            open(targetURL, withAppBundleID: target.bundleID)
            return
        }

        switch profile.engine {
        case .chromium:
            launchBinary(
                appURL: target.appURL,
                arguments: ["--profile-directory=\(profile.id)", targetURL.absoluteString]
            )

        case .firefox:
            launchBinary(
                appURL: target.appURL,
                arguments: ["-P", profile.id, targetURL.absoluteString]
            )

        case .arc:
            openInArcSpace(url: targetURL, spaceName: profile.id)

        case .safari:
            openInSafariProfile(url: targetURL, profileName: profile.id)

        case .standard:
            open(targetURL, withAppBundleID: target.bundleID)
        }
    }

    private func launchBinary(appURL: URL, arguments: [String]) {
        guard let bundle = Bundle(url: appURL),
              let execURL = bundle.executableURL else {
            return
        }

        let process = Process()
        process.executableURL = execURL
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            print("Failed to launch browser binary: \(error)")
        }
    }

    private func openInArcSpace(url: URL, spaceName: String) {
        let escapedURL = url.absoluteString.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedSpace = spaceName.replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource = """
        tell application "Arc"
            tell front window
                tell space "\(escapedSpace)"
                    make new tab with properties {URL:"\(escapedURL)"}
                end tell
            end tell
            activate
        end tell
        """

        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error = error {
                print("Arc AppleScript error: \(error)")
            }
        }
    }

    func openInSafariProfile(url: URL, profileName: String) {
        let escapedURL = url.absoluteString.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedProfile = profileName.replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource = """
        tell application "Safari"
            activate
            set foundWindow to false
            repeat with w in windows
                if name of w starts with "\(escapedProfile) —" or name of w is "\(escapedProfile)" then
                    set index of w to 1
                    tell w to set current tab to (make new tab with properties {URL:"\(escapedURL)"})
                    set foundWindow to true
                    exit repeat
                end if
            end repeat
        end tell

        if not foundWindow then
            tell application "System Events"
                tell process "Safari"
                    click menu item "New \(escapedProfile) Window" of menu "New Window" of menu item "New Window" of menu "File" of menu bar 1
                end tell
            end tell
            delay 0.25
            tell application "Safari"
                set URL of current tab of front window to "\(escapedURL)"
            end tell
        end if
        """

        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error = error {
                print("Safari profile script error: \(error)")
            }
        }
    }
}
