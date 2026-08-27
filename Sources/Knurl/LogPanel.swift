// LogPanel.swift — Collapsible log panel with header, live indicator, copy button, and persistent-log reveal.
//
// Davit-inspired clean terminal: ConsoleView + StatusDot + bordered container.

import SwiftUI
import KnurlCore

/// Expandable log panel that shows installation output lines with copy and reveal-in-Finder actions.
public struct LogPanel: View {
    let lines: [String]
    let expanded: Bool
    let isLive: Bool
    let bufferLimit: Int
    var persistentLogURL: URL? = nil
    let onToggle: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded || isLive {
                terminal
            }
        }
    }

    // MARK: - Header

    /// Header row with expand toggle, line count, live dot, copy, and reveal buttons.
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Log")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(lines.count) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.secondary)
                .contentShape(Rectangle())
                .hitAreaRect()
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .hitAreaRect()
            .disabled(isLive)

            Spacer()

            if isLive {
                HStack(spacing: 4) {
                    StatusDot(color: .green, pulsing: true)
                    Text("live").font(.caption).foregroundStyle(.secondary)
                }
            }

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
        .padding(.bottom, 6)
    }

    // MARK: - Terminal

    /// Monospaced scrollable terminal view backed by the shared ConsoleView.
    private var terminal: some View {
        ConsoleView(lines: Array(lines.suffix(bufferLimit)), autoScroll: isLive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
