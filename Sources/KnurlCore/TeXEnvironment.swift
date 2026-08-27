// TeXEnvironment.swift — Probes the system for available TeX tools and queries kpsewhich for package status.

import Foundation

/// Checks which TeX tools are installed and queries kpsewhich for package availability.
public struct TeXEnvironment: Sendable {
    private let lookup: @Sendable (String) -> Bool
    private let kpsewhich: @Sendable (String, TeXElementKind) -> Bool

    public init(lookup: @escaping @Sendable (String) -> Bool,
                kpsewhich: @escaping @Sendable (String, TeXElementKind) -> Bool) {
        self.lookup = lookup
        self.kpsewhich = kpsewhich
    }

    /// Creates a default environment that uses real PATH lookups and kpsewhich execution.
    public static func makeDefault() -> TeXEnvironment {
        TeXEnvironment(
            lookup: { name in commandExists(name) },
            kpsewhich: { package, kind in
                guard let kpsewhich = locateExecutable("kpsewhich") else { return false }
                return runKpsewhich(kpsewhich, package, kind: kind)
            }
        )
    }

    /// Snapshot of which TeX tools are currently available on the system.
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

    /// Returns the installation status for a mapped element: installed, missing, or unknown.
    public func status(for element: TeXElement, mapped: Bool) -> PackageStatus {
        guard mapped else { return .unmapped }
        guard lookup("kpsewhich") else { return .unknown }
        return kpsewhich(element.value, element.kind) ? .installed : .missing
    }

    /// Returns the installation status for a TeX engine executable.
    public func engineStatus(for executable: String) -> PackageStatus {
        if lookup(executable) { return .installed }
        if lookup("kpsewhich") || lookup("tlmgr") { return .missing }
        return .unknown
    }

    /// Localiza um executável TeX no PATH, na árvore do usuário
    /// (`~/texlive/<ano>/bin/<arq>/`) ou no texbin padrão do macOS.
    /// Robustez para app GUI (PATH mínimo do Finder) e sandbox container.
    public static func locateExecutable(_ name: String) -> String? {
        if let onPath = shellPathLookup(name) { return onPath }
        // Fallback via shell login (captura PATH do usuário em zsh/bash)
        if let viaShell = shellWhich(name) { return viaShell }
        let fm = FileManager.default
        // Home real mesmo dentro de sandbox (FileManager.homeDirectoryForCurrentUser pode ser container)
        let homePath = ProcessInfo.processInfo.environment["HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let homeURL = URL(fileURLWithPath: homePath)
        // Fallbacks hard-coded para PATH típico do macOS + texlive
        let hardPaths = ["/Library/TeX/texbin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        for dir in hardPaths {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) || fm.fileExists(atPath: candidate) { return candidate }
        }
        let candidates: [URL] = [
            homeURL.appendingPathComponent("texlive"),                       // install-tl do usuário (~/texlive/<ano>)
            URL(fileURLWithPath: "/usr/local/texlive"),                    // instalação padrão macOS (/usr/local/texlive/<ano>)
        ]
        for root in candidates {
            if let years = try? fm.contentsOfDirectory(atPath: root.path) {
                for year in years.sorted(by: >) {
                    let bin = root.appendingPathComponent(year).appendingPathComponent("bin")
                    guard let archs = try? fm.contentsOfDirectory(atPath: bin.path) else { continue }
                    for arch in archs {
                        let candidate = bin.appendingPathComponent(arch).appendingPathComponent(name)
                        if fm.isExecutableFile(atPath: candidate.path) || fm.fileExists(atPath: candidate.path) { return candidate.path }
                    }
                }
            }
        }
        let texbin = URL(fileURLWithPath: "/Library/TeX/texbin").appendingPathComponent(name)
        if fm.isExecutableFile(atPath: texbin.path) || fm.fileExists(atPath: texbin.path) { return texbin.path }
        return nil
    }

    /// Searches PATH directories for the named executable.
    private static func shellPathLookup(_ name: String) -> String? {
        let rawPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        // PATH do Finder é mínimo (/usr/bin:/bin:/usr/sbin:/sbin) — suplementa com hard-coded.
        let extra = ":/Library/TeX/texbin:/opt/homebrew/bin:/usr/local/bin"
        let combined = rawPath.isEmpty ? String(extra.dropFirst()) : rawPath + extra
        let fm = FileManager.default
        for dir in combined.split(separator: ":") where !dir.isEmpty {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) || fm.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }

    private static func shellWhich(_ name: String) -> String? {
        // Tenta via shell login para capturar PATH do dotfiles; timeout curto, falha silenciosa.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-l", "-c", "which \(name) 2>/dev/null"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !out.isEmpty else { return nil }
            if FileManager.default.isExecutableFile(atPath: out) || FileManager.default.fileExists(atPath: out) { return out }
        } catch { }
        return nil
    }
}

private func commandExists(_ name: String) -> Bool {
    TeXEnvironment.locateExecutable(name) != nil
}

/// Runs kpsewhich to check whether a package file exists in the TeX tree.
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
