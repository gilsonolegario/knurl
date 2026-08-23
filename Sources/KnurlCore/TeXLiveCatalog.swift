// TeXLiveCatalog.swift — Indexes texlive.tlpdb to map filenames to their owning TeX Live packages.

import Foundation

/// Índice do catálogo do TeX Live (texlive.tlpdb): mapeia nome de arquivo → pacote dono.
/// Resolve casos em que o nome CTAN não é o nome do pacote TeX Live (nicefrac → units,
/// mathrsfs → jknapltx, tikz → pgf) sem tabela manual.
public struct TeXLiveCatalog: Sendable {
    private let index: [String: String]
    private let cache: LockedDict

    public init(index: [String: String]) {
        self.index = index
        self.cache = LockedDict()
    }

    /// Looks up the TeX Live package that owns a given element name and kind.
    public func owner(for name: String, kind: TeXElementKind) -> String? {
        let key = "\(kind.rawValue)|\(name.lowercased())"
        if let cached = cache.value(forKey: key) { return cached }
        let result = fileNames(for: name, kind: kind)
            .lazy
            .compactMap { index[$0] }
            .first
        cache.set(result, forKey: key)
        return result
    }

    /// Consulta direta pelo nome do arquivo (ex.: `csquotes.bbx`, `plain.bst`),
    /// para extensões que não têm `.sty`/`.cls`/`.bib` correspondente.
    public func owner(forFileNamed fileName: String) -> String? {
        index[fileName.lowercased()]
    }

    /// Creates a catalog backed by the lazily-built shared index.
    public static func makeDefault() -> TeXLiveCatalog {
        TeXLiveCatalog(index: SharedIndex.shared.value())
    }

    /// Nomes de arquivo candidatos no catálogo, por tipo de elemento.
    /// Fontes têm múltiplas extensões possíveis (ttf/otf/tfm/vf).
    private func fileNames(for name: String, kind: TeXElementKind) -> [String] {
        let base = name.lowercased()
        switch kind {
        case .documentClass: return ["\(base).cls"]
        case .bibliography: return ["\(base).bib"]
        case .font: return ["\(base).ttf", "\(base).otf", "\(base).tfm", "\(base).vf"]
        default: return ["\(base).sty"]
        }
    }

    /// Parses texlive.tlpdb into a filename→package mapping. Only `run` file lists are indexed.
    private static func buildIndex() -> [String: String] {
        guard let path = tlpdbPath() else { return [:] }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        var index: [String: String] = [:]
        var currentPackage: String?
        var inRun = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty { continue }
            if line.hasPrefix("name ") {
                currentPackage = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                inRun = false
                continue
            }
            if line.hasPrefix("category ") { inRun = false; continue }
            if line == "run" { inRun = true; continue }
            if line == "doc" || line == "src" { inRun = false; continue }
            guard inRun, let currentPackage else { continue }
            let path = line.trimmingCharacters(in: .whitespaces)
            guard path.hasPrefix("tex/") || path.hasPrefix("bibtex/") || path.hasPrefix("fonts/") else { continue }
            guard let basename = path.split(separator: "/").last else { continue }
            let file = String(basename).lowercased()
            if index[file] == nil {
                index[file] = currentPackage
            } else if file.dropLast(4) == currentPackage {
                index[file] = currentPackage
            }
        }
        return index
    }

    /// Locates texlive.tlpdb by probing kpsewhich, tlmgr path, and ~/texlive dirs.
    private static func tlpdbPath() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var candidates: [String] = []
        if let kpsewhich = TeXEnvironment.locateExecutable("kpsewhich") {
            let probe = Process()
            probe.executableURL = URL(fileURLWithPath: kpsewhich)
            probe.arguments = ["--var-value", "TEXMFROOT"]
            let pipe = Pipe()
            probe.standardOutput = pipe
            probe.standardError = FileHandle.nullDevice
            if (try? probe.run()) != nil {
                probe.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let root = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let root, !root.isEmpty {
                    candidates.append("\(root)/tlpkg/texlive.tlpdb")
                }
            }
        }
        if let tlmgr = TeXEnvironment.locateExecutable("tlmgr") {
            let root = URL(fileURLWithPath: tlmgr)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            candidates.append(root.appendingPathComponent("tlpkg/texlive.tlpdb").path)
        }
        if let years = try? fm.contentsOfDirectory(atPath: home.appendingPathComponent("texlive").path) {
            for year in years.sorted(by: >) {
                candidates.append(home.appendingPathComponent("texlive/\(year)/tlpkg/texlive.tlpdb").path)
            }
        }
        for candidate in candidates where fm.isReadableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    /// Thread-safe optional-value dictionary for the per-instance query cache.
    private final class LockedDict: @unchecked Sendable {
        private var storage: [String: String?] = [:]
        private let lock = NSLock()
        func value(forKey key: String) -> String?? { lock.lock(); defer { lock.unlock() }; return storage[key] }
        func set(_ value: String?, forKey key: String) { lock.lock(); defer { lock.unlock() }; storage[key] = value }
    }

    /// Lazily-built, process-wide shared index. Thread-safe via NSLock.
    private final class SharedIndex: @unchecked Sendable {
        static let shared = SharedIndex()
        private let lock = NSLock()
        private var storage: [String: String]?
        func value() -> [String: String] {
            lock.lock(); defer { lock.unlock() }
            if let storage { return storage }
            let built = TeXLiveCatalog.buildIndex()
            storage = built
            return built
        }
    }
}
