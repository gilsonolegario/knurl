public enum TeXElementKind: String, Codable, Sendable {
    case documentClass, usepackage, requirePackage, font, bibliography, minted, index, glossary, nestedFile, engine
}

public struct TeXElement: Codable, Sendable, Equatable {
    public let kind: TeXElementKind
    public let value: String
    public let file: String
    public let line: Int

    public init(kind: TeXElementKind, value: String, file: String, line: Int) {
        self.kind = kind
        self.value = value
        self.file = file
        self.line = line
    }
}

public struct TeXFile: Codable, Sendable, Equatable {
    public let path: String
    public var elements: [TeXElement]

    public init(path: String, elements: [TeXElement]) {
        self.path = path
        self.elements = elements
    }
}

public struct TeXProject: Codable, Sendable, Equatable {
    public let rootPath: String
    public var files: [TeXFile]
    public var localPackages: Set<String>

    public init(rootPath: String, files: [TeXFile], localPackages: Set<String> = []) {
        self.rootPath = rootPath
        self.files = files
        self.localPackages = localPackages
    }

    public var elements: [TeXElement] { files.flatMap(\.elements) }
}

public enum PackageStatus: String, Codable, Sendable {
    case installed, missing, unmapped, unknown, native

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

public struct PackageInfo: Codable, Sendable, Equatable, Identifiable {
    public let element: TeXElement
    public let texlivePackage: String
    public let status: PackageStatus
    public let suggestedCommand: String?

    public var id: String { "\(element.kind.rawValue)-\(element.value)-\(element.file)-\(element.line)" }

    public init(element: TeXElement, texlivePackage: String, status: PackageStatus, suggestedCommand: String?) {
        self.element = element
        self.texlivePackage = texlivePackage
        self.status = status
        self.suggestedCommand = suggestedCommand
    }
}

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

public struct TeXReport: Codable, Sendable, Equatable {
    public let packages: [PackageInfo]
    public let environment: EnvironmentInfo
    public let source: String
    public let warning: String?

    public init(packages: [PackageInfo], environment: EnvironmentInfo, source: String, warning: String?) {
        self.packages = packages
        self.environment = environment
        self.source = source
        self.warning = warning
    }
}
