// VisualEffectBackground.swift — Legacy; Davit-inspired clean background uses system background.
//
// This view is now a no-op stub. It remains to preserve imports/call-sites
// (e.g. ContentView.backgroundLayers) but renders no visual effect. Davit's
// clean native look relies on the system window background, not a custom
// NSVisualEffectView veil.

import SwiftUI

/// Legacy — Davit-inspired clean background uses system background; this view is no-op.
struct VisualEffectBackground: View {
    var body: some View {
        Color.clear
    }
}
