import SwiftUI

// MARK: - GlassCard

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
            .background(Brand.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: Brand.rCard, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 2)
    }
}

// MARK: - Eyebrow

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

// MARK: - Chip

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

// MARK: - ShortcutHint

struct ShortcutHint: View {
    let text: String
    var color: Color = Brand.textTertiary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }
}
