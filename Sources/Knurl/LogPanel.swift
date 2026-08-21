import SwiftUI
import KnurlCore

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

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Text("Log")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(lines.count) lines")
                        .font(.caption)
                    if !isLive {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundStyle(Brand.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLive)

            Spacer()

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
        .padding(.bottom, 6)
    }

    private var terminal: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.suffix(bufferLimit).enumerated()), id: \.offset) { _, line in
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
