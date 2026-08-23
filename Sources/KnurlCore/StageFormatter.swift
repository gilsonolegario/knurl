// StageFormatter.swift — Maps the last analysis log line to a human-readable stage label.

import Foundation

/// Derives a short UI status label from the most recent analysis log line.
public enum StageFormatter {
    /// Returns a stage label like "Consulting CTAN…" or "Scanning project…".
    public static func label(for lastLogLine: String?) -> String {
        guard let line = lastLogLine else { return "Analyzing…" }
        if line.hasPrefix("CTAN:") { return "Consulting CTAN…" }
        if line.contains("Ambiente:") { return "Checking TeX environment…" }
        if line.contains("Erro") { return "Found a problem…" }
        return "Scanning project…"
    }
}
