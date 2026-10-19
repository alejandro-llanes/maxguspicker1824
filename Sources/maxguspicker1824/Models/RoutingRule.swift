import Foundation

enum RouteType: String, CaseIterable, Codable, Identifiable {
    case web = "Website"
    case mail = "Email"

    var id: String { rawValue }

    var icon: String {
        self == .web ? "globe" : "envelope.fill"
    }
}

enum MatchField: String, CaseIterable, Codable, Identifiable {
    // Web fields
    case domain = "Website Domain"
    case fullURL = "Full Web Address"
    case urlPath = "URL Path"
    // Mail fields
    case emailAddress = "Recipient Email"
    case emailDomain = "Email Domain (@company.com)"
    case emailSubject = "Email Subject"

    var id: String { rawValue }

    static func fields(for type: RouteType) -> [MatchField] {
        switch type {
        case .web:
            return [.domain, .fullURL, .urlPath]
        case .mail:
            return [.emailAddress, .emailDomain, .emailSubject]
        }
    }

    var placeholder: String {
        switch self {
        case .domain:
            return "e.g. github.com or figma.com"
        case .fullURL:
            return "e.g. https://docs.google.com/spreadsheets"
        case .urlPath:
            return "e.g. /pull/ or /admin"
        case .emailAddress:
            return "e.g. boss@acme.com"
        case .emailDomain:
            return "e.g. acme.com"
        case .emailSubject:
            return "e.g. Invoice or Support"
        }
    }
}

enum MatchOperator: String, CaseIterable, Codable, Identifiable {
    case contains = "contains"
    case equals = "is exactly"
    case endsWith = "ends with"
    case startsWith = "starts with"
    case regex = "matches regex (advanced)"

    var id: String { rawValue }
}

struct RoutingRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: RouteType

    // Optional Source App filter (e.g., Slack, Teams, Mail, Notion)
    var sourceApp: SourceAppInfo? = nil

    // URL / Email condition (if value is empty, matches ALL links from sourceApp)
    var field: MatchField
    var matchOperator: MatchOperator
    var value: String

    // Destination
    var targetAppBundleID: String
    var targetAppName: String
    var targetProfile: BrowserProfile? = nil
    var isEnabled: Bool = true

    var summarySentence: String {
        var parts: [String] = []
        if let src = sourceApp {
            parts.append("Clicked in \(src.name)")
        }
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        if !trimmedValue.isEmpty {
            if !parts.isEmpty {
                parts.append("\(field.rawValue.lowercased()) \(matchOperator.rawValue) “\(trimmedValue)”")
            } else {
                parts.append("When \(field.rawValue.lowercased()) \(matchOperator.rawValue) “\(trimmedValue)”")
            }
        } else if sourceApp != nil {
            parts.append("any \(type.rawValue.lowercased()) link")
        }
        return parts.joined(separator: " • ")
    }
}

/// Represents a previously opened URL/email and the target application used to open it.
struct ActivityRecord: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var urlString: String
    var hostOrRecipient: String
    var routeType: RouteType
    var sourceApp: SourceAppInfo? = nil
    var targetAppBundleID: String
    var targetAppName: String
    var targetProfile: BrowserProfile? = nil

    var destinationDisplayTitle: String {
        if let profile = targetProfile {
            return "\(targetAppName) (\(profile.displayName))"
        }
        return targetAppName
    }

    var displaySummary: String {
        let fromText = sourceApp.map { " (from \($0.name))" } ?? ""
        return "\(hostOrRecipient)\(fromText) → \(destinationDisplayTitle)"
    }

    /// Converts this history record into a pre-configured `RoutingRule`.
    func toRoutingRule() -> RoutingRule {
        let matchField: MatchField = (routeType == .mail) ? .emailAddress : .domain
        return RoutingRule(
            name: "\(hostOrRecipient) → \(destinationDisplayTitle)",
            type: routeType,
            sourceApp: sourceApp,
            field: matchField,
            matchOperator: .equals,
            value: hostOrRecipient,
            targetAppBundleID: targetAppBundleID,
            targetAppName: targetAppName,
            targetProfile: targetProfile,
            isEnabled: true
        )
    }
}
