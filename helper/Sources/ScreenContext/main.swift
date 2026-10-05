import AppKit
import ServiceManagement
import ScreenContextCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var detector = HotkeyDetector()
    var statusItem: NSStatusItem!
    var hotkeyMonitor: Any?
    var testTrigger: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screen Context")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        try? SMAppService.mainApp.register()

        watchHotkey()
        // A monitor added before Accessibility was allowed never fires, so add it again once it is.
        var trusted = AXIsProcessTrusted()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() && !trusted { self?.watchHotkey() }
            trusted = AXIsProcessTrusted()
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { enableAccessibility(app) }
        }
        NSWorkspace.shared.frontmostApplication.map(enableAccessibility)

        // `pkill -USR1 ScreenContext` takes a Capture without the keyboard, for testing.
        signal(SIGUSR1, SIG_IGN)
        testTrigger = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        testTrigger?.setEventHandler { capture() }
        testTrigger?.resume()
    }

    func watchHotkey() {
        if let hotkeyMonitor { NSEvent.removeMonitor(hotkeyMonitor) }
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, self.detector.handle(flags: event.modifierFlags.rawValue) else { return }
            capture()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "Press both ⌘ keys to capture", action: nil, keyEquivalent: "")
        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Allow Accessibility…", action: #selector(allowAccessibility), keyEquivalent: "").target = self
        }
        if !CGPreflightScreenCaptureAccess() {
            menu.addItem(withTitle: "Allow Screen Recording…", action: #selector(allowScreenRecording), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Screen Context", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
    }

    @objc func allowAccessibility() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    }

    @objc func allowScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
