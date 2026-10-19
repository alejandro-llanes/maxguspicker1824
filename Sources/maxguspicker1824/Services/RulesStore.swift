import Combine
import Foundation

final class RulesStore: ObservableObject {
    static let shared = RulesStore()

    @Published var rules: [RoutingRule] = [] {
        didSet { saveRules() }
    }

    @Published var isPaused: Bool = false // Controlled from the Menu Bar
    @Published var recentActivity: [String] = [] // Shown in Menu Bar

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "SavedRoutingRules_v1") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        loadRules()
    }

    func findMatchingRule(for url: URL, sourceApp: SourceAppInfo? = nil) -> RoutingRule? {
        guard !isPaused, let scheme = url.scheme?.lowercased() else { return nil }
        let type: RouteType = (scheme == "mailto") ? .mail : .web

        for rule in rules where rule.isEnabled && rule.type == type {
            // 1. If the rule specifies a Source App, it must match the sender
            if let requiredSource = rule.sourceApp {
                guard requiredSource.bundleID == sourceApp?.bundleID else { continue }
            }

            // 2. If the rule has no URL/Email pattern (only Source App), it's an immediate match!
            let cleanPattern = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPattern.isEmpty && rule.sourceApp != nil {
                return rule
            }

            // 3. Otherwise evaluate the URL/Email condition
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

    func logActivity(url: URL, source: SourceAppInfo?, destination: String) {
        let host = (url.scheme?.lowercased() == "mailto")
            ? (URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.absoluteString)
            : (url.host ?? url.absoluteString)
        let fromText = source.map { " (from \($0.name))" } ?? ""
        let entry = "\(host)\(fromText) → \(destination)"

        let update = {
            self.recentActivity.insert(entry, at: 0)
            if self.recentActivity.count > 5 {
                self.recentActivity.removeLast()
            }
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
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
}
