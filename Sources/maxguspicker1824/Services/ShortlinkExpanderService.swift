import Foundation

/// Resolves shortened URLs (bit.ly, t.co, tinyurl.com, lnkd.in, etc.) to their final destination URL.
final class ShortlinkExpanderService {
    static let shared = ShortlinkExpanderService()

    private let shortenerDomains: Set<String> = [
        "bit.ly",
        "t.co",
        "tinyurl.com",
        "lnkd.in",
        "buff.ly",
        "ow.ly",
        "is.gd",
        "rb.gy",
        "short.io",
        "rebrand.ly",
        "bl.ink",
        "cutt.ly",
        "tiny.cc"
    ]

    private init() {}

    func isShortlink(_ url: URL) -> Bool {
        guard let rawHost = url.host?.lowercased() else { return false }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        guard let path = url.path.isEmpty ? nil : url.path, path != "/" else {
            return false
        }
        return shortenerDomains.contains(host)
    }

    func expand(_ url: URL, timeout: TimeInterval = 3.0) async -> URL? {
        guard isShortlink(url) else { return nil }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)", forHTTPHeaderField: "User-Agent")

        if let (_, response) = try? await session.data(for: headRequest),
           let finalURL = response.url,
           finalURL.absoluteString != url.absoluteString {
            return URLSanitizerService.shared.sanitize(finalURL)
        }

        // Fallback to lightweight 1-byte GET if HEAD was rejected by the shortener
        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        getRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)", forHTTPHeaderField: "User-Agent")

        if let (_, response) = try? await session.data(for: getRequest),
           let finalURL = response.url,
           finalURL.absoluteString != url.absoluteString {
            return URLSanitizerService.shared.sanitize(finalURL)
        }

        return nil
    }
}
