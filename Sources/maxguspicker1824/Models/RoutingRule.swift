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

/// Optional time-of-day and day-of-week schedule condition for a routing rule.
struct RuleSchedule: Codable, Equatable, Hashable {
    var isEnabled: Bool = false
    /// Calendar weekday numbers: 1 = Sun, 2 = Mon, 3 = Tue, 4 = Wed, 5 = Thu, 6 = Fri, 7 = Sat
    var daysOfWeek: Set<Int> = [2, 3, 4, 5, 6]
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 18
    var endMinute: Int = 0

    func isActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else {
            return false
        }
        guard daysOfWeek.contains(weekday) else {
            return false
        }
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight schedule (e.g., 22:00 -> 06:00)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }

    var displaySummary: String {
        let dayNames: [(Int, String)] = [
            (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
        ]
        let dayText: String
        if daysOfWeek == Set([2, 3, 4, 5, 6]) {
            dayText = "Mon–Fri"
        } else if daysOfWeek == Set([1, 7]) {
            dayText = "Weekends"
        } else if daysOfWeek.count == 7 {
            dayText = "Every day"
        } else {
            dayText = dayNames.filter { daysOfWeek.contains($0.0) }.map(\.1).joined(separator: ", ")
        }
        let timeText = String(format: "%02d:%02d–%02d:%02d", startHour, startMinute, endHour, endMinute)
        return "\(dayText) \(timeText)"
    }
}

