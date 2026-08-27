// TeXAnalyzer.swift — Scans TeX project files and extracts all dependency elements via regex parsing.

import Foundation

/// Scans a TeX project directory and extracts all dependency elements from source files.
public struct TeXAnalyzer: @unchecked Sendable {
    private var fm: FileManager { FileManager.default }
    /// Optional callback invoked with a progress message for each file scanned.
    private let onProgress: (@Sendable (String) -> Void)?

    public init(onProgress: (@Sendable (String) -> Void)? = nil) {
        self.onProgress = onProgress
    }

    /// Analyzes a project directory (or single `.tex` file) and returns all extracted elements.
    /// Respects `fileLimit` to cap the number of files scanned (default 500).
    public func analyze(at url: URL, fileLimit: Int = 500) throws -> TeXProject {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw TeXError.pathNotFound
        }
        let isDirectory = isDir.boolValue
        let root = isDirectory ? url : url.deletingLastPathComponent()
        var files: [TeXFile] = []
        var localStyNames = Set<String>()
        var visited = Set<String>()
        var count = 0

        func scan(_ fileURL: URL) throws {
            let key = fileURL.standardizedFileURL.path
            guard !visited.contains(key) else { return }
            visited.insert(key)
            guard count < fileLimit else { return }
            count += 1
            if fileURL.pathExtension == "sty" {
                localStyNames.insert(fileURL.deletingPathExtension().lastPathComponent)
            }
            onProgress?("Analisando: \(fileURL.lastPathComponent)")

            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return
            }
            var elements: [TeXElement] = []
            let lines = text.components(separatedBy: .newlines)

            var inVerbatim = false
            for (idx, rawLine) in lines.enumerated() {
                if rawLine.contains(#"\begin{verbatim}"#) {
                    inVerbatim = true
                    continue
                }
                if rawLine.contains(#"\end{verbatim}"#) {
                    inVerbatim = false
                    continue
                }
                guard !inVerbatim else { continue }
                let line = rawLine.strippingTeXComment()
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                parseLine(line, file: fileURL.lastPathComponent, lineNo: idx + 1, into: &elements)
            }
            files.append(TeXFile(path: fileURL.path, elements: elements))

