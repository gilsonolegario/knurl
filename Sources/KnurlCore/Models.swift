// Models.swift — Core data types shared across the analysis pipeline.

/// Classifies the kind of a TeX source element extracted by the analyzer.
public enum TeXElementKind: String, Codable, Sendable {
    case documentClass, usepackage, requirePackage, font, bibliography, minted, index, glossary, nestedFile, engine
}

/// A single element extracted from a TeX source file (e.g. `\usepackage{amsmath}`).
public struct TeXElement: Codable, Sendable, Equatable {
    public let kind: TeXElementKind
    /// The raw string value (package name, class name, font name, etc.).
    public let value: String
    /// Source filename where this element was found (relative name, not full path).
    public let file: String
    /// 1-based line number within the source file.
    public let line: Int

    public init(kind: TeXElementKind, value: String, file: String, line: Int) {
        self.kind = kind
        self.value = value
        self.file = file
        self.line = line
    }
}

/// All elements extracted from a single `.tex` or `.sty` file.
public struct TeXFile: Codable, Sendable, Equatable {
    public let path: String
    public var elements: [TeXElement]

    public init(path: String, elements: [TeXElement]) {
        self.path = path
        self.elements = elements
    }
}

/// The complete analysis result for a TeX project: all files and their local packages.
public struct TeXProject: Codable, Sendable, Equatable {
    public let rootPath: String
    public var files: [TeXFile]
    /// Package names provided by `.sty` files co-located in the project root.
    public var localPackages: Set<String>

    public init(rootPath: String, files: [TeXFile], localPackages: Set<String> = []) {
        self.rootPath = rootPath
        self.files = files
        self.localPackages = localPackages
    }

    /// Flattened list of every element across all files.
    public var elements: [TeXElement] { files.flatMap(\.elements) }
}

/// Installation/availability status of a TeX package on the current system.
public enum PackageStatus: String, Codable, Sendable {
    case installed
    case missing
    /// Package was mapped to a TeX Live name but could not be verified via kpsewhich.
    case unmapped
    /// kpsewhich is unavailable, so installation could not be checked.
    case unknown
    /// Provided by a local `.sty` file in the project — no TeX Live install needed.
    case native

    public var displayName: String {
        switch self {
        case .installed: return "installed"
        case .missing: return "missing"
        case .unmapped: return "unmapped"
        case .unknown: return "not verified"
        case .native: return "native"
        }
    }
}

/// Resolved information about one dependency: which TeX Live package provides it and its status.
public struct PackageInfo: Codable, Sendable, Equatable, Identifiable {
    public let element: TeXElement
    /// Name of the TeX Live package that provides this element (may differ from the CTAN name).
    public let texlivePackage: String
    public let status: PackageStatus
    /// Shell command the user should run to install this package, if applicable.
    public let suggestedCommand: String?

    public var id: String { "\(element.kind.rawValue)-\(element.value)-\(element.file)-\(element.line)" }

    public init(element: TeXElement, texlivePackage: String, status: PackageStatus, suggestedCommand: String?) {
        self.element = element
        self.texlivePackage = texlivePackage
        self.status = status
        self.suggestedCommand = suggestedCommand
    }
}

/// Boolean flags indicating which TeX tools/executables are available on the system.
public struct EnvironmentInfo: Codable, Sendable, Equatable {
    public let tlmgr: Bool, kpsewhich: Bool, tectonic: Bool, latexmk: Bool
    public let biber: Bool, makeindex: Bool, pdflatex: Bool, xelatex: Bool, lualatex: Bool

    public init(tlmgr: Bool, kpsewhich: Bool, tectonic: Bool, latexmk: Bool,
                biber: Bool, makeindex: Bool, pdflatex: Bool, xelatex: Bool, lualatex: Bool) {
        self.tlmgr = tlmgr
        self.kpsewhich = kpsewhich
        self.tectonic = tectonic
        self.latexmk = latexmk
        self.biber = biber
        self.makeindex = makeindex
        self.pdflatex = pdflatex
        self.xelatex = xelatex
        self.lualatex = lualatex
    }
}

/// The final output of a full project analysis: all packages, environment info, and metadata.
public struct TeXReport: Codable, Sendable, Equatable {
    public let packages: [PackageInfo]
    public let environment: EnvironmentInfo
    /// `"ctan"` if any package was resolved online, `"heuristic"` otherwise.
    public let source: String
    /// Non-nil when the analysis could not find meaningful `.tex` files.
    public let warning: String?

    public init(packages: [PackageInfo], environment: EnvironmentInfo, source: String, warning: String?) {
        self.packages = packages
        self.environment = environment
        self.source = source
        self.warning = warning
    }
}
