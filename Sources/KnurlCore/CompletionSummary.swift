// CompletionSummary.swift — Generates the one-line completion message shown after analysis.

import Foundation

/// Builds the human-readable summary string shown when analysis finishes.
public enum CompletionSummary {
    /// Returns a short status line with package and missing counts.
    public static func text(packageCount: Int, missingCount: Int) -> String {
        guard packageCount > 0 else {
            return "No packages detected — clean build, suspicious."
        }
        return "All mapped. \(packageCount) packages, \(missingCount) missing."
    }
}
