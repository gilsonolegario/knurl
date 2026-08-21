import Foundation
import Combine
import KnurlCore

enum InstallState: Equatable {
    case idle
    case running(phase: String)
    case succeeded
    case failed(message: String)
    case needsPrivilege(command: String)
    case uninstalled
}

@MainActor
final class InstallCoordinator: ObservableObject {
    static let bootstrapKey = "__bootstrap__"
    static let updatePrefix = "update:"
    @Published private(set) var states: [String: InstallState] = [:]
    private let installLog = InstallLogWriter()
    private let onLog: (String) -> Void
    private let onVerified: (String) -> Void
    private let onUninstalled: (String) -> Void
    private let onBootstrapFinished: () -> Void

    init(onLog: @escaping (String) -> Void,
         onVerified: @escaping (String) -> Void,
         onBootstrapFinished: @escaping () -> Void = {},
         onUninstalled: @escaping (String) -> Void = { _ in }) {
        self.onLog = onLog
        self.onVerified = onVerified
        self.onBootstrapFinished = onBootstrapFinished
        self.onUninstalled = onUninstalled
    }

    func bootstrapTeXLive() {
        guard TeXEnvironment.locateExecutable("tlmgr") == nil else {
            onLog("tlmgr is already available.")
            return
        }
        // Evita operação duplicada se já houver um bootstrap em andamento.
        if case .running = states[Self.bootstrapKey] { return }
        Task { await runBootstrap() }
    }

    func install(package: PackageInfo, strategy: InstallStrategy) {
        if case .running = states[package.id] { return }
        Task { await perform(package, strategy: strategy) }
    }

    func uninstall(package: PackageInfo) {
        if case .running = states[package.id] { return }
        Task { await performUninstall(package) }
    }

    func update(named name: String) {
        let key = "\(Self.updatePrefix)\(name)"
        if case .running = states[key] { return }
        Task { await performUpdate(name) }
    }

    func updateAll(_ names: [String]) async {
        guard !names.isEmpty else {
            onLog("No packages to update.")
            return
        }
        onLog("Updating \(names.count) package(s) sequentially…")
        for name in names {
            states["\(Self.updatePrefix)\(name)"] = .running(phase: "Queue…")
            await performUpdate(name)
        }
        onLog("Update batch completed (\(names.count) package(s)).")
    }

    private func performUpdate(_ name: String) async {
        let key = "\(Self.updatePrefix)\(name)"
        guard let tlmgr = TeXEnvironment.locateExecutable("tlmgr") else {
            states[key] = .failed(message: "tlmgr not found")
            return
        }
        states[key] = .running(phase: "Updating…")
        installLog.record("UPDATE START \(name)")
        onLog("Updating \(name)…")
        var output = await ProcessRunner.run(tlmgr, ["update", name])
        // Falha por permissão na árvore de sistema: tenta elevar privilégios
        // (diálogo de senha do macOS); se o usuário cancelar, oferece o comando sudo.
        if !output.ok, Self.looksLikePermission(output.log) {
            onLog("Permission needed — retrying with administrator privileges…")
            installLog.record("UPDATE PRIV \(name) — requesting admin")
            let admin = await Self.runAdmin(tlmgr, ["--backupdir", "/tmp", "update", name])
            for line in admin.log { onLog("  \(line)") }
            if admin.ok {
                onLog("✓ \(name) updated (with admin privileges)")
                installLog.record("UPDATE OK \(name)")
                states[key] = .succeeded
                return
            }
            if Self.userCancelledAdmin(admin) {
                let command = "sudo tlmgr update \(name)"
                onLog("Administrator password not provided — run in Terminal: \(command)")
                installLog.record("UPDATE CANCELLED \(name)")
                states[key] = .needsPrivilege(command: command)
                return
            }
            // Elevação autorizada mas comando falhou — não adianta o fallback --usermode.
            onLog("Error: update failed for \(name)")
            installLog.record("UPDATE FAIL \(name)")
            states[key] = .failed(message: admin.log.last ?? "admin update failed for \(name)")
            return
        }
        if !output.ok {
            output = await ProcessRunner.run(tlmgr, ["--usermode", "update", name])
        }
        for line in output.log { onLog("  \(line)") }
        if output.ok {
            onLog("✓ \(name) updated")
            installLog.record("UPDATE OK \(name)")
            states[key] = .succeeded
        } else if Self.looksLikePermission(output.log) {
            let command = "sudo tlmgr update \(name)"
            onLog("Permission needed — run in Terminal: \(command)")
            installLog.record("UPDATE PRIV \(name)")
            states[key] = .needsPrivilege(command: command)
        } else {
            onLog("Error: update failed for \(name)")
            installLog.record("UPDATE FAIL \(name)")
            states[key] = .failed(message: "update failed for \(name)")
        }
    }

