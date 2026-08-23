// TeXLiveFileSearch.swift — Last-resort package lookup via `tlmgr search --global --file`.

import Foundation

/// Último recurso de mapeamento: pergunta ao banco do TeX Live
/// (`tlmgr search --global --file`) qual pacote fornece um arquivo.
/// Autoritativo — cobre casos em que o nome CTAN difere do nome do
/// pacote tlmgr e o catálogo local está desatualizado.
public enum TeXLiveFileSearch {

    /// Returns the name of the TeX Live package that provides the given file, or nil.
    public static func owner(ofFile name: String, kind: TeXElementKind) async -> String? {
        guard let tlmgr = TeXEnvironment.locateExecutable("tlmgr") else { return nil }
        switch kind {
        case .font:
            // Fontes: uma única busca pelo nome base casa qualquer extensão.
            // Aceita `nome.otf`, variantes tipo `Nome-Regular.ttf` e arquivos
            // com nome interno curto dentro de diretório homônimo (`carlito/Crlt-*.tfm`).
            let base = name.lowercased()
            let result = await ProcessRunner.run(tlmgr, ["search", "--global", "--file", "/\(name)."])
            return parse(result.output, matchingAny: ["/\(base).", "/\(base)-", "/\(base)/"])
        default:
            let ext = Self.fileExtension(for: kind)
            let result = await ProcessRunner.run(tlmgr, ["search", "--global", "--file", "\(name)\(ext)"])
            return parse(result.output, matchingAny: ["/\(name.lowercased())\(ext)"])
        }
    }

    private static func fileExtension(for kind: TeXElementKind) -> String {
        switch kind {
        case .documentClass: return ".cls"
        case .bibliography: return ".bib"
        default: return ".sty"
        }
    }

    /// Parse da saída real de `tlmgr search --file`:
    ///
    ///     jknapltx:
    ///         texmf-dist/tex/latex/jknapltx/mathrsfs.sty
    ///
    /// Cabeçalhos de pacote não são indentados (`nome:` ou `nome - descrição`);
    /// linhas de arquivo são indentadas. Linhas `.tlpsrc` são metadados do
    /// pseudo-pacote 00texlive.image e são ignoradas.
    public static func parse(_ output: String, matchingAny suffixes: [String]) -> String? {
        var currentPackage: String?
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let isIndented = rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t")
            if isIndented {
                guard !line.contains(".tlpsrc") else { continue }
                let lowered = line.lowercased()
                if let currentPackage, suffixes.contains(where: { lowered.contains($0) }) {
                    return currentPackage
                }
            } else if let dash = line.range(of: " - ") {
                currentPackage = String(line[..<dash.lowerBound]).trimmingCharacters(in: .whitespaces)
            } else if line.hasSuffix(":") {
                currentPackage = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
            } else {
                currentPackage = line.split(separator: " ").first.map(String.init)
            }
        }
        return nil
    }

    /// Compatibilidade: caso único de sufixo.
    public static func parse(_ output: String, matching suffix: String) -> String? {
        parse(output, matchingAny: [suffix])
    }
}
