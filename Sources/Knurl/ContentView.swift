// ContentView.swift — Sidebar navigation and detail routing with NavigationSplitView (Davit-style shell).

import SwiftUI
import AppKit
import KnurlCore
import UniformTypeIdentifiers

// MARK: - Focused Values

/// Holds the current TeX report and a save callback, propagated via `FocusedValues`
/// so menu-bar commands can access them without direct child references.
struct ExportActions {
    let report: TeXReport?
    let save: (String, String) -> Void
}

extension FocusedValues {
    var exportActions: ExportActions? {
        get { self[ExportActionsKey.self] }
        set { self[ExportActionsKey.self] = newValue }
    }
}

private struct ExportActionsKey: FocusedValueKey {
    typealias Value = ExportActions
}

// MARK: - Sidebar Section

/// Sidebar navigation sections — Overview + Resources, mirrored from Davit's Shell.
enum SidebarSection: String, CaseIterable, Hashable {
    case dashboard
    case packages
    case log
    case updates

    /// Human-readable title shown in the sidebar and as the detail navigationTitle.
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .packages: return "Packages"
        case .log: return "Log"
        case .updates: return "Updates"
        }
    }

    /// SF Symbol for the sidebar row.
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.50percent"
        case .packages: return "shippingbox"
        case .log: return "doc.text"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Main Window

/// Primary window content: Davit-inspired NavigationSplitView shell
/// with a sidebar (Overview / Resources) and a detail area.
struct MainWindow: View {
    @Binding var openedURL: URL?
    @StateObject private var vm: ReportViewModel
    @StateObject private var coordinator: InstallCoordinator
    @State private var selection: SidebarSection? = .dashboard
    @State private var isGlobalTargeted = false
    @State private var isDropZoneTargeted = false
    @State private var selectedStatus: PackageStatus?
    @State private var tableSelection = Set<PackageInfo.ID>()
    @State private var cachedSystemInfo: EnvironmentInfo?

