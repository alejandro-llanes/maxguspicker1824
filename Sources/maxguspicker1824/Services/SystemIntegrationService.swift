import AppKit
import ApplicationServices
import Combine
import Foundation
import UniformTypeIdentifiers

final class SystemIntegrationService: ObservableObject {
    static let shared = SystemIntegrationService()

    @Published var isDefaultBrowser: Bool = false
    @Published var isDefaultMailClient: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    private var timer: Timer?
    private let myBundleID = Bundle.main.bundleIdentifier ?? "com.maxguspicker1824.app"

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
}
