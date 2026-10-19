import AppKit
import Foundation

final class SourceAppDetector {
    static let shared = SourceAppDetector()

    private init() {}

    /// Captures the app that sent the URL event or was frontmost at the moment of the click.
    func detectCurrentSourceApp() -> SourceAppInfo? {
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.maxguspicker1824.app"

        // 1. Try extracting sender PID from the current AppleEvent
        if let currentEvent = NSAppleEventManager.shared().currentAppleEvent,
           let senderDescriptor = currentEvent.attributeDescriptor(forKeyword: keyAddressAttr) {
            let pid = senderDescriptor.int32Value
            if pid > 0,
               let runningApp = NSRunningApplication(processIdentifier: pid),
               let bundleID = runningApp.bundleIdentifier,
               bundleID != myBundleID,
               bundleID != "com.maxguspicker1824.app" {
                return SourceAppInfo(
                    bundleID: bundleID,
                    name: runningApp.localizedName ?? bundleID
                )
            }
        }

        // 2. Fallback: Frontmost application at the moment the link was clicked
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier,
           bundleID != myBundleID,
           bundleID != "com.maxguspicker1824.app" {
            return SourceAppInfo(
                bundleID: bundleID,
                name: frontApp.localizedName ?? bundleID
            )
        }

        return nil
    }
}
