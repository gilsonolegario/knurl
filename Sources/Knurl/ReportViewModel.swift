// ReportViewModel.swift — Observable state for the report: analysis, log, install overrides, compile detection, and batch install.

import Foundation
import Combine
import KnurlCore

/// Main view-model for the report workflow: drives analysis, log streaming,
/// package resolution, install overrides, and compile-based missing detection.
@MainActor
final class ReportViewModel: ObservableObject {
    @Published var report: TeXReport?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var log: [String] = []
    @Published var installOverrides: [String: PackageStatus] = [:]
    @Published var compileMissing: [PackageInfo]? = nil
    @Published var isCompiling = false
    @Published var compileMessage: String? = nil
    @Published var isInstallingAll = false
    var installHandler: (@Sendable ([(package: PackageInfo, strategy: InstallStrategy)]) async -> Void)?
    private(set) var lastAnalyzedURL: URL?

    private var generation = 0
    private var currentBuild: Task<TeXReport, Error>?
    private let builderFactory: @Sendable (@escaping @Sendable (String) -> Void) -> ReportBuilder
    private let detectorFactory: @Sendable () -> CompileDetector

    init(builderFactory: @escaping @Sendable (@escaping @Sendable (String) -> Void) -> ReportBuilder = { yield in
        ReportBuilder(analyzer: TeXAnalyzer(onProgress: yield),
                      mapper: CTANMapper(onResolve: yield),
                      environment: TeXEnvironment.makeDefault())
    },
    detectorFactory: @escaping @Sendable () -> CompileDetector = { CompileDetector() }) {
        self.builderFactory = builderFactory
        self.detectorFactory = detectorFactory
    }

    // MARK: - State

    /// Appends a line to the live log buffer.
    func appendLog(_ line: String) {
        log.append(line)
    }

    /// Marks a package as installed via a post-install override.
    func markInstalled(_ id: String) {
        installOverrides[id] = .installed
    }

    /// Marks a package as missing via an override.
    func markMissing(_ id: String) {
        installOverrides[id] = .missing
    }

    /// Pacotes do relatório com overrides de instalação aplicados — a tabela usa isto.
    var resolvedPackages: [PackageInfo] {
        guard let report else { return [] }
        return report.packages.map { pkg in
            if let override = installOverrides[pkg.id] {
                var updated = pkg
                updated = PackageInfo(element: pkg.element, texlivePackage: pkg.texlivePackage,
                                     status: override, suggestedCommand: pkg.suggestedCommand)
                return updated
            }
            return pkg
        }
    }

    // MARK: - Batch install

    var installableMissingCount: Int { installableMissing().count }

    /// Queues all missing packages for sequential installation via the coordinator.
    func installAllMissing() {
        guard !isInstallingAll, let handler = installHandler else { return }
        let rows = installableMissing()
        guard !rows.isEmpty else { return }
        log.append("Installing all missing packages…")
        Task {
            isInstallingAll = true
            await handler(rows)
            isInstallingAll = false
        }
    }

    private func installableMissing() -> [(package: PackageInfo, strategy: InstallStrategy)] {
        guard let environment = report?.environment else { return [] }
        var seen = Set<String>()
        var result: [(package: PackageInfo, strategy: InstallStrategy)] = []
        let candidates = (report?.packages ?? []) + (compileMissing ?? [])
        for package in candidates {
            let effective = installOverrides[package.id] ?? package.status
            guard effective == .missing else { continue }
            guard seen.insert(package.texlivePackage.lowercased()).inserted else { continue }
            let strategy = InstallPlanner.plan(for: package.texlivePackage, kind: package.element.kind, environment: environment)
            if case .unavailable = strategy { continue }
            let batchStrategy: InstallStrategy
            if case .tectonicHandled = strategy {
                batchStrategy = .ctanToUserTree(package: package.texlivePackage, kind: package.element.kind)
            } else {
                batchStrategy = strategy
            }
            result.append((package, batchStrategy))
        }
        return result
    }

    // MARK: - Analysis

    /// Builds a TeXReport from a .tex file/folder URL, streaming log output and cancelling any in-flight build.
    func analyze(at url: URL) {
        generation += 1
        let gen = generation
        currentBuild?.cancel()

        isLoading = true
        errorMessage = nil
        report = nil
        log = []
        compileMissing = nil
        isCompiling = false
        compileMessage = nil
        lastAnalyzedURL = url

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let builder = builderFactory { line in
            continuation.yield(line)
        }
        let logger = Task { @MainActor in
            for await line in stream {
                guard gen == generation else { return }
                log.append(line)
            }
        }
        let build = Task.detached(priority: .userInitiated) {
            try await builder.build(at: url)
        }
        currentBuild = build

        Task { @MainActor in
            let result: Result<TeXReport, Error>
            do {
                result = .success(try await build.value)
            } catch {
                result = .failure(error)
            }
            guard gen == generation else {
                continuation.finish()
                return
            }
            switch result {
            case .success(let built):
                log.append(envLine(built.environment))
                log.append("Report generated: \(built.packages.count) items")
                report = built
            case .failure(let error):
                log.append("Error: \(error.localizedDescription)")
                errorMessage = "Failed to analyze: \(error.localizedDescription)"
            }
            continuation.finish()
            await logger.value
            isLoading = false
        }
    }

    /// Compiles the project to discover packages missing at compile time (independent of the static analysis).
    func detectMissingPackages(at url: URL? = nil) {
        let targetURL = url ?? lastAnalyzedURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let gen = generation
        isCompiling = true
        compileMessage = nil
        compileMissing = nil
        log.append("Detecting missing packages by compilation…")
        let detector = detectorFactory()
        let environment = report?.environment
        Task {
            do {
                let missing = try await Task.detached(priority: .userInitiated) {
                    try await detector.detectMissingPackages(at: targetURL)
                }.value
                guard gen == generation else { return }
                let rows = missing.map { item -> PackageInfo in
                    let element = TeXElement(kind: item.kind, value: item.packageName, file: "compile", line: 0)
                    let strategy = environment.map { InstallPlanner.plan(for: item.packageName, kind: item.kind, environment: $0) }
                    let command: String? = {
                        if case .tlmgr(let pkg) = strategy { return "sudo tlmgr install \(pkg)" }
                        return nil
                    }()
                    return PackageInfo(element: element, texlivePackage: item.packageName, status: .missing, suggestedCommand: command)
                }
                compileMissing = rows
                if rows.isEmpty {
                    compileMessage = "No missing packages detected."
                } else {
                    log.append("Compilation found \(rows.count) missing package(s).")
                }
            } catch {
                guard gen == generation else { return }
                if let compileError = error as? CompileDetectionError, compileError == .noEngineInstalled {
                    compileMessage = "TeX Live not found — install a TeX distribution to detect missing packages."
                } else {
                    compileMessage = "Failed to detect missing: \(error.localizedDescription)"
                }
            }
            guard gen == generation else { return }
            isCompiling = false
        }
    }

    private func envLine(_ info: EnvironmentInfo) -> String {
        var parts: [String] = []
        if info.tlmgr { parts.append("tlmgr ✓") }
        if info.kpsewhich { parts.append("kpsewhich ✓") }
        if info.tectonic { parts.append("tectonic ✓") }
        if info.biber { parts.append("biber ✓") }
        if info.latexmk { parts.append("latexmk ✓") }
        if parts.isEmpty { parts.append("no TeX detected") }
        return "Environment: \(parts.joined(separator: ", "))"
    }
}
