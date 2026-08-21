import Foundation

public struct TeXEnvironment: Sendable {
    private let lookup: @Sendable (String) -> Bool
    private let kpsewhich: @Sendable (String, TeXElementKind) -> Bool

    public init(lookup: @escaping @Sendable (String) -> Bool,
                kpsewhich: @escaping @Sendable (String, TeXElementKind) -> Bool) {
        self.lookup = lookup
        self.kpsewhich = kpsewhich
    }

    public static func makeDefault() -> TeXEnvironment {
        TeXEnvironment(
            lookup: { name in commandExists(name) },
            kpsewhich: { package, kind in
                guard let kpsewhich = locateExecutable("kpsewhich") else { return false }
                return runKpsewhich(kpsewhich, package, kind: kind)
            }
        )
    }

    public var info: EnvironmentInfo {
        EnvironmentInfo(
            tlmgr: lookup("tlmgr"),
            kpsewhich: lookup("kpsewhich"),
            tectonic: lookup("tectonic"),
            latexmk: lookup("latexmk"),
            biber: lookup("biber"),
            makeindex: lookup("makeindex"),
            pdflatex: lookup("pdflatex"),
            xelatex: lookup("xelatex"),
            lualatex: lookup("lualatex")
        )
    }

    public func status(for element: TeXElement, mapped: Bool) -> PackageStatus {
        guard mapped else { return .unmapped }
        guard lookup("kpsewhich") else { return .unknown }
        return kpsewhich(element.value, element.kind) ? .installed : .missing
    }

    public func engineStatus(for executable: String) -> PackageStatus {
        if lookup(executable) { return .installed }
        if lookup("kpsewhich") || lookup("tlmgr") { return .missing }
        return .unknown
    }

    /// Localiza um executável TeX no PATH, na árvore do usuário
    /// (`~/texlive/<ano>/bin/<arq>/`) ou no texbin padrão do macOS.
    public static func locateExecutable(_ name: String) -> String? {
        if let onPath = shellPathLookup(name) { return onPath }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("texlive"),                       // install-tl do usuário (~/texlive/<ano>)
            URL(fileURLWithPath: "/usr/local/texlive"),                    // instalação padrão macOS (/usr/local/texlive/<ano>)
        ]
        for root in candidates {
            if let years = try? fm.contentsOfDirectory(atPath: root.path) {
                for year in years.sorted(by: >) {
                    let bin = root.appendingPathComponent(year).appendingPathComponent("bin")
                    guard let archs = try? fm.contentsOfDirectory(atPath: bin.path) else { continue }
                    for arch in archs {
                        let candidate = bin.appendingPathComponent(arch).appendingPathComponent(name)
                        if fm.isExecutableFile(atPath: candidate.path) { return candidate.path }
                    }
                }
            }
        }
        let texbin = URL(fileURLWithPath: "/Library/TeX/texbin").appendingPathComponent(name)
        if fm.isExecutableFile(atPath: texbin.path) { return texbin.path }
        return nil
    }

    private static func shellPathLookup(_ name: String) -> String? {
        guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        let fm = FileManager.default
        for dir in path.split(separator: ":") where !dir.isEmpty {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}

private func commandExists(_ name: String) -> Bool {
    TeXEnvironment.locateExecutable(name) != nil
}

private func runKpsewhich(_ executable: String, _ package: String, kind: TeXElementKind) -> Bool {
    let suffix: String
    switch kind {
    case .documentClass: suffix = "cls"
    case .bibliography: suffix = "bib"
    default: suffix = "sty"
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = ["\(package).\(suffix)"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}
