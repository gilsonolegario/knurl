import Foundation

public enum CompletionSummary {
    public static func text(packageCount: Int, missingCount: Int) -> String {
        guard packageCount > 0 else {
            return "No packages detected — clean build, suspicious."
        }
        return "All mapped. \(packageCount) packages, \(missingCount) missing."
    }
}
