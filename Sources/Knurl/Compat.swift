// Compat.swift — Helpers de compatibilidade para rodar em macOS 13/14+ a partir do mesmo código.
//
// Centraliza os pontos onde APIs introduzidas no macOS 14 (ex.: `.background.secondary`,
// `.buttonBorderShape(.capsule)`, `alternatingRowBackgrounds()`, `onChange` com `initial:`)
// são usadas, oferecendo fallbacks que compilam com deployment target 13.0 mas
// preservam o comportamento nativo quando rodando em 14+.

import SwiftUI

// MARK: - Card Background (secondary)

extension View {
    /// Fundo de card compatível com 13+: usa `.background.secondary` em 14+, fallback
    /// `controlBackgroundColor` em 13 (visual muito próximo, sem quebrar o build).
    @ViewBuilder
    func knurlCardBackground(cornerRadius: CGFloat = 10) -> some View {
        if #available(macOS 14, *) {
            self.background(.background.secondary, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Variante com raio custom (usado por GlassCard rCard etc.).
    @ViewBuilder
    func knurlCardBackground(cornerRadius: CGFloat, style: RoundedCornerStyle) -> some View {
        if #available(macOS 14, *) {
            self.background(.background.secondary, in: RoundedRectangle(cornerRadius: cornerRadius, style: style))
        } else {
            self.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius, style: style))
        }
    }

    /// Variante com opacidade (usada no filtro de ReportView).
    @ViewBuilder
    func knurlCardBackgroundOpacity(_ opacity: Double, cornerRadius: CGFloat) -> some View {
        if #available(macOS 14, *) {
            self.background(.background.secondary.opacity(opacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(Color(nsColor: .controlBackgroundColor).opacity(opacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Button Shape

extension View {
    /// `buttonBorderShape(.capsule)` só existe em 14+; em 13 usa `.roundedRectangle`.
    @ViewBuilder
    func knurlCapsuleBorder() -> some View {
        if #available(macOS 14, *) {
            self.buttonBorderShape(.capsule)
        } else {
            self.buttonBorderShape(.roundedRectangle)
        }
    }
}

// MARK: - Table

extension View {
    /// `alternatingRowBackgrounds()` só em 14+; em 13 é no-op.
    @ViewBuilder
    func knurlAlternatingRowBackgrounds() -> some View {
        if #available(macOS 14, *) {
            self.alternatingRowBackgrounds()
        } else {
            self
        }
    }
}

// MARK: - onChange compat

extension View {
    /// Compat para `onChange(of:)` que funciona em 13 e 14.
    /// Em 14 usa a overload nova (com `initial: false` implícito), em 13 usa a antiga.
    @ViewBuilder
    func knurlOnChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }

    /// Compat para `onChange` que precisa de `old` e `new` (14+). Em 13 chama com `old == new`.
    @ViewBuilder
    func knurlOnChangeWithOld<V: Equatable>(of value: V, perform action: @escaping (V, V) -> Void) -> some View {
        if #available(macOS 14, *) {
            self.onChange(of: value, action)
        } else {
            self.onChange(of: value) { newValue in
                action(newValue, newValue)
            }
        }
    }
}
