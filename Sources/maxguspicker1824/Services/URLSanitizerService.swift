import Foundation

final class URLSanitizerService {
    static let shared = URLSanitizerService()

    private static let trackingQueryParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_name", "utm_cid", "utm_reader", "utm_viz_id",
        "utm_pubreferrer", "utm_swu", "fbclid", "gclid", "dclid",
        "gbraid", "wbraid", "msclkid", "twclid", "yclid",
        "mc_cid", "mc_eid", "igshid", "_hsenc", "_hsmi",
        "hsctatracking", "vero_id", "vero_conv", "rb_clickid",
        "s_kwcid", "oly_enc_id", "oly_anon_id", "_openstat", "wickedid"
    ]

    private init() {}

    /// Unwraps redirect wrappers (Google, SafeLinks, Slack, Facebook, YouTube) and strips tracking parameters.
    func sanitize(_ url: URL, unwrapRedirects: Bool = true, stripTracking: Bool = true) -> URL {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return url
        }

        var current = url
        if unwrapRedirects {
            // Unwrap up to 3 nested redirect layers
            for _ in 0..<3 {
                if let unwrapped = unwrapSingleLayer(current), unwrapped != current {
                    current = unwrapped
                } else {
                    break
                }
            }
        }

        if stripTracking {
            current = stripTrackingParameters(from: current)
        }

        return current
    }

    func unwrapSingleLayer(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else {
            return nil
        }
        let path = components.path.lowercased()
        let queryItems = components.queryItems ?? []

        // 1. Google Redirects: https://www.google.com/url?q=https://... or ?url=https://...
        if (host == "google.com" || host == "www.google.com" || host.hasSuffix(".google.com")) && path == "/url" {
            if let target = extractRedirectURL(from: queryItems, keys: ["q", "url"]) {
                return target
            }
        }

        // 2. Microsoft Outlook SafeLinks: *.safelinks.protection.outlook.com/?url=https://...
        if host.hasSuffix(".safelinks.protection.outlook.com") || host == "safelinks.protection.outlook.com" {
            if let target = extractRedirectURL(from: queryItems, keys: ["url"]) {
                return target
            }
        }

        // 3. Facebook / Instagram / Messenger Redirects: l.facebook.com/l.php?u=https://...
        if host == "l.facebook.com" || host == "lm.facebook.com" || host == "l.instagram.com" || host == "l.messenger.com" {
            if let target = extractRedirectURL(from: queryItems, keys: ["u"]) {
                return target
            }
        }

        // 4. YouTube Redirects: youtube.com/redirect?q=https://...
        if (host == "youtube.com" || host == "www.youtube.com") && path == "/redirect" {
            if let target = extractRedirectURL(from: queryItems, keys: ["q", "url"]) {
                return target
            }
        }

        // 5. Slack Redirects: slack-redir.net/link?url=https://...
        if host == "slack-redir.net" || host.hasSuffix(".slack-redir.net") {
            if let target = extractRedirectURL(from: queryItems, keys: ["url"]) {
                return target
            }
        }

        return nil
    }

    private func extractRedirectURL(from queryItems: [URLQueryItem], keys: [String]) -> URL? {
        for key in keys {
            if let rawValue = queryItems.first(where: { $0.name.lowercased() == key })?.value,
               let decoded = rawValue.removingPercentEncoding ?? Optional(rawValue),
               let candidate = URL(string: decoded),
               let scheme = candidate.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return candidate
            }
        }
        return nil
    }

    func stripTrackingParameters(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let existingItems = components.queryItems,
              !existingItems.isEmpty else {
            return url
        }

        let filtered = existingItems.filter { item in
            let lowerName = item.name.lowercased()
            if lowerName.hasPrefix("utm_") {
                return false
            }
            return !Self.trackingQueryParameters.contains(lowerName)
        }

        if filtered.count == existingItems.count {
            return url
        }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url ?? url
    }
}
