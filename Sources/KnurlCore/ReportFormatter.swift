import Foundation

public enum ReportFormatter {
    public static func markdown(_ report: TeXReport) -> String {
        var md = "# Relatório de Pacotes TeX\n\n"
        md += "Fonte: \(report.source == "ctan" ? "CTAN (online)" : "heurística (offline)")\n\n"
        if let w = report.warning {
            md += "> \(w)\n\n"
        }
        md += "| Elemento | Pacote TeX Live | Status | Ação |\n"
        md += "|---|---|---|---|\n"
        for p in report.packages {
            let action = p.suggestedCommand ?? "—"
            md += "| \(escape(p.element.value)) | \(escape(p.texlivePackage)) | \(p.status.displayName) | \(escape(action)) |\n"
        }
        return md
    }

    public static func json(_ report: TeXReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|")
    }
}
