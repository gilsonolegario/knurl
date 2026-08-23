// CTANMapper.swift — Resolves TeX package names to their canonical CTAN names via the CTAN JSON API.

import Foundation

/// Protocol for resolving a TeX element name to its CTAN match.
public protocol CTANMapping: Sendable {
    func resolve(_ name: String) async throws -> CTANMatch
}

/// Result of a CTAN name resolution attempt.
public enum CTANMatch: Equatable, Sendable {
    /// Successfully resolved to a canonical CTAN package name.
    case matched(package: String)
    /// No matching package found on CTAN (or network error).
    case unknown
}

/// Resolves TeX package names to canonical CTAN names with in-memory caching.
public struct CTANMapper: Sendable {
    private struct Payload: Decodable {
        let name: String?
    }

    private let session: URLSession
    private let cache: LockedDict
    /// Optional callback invoked on each resolution attempt (for UI progress).
    private let onResolve: (@Sendable (String) -> Void)?

    public init(session: URLSession = .shared, cache: [String: CTANMatch] = [:], onResolve: (@Sendable (String) -> Void)? = nil) {
        self.session = session
        self.cache = LockedDict(initial: cache)
        self.onResolve = onResolve
    }

    /// Resolves a package name against CTAN. Returns cached results; network timeout is 10s.
    public func resolve(_ name: String) async throws -> CTANMatch {
        let key = name.lowercased()
        if let cached = cache.value(forKey: key) { return cached }
        onResolve?(name)
        let url = URL(string: "https://ctan.org/json/2.0/pkg/\(key)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                cache.set(.unknown, forKey: key)
                return .unknown
            }
            // Nome canônico do CTAN (campo `name`); fallback para o nome consultado.
            let canonical = (try? JSONDecoder().decode(Payload.self, from: data).name) ?? name
            cache.set(.matched(package: canonical), forKey: key)
            return .matched(package: canonical)
        } catch {
            cache.set(.unknown, forKey: key)
            return .unknown
        }
    }

    /// Thread-safe dictionary used as the in-memory cache.
    private final class LockedDict: @unchecked Sendable {
        private var storage: [String: CTANMatch]
        private let lock = NSLock()
        init(initial: [String: CTANMatch]) { storage = initial }
        func value(forKey key: String) -> CTANMatch? { lock.lock(); defer { lock.unlock() }; return storage[key] }
        func set(_ value: CTANMatch, forKey key: String) { lock.lock(); defer { lock.unlock() }; storage[key] = value }
    }
}

extension CTANMapper: CTANMapping {}
