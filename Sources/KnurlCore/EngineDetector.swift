// EngineDetector.swift — Determines which TeX engines a project requires based on its elements.

import Foundation

/// Pairs a TeX engine executable with the TeX Live package that provides it.
public struct EngineRequirement: Equatable, Sendable {
    public let executable: String
    public let package: String

    public init(executable: String, package: String) {
        self.executable = executable
        self.package = package
    }
}

/// Infers which TeX engines (pdflatex, xelatex, etc.) are needed by a project.
public enum EngineDetector {
    /// Returns engine requirements based on elements: any `\documentclass` needs pdflatex;
    /// font commands or `fontspec` need xelatex.
    public static func requirements(for elements: [TeXElement]) -> [EngineRequirement] {
        var result: [EngineRequirement] = []
        let hasDocumentClass = elements.contains { $0.kind == .documentClass }
        if hasDocumentClass {
            result.append(EngineRequirement(executable: "pdflatex", package: "pdftex"))
        }
        let needsXeLaTeX = elements.contains { element in
            element.kind == .font
                || ((element.kind == .usepackage || element.kind == .requirePackage)
                    && element.value.lowercased() == "fontspec")
        }
        if needsXeLaTeX {
            result.append(EngineRequirement(executable: "xelatex", package: "xetex"))
        }
        return result
    }
}
