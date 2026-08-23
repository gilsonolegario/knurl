// CTANDownload.swift — Constructs CTAN download URLs and resolves package paths from CTAN's JSON API.

import Foundation

/// Builds sanitized CTAN download URLs for TeX package zip files.
public enum CTANDownloadURL {
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-")

    /// Returns the package name if it contains only safe characters, nil otherwise.
    public static func sanitized(_ package: String) -> String? {
        guard !package.isEmpty, package.rangeOfCharacter(from: allowed.inverted) == nil else { return nil }
        return package
    }

    /// Builds a CTAN mirror download URL from a CTAN path (e.g. `"macros/latex/contrib/amsmath"`).
    public static func tarball(for path: String) -> URL? {
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !clean.isEmpty else { return nil }
        let segments = clean.split(separator: "/", omittingEmptySubsequences: true)
        for segment in segments {
            guard segment.rangeOfCharacter(from: allowed.inverted) == nil else { return nil }
        }
        return URL(string: "https://mirrors.ctan.org/\(clean).zip")
    }
}

/// Resolves a CTAN package name to its repository path via the CTAN JSON API.
public enum CTANPackageLookup {
    private struct Payload: Decodable {
        struct Ctan: Decodable { let path: String }
        let ctan: Ctan
    }

    /// Extracts the `ctan.path` field from raw JSON data; falls back to regex if JSON decoding fails.
    public static func path(from data: Data) throws -> String {
        let text = String(decoding: data, as: UTF8.self)
        let cleaned = String(text.unicodeScalars.filter {
            $0.value >= 0x20 || $0.value == 0x09 || $0.value == 0x0A || $0.value == 0x0D
        })
        if let path = try? JSONDecoder().decode(Payload.self, from: Data(cleaned.utf8)).ctan.path {
            return path
        }
        guard let regex = try? NSRegularExpression(pattern: "\"path\"\\s*:\\s*\"([^\"]+)\"") else {
            throw URLError(.cannotParseResponse)
        }
        let ns = cleaned as NSString
        guard let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: ns.length)) else {
            throw URLError(.cannotParseResponse)
        }
        let value = ns.substring(with: match.range(at: 1))
        guard !value.isEmpty else { throw URLError(.cannotParseResponse) }
        return value
    }

    /// Fetches the CTAN path for a package by name (async network call).
    public static func resolve(_ package: String) async throws -> String {
        guard let name = CTANDownloadURL.sanitized(package) else {
            throw URLError(.badURL)
        }
        let url = URL(string: "https://ctan.org/json/2.0/pkg/\(name)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.resourceUnavailable)
        }
        return try path(from: data)
    }
}
