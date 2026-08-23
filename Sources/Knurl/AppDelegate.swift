// AppDelegate.swift — Minimal NSApplicationDelegate that forwards open-URL events to the SwiftUI app layer.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenURL: ((URL) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        onOpenURL?(url)
    }
}
