import Foundation
import KnurlCore

/// Executes a shell script with administrator privileges by calling AppleScript
/// in-process via NSAppleScript. Shows the native macOS authorization dialog
/// (same dialog as System Preferences / Disk Utility).
///
/// No osascript subprocess — avoids all quoting/escaping issues.
enum NativeAdminRunner {

    /// ProcessRunner status used to signal the user cancelled the password dialog
    /// (AppleScript error -128, userCanceledErr).
    static let userCancelledStatus: Int32 = -128

    /// ProcessRunner status used to signal failed authentication (wrong password).
    static let authorizationFailedStatus: Int32 = -25293

    /// Single-quote escaping for bash: `'` becomes `'\''`. Immune to
    /// double-quotes, `$`, backticks and other metacharacters in arguments.
    private static func shellSingleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func run(_ command: String, arguments: [String], timeout: TimeInterval = 900) async -> ProcessRunner.Result {
        let scriptBody = "#!/bin/bash\nset -e\n"
            + ([command] + arguments).map(shellSingleQuoted).joined(separator: " ") + "\n"

        // Private directory with 0o700: prevents tampering between write and
        // execution as root (TOCTOU on world-writable /tmp).
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("texdiag-admin-\(UUID().uuidString)")
        let scriptURL = dir.appendingPathComponent("admin.sh")
        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try scriptBody.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        } catch {
            return ProcessRunner.Result(status: -1, output: "", error: "failed to create admin script: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: dir) }

        // Escape for AppleScript string: backslashes first, then double-quotes
        let escaped = scriptURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"bash \\\"\(escaped)\\\"\" with administrator privileges"

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: source)
                var errorInfo: NSDictionary?
                let result = appleScript?.executeAndReturnError(&errorInfo)
                let output = result?.stringValue ?? ""
                if let errorInfo {
                    let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
                    let message = errorInfo[NSAppleScript.errorMessage] as? String
                    if number == -128 {
                        continuation.resume(returning: ProcessRunner.Result(status: NativeAdminRunner.userCancelledStatus, output: "", error: "User canceled password prompt"))
                    } else if message?.lowercased().contains("authorization failed") == true {
                        continuation.resume(returning: ProcessRunner.Result(status: NativeAdminRunner.authorizationFailedStatus, output: "", error: message ?? "Authorization failed"))
                    } else if let message {
                        continuation.resume(returning: ProcessRunner.Result(status: -1, output: output, error: message))
                    } else {
                        continuation.resume(returning: ProcessRunner.Result(status: -1, output: output, error: "AppleScript execution failed"))
                    }
                } else {
                    continuation.resume(returning: ProcessRunner.Result(status: 0, output: output, error: ""))
                }
            }
        }
    }
}
