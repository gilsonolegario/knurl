// UpdatesView.swift — Lists pending tlmgr updates (Davit DetailCard style).

import SwiftUI
import KnurlCore

/// Aba de atualizações: lista pacotes TeX Live com atualização pendente
/// (`tlmgr update --list`) e permite atualizar individualmente ou todos,
/// além de atualizar o próprio tlmgr / mirrors (`tlmgr update --self`).
struct UpdatesView: View {
    let environment: EnvironmentInfo
    @ObservedObject var coordinator: InstallCoordinator

    @State private var pending: [String] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var isUpdatingAll = false

    private var mirrorState: InstallState {
        coordinator.states[InstallCoordinator.selfUpdateKey] ?? .idle
    }

    private struct UpdateRow: Identifiable {
        let name: String
        var id: String { name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailCard(title: "Updates", icon: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 12) {
                        actionRow
                        mirrorStatus
                        content
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task { await refresh() }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await refresh() }
            } label: {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Check for updates", systemImage: "arrow.triangle.2.circlepath")
                        .hitAreaRect()
                }
            }
            .disabled(isLoading || !environment.tlmgr)
            .buttonStyle(.bordered)
            .hitAreaRect()

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
                        .hitAreaRect()
                }
            }
            .disabled(isUpdatingAll || !environment.tlmgr || pending.isEmpty)
            .appProminent()
            .hitAreaRect()

            Divider().frame(height: 22)
            mirrorButton
        }
    }

    private var mirrorButton: some View {
        Group {
            switch mirrorState {
            case .running(let phase):
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(phase).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            case .succeeded:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                    Text("mirrors updated").font(.caption).foregroundStyle(.green)
                    Button("Run again") { coordinator.updateMirrors() }
                        .buttonStyle(.bordered).controlSize(.mini).hitAreaRect()
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Text(message).font(.caption).foregroundStyle(.red).lineLimit(1)
                    Button("Retry") { coordinator.updateMirrors() }
                        .buttonStyle(.bordered).controlSize(.mini).hitAreaRect()
                }
            case .needsPrivilege(let command):
                HStack(spacing: 6) {
                    Label("Needs admin", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(Brand.orange)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc").appCapsule()
                    }
                    .buttonStyle(.plain)
                    .help("Copy command: \(command)")
                    Button("Retry") { coordinator.updateMirrors() }
                        .buttonStyle(.bordered).controlSize(.mini)
                }
            case .idle, .uninstalled:
                Button {
                    coordinator.updateMirrors()
                } label: {
                    Label("Update mirrors", systemImage: "network").hitAreaRect()
                }
                .buttonStyle(.bordered)
                .help("Runs tlmgr update --self to refresh the TeX Live infrastructure and mirror database")
                .hitAreaRect()
                .disabled(!environment.tlmgr)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: mirrorState)
    }

    @ViewBuilder
    private var mirrorStatus: some View {
        if case .needsPrivilege(let command) = mirrorState {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill").foregroundStyle(Brand.orange)
                Text("Administrator privileges required — run in Terminal:")
                    .font(.caption).foregroundStyle(.secondary)
                Text(command).font(.caption.monospaced()).textSelection(.enabled)
            }
            .padding(8)
            .background(Brand.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous))
        }
    }

    @ViewBuilder
    private var content: some View {
        if !environment.tlmgr {
            Label("tlmgr not found — updates require a TeX Live installation.",
                  systemImage: "exclamationmark.triangle")
                .font(.callout).foregroundStyle(.secondary)
        } else if isLoading && !hasLoaded {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking for updates…").font(.callout).foregroundStyle(.secondary)
            }
        } else if pending.isEmpty {
            Label("All packages are up to date.", systemImage: "checkmark.circle.fill")
                .font(.callout).foregroundStyle(Brand.green)
        } else {
            Table(pending.map(UpdateRow.init)) {
                TableColumn("Package") { Text($0.name) }
                TableColumn("Status") { _ in Text("update available").foregroundStyle(.secondary) }
                TableColumn("Action") { row in updateCell(for: row.name) }
            }
            .alternatingRowBackgrounds()
            .frame(height: min(320, max(80, CGFloat(pending.count) * 26 + 30)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func updateCell(for name: String) -> some View {
        switch coordinator.states["\(InstallCoordinator.updatePrefix)\(name)"] ?? .idle {
        case .idle:
            Button { coordinator.update(named: name) } label: {
                Label("Update", systemImage: "arrow.up.circle").hitAreaRect()
            }
            .buttonStyle(.bordered).controlSize(.small).hitAreaRect()
        case .running(let phase):
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(phase).font(.caption).foregroundStyle(.secondary)
            }
        case .succeeded:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                Text("updated").font(.caption).foregroundStyle(.green)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message).font(.caption).foregroundStyle(.red).lineLimit(1)
                Button("Retry") { coordinator.update(named: name) }
                    .buttonStyle(.bordered).controlSize(.small)
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
