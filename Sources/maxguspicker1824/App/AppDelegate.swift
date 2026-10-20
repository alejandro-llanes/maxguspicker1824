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

    private var pickerSelectionModel: PickerSelectionModel?
    private var currentPickerSelectHandler: ((AppTarget) -> Void)?
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var receivedURLOnLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Automatically show Onboarding Wizard on first launch only if not launched via a URL event
        if !UserDefaults.standard.bool(forKey: "HasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, !self.receivedURLOnLaunch else { return }
                self.showOnboardingWindow(initialTab: .permissions)
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

    // MARK: - Explicit Window Management (Rules Editor & Setup/Features)

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
        window.setContentSize(NSSize(width: 940, height: 620))
        window.center()
        window.isReleasedWhenClosed = false
        self.rulesWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openRuleBuilderFromHistory(_ record: ActivityRecord) {
        RulesStore.shared.draftRuleFromHistory = record.toRoutingRule()
        showRulesWindow()
    }

    func reopenActivityRecord(_ record: ActivityRecord, showChooser: Bool = false) {
        guard let url = URL(string: record.urlString) else {
            NSSound.beep()
            return
        }
        if showChooser {
            showFloatingPicker(for: url, sourceApp: record.sourceApp)
            return
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: record.targetAppBundleID) else {
            showFloatingPicker(for: url, sourceApp: record.sourceApp)
            return
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        let target = AppTarget(
            bundleID: record.targetAppBundleID,
            name: record.targetAppName,
            appURL: appURL,
            icon: icon,
            profile: record.targetProfile,
            openInPrivateMode: record.openedInPrivateMode
        )
        RulesStore.shared.logActivity(url: url, source: record.sourceApp, target: target)
        AppDiscoveryService.shared.open(url, with: target)
    }

    func copyActivityRecordURL(_ record: ActivityRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.urlString, forType: .string)
    }

    func showOnboardingWindow(initialTab: SetupWindowTab = .permissions) {
        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        let onboardingView = OnboardingWizardView(initialTab: initialTab)
        let hostingController = NSHostingController(rootView: onboardingView)

        if let window = onboardingWindow {
            window.contentViewController = hostingController
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Maxgus Picker 1824 — Setup & Features"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 660, height: 640))
        window.center()
        window.isReleasedWhenClosed = false
        self.onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Active Browser Tab & Clipboard Handoff

    func rerouteActiveBrowserTab() {
        guard let activeURL = AppDiscoveryService.shared.fetchActiveBrowserTabURL() else {
            NSSound.beep()
            return
        }
        let cleanedURL = RulesStore.shared.featureSettings.sanitizeURLsEnabled
            ? URLSanitizerService.shared.sanitize(activeURL)
            : activeURL
        let sourceApp = SourceAppDetector.shared.detectCurrentSourceApp()
        showFloatingPicker(for: cleanedURL, sourceApp: sourceApp)
    }

    func routeClipboardURL() {
        guard let rawString = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawString.isEmpty,
              let parsedURL = Self.normalizeUserURL(from: rawString) else {
            NSSound.beep()
            return
        }
        let cleanedURL = RulesStore.shared.featureSettings.sanitizeURLsEnabled
            ? URLSanitizerService.shared.sanitize(parsedURL)
            : parsedURL
        showFloatingPicker(for: cleanedURL, sourceApp: nil)
    }

    static func normalizeUserURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if trimmed.lowercased().hasPrefix("mailto:") || trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.contains("@") && !trimmed.contains("://") && !trimmed.contains("/") {
            return URL(string: "mailto:\(trimmed)")
        }
        if trimmed.contains(".") && !trimmed.contains("://") {
            return URL(string: "https://\(trimmed)")
        }
        return nil
    }

    // MARK: - URL Interception & Floating Selector

    func routeIncomingRequest(_ rawURL: URL) {
        let store = RulesStore.shared
        // 1. Detect which app the user clicked the link in (e.g., Slack, Mail, Notion)
        let sourceApp = SourceAppDetector.shared.detectCurrentSourceApp()

        // 2. Sanitize URL (unwrap redirects & strip tracking parameters if enabled)
        let url = store.featureSettings.sanitizeURLsEnabled
            ? URLSanitizerService.shared.sanitize(rawURL)
            : rawURL

        // 3. Holding Option (⌥) bypasses rules and forces the floating selector
        let forcePicker = NSEvent.modifierFlags.contains(.option)

        if !forcePicker, let matchedRule = store.findMatchingRule(for: url, sourceApp: sourceApp) {
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
                profile: matchedRule.targetProfile,
                openInPrivateMode: matchedRule.openInPrivateMode
            )
            let finalURL = store.featureSettings.enableURLRewriteRules
                ? matchedRule.transformURL(url)
                : url
            store.recordRuleHit(for: matchedRule.id)
            store.logActivity(url: finalURL, source: sourceApp, target: target)
            AppDiscoveryService.shared.open(finalURL, with: target)
            return
        }

        // 4. No rule matched: show the floating application selector
        showFloatingPicker(for: url, sourceApp: sourceApp)
    }

    func showFloatingPicker(for url: URL, sourceApp: SourceAppInfo? = nil, availableApps: [AppTarget]? = nil) {
        closeFloatingPicker()

        let store = RulesStore.shared
        let isMail = (url.scheme?.lowercased() == "mailto")
        let handlers = availableApps ?? AppDiscoveryService.shared.getAvailableHandlers(
            for: isMail ? "mailto" : "https",
            forURL: isMail ? nil : url,
            sortRunningFirst: store.featureSettings.prioritizeRunningBrowsers,
            includeNativeHandoff: store.featureSettings.nativeAppHandoffEnabled,
            pinnedProfiles: (isMail || !store.featureSettings.showPinnedProfilesInChooser) ? [] : store.pinnedProfiles
        )
        let selectionModel = PickerSelectionModel(apps: handlers, url: url)
        self.pickerSelectionModel = selectionModel

        // Asynchronously unfurl shortlinks (bit.ly, t.co, tinyurl.com, lnkd.in, etc.) if enabled
        if store.featureSettings.expandShortlinksEnabled && ShortlinkExpanderService.shared.isShortlink(url) {
            selectionModel.isExpandingShortlink = true
            Task { @MainActor [weak selectionModel] in
                let expanded = await ShortlinkExpanderService.shared.expand(url)
                guard let selectionModel = selectionModel else { return }
                selectionModel.isExpandingShortlink = false
                if let expanded = expanded {
                    let cleanExpanded = store.featureSettings.sanitizeURLsEnabled
                        ? URLSanitizerService.shared.sanitize(expanded)
                        : expanded
                    selectionModel.expandedShortlinkURL = cleanExpanded
                }
            }
        }

        let handleChoice: (AppTarget) -> Void = { [weak self] chosenTarget in
            let finalURL = selectionModel.effectiveURL
            let shouldRememberDomain = selectionModel.rememberDomainForRule
            self?.closeFloatingPicker()

            if shouldRememberDomain {
                _ = RulesStore.shared.saveQuickDomainRule(for: finalURL, target: chosenTarget, sourceApp: sourceApp)
            }
            RulesStore.shared.logActivity(url: finalURL, source: sourceApp, target: chosenTarget)
            AppDiscoveryService.shared.open(finalURL, with: chosenTarget)
        }
        self.currentPickerSelectHandler = handleChoice

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        let screenSize = screen?.visibleFrame.size ?? NSSize(width: 1440, height: 900)

        // Calculate floating chooser dimensions scaled to the desktop resolution
        let iconSize = min(max(round(screenSize.height * 0.062), 54), 68)
        let tileWidth = iconSize + 42
        let contentWidthForApps = CGFloat(max(handlers.count, 3)) * (tileWidth + 14) + 52
        let minPanelWidth = max(480, round(screenSize.width * 0.32))
        let maxPanelWidth = min(840, round(screenSize.width * 0.62))
        let panelWidth = min(max(contentWidthForApps, minPanelWidth), maxPanelWidth)
        let panelHeight = min(max(round(screenSize.height * 0.22), 210), 250)

        let popupView = FloatingSelectorView(
            url: url,
            sourceApp: sourceApp,
            selectionModel: selectionModel,
            iconSize: iconSize,
            tileWidth: tileWidth,
            onSelect: handleChoice,
            onOpenSettings: { [weak self] in
                self?.closeFloatingPicker()
                self?.showOnboardingWindow(initialTab: .features)
            },
            onClose: { [weak self] in
                self?.closeFloatingPicker()
            }
        )

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

        var origin = NSPoint(x: mouse.x - (panelWidth / 2), y: mouse.y - (panelHeight / 2))

        // Clamp origin to the screen containing the mouse cursor so the panel stays on-screen
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - panelWidth - 12)
            origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - panelHeight - 12)
        }

        panel.setFrameOrigin(origin)
        // Order front on the active Space (including Full Screen spaces) and make key for keyboard navigation
        panel.orderFrontRegardless()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        self.pickerPanel = panel

        installDismissalMonitors()
    }

    func closeFloatingPicker() {
        removeDismissalMonitors()
        pickerPanel?.close()
        pickerPanel = nil
        pickerSelectionModel = nil
        currentPickerSelectHandler = nil
    }

    private func installDismissalMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let panel = self.pickerPanel else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !NSPointInRect(mouseLocation, panel.frame) {
                self.closeFloatingPicker()
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, let model = self.pickerSelectionModel, self.pickerPanel != nil else {
                return event
            }

            if event.type == .flagsChanged {
                model.isPrivateModePreview = event.modifierFlags.contains(.shift)
                return event
            }

            let settings = RulesStore.shared.featureSettings

            // Cmd+C copies the clean URL to clipboard
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                model.copyURLToPasteboard()
                return nil
            }

            // Cmd+R toggles "Remember Domain" quick rule creation
            if settings.showRememberDomainInChooser,
               event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "r" {
                model.toggleRememberDomain()
                return nil
            }

            // Number keys 1..9 immediately select and launch the corresponding app tile
            if settings.showNumberShortcutsInChooser,
               let chars = event.charactersIgnoringModifiers,
               chars.count == 1,
               let digit = Int(chars),
               (1...9).contains(digit) {
                let targetIndex = digit - 1
                if model.apps.indices.contains(targetIndex) {
                    model.selectedIndex = targetIndex
                    var chosen = model.apps[targetIndex]
                    if model.isPrivateModePreview || event.modifierFlags.contains(.shift) {
                        chosen.openInPrivateMode = true
                    }
                    self.currentPickerSelectHandler?(chosen)
                    return nil
                }
            }

            switch event.keyCode {
            case 53: // Escape
                self.closeFloatingPicker()
                return nil
            case 49: // Space -> toggle full URL preview
                model.toggleURLPreview()
                return nil
            case 123, 126: // Left Arrow or Up Arrow
                model.moveLeft()
                return nil
            case 124, 125: // Right Arrow or Down Arrow
                model.moveRight()
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.shift) {
                    model.moveLeft()
                } else {
                    model.moveRight()
                }
                return nil
            case 36, 76: // Return or Keypad Enter
                if var chosen = model.selectedApp {
                    if model.isPrivateModePreview || event.modifierFlags.contains(.shift) {
                        chosen.openInPrivateMode = true
                    }
                    self.currentPickerSelectHandler?(chosen)
                }
                return nil
            default:
                return event
            }
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
}
