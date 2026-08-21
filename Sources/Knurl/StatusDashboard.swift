import SwiftUI
import KnurlCore

struct StatusDashboard: View {
    @ObservedObject var vm: ReportViewModel
    var onSwitchToPackages: (() -> Void)? = nil
    @State private var detectedEnvironment: EnvironmentInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Status")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Brand.textPrimary)

                distributionCard
                HStack(spacing: 16) {
                    enginesCard
                    diskCard
                }
                toolsCard

                if let report = vm.report {
                    packagesSummaryCard
                    if vm.resolvedPackages.filter({ $0.status == .missing }).count > 0 {
                        missingActionsCard
                    }
                }
            }
            .padding(24)
        }
        .task {
            detectedEnvironment = TeXEnvironment.makeDefault().info
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Brand.textSecondary)
                Text("No project loaded")
                    .font(.headline)
                    .foregroundStyle(Brand.textPrimary)
                Text("Drop a .tex file or folder to analyze your TeX project.")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Distribution Card

    private var distributionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "PACKAGE MANAGER", color: distributionColor, glyph: distributionGlyph)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(distributionValue)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)
                    if let chip = distributionChip {
                        Chip(text: chip, color: distributionColor)
                    }
                }

                Text(distributionDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if env.tlmgr && env.tectonic {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text("Tectonic is available as fallback for automatic downloads.")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Brand.textTertiary)
                }
            }
        }
    }

    // MARK: - Engines Card

    private var enginesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "ENGINES", color: Brand.accent, glyph: "cpu")

                VStack(alignment: .leading, spacing: 8) {
                    engineRow(name: "pdfLaTeX", available: env.pdflatex)
                    engineRow(name: "XeLaTeX", available: env.xelatex)
                    engineRow(name: "LuaLaTeX", available: env.lualatex)
                }
            }
        }
    }

    private func engineRow(name: String, available: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(available ? Brand.green : Brand.orange)
            Text(name)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Brand.textPrimary)
            Spacer()
            Text(available ? "ready" : "not found")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(available ? Brand.green : Brand.orange)
        }
    }

    // MARK: - Tools Card

    private var toolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "TOOLS", color: Brand.blue, glyph: "wrench.and.screwdriver")

                VStack(spacing: 8) {
                    // Primary tool — full width
                    toolRow(name: "tlmgr", available: env.tlmgr, primary: true)

                    // Secondary tools in grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        toolPill(name: "kpsewhich", available: env.kpsewhich)
                        toolPill(name: "biber", available: env.biber)
                        toolPill(name: "latexmk", available: env.latexmk)
                        toolPill(name: "makeindex", available: env.makeindex)
                    }
                }
            }
        }
    }

    private func toolRow(name: String, available: Bool, primary: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: primary ? 14 : 12))
                .foregroundStyle(available ? Brand.green : Brand.orange)
            Text(name)
                .font(.system(size: primary ? 15 : 13, weight: primary ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(Brand.textPrimary)
            Spacer()
            if primary && available {
                Chip(text: "primary", color: Brand.green)
            } else if primary && !available {
                Chip(text: "missing", color: Brand.orange)
            } else {
                Text(available ? "ready" : "not found")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(available ? Brand.green : Brand.orange)
            }
        }
    }

    private func toolPill(name: String, available: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(available ? Brand.green : Brand.orange)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Brand.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(available ? Brand.green.opacity(0.08) : Brand.orange.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Packages Summary

    private var packagesSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "PACKAGES", color: Brand.accent, glyph: "shippingbox")
                    Spacer()
                    Text("\(totalCount) total")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Brand.textSecondary)
                }

                HStack(spacing: 16) {
                    summaryPill(label: "Missing", value: missingCount, color: Brand.orange)
                    summaryPill(label: "Installed", value: installedCount, color: Brand.green)
                    summaryPill(label: "Native", value: nativeCount, color: Brand.blue)
                    summaryPill(label: "Unmapped", value: unmappedCount, color: Brand.textSecondary)
                    summaryPill(label: "Unknown", value: unknownCount, color: Brand.textTertiary)
                }
            }
        }
    }

    private func summaryPill(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Missing Actions

    private var missingActionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "MISSING PACKAGES", color: Brand.orange, glyph: "exclamationmark.triangle.fill")

                Text("There are \(missingCount) packages not found in your TeX installation. Switch to the Packages tab to install them.")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    onSwitchToPackages?()
                } label: {
                    Label("View missing packages", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .tint(Brand.orange)
            }
        }
    }

    // MARK: - Disk Card

    private var diskCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "DISK", color: Brand.blue, glyph: "internaldrive")

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(diskValue)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)
                    Text("free")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Brand.textSecondary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var env: EnvironmentInfo {
        detectedEnvironment ?? EnvironmentInfo(
            tlmgr: false, kpsewhich: false, tectonic: false,
            latexmk: false, biber: false, makeindex: false,
            pdflatex: false, xelatex: false, lualatex: false
        )
    }

    private var distributionValue: String {
        if env.tlmgr { return "tlmgr" }
        if env.tectonic { return "Tectonic" }
        return "Not found"
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
        if env.tectonic { return "checkmark.circle" }
        return "exclamationmark.triangle.fill"
    }

    private var distributionColor: Color {
        if env.tlmgr { return Brand.green }
        if env.tectonic { return Brand.blue }
        return Brand.orange
    }

    private var distributionChip: String? {
        if env.tlmgr { return "primary" }
        if env.tectonic { return "fallback" }
        return nil
    }

    private var missingCount: Int {
        vm.resolvedPackages.filter { $0.status == .missing }.count
    }

    private var installedCount: Int {
        vm.resolvedPackages.filter { $0.status == .installed }.count
    }

    private var nativeCount: Int {
        vm.resolvedPackages.filter { $0.status == .native }.count
    }

    private var unmappedCount: Int {
        vm.resolvedPackages.filter { $0.status == .unmapped }.count
    }

    private var unknownCount: Int {
        vm.resolvedPackages.filter { $0.status == .unknown }.count
    }

    private var totalCount: Int {
        vm.resolvedPackages.count
    }

    private var diskValue: String {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let bytes = values.volumeAvailableCapacity else { return "—" }
        return "\(bytes / 1_000_000_000)"
    }
}
