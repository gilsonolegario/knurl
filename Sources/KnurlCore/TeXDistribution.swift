// TeXDistribution.swift — Detects the installed TeX Live distribution, year, root path, and available engines.

import Foundation

/// Information about the TeX Live installation detected on the system.
public struct TeXDistribution: Sendable, Equatable {
    public enum State: String, Sendable, Equatable {
        /// A valid TeX Live installation was found (via tlmgr or /Library/TeX/texbin).
        case ok
        /// No TeX Live installation detected at all.
        case missing
        /// A symlink exists but points to a non-existent target.
        case broken
    }

    public let state: State
    /// Four-digit year of the TeX Live release (e.g. `"2024"`), if detectable.
    public let year: String?
    /// Root path of the TeX Live installation (e.g. `/usr/local/texlive/2024`).
    public let root: String?
    /// Set of engine names found on PATH (e.g. `{"pdflatex", "xelatex"}`).
    public let engines: Set<String>

    public init(state: State, year: String? = nil, root: String? = nil, engines: Set<String> = []) {
        self.state = state
        self.year = year
        self.root = root
        self.engines = engines
    }

    public typealias Lookup = @Sendable (String) -> String?
    public typealias SymlinkTarget = @Sendable (String) -> String?

    /// Probes the system for a TeX Live installation. Checks tlmgr first, then /Library/TeX/texbin symlinks.
    public static func detect(
        lookup: Lookup = { TeXEnvironment.locateExecutable($0) },
        symlinkTarget: SymlinkTarget = { path in
            try? FileManager.default.destinationOfSymbolicLink(atPath: path)
        },
        fileExists: @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> TeXDistribution {
        let engines = Set(["pdflatex", "xelatex", "lualatex"].filter { lookup($0) != nil })
        if let tlmgr = lookup("tlmgr") {
            let (root, year) = parseTLRoot(from: tlmgr)
            return TeXDistribution(state: .ok, year: year, root: root, engines: engines)
        }
        let texbin = "/Library/TeX/texbin"
        if symlinkTarget(texbin) != nil {
            var current = texbin
            var visited = Set<String>()
            while visited.insert(current).inserted, let target = symlinkTarget(current) {
                current = target.hasPrefix("/")
                    ? target
                    : (current as NSString).deletingLastPathComponent + "/" + target
            }
            if !fileExists(current) {
                return TeXDistribution(state: .broken, engines: engines)
            }
            // Symlink válido apontando para uma árvore existente = distribuição detectada.
            let (root, year) = parseTLRoot(from: current)
            return TeXDistribution(state: .ok, year: year, root: root, engines: engines)
        }
        return TeXDistribution(state: .missing, engines: engines)
    }

    /// Extracts the TeX Live root and year from a path like `/usr/local/texlive/2024/bin/...`.
    private static func parseTLRoot(from executablePath: String) -> (root: String?, year: String?) {
        let parts = executablePath.components(separatedBy: "/")
        for (index, part) in parts.enumerated() where part == "texlive" {
            guard index + 1 < parts.count else { break }
            let yearCandidate = parts[index + 1]
            guard yearCandidate.count == 4,
                  yearCandidate.allSatisfy(\.isNumber),
                  Int(yearCandidate) ?? 0 >= 2000 else { continue }
            let root = parts[0...(index + 1)].joined(separator: "/")
            return (root, yearCandidate)
        }
        return (nil, nil)
    }
}
