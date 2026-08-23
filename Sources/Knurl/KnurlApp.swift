// KnurlApp.swift — App entry point: window configuration, menu commands, and icon setup.

import SwiftUI
import AppKit
import KnurlCore

/// Main SwiftUI app definition — configures the window, menus, and the AppDelegate adaptor.
@main
struct KnurlApp: App {
    @FocusedValue(\.exportActions) private var exportActions
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var openedURL: URL?

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = Self.makeAppIcon()
        UserDefaults.standard.register(defaults: ["NSWindowResizeTime": 0.15])
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(openedURL: $openedURL)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    configureWindow()
                    appDelegate.onOpenURL = { url in
                        openedURL = url
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("File") {
                Button("Export JSON…") {
                    guard let actions = exportActions, let report = actions.report,
                          let data = try? ReportFormatter.json(report) else { return }
                    actions.save(String(data: data, encoding: .utf8) ?? "", "tex-report.json")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(exportActions?.report == nil)

                Button("Export Markdown…") {
                    guard let actions = exportActions, let report = actions.report else { return }
                    actions.save(ReportFormatter.markdown(report), "tex-report.md")
                }
                .keyboardShortcut("e")
                .disabled(exportActions?.report == nil)
            }
        }
    }

    /// Configures the main window: transparent titlebar, no resize, movable by background.
    private func configureWindow() {
        guard let window = NSApplication.shared.keyWindow ?? NSApp.mainWindow else { return }

        // Transparent window
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true

        // Style mask: titled + closable + miniaturizable (no resizable)
        window.styleMask.insert([.closable, .miniaturizable])
        window.styleMask.remove(.resizable)
    }

    /// Loads the custom app icon from the module bundle.
    private static func makeAppIcon() -> NSImage {
        guard let url = Bundle.module.url(forResource: "Icon", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url) else { return NSImage() }
        nsImage.size = NSSize(width: 128, height: 128)
        return nsImage
    }
}