    private func performUninstall(_ package: PackageInfo) async {
        let name = package.texlivePackage
        states[package.id] = .running(phase: "Uninstalling…")
        installLog.record("UNINSTALL START \(name)")
        onLog("Uninstalling \(name)…")

        var removed = false
        var permissionBlocked = false
        if let tlmgr = TeXEnvironment.locateExecutable("tlmgr") {
            let output = await ProcessRunner.run(tlmgr, ["remove", name])
            for line in output.log { onLog("  \(line)") }
            if output.ok {
                removed = true
            } else if Self.looksLikePermission(output.log) {
                // Árvore de sistema: elevar privilégios; se cancelar ou errar a
                // senha, oferecer sudo — NÃO apagar cópia do usuário e fingir sucesso.
                permissionBlocked = true
                onLog("Permission needed — retrying with administrator privileges…")
                installLog.record("UNINSTALL PRIV \(name) — requesting admin")
                let admin = await Self.runAdmin(tlmgr, ["remove", name])
                for line in admin.log { onLog("  \(line)") }
                if admin.ok {
                    removed = true
                    permissionBlocked = false
                } else if Self.userCancelledAdmin(admin) || Self.authorizationFailed(admin) {
                    let command = "sudo tlmgr remove \(name)"
                    let reason = Self.authorizationFailed(admin) ? "Administrator authorization failed" : "Administrator password not provided"
                    onLog("\(reason) — run in Terminal: \(command)")
                    installLog.record("UNINSTALL CANCELLED \(name)")
                    finish(package, .needsPrivilege(command: command))
                    return
                }
                // Admin autorizado mas comando falhou: permanece permissionBlocked.
            } else {
                // Pacote pode não ser gerenciado pelo tlmgr — tentar árvore do usuário.
                let usermode = await ProcessRunner.run(tlmgr, ["--usermode", "remove", name])
                for line in usermode.log { onLog("  \(line)") }
                removed = usermode.ok
            }
        }
        if !removed && !permissionBlocked {
            // Fallback: pacote instalado manualmente na árvore do usuário (fluxo CTAN).
            let texmf = (try? await Self.userTexmfPath()) ?? Self.defaultTexmfPath()
            let dir = texmf.appendingPathComponent("tex/latex/\(name)")
            if FileManager.default.fileExists(atPath: dir.path) {
                do {
                    try FileManager.default.removeItem(at: dir)
                    await Self.refreshFilenameDatabase(for: texmf)
                    removed = true
                } catch {
                    onLog("Error: \(error.localizedDescription)")
                }
            }
        }

        if removed {
            onLog("✓ \(name) removed")
            installLog.record("UNINSTALL OK \(name)")
            states[package.id] = .uninstalled
            onUninstalled(package.id)
        } else if permissionBlocked {
            let command = "sudo tlmgr remove \(name)"
            onLog("Error: could not uninstall \(name) — run in Terminal: \(command)")
            installLog.record("UNINSTALL FAIL \(name)")
            finish(package, .needsPrivilege(command: command))
        } else {
            onLog("Error: could not uninstall \(name)")
            installLog.record("UNINSTALL FAIL \(name)")
            states[package.id] = .failed(message: "could not uninstall \(name)")
        }
    }