    init(openedURL: Binding<URL?>) {
        _openedURL = openedURL
        let vm = ReportViewModel()
        _vm = StateObject(wrappedValue: vm)
        _coordinator = StateObject(wrappedValue: InstallCoordinator(
            onLog: { vm.appendLog($0) },
            onVerified: { vm.markInstalled($0) }
        ))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .navigationTitle(selection?.title ?? SidebarSection.dashboard.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onOpenURL { url in
            withAnimation { selection = .packages }
            vm.analyze(at: url)
        }
        .knurlOnChange(of: openedURL) { url in
            if let url {
                withAnimation { selection = .packages }
                vm.analyze(at: url)
                openedURL = nil
            }
        }
        .task {
            // Cache system probe once (off main thread via detached) — avoids per-frame shell calls during drag.
            let info = await Task.detached(priority: .utility) { TeXEnvironment.makeDefault().info }.value
            cachedSystemInfo = info
            updateCachedCounts()
        }
        .onReceive(coordinator.$states) { states in
            // Após instalar o TeX Live, re-prova o ambiente para atualizar o rodapé.
            if case .succeeded = states[InstallCoordinator.bootstrapKey] {
                Task { @MainActor in
                    cachedSystemInfo = await Task.detached(priority: .utility) {
                        TeXEnvironment.makeDefault().info
                    }.value
                }
            }
        }
        .knurlOnChangeWithOld(of: vm.report) { old, new in
            if new != nil && old == nil {
                withAnimation { selection = .packages }
            }
        }
        .focusedSceneValue(\.exportActions, ExportActions(
            report: vm.report,
            save: { text, name in
                let panel = NSSavePanel()
                panel.nameFieldStringValue = name
                if panel.runModal() == .OK, let url = panel.url {
                    try? text.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        ))
        .onDrop(of: [.fileURL], isTargeted: $isGlobalTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task { @MainActor in
                        withAnimation { selection = .packages }
                        vm.analyze(at: url)
                    }
                }
            }
            return true
        }
        .knurlOnChange(of: vm.isLoading) { loading in
            if !loading { isGlobalTargeted = false; isDropZoneTargeted = false }
        }
        .knurlOnChange(of: vm.report) { _ in updateCachedCounts() }
        .knurlOnChange(of: vm.log.count) { _ in updateCachedCounts() }
        .knurlOnChange(of: vm.installOverrides) { _ in updateCachedCounts() }
        .overlay {
            if isGlobalTargeted {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill").font(.system(size: 28)).foregroundStyle(Brand.accent)
                    Text("Drop to analyze in Packages").font(.callout.weight(.medium))
                    Text("Your .tex project will open in the diagnostic view").font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.accent.opacity(0.5), lineWidth: 2))
                .shadow(radius: 12, y: 4)
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .knurlRefresh)) { _ in
            if let url = vm.lastAnalyzedURL {
                vm.analyze(at: url)
            } else if let report = vm.report {
                // Fallback: re-trigger analysis on current report directory if possible
                _ = report
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .knurlSearch)) { _ in
            // ⌘K — jump to Packages where the searchable table lives
            selection = .packages
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Overview") {
                    sidebarRow(.dashboard)
                }
                Section("Resources") {
                    sidebarRow(.packages, badge: cachedMissingCount > 0 ? cachedMissingCount : nil)
                    sidebarRow(.log, badge: cachedAttentionLogCount > 0 ? cachedAttentionLogCount : nil)
                    sidebarRow(.updates)
                }
            }
            .listStyle(.sidebar)

            Divider()
            systemFooter
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
    }

    /// Helper that builds a sidebar row with a Label, optional badge, and tag.
    private func sidebarRow(_ section: SidebarSection, badge: Int? = nil) -> some View {
        Label(section.title, systemImage: section.icon)
            .badge(badge.map { $0 > 0 ? Text("\($0)") : nil } ?? nil)
            .tag(section)
    }

    // MARK: - System Footer

    /// Footer showing TeX Live readiness, disk/log summary, and a refresh action.
    private var systemFooter: some View {
        let ready = isTeXReady
        return HStack(spacing: 8) {
            Circle()
                .fill(ready ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(ready ? "TeX Live ready" : "No TeX found")
                    .font(.caption)
                Text(ready ? "\(diskFreeText) free" : "\(vm.log.count) messages")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let url = vm.lastAnalyzedURL {
                    vm.analyze(at: url)
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .hitAreaRect()
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .quickHelp("Refresh")
            .hitAreaRect()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .dashboard {
        case .dashboard:
            StatusDashboard(vm: vm, coordinator: coordinator, onSwitchToPackages: {
                selection = .packages
            })
        case .packages:
            packagesView
        case .log:
            logView
        case .updates:
            updatesView
        }
    }

    // MARK: - Packages

    private var packagesView: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 12) {
                    if let error = vm.errorMessage {
                        errorBanner(error)
                    }

                    DropZone(isTargeted: $isDropZoneTargeted, prominent: vm.report == nil) { url in
                        withAnimation { selection = .packages }
                        vm.analyze(at: url)
                    }

                    if let report = vm.report {
                        let packages = vm.resolvedPackages
                        ReportView(
                            packages: packages,
                            visiblePackages: selectedStatus == nil
                                ? packages
                                : packages.filter { $0.status == selectedStatus },
                            coordinator: coordinator,
                            environment: report.environment,
                            compileMissing: vm.compileMissing,
                            compileMessage: vm.compileMessage,
                            isCompiling: vm.isCompiling,
                            isInstallingAll: vm.isInstallingAll,
                            installableMissingCount: packages.filter { $0.status == .missing }.count,
                            selectedStatus: $selectedStatus,
                            tableSelection: $tableSelection,
                            onDetect: { vm.detectMissingPackages() },
                            onInstallAll: { vm.installAllMissing() },
                            onInstallPackage: { pkg, strategy in
                                coordinator.install(package: pkg, strategy: strategy)
                            },
                            onCTANPackage: { pkg in
                                coordinator.install(package: pkg, strategy: .ctanToUserTree(package: pkg.id, kind: pkg.element.kind))
                            },
                            onCopyCommand: { cmd in
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(cmd, forType: .string)
                            },
                            onUninstallPackage: { pkg in
                                coordinator.uninstall(package: pkg)
                            },
                            onUpdatePackage: { pkg in
                                coordinator.update(named: pkg.id)
                            }
                        )
                    }
                }
                .padding(24)
            }
            LogTail(
                lines: vm.log,
                tailCount: vm.isLoading ? 200 : 1,
                isLive: vm.isLoading
            )
            .frame(maxHeight: vm.isLoading ? .infinity : 60)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Updates

    private var updatesView: some View {
        ScrollView {
            UpdatesView(
                environment: cachedOrReportEnvironment,
                coordinator: coordinator
            )
            .padding(24)
        }
    }

    // MARK: - Log

    private var logView: some View {
        LogView(
            lines: vm.log,
            isLive: vm.isLoading
        )
        .padding(24)
    }

    // MARK: - Helpers

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Brand.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Brand.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous))
    }

    // MARK: - Computed helpers

    private var isTeXReady: Bool {
        if let env = vm.report?.environment { return env.tlmgr || env.tectonic }
        if let cached = cachedSystemInfo { return cached.tlmgr || cached.tectonic }
        return false
    }

    private var cachedOrReportEnvironment: EnvironmentInfo {
        vm.report?.environment ?? cachedSystemInfo ?? EnvironmentInfo(
            tlmgr: false, kpsewhich: false, tectonic: false,
            latexmk: false, biber: false, makeindex: false,
            pdflatex: false, xelatex: false, lualatex: false
        )
    }

    @State private var cachedMissingCount = 0
    @State private var cachedAttentionLogCount = 0

    private func updateCachedCounts() {
        cachedMissingCount = vm.resolvedPackages.filter { $0.status == .missing }.count
        cachedAttentionLogCount = vm.log.filter { line in
            let lower = line.lowercased()
            return lower.hasPrefix("error:") || lower.contains("failed") || lower.contains("permission") || lower.contains("needs privilege") || lower.contains("not found") || lower.contains("warning")
        }.count
    }

    private var diskFreeText: String {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let bytes = values.volumeAvailableCapacity else { return "— GB" }
        return "\(bytes / 1_000_000_000) GB"
    }
}

// MARK: - ContentView (Compat Wrapper)

/// Legacy wrapper — delegates to `MainWindow` so existing previews/tests keep compiling.
struct ContentView: View {
    @Binding var openedURL: URL?

    var body: some View {
        MainWindow(openedURL: $openedURL)
    }
}
