// LogView.swift — Full-height scrollable log view for the Log tab with copy and reveal-in-Finder actions.
//
// Davit-inspired clean terminal: ConsoleView + header with StatusDot pulsing.

import SwiftUI

/// Full log view used in the Log tab: header with line count, live dot, copy, and reveal buttons.
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

    // MARK: - Header

    /// Header row with line count, live indicator, copy, and reveal buttons.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text").foregroundStyle(.secondary)
            Text("Log").font(.headline)

            Text("\(lines.count) lines")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLive {
                HStack(spacing: 4) {
                    StatusDot(color: .green, pulsing: true)
                    Text("live").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                let text = lines.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .hitAreaRect()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
            .hitAreaRect()
            .help("Copy log")

            if let persistentLogURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([persistentLogURL])
                } label: {
                    Image(systemName: "folder")
                        .hitAreaRect()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .hitAreaRect()
                .help("Reveal installation log in Finder")
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Terminal

    /// Monospaced scrollable terminal backed by the shared ConsoleView.
    private var terminal: some View {
        ConsoleView(lines: lines, autoScroll: isLive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
