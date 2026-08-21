import Foundation

/// Detecção de atualizações pendentes do TeX Live via `tlmgr update --list`.
public enum TeXUpdater {
    /// Extrai os nomes de pacotes com atualização pendente da saída de `tlmgr update --list`.
    ///
    /// Linhas relevantes têm o formato `update: <pkg> [...]` (também aceita
    /// `install:`/`reinstall:`); linhas `skip:` e ruído são ignoradas.
    public static func parseUpdateList(_ lines: [String]) -> [String] {
        let markers: Set<String> = ["update:", "install:", "reinstall:"]
        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2, markers.contains(String(parts[0])) else { continue }
            let name = String(parts[1])
            if seen.insert(name).inserted { result.append(name) }
        }
        return result
    }

    /// Lista pacotes com atualização pendente. Retorna vazio se o tlmgr falhar.
    public static func pendingUpdates(tlmgr: String) async -> [String] {
        let result = await ProcessRunner.run(tlmgr, ["update", "--list"])
        guard result.ok else { return [] }
        return parseUpdateList(result.log)
    }
}
