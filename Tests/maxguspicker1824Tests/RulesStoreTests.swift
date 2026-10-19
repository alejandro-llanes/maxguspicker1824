import Foundation
import Testing
@testable import maxguspicker1824

@Suite("RulesStore Routing Engine & Services Tests")
struct RulesStoreTests {
    private func makeIsolatedStore() -> (RulesStore, UserDefaults, String) {
        let suiteName = "maxguspicker1824Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = RulesStore(userDefaults: defaults, storageKey: "TestRules", activityStorageKey: "TestActivity")
        return (store, defaults, suiteName)
    }

    @Test("Web domain equals strips leading www.")
    func webDomainEqualsStripsLeadingWWW() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let rule = RoutingRule(
            name: "GitHub to Safari",
            type: .web,
            field: .domain,
            matchOperator: .equals,
            value: "github.com",
            targetAppBundleID: "com.apple.Safari",
            targetAppName: "Safari"
        )
        store.rules = [rule]

        let urlWithWWW = URL(string: "https://www.github.com/apple/swift")!
        let urlWithoutWWW = URL(string: "https://github.com/apple/swift")!
        let otherURL = URL(string: "https://gitlab.com/apple/swift")!

        #expect(store.findMatchingRule(for: urlWithWWW)?.id == rule.id)
        #expect(store.findMatchingRule(for: urlWithoutWWW)?.id == rule.id)
        #expect(store.findMatchingRule(for: otherURL) == nil)
    }

    @Test("Web path startsWith and domain regex matching")
    func webPathAndRegexMatching() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pathRule = RoutingRule(
            name: "Admin Path",
            type: .web,
            field: .urlPath,
            matchOperator: .startsWith,
            value: "/admin",
            targetAppBundleID: "com.google.Chrome",
            targetAppName: "Google Chrome"
        )
        let regexRule = RoutingRule(
            name: "Subdomain Regex",
            type: .web,
            field: .domain,
            matchOperator: .regex,
            value: "^.*\\.internal\\.example\\.com$",
            targetAppBundleID: "org.mozilla.firefox",
            targetAppName: "Firefox"
        )
        store.rules = [pathRule, regexRule]

        let adminURL = URL(string: "https://app.example.com/admin/settings")!
        let internalURL = URL(string: "https://staging.internal.example.com/dashboard")!

        #expect(store.findMatchingRule(for: adminURL)?.id == pathRule.id)
        #expect(store.findMatchingRule(for: internalURL)?.id == regexRule.id)
    }

    @Test("Mailto recipient domain and subject matching")
    func mailtoRecipientDomainAndSubjectMatching() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let domainRule = RoutingRule(
            name: "Company Mail",
            type: .mail,
            field: .emailDomain,
            matchOperator: .equals,
            value: "acme.com",
            targetAppBundleID: "com.microsoft.Outlook",
            targetAppName: "Microsoft Outlook"
        )
        let subjectRule = RoutingRule(
            name: "Invoice Mail",
            type: .mail,
            field: .emailSubject,
            matchOperator: .contains,
            value: "invoice",
            targetAppBundleID: "com.apple.mail",
            targetAppName: "Mail"
        )
        store.rules = [domainRule, subjectRule]

        let companyMail = URL(string: "mailto:boss@acme.com?subject=Hello")!
        let invoiceMail = URL(string: "mailto:billing@vendor.io?subject=Monthly%20Invoice%20102")!
        let unmatchedMail = URL(string: "mailto:friend@gmail.com?subject=Lunch")!

        #expect(store.findMatchingRule(for: companyMail)?.id == domainRule.id)
        #expect(store.findMatchingRule(for: invoiceMail)?.id == subjectRule.id)
        #expect(store.findMatchingRule(for: unmatchedMail) == nil)
    }

    @Test("Source application only and combined rules")
    func sourceAppOnlyAndCombinedRules() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let slackApp = SourceAppInfo(bundleID: "com.tinyspeck.slackmacgap", name: "Slack")
        let notionApp = SourceAppInfo(bundleID: "notion.id", name: "Notion")

        let slackFigmaRule = RoutingRule(
            name: "Figma from Slack",
            type: .web,
            sourceApp: slackApp,
            field: .domain,
            matchOperator: .contains,
            value: "figma.com",
            targetAppBundleID: "com.google.Chrome",
            targetAppName: "Google Chrome"
        )
        let anySlackRule = RoutingRule(
            name: "All Slack Links",
            type: .web,
            sourceApp: slackApp,
            field: .domain,
            matchOperator: .contains,
            value: "",
            targetAppBundleID: "com.apple.Safari",
            targetAppName: "Safari"
        )
        store.rules = [slackFigmaRule, anySlackRule]

        let figmaURL = URL(string: "https://www.figma.com/file/123")!
        let docsURL = URL(string: "https://docs.google.com/document/d/1")!

        // Clicked in Slack + Figma URL -> matches first rule (slackFigmaRule)
        #expect(store.findMatchingRule(for: figmaURL, sourceApp: slackApp)?.id == slackFigmaRule.id)

        // Clicked in Slack + Docs URL -> matches second rule (anySlackRule)
        #expect(store.findMatchingRule(for: docsURL, sourceApp: slackApp)?.id == anySlackRule.id)

        // Clicked in Notion -> neither Slack rule matches
        #expect(store.findMatchingRule(for: figmaURL, sourceApp: notionApp) == nil)
    }

    @Test("Pause state and disabled rules bypass evaluation")
    func pauseAndDisabledRules() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var rule = RoutingRule(
            name: "GitHub Rule",
            type: .web,
            field: .domain,
            matchOperator: .contains,
            value: "github.com",
            targetAppBundleID: "com.apple.Safari",
            targetAppName: "Safari",
            isEnabled: true
        )
        store.rules = [rule]
        let url = URL(string: "https://github.com")!

        #expect(store.findMatchingRule(for: url) != nil)

        // Pausing store bypasses all rules
        store.isPaused = true
        #expect(store.findMatchingRule(for: url) == nil)
        store.isPaused = false

        // Disabling rule skips it
        rule.isEnabled = false
        store.rules = [rule]
        #expect(store.findMatchingRule(for: url) == nil)
    }

    @Test("Rules persist and reload via UserDefaults")
    func persistenceRoundTrip() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let profile = BrowserProfile(id: "Profile 1", displayName: "Work", engine: .chromium)
        let rule = RoutingRule(
            name: "Work Chrome",
            type: .web,
            field: .domain,
            matchOperator: .endsWith,
            value: ".corp.example.com",
            targetAppBundleID: "com.google.Chrome",
            targetAppName: "Google Chrome",
            targetProfile: profile
        )
        store.rules = [rule]

        let reloadedStore = RulesStore(userDefaults: defaults, storageKey: "TestRules")
        #expect(reloadedStore.rules.count == 1)
        #expect(reloadedStore.rules.first == rule)
    }

    @Test("Activity history logs opened apps and converts to RoutingRule")
    func activityHistoryToRoutingRule() {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let target = AppTarget(
            bundleID: "com.brave.Browser",
            name: "Brave Browser",
            appURL: URL(fileURLWithPath: "/Applications/Brave Browser.app"),
            icon: .init()
        )
        let source = SourceAppInfo(bundleID: "com.tinyspeck.slackmacgap", name: "Slack")
        let url = URL(string: "https://github.com/alejandro-llanes")!

        store.logActivity(url: url, source: source, target: target)
        #expect(store.recentActivity.count == 1)

        let record = store.recentActivity[0]
        #expect(record.hostOrRecipient == "github.com")
        #expect(record.targetAppBundleID == "com.brave.Browser")

        let generatedRule = record.toRoutingRule()
        store.rules = [generatedRule]
        #expect(store.findMatchingRule(for: url, sourceApp: source)?.id == generatedRule.id)
    }

    @Test("URLSanitizerService unwraps Google & SafeLinks redirects and strips utm/fbclid params")
    func urlSanitizerUnwrapsAndStripsTracking() {
        let dirtyGoogleRedirect = URL(string: "https://www.google.com/url?q=https%3A%2F%2Fgithub.com%2Fapple%2Fswift%3Futm_source%3Dnewsletter%26utm_medium%3Demail%26tab%3Dreadme%26fbclid%3DIwAR123&sa=D")!
        let sanitized = URLSanitizerService.shared.sanitize(dirtyGoogleRedirect)
        #expect(sanitized.absoluteString == "https://github.com/apple/swift?tab=readme")

        let safeLink = URL(string: "https://nam01.safelinks.protection.outlook.com/?url=https%3A%2F%2Ffigma.com%2Ffile%2F123%3Fgclid%3Dabc&data=05")!
        let unwrappedSafeLink = URLSanitizerService.shared.sanitize(safeLink)
        #expect(unwrappedSafeLink.absoluteString == "https://figma.com/file/123")
    }

    @Test("NativeAppHandoffService converts Zoom, Figma, and Spotify URLs to native schemes")
    func nativeAppDeepLinkConversion() {
        let zoomURL = URL(string: "https://us02web.zoom.us/j/8912345678?pwd=secret")!
        let zoomDeep = NativeAppHandoffService.shared.resolvedURL(for: zoomURL, targetBundleID: "us.zoom.xos")
        #expect(zoomDeep.absoluteString == "zoommtg://zoom.us/join?confno=8912345678&pwd=secret")

        let figmaURL = URL(string: "https://www.figma.com/design/abc123/Design-System")!
        let figmaDeep = NativeAppHandoffService.shared.resolvedURL(for: figmaURL, targetBundleID: "com.figma.Desktop")
        #expect(figmaDeep.absoluteString == "figma://www.figma.com/design/abc123/Design-System")

        let spotifyURL = URL(string: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT")!
        let spotifyDeep = NativeAppHandoffService.shared.resolvedURL(for: spotifyURL, targetBundleID: "com.spotify.client")
        #expect(spotifyDeep.absoluteString == "spotify://track/4cOdK2wGLETKBW3PvgPWqT")
    }

    @Test("RuleSchedule evaluates work hours and JSON export/import round-trips")
    func scheduleAndExportImportRoundTrip() throws {
        let (store, defaults, suiteName) = makeIsolatedStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workSchedule = RuleSchedule(
            isEnabled: true,
            daysOfWeek: [2, 3, 4, 5, 6], // Mon-Fri
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0
        )
        let scheduledRule = RoutingRule(
            name: "Work Hours GitHub",
            type: .web,
            field: .domain,
            matchOperator: .equals,
            value: "github.com",
            targetAppBundleID: "com.google.Chrome",
            targetAppName: "Google Chrome",
            openInPrivateMode: true,
            schedule: workSchedule
        )
        store.rules = [scheduledRule]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        // Monday at 10:30 AM (weekday = 2) -> matches
        let mondayMorning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 10, minute: 30))!
        #expect(store.findMatchingRule(for: URL(string: "https://github.com")!, at: mondayMorning)?.id == scheduledRule.id)

        // Monday at 8:30 PM (20:30) -> outside schedule -> nil
        let mondayNight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 20, minute: 30))!
        #expect(store.findMatchingRule(for: URL(string: "https://github.com")!, at: mondayNight) == nil)

        // Export and Import JSON
        let exportedData = try store.exportRulesData()
        store.rules.removeAll()
        #expect(store.rules.isEmpty)

        let importedCount = try store.importRules(from: exportedData, merge: true)
        #expect(importedCount == 1)
        #expect(store.rules.first == scheduledRule)
    }
}
