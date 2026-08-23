// ActionCells.swift — Stateless namespace that renders per-row action cells (install / CTAN / copy-command) for the package table.

import SwiftUI
import KnurlCore

/// Namespace para a renderização das células de ação da tabela de pacotes.
/// Extraído de ContentView (Task 5 da UI rewrite) — sem acoplamento ao view model:
/// recebe o dicionário de estados do coordinator e callbacks de ação.
enum ActionCells {

    // MARK: - Public API
    @MainActor
    @ViewBuilder
    static func actionCell(
        for package: PackageInfo,
        environment: EnvironmentInfo,
        coordinatorStates: [String: InstallState],
        onInstall: @escaping (PackageInfo, InstallStrategy) -> Void,
        onCTAN: @escaping (PackageInfo) -> Void,
        onCopyCommand: @escaping (String) -> Void
    ) -> some View {
        if package.status == .missing {
            let strategy = strategy(for: package, environment: environment)
            switch coordinatorStates[package.id] ?? .idle {
            case .idle:
                switch strategy {
                case .tlmgr, .ctanToUserTree:
                    installButton(package, strategy: strategy, onInstall: onInstall)
                case .tectonicHandled:
                    HStack(spacing: 6) {
                        Text("tectonic handles")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Brand.cardFill))
                            .foregroundStyle(Brand.textSecondary)
                        ctanButton(package, onCTAN: onCTAN)
                    }
                case .unavailable:
                    HStack(spacing: 6) {
                        Text(package.suggestedCommand ?? "—")
                            .font(.caption)
                            .foregroundStyle(Brand.textSecondary)
                        ctanButton(package, onCTAN: onCTAN)
                    }
                }
            case .running(let phase):
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(phase)
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
            case .succeeded:
                installedLabel
            case .failed(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Brand.red)
                        .lineLimit(1)
                    installButton(package, strategy: strategy, onInstall: onInstall)
                }
            case .needsPrivilege(let command):
                copyCommandButton(command, onCopy: onCopyCommand)
            case .uninstalled:
                removedLabel
            }
        } else if package.status == .installed {
            if coordinatorStates[package.id] == .uninstalled {
                removedLabel
            } else {
                installedLabel
            }
        } else if coordinatorStates[package.id] == .uninstalled {
            removedLabel
        } else {
            Text(package.suggestedCommand ?? "—")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Private helpers

    /// Resolves the install strategy for a package via InstallPlanner.
    private static func strategy(for package: PackageInfo, environment: EnvironmentInfo) -> InstallStrategy {
        InstallPlanner.plan(for: package.texlivePackage, kind: package.element.kind, environment: environment)
    }

    @MainActor
    private static func installButton(
        _ package: PackageInfo,
        strategy: InstallStrategy,
        onInstall: @escaping (PackageInfo, InstallStrategy) -> Void
    ) -> some View {
        Button { onInstall(package, strategy) } label: {
            Label("Install", systemImage: "arrow.down.circle.fill")
        }
        .appProminent()
        .controlSize(.small)
    }

    @MainActor
    private static func ctanButton(
        _ package: PackageInfo,
        onCTAN: @escaping (PackageInfo) -> Void
    ) -> some View {
        Button { onCTAN(package) } label: {
            Image(systemName: "arrow.down.circle")
                .appCapsule()
        }
        .buttonStyle(.plain)
        .help("Download from CTAN")
    }

    @MainActor
    static var installedLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Brand.green)
            Text("installed")
                .font(.caption)
                .foregroundStyle(Brand.green)
        }
    }

    @MainActor
    static var removedLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "trash.circle")
                .font(.caption)
                .foregroundStyle(Brand.textSecondary)
            Text("removed")
                .font(.caption)
                .foregroundStyle(Brand.textSecondary)
        }
    }

    @MainActor
    private static func copyCommandButton(
        _ command: String,
        onCopy: @escaping (String) -> Void
    ) -> some View {
        Button { onCopy(command) } label: {
            Image(systemName: "doc.on.doc")
                .appCapsule()
        }
        .buttonStyle(.plain)
        .help("Copy command")
    }
}