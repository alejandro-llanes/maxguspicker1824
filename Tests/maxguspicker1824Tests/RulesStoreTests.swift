import Foundation
import Testing
@testable import maxguspicker1824

@Suite("RulesStore Routing Engine Tests")
struct RulesStoreTests {
    private func makeIsolatedStore() -> (RulesStore, UserDefaults, String) {
        let suiteName = "maxguspicker1824Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = RulesStore(userDefaults: defaults, storageKey: "TestRules")
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
        let suiteName = "maxguspicker1824Tests.History.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = RulesStore(
            userDefaults: defaults,
            storageKey: "TestRules",
            activityStorageKey: "TestActivity"
        )
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
}
