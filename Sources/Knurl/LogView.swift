// LogView.swift — Full-height scrollable log view for the Log tab with copy and reveal-in-Finder actions.

import SwiftUI

/// Full log view used in the Log tab: header with line count, copy, and reveal buttons.
struct LogView: View {
    let lines: [String]
    let isLive: Bool
    var persistentLogURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            terminal
        }
    }

    /// Header row with line count, live indicator, copy, and reveal buttons.
    private var header: some View {
        HStack(spacing: 6) {
            Text("Log")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)

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

            Button {
                let text = lines.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy log")

            if let persistentLogURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([persistentLogURL])
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Reveal installation log in Finder")
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 8)
    }

    /// Monospaced scrollable terminal with auto-scroll when live.
    private var terminal: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear
                        .frame(height: 0)
                        .id("bottom")
                }
                .padding(8)
            }
            .scrollIndicators(.visible)
            .onChange(of: lines.count) { _, _ in
                guard isLive else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous)
                .fill(Brand.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous)
                        .strokeBorder(Brand.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 2)
        )
    }
}
