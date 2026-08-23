// ReportBuilder.swift — Orchestrates the full analysis pipeline: scan → resolve → build TeXReport.

import Foundation

/// Top-level coordinator that scans a project, resolves all dependencies, and produces a `TeXReport`.
public struct ReportBuilder: Sendable {
    private let analyzer: TeXAnalyzer
    private let mapper: CTANMapping
    private let environment: TeXEnvironment
    private let catalog: TeXLiveCatalog

    public init(analyzer: TeXAnalyzer, mapper: CTANMapping, environment: TeXEnvironment,
                catalog: TeXLiveCatalog = .makeDefault()) {
        self.analyzer = analyzer
        self.mapper = mapper
        self.environment = environment
        self.catalog = catalog
    }

    /// Builds a complete report for the project at the given URL (file or directory).
    public func build(at url: URL) async throws -> TeXReport {
        let project = try analyzer.analyze(at: url)
        let local = project.localPackages
        let elements = project.elements

        func isLocal(_ element: TeXElement) -> Bool {
            switch element.kind {
            case .usepackage, .requirePackage:
                return local.contains(element.value)
            default:
                return false
            }
        }

        var resolution: [Int: Resolved] = [:]
        await resolveInParallel(elements: elements, isLocal: isLocal, into: &resolution)

        var packages: [PackageInfo] = []
        var usedCTAN = false
        var pygmentsNoted = false

        for (index, element) in elements.enumerated() {
            guard element.kind != .nestedFile, element.kind != .minted, element.kind != .bibliography else { continue }
            if isLocal(element) {
                packages.append(PackageInfo(
                    element: element,
                    texlivePackage: element.value,
                    status: .native,
                    suggestedCommand: nil
                ))
                continue
            }
            let (mapped, texName, source) = resolution[index] ?? (false, element.value, nil)
            if source == "ctan" { usedCTAN = true }
            let status = environment.status(for: element, mapped: mapped)
            let command = suggestedCommand(for: element, texName: texName, status: status)
            packages.append(PackageInfo(
                element: element,
                texlivePackage: texName ?? element.value,
                status: status,
                suggestedCommand: command
            ))
            if element.kind == .usepackage && element.value.lowercased() == "minted" && !pygmentsNoted {
                pygmentsNoted = true
                packages.append(PackageInfo(
                    element: TeXElement(kind: .minted, value: "pygments", file: element.file, line: element.line),
                    texlivePackage: "pygments",
                    status: .unmapped,
                    suggestedCommand: "python3 -m pip install pygments"
                ))
            }
        }
        let engineRows: [PackageInfo] = EngineDetector.requirements(for: elements).compactMap { requirement in
            // lualatex também suporta fontspec — não exigir xelatex quando ele cobre o requisito.
            if requirement.executable == "xelatex" && environment.info.lualatex { return nil }
            let status = environment.engineStatus(for: requirement.executable)
            let command = status == .missing && environment.info.tlmgr
                ? "sudo tlmgr install \(requirement.package)"
                : nil
            return PackageInfo(
                element: TeXElement(kind: .engine, value: requirement.executable, file: "", line: 0),
                texlivePackage: requirement.package,
                status: status,
                suggestedCommand: command
            )
        }
        if !engineRows.isEmpty {
            packages.insert(contentsOf: engineRows, at: 0)
        }
        let warning = elements.isEmpty
            ? "Nenhum arquivo .tex encontrado no caminho informado."
            : nil
        return TeXReport(
            packages: packages,
            environment: environment.info,
            source: usedCTAN ? "ctan" : "heuristic",
            warning: warning
        )
    }

    private typealias Resolved = (mapped: Bool, texName: String?, source: String?)

    /// Resolves non-local elements in parallel with a concurrency limit of 6.
    private func resolveInParallel(elements: [TeXElement], isLocal: (TeXElement) -> Bool,
                                   into resolution: inout [Int: Resolved]) async {
        let candidates = elements.indices.filter { index in
            let element = elements[index]
            guard element.kind != .nestedFile, element.kind != .minted, element.kind != .bibliography else { return false }
            return !isLocal(element)
        }
        guard !candidates.isEmpty else { return }
        await withTaskGroup(of: (Int, Resolved).self) { group in
            var iterator = candidates.makeIterator()
            var active = 0
            let limit = 6
            func addNext() {
                while active < limit, let index = iterator.next() {
                    active += 1
                    group.addTask {
                        (index, await self.resolve(elements[index]))
                    }
                }
            }
            addNext()
            for await (index, result) in group {
                resolution[index] = result
                active -= 1
                addNext()
            }
        }
    }

    /// Resolution cascade: local overrides → catalog → CTAN API → tlmgr file search.
    private func resolve(_ element: TeXElement) async -> Resolved {
        if let override = TeXLivePackageOverrides.texlivePackage(for: element) {
            return (true, override, "heuristic")
        }
        switch element.kind {
        case .minted, .nestedFile:
            return (false, nil, nil)
        default:
            if let owner = catalog.owner(for: element.value, kind: element.kind) {
                return (true, owner, "tlmgr")
            }
            let match = (try? await mapper.resolve(element.value)) ?? .unknown
            switch match {
            case .matched(let p): return (true, p, "ctan")
            case .unknown:
                // Último recurso: pergunta ao banco do TeX Live qual pacote
                // fornece o arquivo (autoritativo, cobre nomes CTAN ≠ tlmgr).
                if let owner = await TeXLiveFileSearch.owner(ofFile: element.value, kind: element.kind) {
                    return (true, owner, "tlmgr-search")
                }
                return (false, element.value, nil)
            }
        }
    }

    /// Generates a shell command to install a missing package, or nil if not applicable.
    private func suggestedCommand(for element: TeXElement, texName: String?, status: PackageStatus) -> String? {
        guard status == .missing, let texName else { return nil }
        if environment.info.tlmgr {
            return "sudo tlmgr install \(texName)"
        }
        if environment.info.tectonic {
            return "tectonic baixa automaticamente (nada a fazer)"
        }
        return "instale via tlmgr (TeX Live) ou use o Tectonic"
    }
}
