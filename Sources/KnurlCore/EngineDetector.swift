import Foundation

public struct EngineRequirement: Equatable, Sendable {
    public let executable: String
    public let package: String

    public init(executable: String, package: String) {
        self.executable = executable
        self.package = package
    }
}

public enum EngineDetector {
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
