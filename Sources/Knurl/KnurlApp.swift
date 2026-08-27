// KnurlApp.swift — App entry point: window configuration, menu commands, and icon setup.

import SwiftUI
import AppKit
import KnurlCore

// MARK: - Notifications

extension Notification.Name {
    /// Posted when the user triggers Refresh (⌘R) from the menu.
    static let knurlRefresh = Notification.Name("knurl.refresh")
    /// Posted when the user triggers Search (⌘K) from the menu.
    static let knurlSearch = Notification.Name("knurl.search")
}

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
        Window("Knurl", id: "main") {
            MainWindow(openedURL: $openedURL)
                .frame(minWidth: 940, minHeight: 560)
                .onAppear {
                    appDelegate.onOpenURL = { url in
                        openedURL = url
                    }
                }
        }
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .knurlRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Search…") {
                    NotificationCenter.default.post(name: .knurlSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }

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

    /// Loads the custom app icon from the module resource bundle.
    private static func makeAppIcon() -> NSImage {
        guard let iconURL = appIconURL(),
              let nsImage = NSImage(contentsOf: iconURL) else { return NSImage() }
        nsImage.size = NSSize(width: 128, height: 128)
        return nsImage
    }

    /// Resolves `Icon.png` from the SwiftPM-managed resource bundle.
    ///
    /// SwiftPM's generated `Bundle.module` only knows how to find the resource bundle
    /// sitting next to a bare executable (what `swift run Knurl` produces). Inside the
    /// packaged `.app` the bundle lives under `Contents/Resources`, which that accessor
    /// never checks — it asserts instead. So we look in `Bundle.main.resourceURL` first
    /// (the `.app` layout) and fall back to `Bundle.module` for `swift run`.
    private static func appIconURL() -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundledIcon = resourceURL
                .appendingPathComponent("Knurl_Knurl.bundle")
                .appendingPathComponent("Icon.png")
            if FileManager.default.fileExists(atPath: bundledIcon.path) {
                return bundledIcon
            }
        }
        return Bundle.module.url(forResource: "Icon", withExtension: "png")
    }
}