    func installAll(_ items: [(package: PackageInfo, strategy: InstallStrategy)]) async {
        guard !items.isEmpty else {
            onLog("No packages to install.")
            return
        }
        onLog("Installing \(items.count) package(s) sequentially…")
        for (index, item) in items.enumerated() {
            states[item.package.id] = .running(phase: "Queue \(index + 1)/\(items.count)…")
            await perform(item.package, strategy: item.strategy)
        }
        onLog("Batch completed (\(items.count) package(s)).")
    }

    private func perform(_ package: PackageInfo, strategy: InstallStrategy) async {
        installLog.record("START \(package.texlivePackage) strategy=\(strategyName(strategy))")
        switch strategy {
        case .tlmgr(let pkg):
            await runTlmgr(package: package, name: pkg)
        case .tectonicHandled(let pkg):
            onLog("\(pkg): tectonic downloads automatically on compile.")
            finish(package, .succeeded)
        case .ctanToUserTree(let pkg, let kind):
            await runCTAN(package: package, name: pkg, kind: kind)
        case .unavailable:
            onLog("No manager available for \(package.texlivePackage).")
            finish(package, .failed(message: "no manager available"))
        }
    }

    /// Define o estado final de um pacote e registra o resultado no log persistente.
    private func finish(_ package: PackageInfo, _ state: InstallState) {
        states[package.id] = state
        switch state {
        case .succeeded:
            installLog.record("OK \(package.texlivePackage)")
        case .failed(let message):
            installLog.record("FAIL \(package.texlivePackage): \(message)")
        case .needsPrivilege:
            installLog.record("PRIV \(package.texlivePackage): requires sudo (command logged in UI)")
        case .idle, .running, .uninstalled:
            break
        }
    }

    private func strategyName(_ strategy: InstallStrategy) -> String {
        switch strategy {
        case .tlmgr: return "tlmgr"
        case .tectonicHandled: return "tectonic"
        case .ctanToUserTree: return "ctan"
        case .unavailable: return "none"
        }
    }

    private func runTlmgr(package: PackageInfo, name: String) async {
        guard let tlmgr = TeXEnvironment.locateExecutable("tlmgr") else {
            finish(package, .failed(message: "tlmgr not found"))
            return
        }
        let repo = ["-repository", "https://mirror.ctan.org/systems/texlive/tlnet"]
        states[package.id] = .running(phase: "Installing…")
        if Self.usesUserTeXTree() {
            onLog("tlmgr -repository mirror.ctan.org install \(name)")
            let user = await ProcessRunner.run(tlmgr, repo + ["install", name])
            for line in user.log { onLog("  \(line)") }
            if user.ok {
                await verify(package, name: name, base: nil)
            } else if Self.looksLikePermission(user.log) {
                let command = "sudo tlmgr -repository https://mirror.ctan.org/systems/texlive/tlnet install \(name)"
                onLog("Permission needed — run in Terminal: \(command)")
                finish(package, .needsPrivilege(command: command))
            } else {
                finish(package, .failed(message: "tlmgr failed: \(user.log.last ?? "unknown error")"))
            }
            return
        }
        onLog("Preparing user tree (tlmgr init-usertree)…")
        let initTree = await ProcessRunner.run(tlmgr, ["init-usertree"])
        for line in initTree.log where !initTree.ok { onLog("  \(line)") }
        onLog("tlmgr --usermode install \(name)")
        let output = await ProcessRunner.run(tlmgr, ["--usermode"] + repo + ["install", name])
        for line in output.log { onLog("  \(line)") }
        if output.ok {
            await verify(package, name: name, base: nil)
        } else {
            onLog("tlmgr --usermode failed; trying without usermode")
            let sys = await ProcessRunner.run(tlmgr, repo + ["install", name])
            for line in sys.log { onLog("  \(line)") }
            if sys.ok {
                await verify(package, name: name, base: nil)
            } else if Self.looksLikePermission(sys.log) {
                let command = "sudo tlmgr -repository https://mirror.ctan.org/systems/texlive/tlnet install \(name)"
                onLog("Permission needed — run in Terminal: \(command)")
                finish(package, .needsPrivilege(command: command))
            } else {
                finish(package, .failed(message: "tlmgr failed: \(sys.log.last ?? "unknown error")"))
            }
        }
    }

