// ReportView.swift — Package report table with status filter, action row, install-all, compile-missing section, and context menus.

import SwiftUI
import KnurlCore

/// Seção de relatório extraída de ContentView (Task 6 da UI rewrite):
/// filtro de status, resumo, ações, tabela principal, faltantes por compilação e exportação.
struct ReportView: View {
    let packages: [PackageInfo]
    let visiblePackages: [PackageInfo]
    let coordinator: InstallCoordinator
    let environment: EnvironmentInfo
    let compileMissing: [PackageInfo]?
    let compileMessage: String?
    let isCompiling: Bool
    let isInstallingAll: Bool
    let installableMissingCount: Int
    @Binding var selectedStatus: PackageStatus?
    @Binding var tableSelection: Set<PackageInfo.ID>
    let onDetect: () -> Void
    let onInstallAll: () -> Void
    let onInstallPackage: (PackageInfo, InstallStrategy) -> Void
    let onCTANPackage: (PackageInfo) -> Void
    let onCopyCommand: (String) -> Void
    var onUninstallPackage: ((PackageInfo) -> Void)? = nil
    var onUpdatePackage: ((PackageInfo) -> Void)? = nil

    @State private var pendingUninstall: PackageInfo?

    var body: some View {
        VStack(spacing: 12) {
            statusFilter(packages)
                .transition(.opacity)
            completionSummary
                .transition(.opacity)
            actionRow
                .transition(.opacity)
            mainTable
                .transition(.opacity)
            if let compileMissing {
                compileSection(compileMissing)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Sections

    /// Segmented status filter (All / Missing / Installed / Native / …).
    private func statusFilter(_ packages: [PackageInfo]) -> some View {
        let counts = Dictionary(grouping: packages, by: \.status).mapValues(\.count)
        let statuses: [(PackageStatus, String)] = [
            (.missing, "Missing"),
            (.installed, "Installed"),
            (.native, "Native"),
            (.unmapped, "Unmapped"),
            (.unknown, "Not verified"),
        ]
        return Picker("Status filter", selection: $selectedStatus) {
            Text("All (\(packages.count))").tag(PackageStatus?.none)
            ForEach(statuses, id: \.0) { status, label in
                Text("\(label) (\(counts[status, default: 0]))").tag(Optional(status))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// Summary line: "X of Y packages installed".
    private var completionSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Brand.green)
            Text(CompletionSummary.text(
                packageCount: packages.count,
                missingCount: packages.filter { $0.status == .missing }.count))
                .font(.callout)
                .foregroundStyle(Brand.textSecondary)
            Spacer()
        }
    }

    /// "Detect missing" and "Install all" buttons with keyboard shortcuts.
    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                onDetect()
            } label: {
                if isCompiling {
                    ProgressView().controlSize(.small)
                } else {
                    Label {
                        HStack(spacing: 6) {
                            Text("Detect missing")
                            ShortcutHint(text: "⌘D")
                        }
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                }
            }
            .disabled(isCompiling)
            .buttonStyle(.bordered)
            .keyboardShortcut("d")
            .help("Detect missing (⌘D)")
            Button {
                onInstallAll()
            } label: {
                if isInstallingAll {
                    ProgressView().controlSize(.small).tint(Brand.onAccent)
                } else {
                    Label {
                        HStack(spacing: 6) {
                            Text("Install all")
                            ShortcutHint(text: "⌘I", color: Brand.onAccent.opacity(0.55))
                        }
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    .foregroundStyle(Brand.onAccent)
                }
            }
            .disabled(isInstallingAll || installableMissingCount == 0)
            .appProminent()
            .keyboardShortcut("i")
            .help("Install all (⌘I)")
        }
    }

    /// Main table with Element, Package, Status, and Action columns.
    private var mainTable: some View {
        Table(visiblePackages, selection: $tableSelection) {
            TableColumn("Element") { Text($0.element.value).uninstallMenu($0, coordinator: coordinator, environment: environment, onUninstall: queueUninstall, onUpdate: onUpdatePackage) }
            TableColumn("TeX Live Package") { Text($0.texlivePackage).uninstallMenu($0, coordinator: coordinator, environment: environment, onUninstall: queueUninstall, onUpdate: onUpdatePackage) }
            TableColumn("Status") { Text($0.status.displayName).uninstallMenu($0, coordinator: coordinator, environment: environment, onUninstall: queueUninstall, onUpdate: onUpdatePackage) }
            TableColumn("Action") { package in
                ActionCells.actionCell(
                    for: package,
                    environment: environment,
                    coordinatorStates: coordinator.states,
                    onInstall: onInstallPackage,
                    onCTAN: onCTANPackage,
                    onCopyCommand: onCopyCommand
                )
                .uninstallMenu(package, coordinator: coordinator, environment: environment, onUninstall: queueUninstall, onUpdate: onUpdatePackage)
            }
        }
        .alternatingRowBackgrounds()
        .frame(height: tableHeight)
        .confirmationDialog(
            "Uninstall \(pendingUninstall?.texlivePackage ?? "")?",
            isPresented: Binding(get: { pendingUninstall != nil }, set: { if !$0 { pendingUninstall = nil } }),
            presenting: pendingUninstall
        ) { package in
            Button("Uninstall \(package.texlivePackage)", role: .destructive) {
                onUninstallPackage?(package)
            }
            Button("Cancel", role: .cancel) {}
        } message: { package in
            Text("The package will be removed from your TeX installation. You can reinstall it later.")
        }
    }

    /// Enqueues a package for uninstall confirmation.
    private func queueUninstall(_ package: PackageInfo) {
        pendingUninstall = package
    }

    /// Table of packages discovered by compilation (compile-detect flow).
    @ViewBuilder
    private func compileSection(_ missing: [PackageInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Missing detected by compilation")
                .font(.headline)
            if let message = compileMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if !missing.isEmpty {
                Table(missing) {
                    TableColumn("Element") { Text($0.element.value) }
                    TableColumn("TeX Live Package") { Text($0.texlivePackage) }
                    TableColumn("Status") { Text($0.status.displayName) }
                    TableColumn("Action") { package in
                        ActionCells.actionCell(
                            for: package,
                            environment: environment,
                            coordinatorStates: coordinator.states,
                            onInstall: onInstallPackage,
                            onCTAN: onCTANPackage,
                            onCopyCommand: onCopyCommand
                        )
                    }
                }
                .alternatingRowBackgrounds()
                .frame(height: 120)
            }
        }
        .padding(.top, 12)
    }

    private var tableHeight: CGFloat {
        Self.tableHeight(for: packages)
    }

    /// Altura da tabela principal — usada também pelo ContentView no cálculo do tamanho da janela.
    static func tableHeight(for packages: [PackageInfo]) -> CGFloat {
        let rows = min(packages.count, 30)
        return min(LayoutMetrics.tableMaxHeight,
                   max(LayoutMetrics.tableMinHeight, CGFloat(rows) * 26 + 30))
    }
}

/// Menu de contexto (botão direito) para pacotes instalados: atualizar e desinstalar.
@MainActor
extension View {
    @ViewBuilder
    func uninstallMenu(
        _ package: PackageInfo,
        coordinator: InstallCoordinator,
        environment: EnvironmentInfo,
        onUninstall: @escaping (PackageInfo) -> Void,
        onUpdate: ((PackageInfo) -> Void)? = nil
    ) -> some View {
        let state = coordinator.states[package.id]
        let isInstalled = package.status == .installed || state == .succeeded
        if isInstalled, state != .uninstalled {
            contextMenu {
                if environment.tlmgr, let onUpdate {
                    Button {
                        onUpdate(package)
                    } label: {
                        Label("Update \(package.texlivePackage)", systemImage: "arrow.up.circle")
                    }
                    Divider()
                }
                Button(role: .destructive) {
                    onUninstall(package)
                } label: {
                    Label("Uninstall \(package.texlivePackage)", systemImage: "trash")
                }
            }
        } else {
            self
        }
    }
}