import Foundation

/// Registro persistente das instalações de pacotes.
///
/// Grava linhas com timestamp em `~/Library/Logs/Knurl/install.log`,
/// criando o diretório se necessário. Injetável via `fileURL` para testes.
public struct InstallLogWriter {
    public let fileURL: URL
    private let formatter: ISO8601DateFormatter

    /// Local padrão do log de instalação (`~/Library/Logs/Knurl/install.log`).
    public static var defaultLogURL: URL {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Knurl", isDirectory: true)
        return dir.appendingPathComponent("install.log")
    }

    public init(fileURL: URL? = nil) {
        let target = fileURL ?? Self.defaultLogURL
        let dir = target.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = target
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        self.formatter = f
    }

    /// Anexa uma linha ao log com timestamp ISO 8601.
    public func record(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}