struct RoutingRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: RouteType

    // Optional Source App filter (e.g., Slack, Teams, Mail, Notion)
    var sourceApp: SourceAppInfo? = nil

    // Optional Identity Context filter (Work, Personal, Client / Dev)
    var contextFilter: IdentityContext? = nil

    // URL / Email condition (if value is empty, matches ALL links from sourceApp)
    var field: MatchField
    var matchOperator: MatchOperator
    var value: String

    // Destination
    var targetAppBundleID: String
    var targetAppName: String
    var targetProfile: BrowserProfile? = nil
    var openInPrivateMode: Bool = false
    var schedule: RuleSchedule? = nil

    // Multi-Account URL Rewriting & Account Hinting
    var googleAuthUser: String? = nil
    var urlFindPattern: String? = nil
    var urlReplacePattern: String? = nil

    // Activity & Insights
    var hitCount: Int = 0
    var lastMatchedAt: Date? = nil

    var isEnabled: Bool = true

    init(
        id: UUID = UUID(),
        name: String,
        type: RouteType,
        sourceApp: SourceAppInfo? = nil,
        contextFilter: IdentityContext? = nil,
        field: MatchField,
        matchOperator: MatchOperator,
        value: String,
        targetAppBundleID: String,
        targetAppName: String,
        targetProfile: BrowserProfile? = nil,
        openInPrivateMode: Bool = false,
        schedule: RuleSchedule? = nil,
        googleAuthUser: String? = nil,
        urlFindPattern: String? = nil,
        urlReplacePattern: String? = nil,
        hitCount: Int = 0,
        lastMatchedAt: Date? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sourceApp = sourceApp
        self.contextFilter = contextFilter
        self.field = field
        self.matchOperator = matchOperator
        self.value = value
        self.targetAppBundleID = targetAppBundleID
        self.targetAppName = targetAppName
        self.targetProfile = targetProfile
        self.openInPrivateMode = openInPrivateMode
        self.schedule = schedule
        self.googleAuthUser = googleAuthUser
        self.urlFindPattern = urlFindPattern
        self.urlReplacePattern = urlReplacePattern
        self.hitCount = hitCount
        self.lastMatchedAt = lastMatchedAt
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, sourceApp, contextFilter, field, matchOperator, value
        case targetAppBundleID, targetAppName, targetProfile, openInPrivateMode, schedule
        case googleAuthUser, urlFindPattern, urlReplacePattern, hitCount, lastMatchedAt, isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(RouteType.self, forKey: .type)
        sourceApp = try container.decodeIfPresent(SourceAppInfo.self, forKey: .sourceApp)
        contextFilter = try container.decodeIfPresent(IdentityContext.self, forKey: .contextFilter)
        field = try container.decode(MatchField.self, forKey: .field)
        matchOperator = try container.decode(MatchOperator.self, forKey: .matchOperator)
        value = try container.decode(String.self, forKey: .value)
        targetAppBundleID = try container.decode(String.self, forKey: .targetAppBundleID)
        targetAppName = try container.decode(String.self, forKey: .targetAppName)
        targetProfile = try container.decodeIfPresent(BrowserProfile.self, forKey: .targetProfile)
        openInPrivateMode = try container.decodeIfPresent(Bool.self, forKey: .openInPrivateMode) ?? false
        schedule = try container.decodeIfPresent(RuleSchedule.self, forKey: .schedule)
        googleAuthUser = try container.decodeIfPresent(String.self, forKey: .googleAuthUser)
        urlFindPattern = try container.decodeIfPresent(String.self, forKey: .urlFindPattern)
        urlReplacePattern = try container.decodeIfPresent(String.self, forKey: .urlReplacePattern)
        hitCount = try container.decodeIfPresent(Int.self, forKey: .hitCount) ?? 0
        lastMatchedAt = try container.decodeIfPresent(Date.self, forKey: .lastMatchedAt)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    /// Applies any configured multi-account `authuser` parameter or custom find/replace URL transformation.
    func transformURL(_ inputURL: URL) -> URL {
        var workingURL = inputURL

        // 1. Custom Find & Replace rewrite
        if let find = urlFindPattern?.trimmingCharacters(in: .whitespacesAndNewlines),
           !find.isEmpty {
            let replacement = urlReplacePattern ?? ""
            let updatedString = workingURL.absoluteString.replacingOccurrences(of: find, with: replacement)
            if let rewritten = URL(string: updatedString) {
                workingURL = rewritten
            }
        }

        // 2. Google Workspace / Meet `authuser` parameter injection
        if let authUser = googleAuthUser?.trimmingCharacters(in: .whitespacesAndNewlines),
           !authUser.isEmpty,
           var components = URLComponents(url: workingURL, resolvingAgainstBaseURL: false) {
            var items = components.queryItems ?? []
            items.removeAll { $0.name.lowercased() == "authuser" }
            items.append(URLQueryItem(name: "authuser", value: authUser))
            components.queryItems = items
            if let updated = components.url {
                workingURL = updated
            }
        }

        return workingURL
    }

    var summarySentence: String {
        var parts: [String] = []
        if let ctx = contextFilter, ctx != .all {
            parts.append("Context: \(ctx.rawValue)")
        }
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
        if let schedule = schedule, schedule.isEnabled {
            parts.append("⏰ \(schedule.displaySummary)")
        }
        if let authUser = googleAuthUser?.trimmingCharacters(in: .whitespaces), !authUser.isEmpty {
            parts.append("👤 authuser=\(authUser)")
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
    var openedInPrivateMode: Bool = false

    var destinationDisplayTitle: String {
        var base = targetAppName
        if let profile = targetProfile {
            base += " (\(profile.displayName))"
        }
        if openedInPrivateMode {
            base += " [Private]"
        }
        return base
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
            openInPrivateMode: openedInPrivateMode,
            isEnabled: true
        )
    }
}

/// Curated one-click rule templates for common workflows.
struct RuleTemplatePreset: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let type: RouteType
    let field: MatchField
    let matchOperator: MatchOperator
    let value: String
    var defaultWorkHoursSchedule: Bool = false

    static let builtInPresets: [RuleTemplatePreset] = [
        RuleTemplatePreset(
            id: "localhost-dev",
            title: "Localhost & Dev Servers",
            subtitle: "Matches localhost, 127.0.0.1, or .local domains",
            icon: "terminal.fill",
            type: .web,
            field: .domain,
            matchOperator: .regex,
            value: "^(localhost|127\\.0\\.0\\.1|.*\\.local)$"
        ),
        RuleTemplatePreset(
            id: "github-gitlab",
            title: "GitHub & GitLab Repositories",
            subtitle: "Matches github.com and gitlab.com links",
            icon: "chevron.left.forwardslash.chevron.right",
            type: .web,
            field: .domain,
            matchOperator: .regex,
            value: "(^|\\.)(github|gitlab)\\.com$"
        ),
        RuleTemplatePreset(
            id: "google-workspace-workhours",
            title: "Google Workspace (Work Hours)",
            subtitle: "Docs, Drive, Mail & Calendar during Mon–Fri 09:00–18:00",
            icon: "briefcase.fill",
            type: .web,
            field: .domain,
            matchOperator: .regex,
            value: "^(docs|drive|mail|calendar|meet)\\.google\\.com$",
            defaultWorkHoursSchedule: true
        ),
        RuleTemplatePreset(
            id: "video-meetings",
            title: "Video Calls (Meet, Zoom, Teams)",
            subtitle: "Matches Google Meet, Zoom, and Microsoft Teams links",
            icon: "video.fill",
            type: .web,
            field: .domain,
            matchOperator: .regex,
            value: "(meet\\.google\\.com|zoom\\.us|teams\\.microsoft\\.com)"
        ),
        RuleTemplatePreset(
            id: "design-product",
            title: "Figma, Notion & Linear",
            subtitle: "Matches figma.com, notion.so, and linear.app",
            icon: "paintbrush.pointed.fill",
            type: .web,
            field: .domain,
            matchOperator: .regex,
            value: "(^|\\.)(figma\\.com|notion\\.so|linear\\.app)$"
        )
    ]

    func toRoutingRule(defaultApp: AppTarget?) -> RoutingRule {
        let schedule: RuleSchedule? = defaultWorkHoursSchedule
            ? RuleSchedule(isEnabled: true, daysOfWeek: [2, 3, 4, 5, 6], startHour: 9, startMinute: 0, endHour: 18, endMinute: 0)
            : nil
        return RoutingRule(
            name: title,
            type: type,
            field: field,
            matchOperator: matchOperator,
            value: value,
            targetAppBundleID: defaultApp?.bundleID ?? "com.apple.Safari",
            targetAppName: defaultApp?.name ?? "Safari",
            schedule: schedule,
            isEnabled: true
        )
    }
}