    private func runCTAN(package: PackageInfo, name: String, kind: TeXElementKind) async {
        states[package.id] = .running(phase: "Locating…")
        onLog("Locating \(name) on CTAN…")
        do {
            let path = try await CTANPackageLookup.resolve(name)
            guard let url = CTANDownloadURL.tarball(for: path) else {
                finish(package, .failed(message: "Invalid package name"))
                return
            }
            states[package.id] = .running(phase: "Downloading…")
            onLog("Downloading \(name) from CTAN…")
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.resourceUnavailable)
            }

            let install = await Task.detached(priority: .userInitiated) { () -> Result<CTANInstallResult, Error> in
                let fm = FileManager.default
                let tmp = fm.temporaryDirectory
                    .appendingPathComponent("texdiag-\(name)-\(UUID().uuidString)")
                // Cleanup garantido em qualquer saída (sucesso, erro ou cancelamento).
                defer { try? fm.removeItem(at: tmp) }
                do {
                    try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
                    let archive = tmp.appendingPathComponent("\(name).zip")
                    try data.write(to: archive)
                    let texmf = try await Self.userTexmfPath()
                    let target = texmf.appendingPathComponent("tex/latex/\(name)")
                    try fm.createDirectory(at: target, withIntermediateDirectories: true)
                    let extract = await ProcessRunner.run("/usr/bin/ditto", ["-xk", archive.path, target.path])
                    Self.flattenSingleChild(at: target)
                    await Self.refreshFilenameDatabase(for: texmf)
                    return .success(CTANInstallResult(target: target, log: extract.log))
                } catch {
                    return .failure(error)
                }
            }.value

