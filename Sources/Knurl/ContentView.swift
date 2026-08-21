import SwiftUI
import KnurlCore

// MARK: - Focused Values

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

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = ReportViewModel()
    @StateObject private var coordinator: InstallCoordinator
    @State private var selectedTab: RailItem = .status
    @State private var isTargeted = false
    @State private var selectedStatus: PackageStatus?
    @State private var tableSelection = Set<PackageInfo.ID>()
    @Binding var openedURL: URL?

    init(openedURL: Binding<URL?>) {
        let vm = ReportViewModel()
        _vm = StateObject(wrappedValue: vm)
        _coordinator = StateObject(wrappedValue: InstallCoordinator(
            onLog: { vm.appendLog($0) },
            onVerified: { vm.markInstalled($0) }
        ))
        _openedURL = openedURL
    }

    var body: some View {
        ZStack {
            // Background layers
            backgroundLayers

            // Main content
            HStack(spacing: 0) {
                // Floating sidebar
                FloatingRail(selectedTab: $selectedTab)
                    .padding(.leading, 16)
                    .padding(.vertical, 16)

                // Content area
                contentArea
            }
        }
        .preferredColorScheme(nil)
        .onOpenURL { url in
            vm.analyze(at: url)
        }
        .onChange(of: openedURL) { _, url in
            if let url {
                vm.analyze(at: url)
                openedURL = nil
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
    }

    // MARK: - Background Layers

    private var backgroundLayers: some View {
        ZStack {
            VisualEffectBackground()

            // Warm veil
            LinearGradient(
                stops: [
                    .init(color: Brand.windowVeilTop, location: 0),
                    .init(color: Brand.windowVeilBottom, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Ambient glow
            RadialGradient(
                colors: [Brand.ambientGlow.opacity(0.07), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 560
            )

            // Grain
            GrainOverlay(opacity: 0.04)
        }
        .ignoresSafeArea()
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .status:
                StatusDashboard(vm: vm, onSwitchToPackages: {
                    withAnimation { selectedTab = .packages }
                })
            case .packages:
                packagesView
            case .log:
                logView
            case .updates:
                updatesView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.trailing, 24)
        .padding(.bottom, 28)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task { @MainActor in vm.analyze(at: url) }
                }
            }
            return true
        }
    }

    // MARK: - Package View

    private var packagesView: some View {
        VStack(spacing: 12) {
            if let error = vm.errorMessage {
                errorBanner(error)
            }

            DropZone(isTargeted: $isTargeted, prominent: vm.report == nil) { url in
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
                        // CTAN download - use install with CTAN strategy
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

            LogTail(
                lines: vm.log,
                tailCount: 5,
                isLive: vm.isLoading
            )
        }
        .padding(24)
    }

    // MARK: - Updates View

    private var updatesView: some View {
        UpdatesView(
            environment: vm.report?.environment ?? EnvironmentInfo(
                tlmgr: false, kpsewhich: false, tectonic: false,
                latexmk: false, biber: false, makeindex: false,
                pdflatex: false, xelatex: false, lualatex: false
            ),
            coordinator: coordinator
        )
        .padding(24)
    }

    // MARK: - Log View

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
}
