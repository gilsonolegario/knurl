// DropZoneView.swift — Drag-and-drop target that accepts .tex files or folders for analysis, with prominent and slim modes.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Drop zone that accepts `.tex` files or folders for TeX analysis.
/// Shows a prominent empty-state or a compact inline bar depending on `prominent`.
struct DropZone: View {
    @Binding var isTargeted: Bool
    var prominent: Bool = true
    let onDrop: (URL) -> Void
    @State private var confirmed = false

    init(isTargeted: Binding<Bool>, prominent: Bool = true, onDrop: @escaping (URL) -> Void) {
        _isTargeted = isTargeted
        self.prominent = prominent
        self.onDrop = onDrop
    }

    var body: some View {
        if prominent {
            prominentContent
        } else {
            slimContent
        }
    }

    private var prominentContent: some View {
        VStack(spacing: 8) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "doc.text.magnifyingglass")
                .font(.system(size: 24, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(confirmed ? .green : Brand.accent)
            Text(isTargeted ? "Drop to analyze" : "Drop the .tex file (or folder) here")
                .font(.system(size: 13, weight: .medium))
            Text("or click to choose")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(chrome)
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .animation(.easeOut(duration: 0.15), value: confirmed)
        .contentShape(Rectangle())
        .modifier(DropZoneGestures(isTargeted: $isTargeted, confirmed: $confirmed, onDrop: onDrop))
    }

    private var slimContent: some View {
        HStack(spacing: 8) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "doc.text.magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(confirmed ? .green : Brand.accent)
            Text(isTargeted ? "Drop to analyze" : "Drop the .tex file (or folder) here")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(chrome)
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .animation(.easeOut(duration: 0.15), value: confirmed)
        .contentShape(Rectangle())
        .modifier(DropZoneGestures(isTargeted: $isTargeted, confirmed: $confirmed, onDrop: onDrop))
    }

    private var chrome: some View {
        RoundedRectangle(cornerRadius: Brand.rCard, style: .continuous)
            .fill(isTargeted ? Brand.accent.opacity(0.08) : Brand.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: Brand.rCard, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Brand.accent : Brand.hairline,
                        lineWidth: isTargeted ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 2)
    }
}

/// ViewModifier that wires `onDrop` and click-to-open gestures to a drop zone.
private struct DropZoneGestures: ViewModifier {
    @Binding var isTargeted: Bool
    @Binding var confirmed: Bool
    let onDrop: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                confirmed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { confirmed = false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in onDrop(url) }
                    }
                }
                return true
            }
            .onTapGesture {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowedContentTypes = [.init(filenameExtension: "tex")!, .folder]
                if panel.runModal() == .OK, let url = panel.url {
                    onDrop(url)
                }
            }
    }
}
