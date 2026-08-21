import Foundation

public struct CompileMissing: Codable, Sendable, Equatable {
    public let fileName: String
    public let packageName: String
    public let kind: TeXElementKind

    public init(fileName: String, packageName: String, kind: TeXElementKind) {
        self.fileName = fileName
        self.packageName = packageName
        self.kind = kind
    }
}

public enum CompileDetectionError: Error, Sendable, Equatable {
    case noEngineInstalled
}

public struct CompileDetector: Sendable {
    public typealias Runner = @Sendable (String, [String], URL?) async -> ProcessRunner.Result
    public typealias EngineCheck = @Sendable (String) -> Bool

    private let runProcess: Runner
    private let engineCheck: EngineCheck
    private let catalog: TeXLiveCatalog

    public init(runProcess: Runner? = nil,
                engineCheck: @escaping EngineCheck = { TeXEnvironment.locateExecutable($0) != nil },
                catalog: TeXLiveCatalog = .makeDefault(),
                timeout: TimeInterval = 120) {
        self.runProcess = runProcess ?? { path, args, cwd in
            await ProcessRunner.run(path, args, timeout: timeout, currentDirectoryURL: cwd)
        }
        self.engineCheck = engineCheck
        self.catalog = catalog
    }

    public func detectMissingPackages(at projectDir: URL) async throws -> [CompileMissing] {
        guard let engine = installedEngine(for: projectDir) else { throw CompileDetectionError.noEngineInstalled }
        guard let main = Self.findMainTex(in: projectDir) else { return [] }

        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("texdiag-compile-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outDir) }

        let result = await runProcess(
            engine,
            ["-interaction=nonstopmode", "-output-directory", outDir.path, main.lastPathComponent],
            projectDir
        )
        return MissingFileParser.parse(log: result.output + "\n" + result.error)
            .map(mapFile)
            .sorted { $0.packageName.localizedCaseInsensitiveCompare($1.packageName) == .orderedAscending }
    }

    private func installedEngine(for projectDir: URL) -> String? {
        // Projetos com fontspec/fontes não compilam com pdflatex — preferir
        // xelatex/lualatex para evitar falsos "File not found" no log.
        let needsUnicode = usesUnicodeEngine(in: projectDir)
        let preference = needsUnicode
            ? ["xelatex", "lualatex", "pdflatex"]
            : ["pdflatex", "xelatex", "lualatex"]
        for name in preference where engineCheck(name) {
            return name
        }
        return nil
    }

    private func usesUnicodeEngine(in projectDir: URL) -> Bool {
        let files = (try? FileManager.default.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)) ?? []
        let fontPattern = #"\\(?:setmainfont|setmathfont|setsansfont|setmonofont)"#
        for file in files where file.pathExtension.lowercased() == "tex" {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            if text.contains("fontspec") || text.range(of: fontPattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private func mapFile(_ fileName: String) -> CompileMissing {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.lowercased()
        let kind: TeXElementKind = ext == "cls" ? .documentClass : .usepackage
        let element = TeXElement(kind: kind, value: base, file: "compile", line: 0)
        let package = catalog.owner(forFileNamed: fileName)
            ?? catalog.owner(for: base, kind: kind)
            ?? TeXLivePackageOverrides.texlivePackage(for: element)
            ?? base
        return CompileMissing(fileName: fileName, packageName: package, kind: kind)
    }

    static func findMainTex(in dir: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let texFiles = files
            .filter { $0.pathExtension.lowercased() == "tex" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        for file in texFiles {
            if let text = try? String(contentsOf: file, encoding: .utf8), text.contains(#"\documentclass"#) {
                return file
            }
        }
        return texFiles.first
    }
}

public enum MissingFileParser {
    private static let packageExtensions: Set<String> = ["sty", "cls", "bbx", "cbx", "bst"]

    public static func parse(log: String) -> [String] {
        let pattern = #"File [`']([^`']+?)['`] not found"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = log as NSString
        var seen = Set<String>()
        var result: [String] = []
        for match in regex.matches(in: log, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges > 1 else { continue }
            let file = ns.substring(with: match.range(at: 1))
            let name = (file as NSString).lastPathComponent
            guard packageExtensions.contains((name as NSString).pathExtension.lowercased()) else { continue }
            guard seen.insert(name.lowercased()).inserted else { continue }
            result.append(name)
        }
        return result
    }
}
