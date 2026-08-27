// QuickHelp.swift — Tooltip com atraso menor que o padrão do sistema (~1,5s do macOS).
// Substitui `.quickHelp()` nos controles onde queremos resposta mais rápida ao hover.

import SwiftUI

/// Atraso (segundos) antes do tooltip aparecer. Bem abaixo do ~1,5s padrão do macOS.
private let quickHelpDelay: Double = 0.35

extension View {
    /// Tooltip leve que aparece `quickHelpDelay` segundos após o início do hover.
    /// Mantém o suporte a VoiceOver via `accessibilityHint`.
    func quickHelp(_ text: String) -> some View {
        modifier(QuickHelpModifier(text: text, delay: quickHelpDelay))
    }
}

private struct QuickHelpModifier: ViewModifier {
    let text: String
    let delay: Double

    @State private var showing = false
    @State private var pending: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .accessibilityHint(text)
            .overlay(alignment: .bottom) {
                if showing {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .fixedSize()
                        .offset(y: 8)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onHover { inside in
                if inside {
                    let item = DispatchWorkItem { showing = true }
                    pending = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
                } else {
                    pending?.cancel()
                    pending = nil
                    showing = false
                }
            }
    }
}
