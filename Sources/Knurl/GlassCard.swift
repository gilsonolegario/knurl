// GlassCard.swift — Card containers and Davit-inspired native UI primitives.
//
// Legacy GlassCard/Eyebrow/Chip/ShortcutHint kept for compat.
// Davit clean look: DetailCard, StatusDot, StateChip, InfoRow, EmptyState,
// ConsoleView, CardList, HoverRow, and refreshIndicator.

import SwiftUI
import AppKit

// MARK: - GlassCard (Legacy compat — now Davit-style background)

/// Frosted-glass card container with consistent padding, corner radius, and shadow.
/// Now renders with Davit-style `.background.secondary` (clean native look)
/// instead of the legacy warm `Brand.cardFill`.
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .knurlCardBackground(cornerRadius: Brand.rCard)
    }
}

// MARK: - Eyebrow (Legacy)

/// Small uppercase label used as a card eyebrow header.
struct Eyebrow: View {
    let text: String
    var color: Color = Brand.accent
    var glyph: String?

    var body: some View {
        HStack(spacing: 4) {
            if let glyph {
                Image(systemName: glyph)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.0)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Chip (Legacy)

/// Colored pill badge for short status text.
struct Chip: View {
    let text: String
    var color: Color = Brand.accent

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }
}

// MARK: - ShortcutHint (Legacy)

/// Keyboard-shortcut hint label (e.g. "⌘D").
struct ShortcutHint: View {
    let text: String
    var color: Color = Brand.textTertiary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }
}

// MARK: - DetailCard (Davit-inspired)

/// Native card with title + icon header, Davit-style secondary background.
/// Mirrors Davit `DetailCard` (Components.swift:74-93): 14pt padding,
/// rounded 10, `.background.secondary`.
struct DetailCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).foregroundStyle(.secondary)
                }
                Text(title).font(.headline)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .knurlCardBackground(cornerRadius: 10)
    }
}

// MARK: - StatusDot

/// 9pt status indicator circle, optionally pulsing (Davit StatusDot).
struct StatusDot: View {
    let color: Color
    var pulsing = false
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay {
                if pulsing {
                    Circle()
                        .stroke(color.opacity(pulse ? 0 : 0.55), lineWidth: 3)
                        .scaleEffect(pulse ? 2.0 : 1.0)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                }
            }
            .onAppear { pulse = true }
    }
}

// MARK: - StateChip

/// Generic pill badge for a state label + tint, Davit-style.
/// Use for PackageStatus or any textual status.
struct StateChip: View {
    let text: String
    var color: Color = Brand.accent
    /// When true, foreground is secondary (e.g. "stopped"/neutral state).
    var muted = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(muted ? Color.secondary : color)
    }
}

// MARK: - InfoRow

/// Label/value row with optional monospaced value and copy button (Davit InfoRow).
struct InfoRow: View {
    let label: String
    let value: String
    var monospaced = false
    var copyable = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            if monospaced {
                Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            } else {
                Text(value).textSelection(.enabled)
            }
            if copyable {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .quickHelp("Copy")
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

// MARK: - EmptyState

/// Centered empty-state placeholder with icon, title, message, and optional action.
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.quaternary)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ConsoleView

/// Monospaced scrollable log view with auto-scroll (Davit ConsoleView).
struct ConsoleView: View {
    let lines: [String]
    var autoScroll = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 11.5, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("console-bottom")
                }
                .padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .knurlOnChange(of: lines.count) { _ in
                if autoScroll {
                    proxy.scrollTo("console-bottom", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - CardList + HoverRow

/// Scrollable (or static) vertical list with tight spacing, Davit CardList style.
struct CardList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var scrollable = true
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        if scrollable {
            ScrollView { inner }
        } else {
            inner
        }
    }

    private var inner: some View {
        LazyVStack(spacing: 2) {
            ForEach(items) { item in
                row(item)
            }
        }
        .padding(10)
    }
}

/// Hover-highlight row with optional tap action (Davit HoverRow).
struct HoverRow<Content: View>: View {
    var action: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @State private var hovering = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowBody }
                    .buttonStyle(.plain)
            } else {
                rowBody
            }
        }
        .onHover { hovering = $0 }
    }

    private var rowBody: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(
                hovering ? AnyShapeStyle(.primary.opacity(0.055)) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

// MARK: - refreshIndicator (no-op)

extension View {
    /// The background poll is effectively instant — a toolbar spinner would
    /// either reflow the toolbar or leave an empty pill, so refresh is silent.
    /// Kept as a no-op so call sites stay put (mirrors Davit).
    func refreshIndicator(_ refreshing: Bool) -> some View { self }
}
