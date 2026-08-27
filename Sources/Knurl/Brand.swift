// Brand.swift — Centralized color palette, corner-radius tokens, and reusable button styles.
//
// Davit-inspired clean native look: warm amber accent (#F5C542) preserved for
// identity, surfaces lean on system backgrounds (.background.secondary) while
// legacy warm tokens remain for compat until callers migrate.

import SwiftUI
import AppKit

/// Unified design-system palette: accent, text, semantic colors, and corner radii.
/// Surfaces favor system backgrounds (Davit-style); warm tokens kept for compat.
@MainActor
enum Brand {
    // MARK: - Surface Colors

    /// Legacy warm base — kept for compat. Prefer system background for new views.
    static let base = Color.adaptive(
        dark: Color(red: 0x17/255, green: 0x12/255, blue: 0x0A/255),
        light: Color(red: 0xF4/255, green: 0xEF/255, blue: 0xE6/255)
    )

    /// Legacy warm soft base — kept for compat.
    static let baseSoft = Color.adaptive(
        dark: Color(red: 0x21/255, green: 0x1A/255, blue: 0x11/255),
        light: .white
    )

    /// Primary card fill — translucent warm veil (legacy). New cards should
    /// use `cardFill2` / `.background.secondary` (Davit DetailCard style).
    static let cardFill = Color.adaptive(
        dark: .white.opacity(0.07),
        light: .white.opacity(0.66)
    )

    static let cardFillHover = Color.adaptive(
        dark: .white.opacity(0.11),
        light: .white.opacity(0.72)
    )

    /// Davit-style card background alias — system secondary background.
    /// Prefer `.background(.background.secondary, in: RoundedRectangle(...))`
    /// at call-site; this alias is a Color fallback for non-shape-style use.
    static let cardFill2 = Color(nsColor: .controlBackgroundColor)

    // MARK: - Accent

    /// Warm amber — Knurl identity (unchanged).
    static let accent = Color(red: 0xF5/255, green: 0xC5/255, blue: 0x42/255)
    static let onAccent = Color.black.opacity(0.85)

    // MARK: - Text Colors

    static let textPrimary = Color.adaptive(
        dark: Color(red: 0xED/255, green: 0xE6/255, blue: 0xDA/255),
        light: Color(red: 0x22/255, green: 0x1B/255, blue: 0x11/255)
    )

    static let textSecondary = textPrimary.opacity(0.62)
    static let textTertiary = textPrimary.opacity(0.40)

    // MARK: - Semantic Colors

    static let green = Color(red: 0x3C/255, green: 0xB3/255, blue: 0x71/255)
    static let orange = Color(red: 0xF0/255, green: 0x71/255, blue: 0x4E/255)
    static let red = Color(red: 0xFF/255, green: 0x6B/255, blue: 0x6B/255)
    static let blue = Color(red: 0x4F/255, green: 0xA3/255, blue: 0xE3/255)

    // MARK: - Hairline

    static let hairline = Color.adaptive(
        dark: .white.opacity(0.08),
        light: .black.opacity(0.08)
    )

    // MARK: - Window Veil (Legacy)

    /// Legacy warm veil — no longer used by clean background; kept for compat.
    static let windowVeilTop = Color.adaptive(
        dark: Color(red: 0x17/255, green: 0x12/255, blue: 0x0A/255).opacity(0.55),
        light: Color(red: 0xF4/255, green: 0xEF/255, blue: 0xE6/255).opacity(0.50)
    )

    static let windowVeilBottom = Color.adaptive(
        dark: Color(red: 0x17/255, green: 0x12/255, blue: 0x0A/255).opacity(0.82),
        light: Color(red: 0xF4/255, green: 0xEF/255, blue: 0xE6/255).opacity(0.64)
    )

    // MARK: - Ambient Glow (Legacy)

    static let ambientGlow = Color(red: 0xD9/255, green: 0xA0/255, blue: 0x66/255)

    // MARK: - Shapes (Davit-aligned)

    static let rSmall: CGFloat = 12
    static let rCard: CGFloat = 10
    static let rLarge: CGFloat = 22
}

// MARK: - Color Adapter

/// Resolves a `Color` that switches between dark and light variants
/// based on the current system appearance.
extension Color {
    @MainActor
    static func adaptive(dark: Color, light: Color) -> Color {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? dark : light
    }
}

// MARK: - Button Styles

/// Standard app-wide button modifiers: `.appProminent()` and `.appCapsule()`.
extension View {
    /// Primary prominent pill button — amber tint, capsule shape, full hit area.
    func appProminent() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Brand.accent)
            .contentShape(Rectangle())
    }

    /// Secondary capsule badge — translucent fill with hairline stroke.
    func appCapsule() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Brand.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Brand.cardFill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Brand.hairline, lineWidth: 1))
            .contentShape(Capsule())
    }

    /// Expande a área clicável de um Button/Label para todo o seu bounds
    /// (corrige bug onde só o ícone dentro do Label recebe o clique, comum
    /// em Table cells e Labels com HStack custom).
    func hitAreaRect() -> some View {
        self.contentShape(Rectangle())
    }
}
