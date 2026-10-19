import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var pickerPanel: NSPanel?
    var rulesWindow: NSWindow?
    var onboardingWindow: NSWindow?

    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var receivedURLOnLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Automatically show Onboarding Wizard on first launch only if not launched via a URL event
        if !UserDefaults.standard.bool(forKey: "HasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, !self.receivedURLOnLaunch else { return }
                self.showOnboardingWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Do not automatically open the Routing Rules window when reopening or handling URLs
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedURLOnLaunch = true
        for url in urls {
            routeIncomingRequest(url)
        }
    }

    // MARK: - Explicit Window Management (Rules Editor & Onboarding)

    func showRulesWindow() {
        if let window = rulesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: RulesManagerView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Routing Rules"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        self.rulesWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingWizardView { [weak self] in
            self?.onboardingWindow?.close()
            self?.showRulesWindow()
        }
        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to maxguspicker1824"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 560, height: 540))
        window.center()
        window.isReleasedWhenClosed = false
        self.onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - URL Interception & Floating Selector

    func routeIncomingRequest(_ url: URL) {
        // 1. Detect which app the user clicked the link in (e.g., Slack, Mail, Notion)
        let sourceApp = SourceAppDetector.shared.detectCurrentSourceApp()

        // 2. Holding Option (⌥) bypasses rules and forces the floating selector
        let forcePicker = NSEvent.modifierFlags.contains(.option)

        if !forcePicker, let matchedRule = RulesStore.shared.findMatchingRule(for: url, sourceApp: sourceApp) {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: matchedRule.targetAppBundleID) else {
                showFloatingPicker(for: url, sourceApp: sourceApp)
                return
            }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let target = AppTarget(
                bundleID: matchedRule.targetAppBundleID,
                name: matchedRule.targetAppName,
                appURL: appURL,
                icon: icon,
                profile: matchedRule.targetProfile
            )
            RulesStore.shared.logActivity(url: url, source: sourceApp, destination: target.displayTitle)
            AppDiscoveryService.shared.open(url, with: target)
            return
        }

        // 3. No rule matched: show the floating application selector
        showFloatingPicker(for: url, sourceApp: sourceApp)
    }

    func showFloatingPicker(for url: URL, sourceApp: SourceAppInfo? = nil) {
        closeFloatingPicker()

        let isMail = (url.scheme?.lowercased() == "mailto")
        let handlers = AppDiscoveryService.shared.getAvailableHandlers(for: isMail ? "mailto" : "https")

        let popupView = FloatingSelectorView(
            url: url,
            sourceApp: sourceApp,
            apps: handlers,
            onSelect: { [weak self] chosenTarget, rememberDomain in
                self?.closeFloatingPicker()

                // Save a quick rule if the user checked "Always open ... with chosen app"
                if rememberDomain {
                    self?.createQuickRule(from: url, target: chosenTarget)
                }

                RulesStore.shared.logActivity(url: url, source: sourceApp, destination: chosenTarget.displayTitle)
                AppDiscoveryService.shared.open(url, with: chosenTarget)
            },
            onClose: { [weak self] in
                self?.closeFloatingPicker()
            }
        )

        let panelWidth: CGFloat = 350
        let panelHeight: CGFloat = 160
        let hostingView = NSHostingView(rootView: popupView)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let panel = FloatingPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Configure panel so it appears over Full Screen spaces and can be dragged freely
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView

        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x - (panelWidth / 2), y: mouse.y - (panelHeight / 2))

        // Clamp origin to the screen containing the mouse cursor so the panel stays on-screen
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panelWidth - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - panelHeight - 8)
        }

        panel.setFrameOrigin(origin)
        // Order front on the active Space (including Full Screen spaces) without activating the full app
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        self.pickerPanel = panel

        installDismissalMonitors()
    }

    func closeFloatingPicker() {
        removeDismissalMonitors()
        pickerPanel?.close()
        pickerPanel = nil
    }

    private func installDismissalMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let panel = self.pickerPanel else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !NSPointInRect(mouseLocation, panel.frame) {
                self.closeFloatingPicker()
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Escape keyCode is 53
            if event.keyCode == 53, self?.pickerPanel != nil {
                self?.closeFloatingPicker()
                return nil
            }
            return event
        }
    }

    private func removeDismissalMonitors() {
        if let globalMouseMonitor = globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localKeyMonitor = localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func createQuickRule(from url: URL, target: AppTarget) {
        let isMail = (url.scheme?.lowercased() == "mailto")
        let hostOrRecipient: String
        if isMail {
            hostOrRecipient = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? ""
        } else {
            hostOrRecipient = url.host ?? ""
        }
        guard !hostOrRecipient.isEmpty else { return }

        let quickRule = RoutingRule(
            name: "\(hostOrRecipient) → \(target.displayTitle)",
            type: isMail ? .mail : .web,
            field: isMail ? .emailAddress : .domain,
            matchOperator: .equals,
            value: hostOrRecipient,
            targetAppBundleID: target.bundleID,
            targetAppName: target.name,
            targetProfile: target.profile
        )
        RulesStore.shared.rules.append(quickRule)
    }
}
