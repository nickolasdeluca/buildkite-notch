import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let settings = AppSettings()
    private let notifier = Notifier()
    private lazy var store = BuildStore(settings: settings, notifier: notifier)
    private var notch: NotchController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.setUp()
        notch = NotchController(settings: settings, store: store) { [weak self] in self?.showSettings() }
        installStatusItem()
        installMenus()

        store.start()
        observeChanges({ [settings] in settings.pollConfiguration }) { [weak self] in self?.store.restart() }
        // Keep the builds we have; only reschedule so a shorter interval applies right away.
        observeChanges({ [settings] in (settings.activePollInterval, settings.idlePollInterval) }) { [weak self] in
            self?.store.start(debounce: .seconds(1))
        }
        observeChanges({ [settings] in settings.language }) { [weak self] in self?.installMenus() }

        if !settings.isConfigured { showSettings() }
    }

    /// Clicking the Dock icon (only present while settings are open) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Buildkite Notch")
        statusItem = item
    }

    /// (Re)builds every menu in the current language.
    private func installMenus() {
        let strings = settings.strings
        NSApp.mainMenu = Self.makeMainMenu(strings)

        let menu = NSMenu()
        menu.addItem(withTitle: strings.refreshNow, action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(withTitle: strings.settingsMenuItem, action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: strings.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc private func refresh() { store.refreshNow() }
    @objc private func openSettings() { showSettings() }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "Buildkite Notch"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        // Show in the Dock and ⌘Tab only while settings are open.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Chrome for the regular (settings open) mode

    /// App and Edit menus; without Edit, ⌘C/⌘V don't reach text fields.
    private static func makeMainMenu(_ strings: any Strings) -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: strings.closeWindow, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: strings.quitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Buildkite Notch", action: nil, keyEquivalent: "").submenu = appMenu

        let editMenu = NSMenu(title: strings.edit)
        editMenu.addItem(withTitle: strings.undo, action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: strings.redo, action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: strings.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: strings.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: strings.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: strings.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: strings.edit, action: nil, keyEquivalent: "").submenu = editMenu

        return main
    }
}
