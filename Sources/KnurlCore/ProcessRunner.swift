// ProcessRunner.swift — Async wrapper around Foundation.Process with timeout, stdin, and streaming capture.

import Foundation

/// Runs external processes asynchronously with timeout protection and full stream capture.
public enum ProcessRunner {
    /// The captured output of a completed process.
    public struct Result: Sendable, Equatable {
        public let status: Int32
        public let output: String
        public let error: String

        public init(status: Int32, output: String, error: String) {
            self.status = status
            self.output = output
            self.error = error
        }

        /// True when the process exited with status 0.
        public var ok: Bool { status == 0 }

        /// stdout and stderr merged and split into individual lines.
        public var log: [String] {
            (output + error).split(separator: "\n").map(String.init)
        }
    }

    private enum StreamKind { case stdout, stderr }

    private struct StreamData {
        let kind: StreamKind
        let data: Data
    }

    /// Boxed FileHandle to satisfy Sendable across task boundaries.
    private final class HandleBox: @unchecked Sendable {
        let handle: FileHandle
        init(_ handle: FileHandle) { self.handle = handle }
    }

    /// Runs an executable with arguments. stdin receives EOF unless `input` is provided.
    /// Process is killed (SIGTERM → SIGKILL) after `timeout` seconds.
    public static func run(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval = 300,
        currentDirectoryURL: URL? = nil,
        input: Data? = nil
    ) async -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectoryURL { process.currentDirectoryURL = currentDirectoryURL }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        // Sem stdin dedicado, usa nullDevice: prompts interativos recebem EOF
        // imediato e o processo aborta em vez de congelar para sempre.
        var stdinPipe: Pipe?
        if let input {
            let pipe = Pipe()
            stdinPipe = pipe
            process.standardInput = pipe
        } else {
            process.standardInput = FileHandle.nullDevice
        }

        do {
            try process.run()
        } catch {
            return Result(status: -1, output: "", error: error.localizedDescription)
        }
        if let stdinPipe, let data = input {
            // Escrita em task separada: se o processo não consome o input,
            // o write bloquearia; fechar o handle destrava com EPIPE.
            let handle = stdinPipe.fileHandleForWriting
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handle.write(contentsOf: data) } catch {}
                try? handle.close()
            }
        }

        let out = HandleBox(outPipe.fileHandleForReading)
        let err = HandleBox(errPipe.fileHandleForReading)

        // Guardião de timeout: Task separado, NÃO filho do grupo. `withTaskGroup`
        // espera TODOS os filhos — timeout dentro do grupo faria toda chamada
        // levar ≥ timeout segundos e deixaria um drain sem ser atendido.
        let timeoutGuard = Task {
            try? await Task.sleep(for: .seconds(timeout))
            guard process.isRunning else { return }
            process.terminate()
            // SIGTERM pode não matar filhos que herdaram os pipes de escrita;
            // fecha os FDs de leitura para forçar EOF e destravar o grupo.
            try? await Task.sleep(for: .seconds(1))
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            try? outPipe.fileHandleForReading.close()
            try? errPipe.fileHandleForReading.close()
        }

        let (outData, errData) = await withTaskGroup(of: StreamData.self) { group -> (Data, Data) in
            group.addTask {
                var data = Data()
                do {
                    for try await byte in out.handle.bytes { data.append(byte) }
                } catch {}
                return StreamData(kind: .stdout, data: data)
            }
            group.addTask {
                var data = Data()
                do {
                    for try await byte in err.handle.bytes { data.append(byte) }
                } catch {}
                return StreamData(kind: .stderr, data: data)
            }
            var stdout = Data()
            var stderr = Data()
            for await item in group {
                switch item.kind {
                case .stdout: stdout = item.data
                case .stderr: stderr = item.data
                }
            }
            return (stdout, stderr)
        }
        process.waitUntilExit()
        timeoutGuard.cancel()

        return Result(
            status: process.terminationStatus,
            output: String(decoding: outData, as: UTF8.self),
            error: String(decoding: errData, as: UTF8.self)
        )
    }
}
