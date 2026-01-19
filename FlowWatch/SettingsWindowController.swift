import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hostingController = NSHostingController(
            rootView: LocalizedRootView { SettingsView() }
                .environmentObject(LocalizationManager.shared)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = LocalizationManager.shared.t("settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 620))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        window?.title = LocalizationManager.shared.t("settings.title")
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
