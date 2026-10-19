import AppKit
import ApplicationServices
import Combine
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

final class SystemIntegrationService: ObservableObject {
    static let shared = SystemIntegrationService()

    @Published var isDefaultBrowser: Bool = false
    @Published var isDefaultMailClient: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published var isLaunchAtLoginEnabled: Bool = false

    private var timer: Timer?
    private let myBundleID = Bundle.main.bundleIdentifier ?? "com.maxguspicker1824.app"

    private var launchAgentFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(myBundleID).plist")
    }

    private init() {
        refreshStatus()
        // Poll every 2 seconds while running so checkmarks update live
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func refreshStatus() {
        // 1. Check Default Browser (https)
        if let httpsURL = URL(string: "https://example.com"),
           let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: httpsURL),
           let bundle = Bundle(url: defaultBrowserURL) {
            isDefaultBrowser = (bundle.bundleIdentifier == myBundleID)
        } else {
            isDefaultBrowser = false
        }

        // 2. Check Default Mail Client (mailto)
        if let mailURL = URL(string: "mailto:test@example.com"),
           let defaultMailURL = NSWorkspace.shared.urlForApplication(toOpen: mailURL),
           let bundle = Bundle(url: defaultMailURL) {
            isDefaultMailClient = (bundle.bundleIdentifier == myBundleID)
        } else {
            isDefaultMailClient = false
        }

        // 3. Check Accessibility Permission (for Safari Profiles)
        hasAccessibilityPermission = AXIsProcessTrusted()

        // 4. Check Auto Start on Login (SMAppService or LaunchAgent plist)
        let smEnabled = (SMAppService.mainApp.status == .enabled)
        let plistExists = FileManager.default.fileExists(atPath: launchAgentFileURL.path)
        isLaunchAtLoginEnabled = smEnabled || plistExists
    }

    func requestDefaultBrowser() {
        let myAppURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: myAppURL, toOpenURLsWithScheme: "http") { _ in }
        NSWorkspace.shared.setDefaultApplication(at: myAppURL, toOpenURLsWithScheme: "https") { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshStatus()
            }
        }
    }

    func requestDefaultMailClient() {
        let myAppURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: myAppURL, toOpenURLsWithScheme: "mailto") { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshStatus()
            }
        }
    }

    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshStatus()
    }

    func toggleLaunchAtLogin() {
        setLaunchAtLogin(!isLaunchAtLoginEnabled)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                // Fallback to user LaunchAgent plist when running with ad-hoc signature
                installLaunchAgentPlist()
            }
            if SMAppService.mainApp.status != .enabled {
                installLaunchAgentPlist()
            }
        } else {
            try? SMAppService.mainApp.unregister()
            try? FileManager.default.removeItem(at: launchAgentFileURL)
        }
        refreshStatus()
    }

    private func installLaunchAgentPlist() {
        let execPath = Bundle.main.executableURL?.path ?? "/Applications/maxguspicker1824.app/Contents/MacOS/maxguspicker1824"
        let plistDict: [String: Any] = [
            "Label": myBundleID,
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let launchAgentsDir = launchAgentFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0) {
            try? data.write(to: launchAgentFileURL, options: .atomic)
        }
    }
}