            switch install {
            case .failure(let error):
                onLog("Error: \(error.localizedDescription)")
                finish(package, .failed(message: error.localizedDescription))
            case .success(let result):
                for line in result.log { onLog("  \(line)") }
                onLog("Installing to \(result.target.path)…")
                await verify(package, name: name, base: result.target)
            }
        } catch {
            onLog("Error: \(error.localizedDescription)")
            finish(package, .failed(message: error.localizedDescription))
        }
    }

    private func verify(_ package: PackageInfo, name: String, base: URL?) async {
        states[package.id] = .running(phase: "Verifying…")
        onLog("Verifying \(name)…")
        let kind = package.element.kind
        let verified = await Task.detached { () -> Bool in
            if kind == .engine {
                return TeXEnvironment.locateExecutable(name) != nil
            }
            if let kpsewhich = TeXEnvironment.locateExecutable("kpsewhich") {
                let elemName = package.element.value
                if let ext = Self.ext(for: kind) {
                    if await ProcessRunner.run(kpsewhich, ["\(elemName).\(ext)"]).ok { return true }
                } else if kind == .font {
                    for ext in Self.fontExtensions {
                        if await ProcessRunner.run(kpsewhich, ["\(elemName).\(ext)"]).ok { return true }
                    }
                }
            }
            if let base { return Self.hasArtifact(base) }
            let texmf = (try? await Self.userTexmfPath()) ?? Self.defaultTexmfPath()
            if kind == .font {
                // Fontes instalam como fonts/<formato>/<vendor>/<pacote> (ex.:
                // type1/google/carlito) e os arquivos podem ter nome interno
                // curto (Crlt-*.tfm) — procura o diretório/pacote por nível.
                var roots = [texmf]
                if let dist = await Self.systemTexmfDistRoot() { roots.append(dist) }
                for root in roots {
                    if Self.fontPackageExists(named: name, under: root.appendingPathComponent("fonts")) { return true }
                }
            }
            return Self.hasArtifact(texmf.appendingPathComponent("tex/latex/\(name)"))
        }.value
        if verified {
            onLog("✓ \(name) installed")
            finish(package, .succeeded)
            onVerified(package.id)
        } else {
            onLog("Error: \(name) not found after installation")
            finish(package, .failed(message: "verification failed for \(name)"))
        }
    }

    private nonisolated static let fontExtensions = ["otf", "ttf", "tfm"]

    private nonisolated static func ext(for kind: TeXElementKind) -> String? {
        switch kind {
        case .documentClass: return "cls"
        case .bibliography: return "bib"
        case .font: return nil
        default: return "sty"
        }
    }

    private nonisolated static func flattenSingleChild(at target: URL) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(atPath: target.path), children.count == 1 else { return }
        let only = target.appendingPathComponent(children[0])
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: only.path, isDirectory: &isDir), isDir.boolValue else { return }
        for item in (try? fm.contentsOfDirectory(atPath: only.path)) ?? [] {
            try? fm.moveItem(at: only.appendingPathComponent(item), to: target.appendingPathComponent(item))
        }
        try? fm.removeItem(at: only)
    }

    private nonisolated static func defaultTexmfPath() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/texmf")
    }

    private nonisolated static func usesUserTeXTree() -> Bool {
        guard let tlmgr = TeXEnvironment.locateExecutable("tlmgr") else { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return tlmgr.hasPrefix(home + "/") && tlmgr.contains("/texlive/")
    }

    private nonisolated static func hasArtifact(_ base: URL) -> Bool {
        let recognized: Set<String> = ["sty", "cls", "dtx", "ins", "bbx", "cbx", "bst", "bib"]
        guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return false }
        for case let url as URL in enumerator {
            if recognized.contains(url.pathExtension.lowercased()) { return true }
        }
        return false
    }

    /// Raiz da árvore de distribuição do sistema (texmf-dist), via kpsewhich.
    private nonisolated static func systemTexmfDistRoot() async -> URL? {
        guard let kpsewhich = TeXEnvironment.locateExecutable("kpsewhich") else { return nil }
        let probe = await ProcessRunner.run(kpsewhich, ["--var-value", "TEXMFDIST"])
        guard probe.ok, let raw = probe.log.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        let url = URL(fileURLWithPath: raw)
        return FileManager.default.isReadableFile(atPath: url.path) ? url : nil
    }

    /// Procura um pacote de fonte em `fonts/<formato>/<vendor>/<pacote>` e
    /// `fonts/<formato>/<pacote>` (até 3 níveis), casando nome de diretório
    /// ou de arquivo sem extensão — cobre nomes internos curtos (Crlt-*).
    private nonisolated static func fontPackageExists(named name: String, under fontsDir: URL) -> Bool {
        let fm = FileManager.default
        let target = name.lowercased()
        guard let formats = try? fm.contentsOfDirectory(atPath: fontsDir.path) else { return false }
        for format in formats {
            let formatURL = fontsDir.appendingPathComponent(format)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: formatURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let vendors = try? fm.contentsOfDirectory(atPath: formatURL.path) else { continue }
            for vendor in vendors {
                let vendorURL = formatURL.appendingPathComponent(vendor)
                if vendor.lowercased() == target { return true }
                guard fm.fileExists(atPath: vendorURL.path, isDirectory: &isDir), isDir.boolValue else {
                    // Arquivo solto: casa pelo nome sem extensão (ex.: carlito.sty).
                    if (vendor as NSString).deletingPathExtension.lowercased() == target { return true }
                    continue
                }
                guard let entries = try? fm.contentsOfDirectory(atPath: vendorURL.path) else { continue }
                for entry in entries where entry.lowercased() == target {
                    return true
                }
            }
        }
        return false
    }

    private nonisolated static func userTexmfPath() async throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var writableFallback: URL?
        if let kpsewhich = TeXEnvironment.locateExecutable("kpsewhich") {
            for variable in ["TEXMFLOCAL", "TEXMFHOME"] {
                let probe = await ProcessRunner.run(kpsewhich, ["--var-value", variable])
                if probe.ok, let raw = probe.log.first?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                    let url = URL(fileURLWithPath: raw)
                    if url.path.hasPrefix(home.path) { return url }
                    if writableFallback == nil, FileManager.default.isWritableFile(atPath: url.path) {
                        writableFallback = url
                    }
                }
            }
        }
        if let writableFallback { return writableFallback }
        return home.appendingPathComponent("Library/texmf")
    }

    private nonisolated static func refreshFilenameDatabase(for texmf: URL) async {
        guard let mktexlsr = TeXEnvironment.locateExecutable("mktexlsr") else { return }
        _ = await ProcessRunner.run(mktexlsr, [texmf.path])
    }

    private nonisolated static func looksLikePermission(_ lines: [String]) -> Bool {
        // Padrões específicos de erro de permissão do tlmgr/POSIX — evita
        // falsos positivos com palavras soltas ("sudoers", "permissioned").
        let patterns = [
            "permission denied",
            "operation not permitted",
            "not permitted",
            "you don't have permission",
            "insufficient permissions",
            "please run as administrator",
            "run this as root",
            "cannot write to",
            "can't write to",
            "read-only file system",
        ]
        let joined = lines.joined(separator: "\n").lowercased()
        return patterns.contains { joined.contains($0) }
    }

    /// Executa um comando elevando privilégios via diálogo nativo do macOS
    /// (Security framework — mesmo estilo System Preferences).
    ///
    /// O `cd /tmp` inicial é obrigatório: no ambiente de root, o diretório
    /// herdado faz `Cwd::getcwd` retornar undef dentro do tlmgr.
    private nonisolated static func runAdmin(_ executable: String, _ arguments: [String]) async -> ProcessRunner.Result {
        await NativeAdminRunner.run(executable, arguments: arguments)
    }

    private nonisolated static func userCancelledAdmin(_ result: ProcessRunner.Result) -> Bool {
        // Cancelamento é sinalizado pelo NativeAdminRunner com status -128
        // (userCanceledErr do AppleScript) — não por heurística de log.
        result.status == NativeAdminRunner.userCancelledStatus
    }

    private nonisolated static func authorizationFailed(_ result: ProcessRunner.Result) -> Bool {
        // Senha errada (3 tentativas) — status dedicado do NativeAdminRunner.
        result.status == NativeAdminRunner.authorizationFailedStatus
    }

    private func runBootstrap() async {
        states[Self.bootstrapKey] = .running(phase: "Preparing…")
        installLog.record("START TeX Live bootstrap (install-tl basic scheme)")
        onLog("Downloading TeX Live installer (minimum: tlmgr + kpsewhich + basic engines)…")
        let script = """
        set -e
        TMPDIR=$(mktemp -d)
        trap 'rm -rf "$TMPDIR"' EXIT
        cd "$TMPDIR"
        curl -fsSL "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz" -o install-tl-unx.tar.gz
        tar -xzf install-tl-unx.tar.gz
        perl install-tl-*/install-tl -scheme basic -no-interaction -repository https://mirror.ctan.org/systems/texlive/tlnet
        TLDIR=$(ls -d /usr/local/texlive/20* 2>/dev/null | sort -V | tail -1)
        mkdir -p /Library/TeX/texbin
        ln -sf "$TLDIR"/bin/*darwin/* /Library/TeX/texbin/ 2>/dev/null || true
        mkdir -p /etc/paths.d
        echo "/Library/TeX/texbin" > /etc/paths.d/TeX
        """
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("texdiag-bootstrap-\(UUID().uuidString).sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            // 0o700: só o dono executa — evita tampering antes da elevação a root.
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        } catch {
            states[Self.bootstrapKey] = .failed(message: "could not prepare bootstrap")
            return
        }
        defer { try? FileManager.default.removeItem(at: scriptURL) }
        let osa = await NativeAdminRunner.run("/bin/bash", arguments: [scriptURL.path])
        for line in osa.log { onLog("  \(line)") }
        if osa.ok, TeXEnvironment.locateExecutable("tlmgr") != nil {
            onLog("✓ tlmgr installed at \(TeXEnvironment.locateExecutable("tlmgr") ?? "?")")
            installLog.record("OK TeX Live bootstrap")
            states[Self.bootstrapKey] = .succeeded
            onBootstrapFinished()
        } else {
            onLog("Error: TeX Live installation not completed.")
            installLog.record("FAIL TeX Live bootstrap: installation failed or password not provided")
            states[Self.bootstrapKey] = .failed(message: "TeX Live installation failed or password not provided")
        }
    }
}

private struct CTANInstallResult {
    let target: URL
    let log: [String]
}
