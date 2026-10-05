import AppKit
import ApplicationServices
import ScreenContextCore
import os

let log = Logger(subsystem: "io.github.vavald.ScreenContext", category: "capture")
let store = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/screen-context")

/// What the Helper writes next to each Screenshot, and the Mod reads.
struct CaptureRecord: Codable {
    let id: String
    let takenAt: Double
    let app: String
    let window: String
    /// Absent when Screen Recording isn't allowed.
    let screenshot: String?
    /// A small JPEG of the Screenshot as a data URL, for the Mod to show above the prompt.
    let thumbnail: String?
    let text: String
    /// The CLI session id of the Open session this Capture went to.
    let session: String
}

func capture() {
    guard let app = NSWorkspace.shared.frontmostApplication else { return }
    let id = String(format: "%06x", UInt32.random(in: 0..<0x100_0000))
    let takenAt = Date().timeIntervalSince1970 * 1000
    try? FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)

    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(axApp, 1)
    enableAccessibility(app)
    let window = element(axApp, kAXFocusedWindowAttribute)

    // The Screenshot first, before anything on screen moves.
    let png = store.appendingPathComponent("\(id).png")
    let screenshotTaken = screenshot(displayRect(around: window), to: png)
    var budget = 20_000
    var text = window.map { screenText(of: readTree($0, until: Date() + 3, budget: &budget)) } ?? ""
    // A window too big to read in time: say so, rather than let Claude think it saw everything.
    if budget <= 0 && !text.hasSuffix("[truncated]") { text += "\n[truncated]" }
    let title = window.flatMap { attribute($0, kAXTitleAttribute) as? String } ?? ""
    let appName = app.localizedName ?? app.bundleIdentifier ?? "App"

    guard let session = route(sessions: desktopSessions()) else {
        log.error("capture \(id): no session in Claude to send it to")
        try? FileManager.default.removeItem(at: png)
        return
    }
    let record = CaptureRecord(id: id, takenAt: takenAt, app: appName, window: title,
                               screenshot: screenshotTaken ? png.path : nil,
                               thumbnail: screenshotTaken ? thumbnail(of: png) : nil,
                               text: text, session: session.cliSessionId)
    do {
        try JSONEncoder().encode(record).write(to: store.appendingPathComponent("\(id).json"), options: .atomic)
    } catch {
        log.error("could not save capture \(id): \(error)")
        return
    }
    open("claude://code/continue?session=\(session.id)")
    log.info("capture \(id) of \(appName): \(text.count) characters, sent to \(session.id)")
    prune()
}

/// Puts Chrome and Electron apps into screen-reader mode so their windows expose text.
func enableAccessibility(_ app: NSRunningApplication) {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    if chromium.contains(app.bundleIdentifier ?? "") {
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }
}

private let chromium: Set = [
    "com.google.Chrome", "com.google.Chrome.canary", "org.chromium.Chromium", "com.brave.Browser",
    "com.microsoft.edgemac", "company.thebrowser.Browser", "company.thebrowser.dia", "com.vivaldi.Vivaldi",
    "com.operasoftware.Opera",
]

private func open(_ link: String) {
    if let url = URL(string: link) { NSWorkspace.shared.open(url) }
}

private func prune() {
    let files = (try? FileManager.default.contentsOfDirectory(at: store, includingPropertiesForKeys: [.creationDateKey])) ?? []
    let captures = files.filter { $0.pathExtension == "json" }.map { url in
        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
        return (id: url.deletingPathExtension().lastPathComponent, takenAt: created.timeIntervalSince1970 * 1000)
    }
    // Anything not part of a kept Capture goes too, like a Screenshot whose record failed to save.
    let kept = Set(captures.map(\.id)).subtracting(capturesToDelete(captures))
    for file in files where !kept.contains(file.deletingPathExtension().lastPathComponent) {
        try? FileManager.default.removeItem(at: file)
    }
}

