// StatusDashboard.swift — Overview dashboard showing distribution, engines, tools, disk, and package summary cards.
//
// Davit-inspired clean layout: DetailCard, CountRow, DiskRow, secondary background.

import SwiftUI
import KnurlCore

/// Status tab: overview of the detected TeX environment, available tools, and package counts.
struct StatusDashboard: View {
    @ObservedObject var vm: ReportViewModel
    /// Drives install/bootstrap workflows (used for the "Install BasicTeX" CTA).
    @ObservedObject var coordinator: InstallCoordinator
    /// Called when the user taps "View missing packages" from the dashboard.
    var onSwitchToPackages: (() -> Void)? = nil
    @State private var detectedEnvironment: EnvironmentInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                systemCard
                if !isManagerAvailable {
                    installTeXCard
                }
                HStack(alignment: .top, spacing: 16) {
                    countsCard
                    diskCard
                }
                toolsCard
                if vm.report != nil {
                    packagesSummaryCard
                    if vm.resolvedPackages.contains(where: { $0.status == .missing }) {
                        missingActionsCard
                    }
                } else {
                    EmptyState(
                        icon: "doc.text.magnifyingglass",
                        title: "No project loaded",
                        message: "Drop a .tex file or folder to analyze your TeX project."
                    )
                    .padding(.vertical, 20)
                    .knurlCardBackground(cornerRadius: 10)
                }
            }
            .padding(18)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task {
            detectedEnvironment = TeXEnvironment.makeDefault().info
        }
        .knurlOnChange(of: coordinator.states[InstallCoordinator.bootstrapKey]) { newState in
            // Após instalar o TeX Live, re-prova o ambiente para refletir a nova distribuição.
            if case .succeeded = newState {
                detectedEnvironment = TeXEnvironment.makeDefault().info
            }
        }
    }

    // MARK: - System / Package Manager Card

    /// Top hero card: circle 52pt + headline + version/binary + Refresh button.
    private var systemCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isManagerAvailable ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 52, height: 52)
                Image(systemName: distributionGlyph)
                    .font(.system(size: 26))
                    .foregroundStyle(distributionColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(systemHeadline)
                    .font(.headline)
                Text(distributionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let binary = tlmgrBinaryPath {
                    Text(binary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if env.tlmgr && env.tectonic {
                    Text("Tectonic available as fallback for automatic downloads.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                Task { detectedEnvironment = TeXEnvironment.makeDefault().info }
            } label: {
                Text("Refresh").frame(width: 72).hitAreaRect()
            }
            .buttonStyle(.bordered)
            .hitAreaRect()
        }
        .padding(16)
        .knurlCardBackground(cornerRadius: 12)
    }

    // MARK: - Install BasicTeX (no distribution present)

    /// CTA shown when no TeX distribution is detected: downloads/installs BasicTeX.
    private var installTeXCard: some View {
        DetailCard(title: "Get started", icon: "arrow.down.circle") {
            VStack(alignment: .leading, spacing: 10) {
                Text("No TeX distribution is installed. Install BasicTeX to get tlmgr, kpsewhich, and the basic engines — then reopen your project.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                bootstrapAction
            }
        }
    }

    /// Action area for the BasicTeX install: button, progress, success, or failure.
    @ViewBuilder
    private var bootstrapAction: some View {
        switch coordinator.states[InstallCoordinator.bootstrapKey] {
        case .running(let phase):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(phase).font(.callout).foregroundStyle(.secondary)
            }
        case .succeeded:
            Label("TeX Live installed", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .failed(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Brand.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        default:
            Button {
                coordinator.bootstrapTeXLive()
            } label: {
                Label("Install BasicTeX", systemImage: "arrow.down.circle.fill")
                    .hitAreaRect()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .hitAreaRect()
        }
    }

    // MARK: - Resource Counts

    private var countsCard: some View {
        DetailCard(title: "Resources", icon: "square.grid.2x2") {
            VStack(spacing: 10) {
                CountRow(icon: "shippingbox.fill", tint: .orange, label: "Packages",
                         value: vm.report == nil ? "—" : "\(totalCount) total")
                CountRow(icon: "exclamationmark.triangle.fill", tint: .red, label: "Missing",
                         value: "\(missingCount)")
                CountRow(icon: "checkmark.circle.fill", tint: .green, label: "Installed",
                         value: "\(installedCount)")
                CountRow(icon: "shippingbox", tint: .blue, label: "Native",
                         value: "\(nativeCount)")
            }
        }
    }

    // MARK: - Disk Usage

    private var diskCard: some View {
        DetailCard(title: "Disk Usage", icon: "internaldrive") {
            if let freeBytes = diskFreeBytes {
                DiskRow(label: "Available", value: freeBytes, tint: .blue, fraction: nil)
            } else {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tools Card

    private var toolsCard: some View {
        DetailCard(title: "Tools", icon: "wrench.and.screwdriver") {
            VStack(spacing: 10) {
                CountRow(icon: "hammer.fill", tint: env.tlmgr ? .green : .orange,
                         label: "tlmgr", value: env.tlmgr ? "ready · primary" : "not found")
                CountRow(icon: "magnifyingglass", tint: env.kpsewhich ? .green : .secondary,
                         label: "kpsewhich", value: env.kpsewhich ? "ready" : "not found")
                CountRow(icon: "books.vertical.fill", tint: env.biber ? .green : .secondary,
                         label: "biber", value: env.biber ? "ready" : "not found")
                CountRow(icon: "doc.text", tint: env.latexmk ? .green : .secondary,
                         label: "latexmk", value: env.latexmk ? "ready" : "not found")
                CountRow(icon: "character.book.closed.fill", tint: env.makeindex ? .green : .secondary,
                         label: "makeindex", value: env.makeindex ? "ready" : "not found")
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 8) {
                    engineRow(name: "pdfLaTeX", available: env.pdflatex)
                    engineRow(name: "XeLaTeX", available: env.xelatex)
                    engineRow(name: "LuaLaTeX", available: env.lualatex)
                }
            }
        }
    }

    /// Single engine row with status dot.
    private func engineRow(name: String, available: Bool) -> some View {
        HStack(spacing: 8) {
            StatusDot(color: available ? .green : .secondary)
            Text(name)
                .font(.system(size: 13, design: .monospaced))
            Spacer()
            Text(available ? "ready" : "not found")
                .font(.caption)
                .foregroundStyle(available ? Color.green : Color.secondary)
        }
    }

    // MARK: - Packages Summary

    private var packagesSummaryCard: some View {
        DetailCard(title: "Packages", icon: "shippingbox") {
            VStack(spacing: 10) {
                CountRow(icon: "xmark.circle.fill", tint: .orange, label: "Missing",
                         value: "\(missingCount)")
                CountRow(icon: "checkmark.circle.fill", tint: .green, label: "Installed",
                         value: "\(installedCount)")
                CountRow(icon: "shippingbox.fill", tint: .blue, label: "Native",
                         value: "\(nativeCount)")
                CountRow(icon: "questionmark.circle.fill", tint: .secondary, label: "Unmapped",
                         value: "\(unmappedCount)")
                CountRow(icon: "exclamationmark.circle.fill", tint: Brand.textTertiary, label: "Not verified",
                         value: "\(unknownCount)")
            }
        }
    }

    // MARK: - Missing Actions

    private var missingActionsCard: some View {
        DetailCard(title: "Missing Packages", icon: "exclamationmark.triangle.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("There are \(missingCount) package(s) not found in your TeX installation. Switch to the Packages tab to install them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    onSwitchToPackages?()
                } label: {
                    Label("View missing packages", systemImage: "arrow.right.circle")
                        .hitAreaRect()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .hitAreaRect()
            }
        }
    }

    // MARK: - Computed Properties

    private var env: EnvironmentInfo {
        // Cache: evita TeXEnvironment.makeDefault().info síncrono a cada frame
        // (shell `which` + fileExists) que causa beachball durante drag. O .task
        // preenche detectedEnvironment em background logo após aparecer.
        detectedEnvironment ?? vm.report?.environment ?? EnvironmentInfo(
            tlmgr: false, kpsewhich: false, tectonic: false,
            latexmk: false, biber: false, makeindex: false,
            pdflatex: false, xelatex: false, lualatex: false
        )
    }

    private var isManagerAvailable: Bool { env.tlmgr || env.tectonic }

    private var systemHeadline: String {
        if env.tlmgr { return "TeX Live ready" }
        if env.tectonic { return "Tectonic ready" }
        return "No TeX manager found"
    }

    private var distributionDescription: String {
        if env.tlmgr {
            return "TeX Live package manager. Install, update and remove packages with tlmgr."
        }
        if env.tectonic {
            return "Tectonic compiles on demand and downloads packages automatically."
        }
        return "No TeX package manager found. Install TeX Live or Tectonic to get started."
    }

    private var distributionGlyph: String {
        if env.tlmgr { return "checkmark.circle.fill" }
        if env.tectonic { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var distributionColor: Color {
        if env.tlmgr { return .green }
        if env.tectonic { return .blue }
        return .orange
    }

    private var tlmgrBinaryPath: String? {
        guard env.tlmgr, let path = TeXEnvironment.locateExecutable("tlmgr") else { return nil }
        return path
    }

    private var missingCount: Int { vm.resolvedPackages.filter { $0.status == .missing }.count }
    private var installedCount: Int { vm.resolvedPackages.filter { $0.status == .installed }.count }
    private var nativeCount: Int { vm.resolvedPackages.filter { $0.status == .native }.count }
    private var unmappedCount: Int { vm.resolvedPackages.filter { $0.status == .unmapped }.count }
    private var unknownCount: Int { vm.resolvedPackages.filter { $0.status == .unknown }.count }
    private var totalCount: Int { vm.resolvedPackages.count }

    private var diskFreeBytes: String? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let bytes = values.volumeAvailableCapacity else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - CountRow / DiskRow (Davit Dashboard style)

/// Icon + label + trailing value row, Davit `CountRow` style.
private struct CountRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label).font(.callout)
            Spacer()
            Text(value).font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// Label + value + optional bar indicator, Davit `DiskRow` style (adapted for free-space display).
private struct DiskRow: View {
    let label: String
    let value: String
    var tint: Color = .blue
    var fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(value)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.12))
                        Capsule().fill(tint.opacity(0.4))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 5)
            }
        }
    }
}
