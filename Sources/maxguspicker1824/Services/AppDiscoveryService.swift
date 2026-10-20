import AppKit
import Foundation

final class AppDiscoveryService {
    static let shared = AppDiscoveryService()

    private init() {}

    func getAvailableHandlers(
        for scheme: String,
        forURL url: URL? = nil,
        sortRunningFirst: Bool = true
    ) -> [AppTarget] {
        let probeString = (scheme.lowercased() == "mailto") ? "mailto:user@example.com" : "\(scheme)://example.com"
        guard let probeURL = URL(string: probeString) ?? URL(string: "\(scheme)://") ?? URL(string: "\(scheme):") else {
            return []
        }

        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.maxguspicker1824.app"
        let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let excludedWebNonBrowsers: Set<String> = [
            "io.mpv",
            "org.videolan.vlc",
            "com.colliderli.iina",
            "com.openai.chat"
        ]
        let isWebScheme = (scheme.lowercased() == "http" || scheme.lowercased() == "https")

        var seenBundleIDs = Set<String>()
        var targets: [AppTarget] = appURLs.compactMap { appURL in
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != myBundleID,
                  bundleID != "com.maxguspicker1824.app",
                  !(isWebScheme && excludedWebNonBrowsers.contains(bundleID)),
                  !seenBundleIDs.contains(bundleID) else {
                return nil
            }
            seenBundleIDs.insert(bundleID)

            let rawName = FileManager.default.displayName(atPath: appURL.path)
            let name = rawName.hasSuffix(".app") ? String(rawName.dropLast(4)) : rawName
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return AppTarget(
                bundleID: bundleID,
                name: name,
                appURL: appURL,
                icon: icon,
                isRunning: runningBundleIDs.contains(bundleID)
            )
        }

        if sortRunningFirst {
            targets.sort { lhs, rhs in
                if lhs.isRunning != rhs.isRunning {
                    return lhs.isRunning && !rhs.isRunning
                }
                return false
            }
        }

        // Prepend installed native macOS desktop app if this URL supports native deep-link handoff
        if let url = url,
           let nativeTarget = NativeAppHandoffService.shared.installedNativeAppTarget(for: url) {
            targets.removeAll { $0.bundleID == nativeTarget.bundleID }
            targets.insert(nativeTarget, at: 0)
        }

        return targets
    }

    func open(_ targetURL: URL, withAppBundleID bundleID: String) {
        let finalURL = NativeAppHandoffService.shared.resolvedURL(for: targetURL, targetBundleID: bundleID)
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.open([finalURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error = error {
                print("Failed to open URL: \(error.localizedDescription)")
            }
        }
    }

    func open(_ targetURL: URL, with target: AppTarget) {
        let finalURL = NativeAppHandoffService.shared.resolvedURL(for: targetURL, targetBundleID: target.bundleID)

        // Handle Private / Incognito mode even when no specific profile is chosen
        if target.openInPrivateMode && target.profile == nil {
            openInPrivateWindow(finalURL, target: target)
            return
        }

        guard let profile = target.profile else {
            open(finalURL, withAppBundleID: target.bundleID)
            return
        }

        switch profile.engine {
        case .chromium:
            var args = ["--profile-directory=\(profile.id)"]
            if target.openInPrivateMode {
                args.append(privateFlag(for: target.bundleID))
            }
            args.append(finalURL.absoluteString)
            launchBinary(appURL: target.appURL, arguments: args)

        case .firefox:
            var args = ["-P", profile.id]
            if target.openInPrivateMode {
                args.append("-private-window")
            }
            args.append(finalURL.absoluteString)
            launchBinary(appURL: target.appURL, arguments: args)

        case .arc:
            openInArcSpace(url: finalURL, spaceName: profile.id)

        case .safari:
            openInSafariProfile(url: finalURL, profileName: profile.id)

        case .standard:
            open(finalURL, withAppBundleID: target.bundleID)
        }
    }

    private func privateFlag(for bundleID: String) -> String {
        if bundleID == "com.microsoft.edgemac" {
            return "--inprivate"
        }
        return "--incognito"
    }

    private func openInPrivateWindow(_ url: URL, target: AppTarget) {
        switch target.bundleID {
        case "com.google.Chrome", "com.brave.Browser", "com.vivaldi.Vivaldi":
            launchBinary(appURL: target.appURL, arguments: ["--incognito", url.absoluteString])
        case "com.microsoft.edgemac":
            launchBinary(appURL: target.appURL, arguments: ["--inprivate", url.absoluteString])
        case "org.mozilla.firefox":
            launchBinary(appURL: target.appURL, arguments: ["-private-window", url.absoluteString])
        case "com.apple.Safari":
            openInSafariPrivateWindow(url: url, fallbackTarget: target)
        default:
            open(url, withAppBundleID: target.bundleID)
        }
    }

    private func openInSafariPrivateWindow(url: URL, fallbackTarget: AppTarget) {
        let escapedURL = url.absoluteString.replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = """
        tell application "Safari" to activate
        tell application "System Events"
            tell process "Safari"
                click menu item "New Private Window" of menu "File" of menu bar 1
            end tell
        end tell
        delay 0.25
        tell application "Safari"
            set URL of current tab of front window to "\(escapedURL)"
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error != nil {
                open(url, withAppBundleID: fallbackTarget.bundleID)
            }
        } else {
            open(url, withAppBundleID: fallbackTarget.bundleID)
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

    // MARK: - Active Browser Tab Handoff

    /// Queries the frontmost or running browser (Safari, Chrome, Brave, Edge, Arc) for its current tab URL.
    func fetchActiveBrowserTabURL() -> URL? {
        let browserScripts: [(bundleID: String, script: String)] = [
            ("com.apple.Safari", """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            """),
            ("com.google.Chrome", """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """),
            ("com.brave.Browser", """
            tell application "Brave Browser"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """),
            ("com.microsoft.edgemac", """
            tell application "Microsoft Edge"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """),
            ("company.thebrowser.Browser", """
            tell application "Arc"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """)
        ]

        let runningIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // Prioritize the frontmost application if it's a supported browser, then check other running browsers
        let orderedScripts = browserScripts.sorted { lhs, rhs in
            if lhs.bundleID == frontBundleID { return true }
            if rhs.bundleID == frontBundleID { return false }
            return false
        }

        for entry in orderedScripts where runningIDs.contains(entry.bundleID) {
            guard let appleScript = NSAppleScript(source: entry.script) else { continue }
            var error: NSDictionary?
            let descriptor = appleScript.executeAndReturnError(&error)
            if error == nil,
               let urlString = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url
            }
        }

        return nil
    }
}
