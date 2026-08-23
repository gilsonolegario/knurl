// UpdatesView.swift — Lists pending tlmgr updates and allows updating packages individually or all at once.

import SwiftUI
import KnurlCore

/// Aba de atualizações: lista pacotes TeX Live com atualização pendente
/// (`tlmgr update --list`) e permite atualizar individualmente ou todos.
struct UpdatesView: View {
    let environment: EnvironmentInfo
    let coordinator: InstallCoordinator

    @State private var pending: [String] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var isUpdatingAll = false

    private struct UpdateRow: Identifiable {
        let name: String
        var id: String { name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            actionRow
            content
        }
        .task { await refresh() }
    }

    // MARK: - Sections

    /// "Check for updates" and "Update all" buttons.
    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await refresh() }
            } label: {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Check for updates", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(isLoading || !environment.tlmgr)
            .buttonStyle(.bordered)

            Button {
                Task {
                    isUpdatingAll = true
                    await coordinator.updateAll(pending)
                    isUpdatingAll = false
                    await refresh()
                }
            } label: {
                if isUpdatingAll {
                    ProgressView().controlSize(.small).tint(Brand.onAccent)
                } else {
                    Label("Update all", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(Brand.onAccent)
                }
            }
            .disabled(isUpdatingAll || !environment.tlmgr || pending.isEmpty)
            .appProminent()
        }
    }

    /// Renders the table of pending updates or the current state message.
    @ViewBuilder
    private var content: some View {
        if !environment.tlmgr {
            Label("tlmgr not found — updates require a TeX Live installation.",
                  systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(Brand.textSecondary)
        } else if isLoading && !hasLoaded {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking for updates…")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
            }
        } else if pending.isEmpty {
            Label("All packages are up to date.", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Brand.green)
        } else {
            Table(pending.map(UpdateRow.init)) {
                TableColumn("Package") { Text($0.name) }
                TableColumn("Status") { _ in Text("update available").foregroundStyle(Brand.textSecondary) }
                TableColumn("Action") { row in updateCell(for: row.name) }
            }
            .alternatingRowBackgrounds()
            .frame(height: min(320, max(80, CGFloat(pending.count) * 26 + 30)))
        }
    }

    /// Per-package action cell: Update / running / updated / failed+retry / copy-command.
    @ViewBuilder
    private func updateCell(for name: String) -> some View {
        switch coordinator.states["\(InstallCoordinator.updatePrefix)\(name)"] ?? .idle {
        case .idle:
            Button { coordinator.update(named: name) } label: {
                Label("Update", systemImage: "arrow.up.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .running(let phase):
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(phase).font(.caption).foregroundStyle(.secondary)
            }
        case .succeeded:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("updated").font(.caption).foregroundStyle(.green)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message).font(.caption).foregroundStyle(.red).lineLimit(1)
                Button("Retry") { coordinator.update(named: name) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        case .needsPrivilege(let command):
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc").appCapsule()
            }
            .buttonStyle(.plain)
            .help("Copy command: \(command)")
        case .uninstalled:
            EmptyView()
        }
    }

    /// Queries tlmgr for pending updates and populates `pending`.
    private func refresh() async {
        guard let tlmgr = TeXEnvironment.locateExecutable("tlmgr") else { return }
        isLoading = true
        let found = await Task.detached(priority: .userInitiated) {
            await TeXUpdater.pendingUpdates(tlmgr: tlmgr)
        }.value
        pending = found
        hasLoaded = true
        isLoading = false
    }
}
