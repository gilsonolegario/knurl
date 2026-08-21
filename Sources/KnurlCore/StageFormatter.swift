import Foundation

public enum StageFormatter {
    public static func label(for lastLogLine: String?) -> String {
        guard let line = lastLogLine else { return "Analyzing…" }
        if line.hasPrefix("CTAN:") { return "Consulting CTAN…" }
        if line.contains("Ambiente:") { return "Checking TeX environment…" }
        if line.contains("Erro") { return "Found a problem…" }
        return "Scanning project…"
    }
}
