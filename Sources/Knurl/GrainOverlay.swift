// GrainOverlay.swift — Legacy; Davit-inspired clean background uses system background.
//
// This view is now a no-op stub. It remains to preserve imports/call-sites
// (e.g. ContentView.backgroundLayers) but renders no grain texture. Davit
// does not use a veil/grain layer; the native system background is sufficient.

import SwiftUI

/// Legacy — Davit-inspired clean background uses system background; this view is no-op.
struct GrainOverlay: View {
    var opacity: Double = 0.04

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
    }
}
