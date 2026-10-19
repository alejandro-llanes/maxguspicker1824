import Combine
import Foundation

final class RulesStore: ObservableObject {
    static let shared = RulesStore()

    @Published var rules: [RoutingRule] = [] {
        didSet { saveRules() }
    }

    @Published var isPaused: Bool = false // Controlled from the Menu Bar
    @Published var sanitizeURLsEnabled: Bool = true {
        didSet { userDefaults.set(sanitizeURLsEnabled, forKey: "SanitizeURLsEnabled_v1") }
    }
    @Published var prioritizeRunningBrowsers: Bool = true {
        didSet { userDefaults.set(prioritizeRunningBrowsers, forKey: "PrioritizeRunningBrowsers_v1") }
    }

    @Published var recentActivity: [ActivityRecord] = [] {
        didSet { saveActivity() }
    }

    /// Used to open the Rule Builder Sheet pre-populated from a history item or template.
    @Published var draftRuleFromHistory: RoutingRule? = nil

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let activityStorageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "SavedRoutingRules_v1",
        activityStorageKey: String = "SavedRecentActivity_v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.activityStorageKey = activityStorageKey
        if userDefaults.object(forKey: "SanitizeURLsEnabled_v1") != nil {
            self.sanitizeURLsEnabled = userDefaults.bool(forKey: "SanitizeURLsEnabled_v1")
        }
        if userDefaults.object(forKey: "PrioritizeRunningBrowsers_v1") != nil {
            self.prioritizeRunningBrowsers = userDefaults.bool(forKey: "PrioritizeRunningBrowsers_v1")
        }
        loadRules()
        loadActivity()
    }

    func findMatchingRule(for url: URL, sourceApp: SourceAppInfo? = nil, at date: Date = Date()) -> RoutingRule? {
        guard !isPaused, let scheme = url.scheme?.lowercased() else { return nil }
        let type: RouteType = (scheme == "mailto") ? .mail : .web

        for rule in rules where rule.isEnabled && rule.type == type {
            // 1. If the rule has an active schedule, verify day & time window
            if let schedule = rule.schedule, schedule.isEnabled {
                guard schedule.isActive(at: date) else { continue }
            }

            // 2. If the rule specifies a Source App, it must match the sender
            if let requiredSource = rule.sourceApp {
                guard requiredSource.bundleID == sourceApp?.bundleID else { continue }
            }

            // 3. If the rule has no URL/Email pattern (only Source App), it's an immediate match!
            let cleanPattern = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPattern.isEmpty && rule.sourceApp != nil {
                return rule
            }

            // 4. Otherwise evaluate the URL/Email condition
            if evaluate(rule: rule, against: url) {
                return rule
            }
        }
        return nil
    }

    func evaluate(rule: RoutingRule, against url: URL) -> Bool {
        let candidate = extractField(rule.field, from: url).lowercased()
        let target = rule.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty, !candidate.isEmpty else { return false }

        switch rule.matchOperator {
        case .contains:
            return candidate.contains(target)
        case .equals:
            // For domains, strip leading "www." so "github.com" matches "www.github.com"
            let cleanCandidate = candidate.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
            let cleanTarget = target.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
            return cleanCandidate == cleanTarget
        case .endsWith:
            return candidate.hasSuffix(target)
        case .startsWith:
            return candidate.hasPrefix(target)
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: rule.value, options: [.caseInsensitive]) else {
                return false
            }
            let range = NSRange(candidate.startIndex..., in: candidate)
            return regex.firstMatch(in: candidate, range: range) != nil
        }
    }

    func extractField(_ field: MatchField, from url: URL) -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch field {
        case .domain:
            return url.host ?? ""
        case .fullURL:
            return url.absoluteString
        case .urlPath:
            return url.path
        case .emailAddress:
            return components?.path ?? ""
        case .emailDomain:
            let email = components?.path ?? ""
            guard email.contains("@") else { return "" }
            return email.components(separatedBy: "@").last ?? ""
        case .emailSubject:
            return components?.queryItems?.first(where: { $0.name.lowercased() == "subject" })?.value ?? ""
        }
    }

    func logActivity(url: URL, source: SourceAppInfo?, target: AppTarget) {
        let isMail = (url.scheme?.lowercased() == "mailto")
        let hostOrRecipient = isMail
            ? (URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.absoluteString)
            : (url.host ?? url.absoluteString)

        let record = ActivityRecord(
            timestamp: Date(),
            urlString: url.absoluteString,
            hostOrRecipient: hostOrRecipient,
            routeType: isMail ? .mail : .web,
            sourceApp: source,
            targetAppBundleID: target.bundleID,
            targetAppName: target.name,
            targetProfile: target.profile,
            openedInPrivateMode: target.openInPrivateMode
        )

        // Avoid consecutive duplicate entries for the exact same host/app/source
        self.recentActivity.removeAll {
            $0.hostOrRecipient.caseInsensitiveCompare(record.hostOrRecipient) == .orderedSame &&
            $0.targetAppBundleID == record.targetAppBundleID &&
            $0.targetProfile == record.targetProfile &&
            $0.sourceApp == record.sourceApp &&
            $0.openedInPrivateMode == record.openedInPrivateMode
        }
        self.recentActivity.insert(record, at: 0)
        if self.recentActivity.count > 20 {
            self.recentActivity = Array(self.recentActivity.prefix(20))
        }
    }

    func clearHistory() {
        recentActivity.removeAll()
    }

    // MARK: - Export & Import Rules (JSON)

    func exportRulesData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(rules)
    }

    @discardableResult
    func importRules(from data: Data, merge: Bool = true) throws -> Int {
        let decoded = try JSONDecoder().decode([RoutingRule].self, from: data)
        if merge {
            var existingIDs = Set(rules.map(\.id))
            var addedCount = 0
            for rule in decoded {
                if !existingIDs.contains(rule.id) {
                    rules.append(rule)
                    existingIDs.insert(rule.id)
                    addedCount += 1
                } else if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                    rules[idx] = rule
                    addedCount += 1
                }
            }
            return addedCount
        } else {
            rules = decoded
            return decoded.count
        }
    }

    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }

    private func loadRules() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RoutingRule].self, from: data) else {
            return
        }
        rules = decoded
    }

    private func saveActivity() {
        if let encoded = try? JSONEncoder().encode(recentActivity) {
            userDefaults.set(encoded, forKey: activityStorageKey)
        }
    }

    private func loadActivity() {
        guard let data = userDefaults.data(forKey: activityStorageKey),
              let decoded = try? JSONDecoder().decode([ActivityRecord].self, from: data) else {
            return
        }
        recentActivity = decoded
    }
}