/// The Claude Code sessions the desktop app knows about (see docs/adr/0001).
// ponytail: parses every session file whole (~0.5 s for 200); read only the fields needed if that grows.
private func desktopSessions() -> [DesktopSession] {
    let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
    return files.filter { $0.lastPathComponent.hasPrefix("local_") && $0.pathExtension == "json" }.compactMap { url in
        guard let data = try? Data(contentsOf: url),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = o["sessionId"] as? String,
              // Without it no Mod could pick a Capture up in that session.
              let cliSessionId = o["cliSessionId"] as? String else { return nil }
        return DesktopSession(id: id, cliSessionId: cliSessionId,
                              lastFocusedAt: o["lastFocusedAt"] as? Double ?? 0, isArchived: o["isArchived"] as? Bool ?? false)
    }
}

// MARK: Screenshot

/// The display the window's center is on, in screencapture's top-left coordinates.
private func displayRect(around window: AXUIElement?) -> CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    let displays = NSScreen.screens.map { f in
        CGRect(x: f.frame.minX, y: primaryHeight - f.frame.maxY, width: f.frame.width, height: f.frame.height)
    }
    if let window,
       let origin = axValue(window, kAXPositionAttribute, .cgPoint, CGPoint.zero),
       let size = axValue(window, kAXSizeAttribute, .cgSize, CGSize.zero) {
        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        if let display = displays.first(where: { $0.contains(center) }) { return display }
    }
    return displays.first ?? .zero
}

private func screenshot(_ rect: CGRect, to url: URL) -> Bool {
    guard CGPreflightScreenCaptureAccess() else { return false }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = ["-x", "-R", "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))", url.path]
    do { try p.run() } catch { return false }
    p.waitUntilExit()
    return p.terminationStatus == 0 && FileManager.default.fileExists(atPath: url.path)
}

/// A JPEG small enough to draw above the prompt, as a data URL.
private func thumbnail(of png: URL) -> String? {
    let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 320] as CFDictionary
    let jpeg = NSMutableData()
    guard let source = CGImageSourceCreateWithURL(png as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
          let destination = CGImageDestinationCreateWithData(jpeg, "public.jpeg" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? "data:image/jpeg;base64," + (jpeg as Data).base64EncodedString() : nil
}

// MARK: Accessibility

private let treeAttributes = [kAXRoleAttribute, kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, kAXChildrenAttribute] as CFArray

/// Reads the element and everything under it, giving up past `deadline` or after `budget` elements.
private func readTree(_ e: AXUIElement, until deadline: Date, budget: inout Int, depth: Int = 0) -> AXNode {
    budget -= 1
    var values: CFArray?
    AXUIElementCopyMultipleAttributeValues(e, treeAttributes, [], &values)
    let v = values as? [Any] ?? []
    func string(_ i: Int) -> String? { v.indices.contains(i) ? v[i] as? String : nil }
    var node = AXNode(role: string(0) ?? "", title: string(1), value: string(2), description: string(3))
    if depth < 100, v.indices.contains(4), let kids = v[4] as? [AXUIElement] {
        for kid in kids {
            // Out of time or elements: stop, and tell the caller through the budget.
            guard budget > 0, Date() < deadline else { budget = 0; break }
            node.children.append(readTree(kid, until: deadline, budget: &budget, depth: depth + 1))
        }
    }
    return node
}

private func attribute(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
    var ref: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, name as CFString, &ref) == .success ? ref : nil
}

private func element(_ e: AXUIElement, _ name: String) -> AXUIElement? {
    guard let ref = attribute(e, name), CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
    return (ref as! AXUIElement)
}

private func axValue<T: BitwiseCopyable>(_ e: AXUIElement, _ name: String, _ type: AXValueType, _ empty: T) -> T? {
    guard let ref = attribute(e, name), CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
    var out = empty
    return AXValueGetValue(ref as! AXValue, type, &out) ? out : nil
}
