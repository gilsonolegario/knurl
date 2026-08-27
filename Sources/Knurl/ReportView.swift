// ReportView.swift — Package report table with status filter, action row, install-all, compile-missing section, and context menus.
//
// Davit-inspired clean layout: DetailCard sections, secondary background, system colors.

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
    /// Called to confirm uninstall of a package.
    var onUninstallPackage: ((PackageInfo) -> Void)? = nil
    /// Called to update a single installed package.
    var onUpdatePackage: ((PackageInfo) -> Void)? = nil

    @State private var pendingUninstall: PackageInfo?
    @State private var searchText: String = ""

    /// Packages after search filtering (client-side, supplements `visiblePackages` status filtering).
    private var filteredPackages: [PackageInfo] {
        guard !searchText.isEmpty else { return visiblePackages }
        let q = searchText.lowercased()
        return visiblePackages.filter {
            $0.texlivePackage.lowercased().contains(q)
                || $0.element.value.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filtersCard
                completionSummary
                actionRow
                resultsCard
                if compileMissing != nil || compileMessage != nil {
                    compileCard
                }
            }
            .padding(4)
        }
    }

    // MARK: - Helpers for native indented children

    private var localNames: Set<String> {
        Set(packages.filter { $0.status == .native }.map { $0.texlivePackage.lowercased() + ".sty" })
    }

    private func isChild(_ pkg: PackageInfo) -> Bool {
        localNames.contains(pkg.element.file.lowercased())
    }

    private var topLevelPackages: [PackageInfo] {
        filteredPackages.filter { !isChild($0) }
    }

    private func children(of native: PackageInfo) -> [PackageInfo] {
        let key = native.texlivePackage.lowercased() + ".sty"
        return filteredPackages.filter { $0.element.file.lowercased() == key }
    }

    private var orphanChildren: [PackageInfo] {
        let presentKeys = Set(topLevelPackages.filter { $0.status == .native }.map { $0.texlivePackage.lowercased() + ".sty" })
        return filteredPackages.filter { isChild($0) && !presentKeys.contains($0.element.file.lowercased()) }
    }

    // MARK: - Filter Card

    /// Search + segmented status filter wrapped in a DetailCard.
    private var filtersCard: some View {
        DetailCard(title: "Filters", icon: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search packages", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.background.secondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.08), lineWidth: 1))

                statusFilter(packages)
            }
        }
    }

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
        .hitAreaRect()
    }

    // MARK: - Summary

    /// Summary line: "X of Y packages installed".
    private var completionSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.green)
            Text(CompletionSummary.text(
                packageCount: packages.count,
                missingCount: packages.filter { $0.status == .missing }.count))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Action Row

    /// "Detect missing" and "Install all" buttons with keyboard shortcuts.
    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                onDetect()
            } label: {
                if isCompiling {
                    ProgressView().controlSize(.small).frame(width: 80)
                } else {
                    Label {
                        HStack(spacing: 6) {
                            Text("Detect missing")
                            ShortcutHint(text: "⌘D")
                        }
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                    .hitAreaRect()
                }
            }
            .disabled(isCompiling)
            .buttonStyle(.bordered)
            .hitAreaRect()
            .keyboardShortcut("d")
            .quickHelp("Detect missing (⌘D)")

            Button {
                onInstallAll()
            } label: {
                if isInstallingAll {
                    ProgressView().controlSize(.small).tint(.white).frame(width: 80)
                } else {
                    Label {
                        HStack(spacing: 6) {
                            Text("Install all")
                            ShortcutHint(text: "⌘I", color: Color.white.opacity(0.65))
                        }
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    .foregroundStyle(.white)
                    .hitAreaRect()
                }
            }
            .disabled(isInstallingAll || installableMissingCount == 0)
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .hitAreaRect()
            .keyboardShortcut("i")
            .quickHelp("Install all (⌘I)")

            Spacer()
        }
    }

    // MARK: - Results Card (flat + native indented)

    /// Lista de pacotes: flat com `native` expansível mostrando seus deps indentados.
    private var resultsCard: some View {
        DetailCard(title: "Packages", icon: "tablecells") {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Element").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text("TeX Live Package").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Status").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 90)
                    Text("Action").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 110)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(topLevelPackages, id: \.id) { pkg in
                            packageRow(pkg, indented: false)
                            if pkg.status == .native {
                                let kids = children(of: pkg)
                                ForEach(kids, id: \.id) { child in
                                    packageRow(child, indented: true)
                                }
                            }
                            Divider().opacity(0.15)
                        }
                        ForEach(orphanChildren, id: \.id) { pkg in
                            packageRow(pkg, indented: true)
                            Divider().opacity(0.15)
                        }
                    }
                }
                .frame(height: tableHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.06), lineWidth: 1))
            }
            .confirmationDialog(
                "Uninstall \(pendingUninstall?.texlivePackage ?? "")?",
                isPresented: Binding(get: { pendingUninstall != nil }, set: { if !$0 { pendingUninstall = nil } }),
                presenting: pendingUninstall
            ) { package in
                Button("Uninstall \(package.texlivePackage)", role: .destructive) {
                    onUninstallPackage?(package)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("The package will be removed from your TeX installation. You can reinstall it later.")
            }
        }
    }

    @ViewBuilder
    private func packageRow(_ pkg: PackageInfo, indented: Bool) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if indented { Color.clear.frame(width: 16) }
                StatusDot(color: statusColor(pkg.status))
                Text(pkg.element.value).font(.callout).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(pkg.texlivePackage).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(pkg.status.displayName).font(.caption.weight(.medium)).foregroundStyle(statusColor(pkg.status))
                .frame(width: 90)
            ActionCells.actionCell(
                for: pkg,
                environment: environment,
                coordinatorStates: coordinator.states,
                onInstall: onInstallPackage,
                onCTAN: onCTANPackage,
                onCopyCommand: onCopyCommand
            )
            .frame(width: 110)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(indented ? Color.primary.opacity(0.02) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(indented ? Color.blue.opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .uninstallMenu(pkg, coordinator: coordinator, environment: environment, onUninstall: queueUninstall, onUpdate: onUpdatePackage)
    }

    private func statusColor(_ status: PackageStatus) -> Color {
        switch status {
        case .missing: return .orange
        case .installed: return .green
        case .native: return .blue
        case .unmapped: return .secondary
        case .unknown: return .secondary
        }
    }

    /// Enqueues a package for uninstall confirmation.
    private func queueUninstall(_ package: PackageInfo) {
        pendingUninstall = package
    }

    // MARK: - Compile Section

    /// Packages discovered by compilation (compile-detect flow) inside a DetailCard.
    @ViewBuilder
    private var compileCard: some View {
        DetailCard(title: "Missing detected by compilation", icon: "hammer") {
            VStack(alignment: .leading, spacing: 8) {
                if let message = compileMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let missing = compileMissing, !missing.isEmpty {
                    Table(missing) {
                        TableColumn("Element") { Text($0.element.value) }
                        TableColumn("TeX Live Package") { Text($0.texlivePackage) }
                        TableColumn("Status") { Text($0.status.displayName).foregroundStyle(.orange) }
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
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.06), lineWidth: 1))
                }
            }
        }
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
