// LogTail.swift — Compact read-only log snippet showing the last N lines beneath the packages table.

import SwiftUI

/// Shows the last few log lines as a compact terminal strip.
struct LogTail: View {
    let lines: [String]
    let tailCount: Int
    let isLive: Bool

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header
                terminal
            }
        }
    }

    /// Header row with line count and live indicator (no expand toggle — always compact).
    private var header: some View {
        HStack(spacing: 6) {
            Text("Log")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.textSecondary)

            Text("\(lines.count) lines")
                .font(.caption)
                .foregroundStyle(Brand.textSecondary)

            if isLive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Brand.accent)
                        .frame(width: 6, height: 6)
                    Text("live")
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Brand.textSecondary)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 6)
    }

    /// Renders the last `tailCount` lines — large while parsing, single line after.
    private var terminal: some View {
        let tail = Array(lines.suffix(tailCount))
        return ConsoleView(lines: tail, autoScroll: isLive)
            .frame(height: isLive ? nil : 36, alignment: .top)
            .frame(minHeight: isLive ? 180 : 36)
            .frame(maxHeight: isLive ? .infinity : 60, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous)
                    .strokeBorder(Brand.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 2)
    }
}
