// DropZoneView.swift — Drag-and-drop target that accepts .tex files or folders for analysis, with prominent and slim modes.
//
// Davit-inspired clean look: EmptyState-like prominent, secondary background, hairline stroke.

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

    // MARK: - Prominent (EmptyState-like Davit)

    private var prominentContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isTargeted ? 2 : 1)
                )
            VStack(spacing: 12) {
                Image(systemName: confirmed ? "checkmark.circle.fill" : "doc.text.magnifyingglass")
                    .font(.system(size: 42))
                    .foregroundStyle(confirmed ? Color.green : Color.primary.opacity(0.25))
                VStack(spacing: 4) {
                    Text(isTargeted ? "Drop to analyze" : "Drop the .tex file (or folder) here")
                        .font(.title3.weight(.semibold))
                    Text("or choose a file to get started")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button {
                    openPanel()
                } label: {
                    Text("Choose File").hitAreaRect()
                }
                .buttonStyle(.borderedProminent)
                .hitAreaRect()
                .padding(.top, 4)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .animation(.easeOut(duration: 0.15), value: confirmed)
        .contentShape(Rectangle())
        .modifier(DropZoneGestures(isTargeted: $isTargeted, confirmed: $confirmed, onDrop: onDrop))
    }

    // MARK: - Slim (compact bar)

    private var slimContent: some View {
        HStack(spacing: 10) {
            Image(systemName: confirmed ? "checkmark.circle.fill" : "doc.text.magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(confirmed ? Color.green : Color.secondary)
            Text(isTargeted ? "Drop to analyze" : "Drop the .tex file (or folder) here")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button {
                openPanel()
            } label: {
                Text("Choose File")
                    .font(.caption)
                    .hitAreaRect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .hitAreaRect()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isTargeted ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .animation(.easeOut(duration: 0.15), value: confirmed)
        .contentShape(Rectangle())
        .modifier(DropZoneGestures(isTargeted: $isTargeted, confirmed: $confirmed, onDrop: onDrop))
    }

    /// Opens an NSOpenPanel to pick a .tex file or folder directly (Choose File button).
    private func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.init(filenameExtension: "tex")!, .folder]
        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }
}

/// ViewModifier that wires `onDrop` to a drop zone (drag only; click handled by the caller button).
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
    }
}