            let includes = elements.filter { $0.kind == .nestedFile }
            for inc in includes {
                let target = resolve(inc.value, relativeTo: fileURL)
                if fm.fileExists(atPath: target.path) {
                    try scan(target)
                }
            }
        }

        // Helper: recursively collect .tex/.sty under root (Davit-style exhaustive scan).
        func collectRecursively(at dir: URL, exts: Set<String>) -> [URL] {
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
            var out: [URL] = []
            for case let fileURL as URL in enumerator {
                guard exts.contains(fileURL.pathExtension.lowercased()) else { continue }
                // Skip build artefacts
                if fileURL.path.contains("/.build/") || fileURL.path.contains("/build/") { continue }
                out.append(fileURL)
            }
            return out.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        if isDirectory {
            let texFiles = collectRecursively(at: root, exts: ["tex"])
            let styFiles = collectRecursively(at: root, exts: ["sty"])
            for f in texFiles { try scan(f) }
            for f in styFiles { try scan(f) }
        } else {
            try scan(url)
            // Single-file drop: also parse every local .sty under the same root (recursive),
            // so that dependencies inside local packages are discovered.
            let styFiles = collectRecursively(at: root, exts: ["sty"])
            for f in styFiles where f.standardizedFileURL.path != url.standardizedFileURL.path {
                try scan(f)
            }
        }

        return dedupe(TeXProject(rootPath: root.path, files: files, localPackages: localStyNames))
    }

    /// Removes duplicate elements across files, keeping the first occurrence.
    /// Normaliza `value` para lowercased e agrupa `usepackage`/`requirePackage` sob a
    /// mesma chave — evita \usepackage{foo} + \RequirePackage{foo} gerarem duas
    /// notificações — mas mantém `minted`/`bibliography`/`font` separados.
    private func dedupe(_ project: TeXProject) -> TeXProject {
        var seen = Set<String>()
        var files = project.files
        for i in files.indices {
            files[i].elements = files[i].elements.filter { el in
                let normalizedKind: String
                switch el.kind {
                case .usepackage, .requirePackage: normalizedKind = "package"
                default: normalizedKind = el.kind.rawValue
                }
                let key = "\(normalizedKind)\u{0}\(el.value.lowercased())"
                return seen.insert(key).inserted
            }
        }
        return TeXProject(rootPath: project.rootPath, files: files, localPackages: project.localPackages)
    }

    /// Applies regex patterns to a single line, extracting matched elements.
    private func parseLine(_ line: String, file: String, lineNo: Int, into elements: inout [TeXElement]) {
        add(.documentClass, pattern: #"\\documentclass\s*(?:\[[^\]]*\])?\s*\{([^}]+)\}"#)
        addMulti(.usepackage, pattern: #"\\usepackage\s*(?:\[[^\]]*\])?\s*\{([^}]+)\}"#)
        addMulti(.requirePackage, pattern: #"\\RequirePackage\s*(?:\[[^\]]*\])?\s*\{([^}]+)\}"#)
        addSingle(.font, pattern: #"\\(?:setmainfont|setmathfont|setsansfont|setmonofont)\s*\{([^}]+)\}"#)
        add(.bibliography, pattern: #"\\(?:bibliography|addbibresource)\s*\{([^}]+)\}"#)
        add(.minted, pattern: #"\\usepackage\s*(?:\[[^\]]*\])?\s*\{[^}]*minted[^}]*\}"#, mapTo: { _ in "minted" })
        add(.nestedFile, pattern: #"\\(?:input|include|subfile)\s*\{([^}]+)\}"#)

        func add(_ kind: TeXElementKind, pattern: String, mapTo: ((String) -> String)? = nil) {
            guard let m = firstMatch(pattern, in: line) else { return }
            let value = mapTo?(m) ?? m
            elements.append(TeXElement(kind: kind, value: value, file: file, line: lineNo))
        }

        func addMulti(_ kind: TeXElementKind, pattern: String) {
            for name in firstMatchList(pattern, in: line) {
                elements.append(TeXElement(kind: kind, value: name, file: file, line: lineNo))
            }
        }

        func addSingle(_ kind: TeXElementKind, pattern: String) {
            guard let m = firstMatch(pattern, in: line) else { return }
            elements.append(TeXElement(kind: kind, value: m, file: file, line: lineNo))
        }
    }

    private func firstMatch(_ pattern: String, in line: String) -> String? {
        guard let r = line.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(line[r])
        return firstCapture(pattern, in: matched) ?? matched
    }

    /// Returns all capture-group-1 values from all regex matches in the line.
    private func firstMatchList(_ pattern: String, in line: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        var result: [String] = []
        for match in regex.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges > 1 else { continue }
            let group = ns.substring(with: match.range(at: 1))
            result.append(contentsOf: group.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
        }
        return result
    }

    private func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    /// Resolves an `\input{foo}` value to an absolute `.tex` URL relative to the including file.
    private func resolve(_ value: String, relativeTo fileURL: URL) -> URL {
        let base = fileURL.deletingLastPathComponent()
        var path = value
        if path.hasSuffix(".tex") {
            path = String(path.dropLast(4))
        }
        return base.appendingPathComponent(path).appendingPathExtension("tex")
    }
}

public enum TeXError: Error {
    case pathNotFound
}

private extension String {
    /// Strips TeX comments (everything after unescaped `%`) from a line.
    func strippingTeXComment() -> String {
        // `%` é comentário a menos que precedido por um número ÍMPAR de backslashes
        // (`\%` = literal; `\\%` = quebra de linha + comentário; `\\\%` = literal).
        var escaped = false
        var result = ""
        for ch in self {
            if ch == "\\" {
                escaped.toggle()
                result.append(ch)
                continue
            }
            if ch == "%" && !escaped {
                return result
            }
            result.append(ch)
            escaped = false
        }
        return result
    }
}
