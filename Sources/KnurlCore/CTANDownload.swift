import Foundation

public enum CTANDownloadURL {
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-")

    public static func sanitized(_ package: String) -> String? {
        guard !package.isEmpty, package.rangeOfCharacter(from: allowed.inverted) == nil else { return nil }
        return package
    }

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

public enum CTANPackageLookup {
    private struct Payload: Decodable {
        struct Ctan: Decodable { let path: String }
        let ctan: Ctan
    }

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
