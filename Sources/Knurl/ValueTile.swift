// ValueTile.swift — Generic card displaying an eyebrow label, large value, subtitle, and optional chip.

import SwiftUI

/// A GlassCard-backed stat tile with an eyebrow, large monospaced value, and optional chip badge.
struct ValueTile: View {
    let eyebrow: String
    let value: String
    let subtitle: String
    var glyph: String?
    var color: Color = Brand.accent
    var chip: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Eyebrow(text: eyebrow, color: color, glyph: glyph)
                    Spacer()
                    if let chip {
                        Chip(text: chip, color: color)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Brand.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Brand.textSecondary)
                }
            }
        }
    }
}
