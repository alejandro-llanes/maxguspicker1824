import AppKit
import Foundation

struct NativeAppMapping {
    let bundleIDs: [String]
    let matchHost: (String) -> Bool
    let buildDeepLink: (URL) -> URL?
}

final class NativeAppHandoffService {
    static let shared = NativeAppHandoffService()

    private let mappings: [NativeAppMapping] = [
        // 1. Zoom (zoom.us/j/<id> -> zoommtg://zoom.us/join?confno=<id>)
        NativeAppMapping(
            bundleIDs: ["us.zoom.xos"],
            matchHost: { $0 == "zoom.us" || $0.hasSuffix(".zoom.us") },
            buildDeepLink: { url in
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
                let parts = components.path.split(separator: "/").map(String.init)
                guard parts.count >= 2, (parts[0] == "j" || parts[0] == "w" || parts[0] == "s") else { return nil }
                let confNo = parts[1]
                var query = "confno=\(confNo)"
                if let pwd = components.queryItems?.first(where: { $0.name == "pwd" })?.value {
                    query += "&pwd=\(pwd)"
                }
                return URL(string: "zoommtg://zoom.us/join?\(query)")
            }
        ),
        // 2. Figma (figma.com/file|design|proto|board/... -> figma://...)
        NativeAppMapping(
            bundleIDs: ["com.figma.Desktop"],
            matchHost: { $0 == "figma.com" || $0 == "www.figma.com" },
            buildDeepLink: { url in
                let path = url.path
                guard path.hasPrefix("/file/") || path.hasPrefix("/design/") || path.hasPrefix("/proto/") || path.hasPrefix("/board/") else {
                    return nil
                }
                let raw = url.absoluteString
                if let range = raw.range(of: "://") {
                    return URL(string: "figma" + String(raw[range.lowerBound...]))
                }
                return nil
            }
        ),
        // 3. Notion (notion.so/... -> notion://...)
        NativeAppMapping(
            bundleIDs: ["notion.id"],
            matchHost: { $0 == "notion.so" || $0 == "www.notion.so" },
            buildDeepLink: { url in
                let raw = url.absoluteString
                if let range = raw.range(of: "://") {
                    return URL(string: "notion" + String(raw[range.lowerBound...]))
                }
                return nil
            }
        ),
        // 4. Linear (linear.app/... -> linear://...)
        NativeAppMapping(
            bundleIDs: ["com.linear"],
            matchHost: { $0 == "linear.app" || $0 == "www.linear.app" },
            buildDeepLink: { url in
                let raw = url.absoluteString
                if let range = raw.range(of: "://") {
                    return URL(string: "linear" + String(raw[range.lowerBound...]))
                }
                return nil
            }
        ),
        // 5. Spotify (open.spotify.com/<type>/<id> -> spotify://<type>/<id>)
        NativeAppMapping(
            bundleIDs: ["com.spotify.client"],
            matchHost: { $0 == "open.spotify.com" },
            buildDeepLink: { url in
                let parts = url.path.split(separator: "/").map(String.init)
                guard parts.count >= 2 else { return nil }
                return URL(string: "spotify://\(parts[0])/\(parts[1])")
            }
        ),
        // 6. Discord (discord.com/channels/... -> discord://-/channels/...)
        NativeAppMapping(
            bundleIDs: ["com.hnc.Discord"],
            matchHost: { $0 == "discord.com" || $0 == "ptb.discord.com" || $0 == "canary.discord.com" },
            buildDeepLink: { url in
                guard url.path.hasPrefix("/channels/") else { return nil }
                return URL(string: "discord://-\(url.path)")
            }
        ),
        // 7. Microsoft Teams (teams.microsoft.com/l/... -> msteams://teams.microsoft.com/l/...)
        NativeAppMapping(
            bundleIDs: ["com.microsoft.teams2", "com.microsoft.teams"],
            matchHost: { $0 == "teams.microsoft.com" },
            buildDeepLink: { url in
                guard url.path.hasPrefix("/l/") else { return nil }
                let raw = url.absoluteString
                if let range = raw.range(of: "://") {
                    return URL(string: "msteams" + String(raw[range.lowerBound...]))
                }
                return nil
            }
        )
    ]

    private init() {}

    /// Returns the converted native deep-link URL if `url` matches `bundleID`'s native scheme, or the original URL otherwise.
    func resolvedURL(for url: URL, targetBundleID: String) -> URL {
        guard let host = url.host?.lowercased() else { return url }
        for mapping in mappings where mapping.bundleIDs.contains(targetBundleID) && mapping.matchHost(host) {
            if let deepLink = mapping.buildDeepLink(url) {
                return deepLink
            }
        }
        return url
    }

    /// Detects if an installed native macOS desktop app can handle this web URL directly.
    func installedNativeAppTarget(for url: URL) -> AppTarget? {
        guard let host = url.host?.lowercased() else { return nil }
        let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))

        for mapping in mappings where mapping.matchHost(host) {
            guard mapping.buildDeepLink(url) != nil else { continue }
            for bundleID in mapping.bundleIDs {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    let rawName = FileManager.default.displayName(atPath: appURL.path)
                    let name = rawName.hasSuffix(".app") ? String(rawName.dropLast(4)) : rawName
                    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                    return AppTarget(
                        bundleID: bundleID,
                        name: name,
                        appURL: appURL,
                        icon: icon,
                        isRunning: runningBundleIDs.contains(bundleID),
                        isNativeAppHandoff: true
                    )
                }
            }
        }
        return nil
    }
}
