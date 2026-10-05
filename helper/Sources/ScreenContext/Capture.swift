import AppKit
import ApplicationServices
import ScreenContextCore
import os

let log = Logger(subsystem: "io.github.vavald.ScreenContext", category: "capture")
let claudeBundleID = "com.anthropic.claudefordesktop"
let store = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/screen-context")
var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

/// What the Helper writes next to each Screenshot, and the Mod reads.
struct CaptureRecord: Codable {
    let id: String
    let takenAt: Double
    let app: String
    let window: String
    /// Absent when Screen Recording isn't allowed.
    let screenshot: String?
    let text: String
    /// The CLI session id of the Recent session this Capture went to; absent when it went to a new session.
    let session: String?
}

final class Capturer {
    /// When the Claude app last stopped being frontmost.
    var claudeLeftAt: Double?
    private var draft: Draft?
    /// The prompt-box line for each Capture that went to a new session.
    private var markers: [String: String] = [:]

    func capture() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let id = String(format: "%06x", UInt32.random(in: 0..<0x100_0000))
        let takenAt = nowMs
        try? FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 1)
        enableAccessibility(app)
        let window = element(axApp, kAXFocusedWindowAttribute)

        // The Screenshot first, before anything on screen moves.
        let png = store.appendingPathComponent("\(id).png")
        let shot = screenshot(displayRect(around: window), to: png)
        var budget = 20_000
        let text = window.map { screenText(of: readTree($0, until: Date() + 3, budget: &budget)) } ?? ""
        let title = window.flatMap { attribute($0, kAXTitleAttribute) as? String } ?? ""
        let appName = app.localizedName ?? app.bundleIdentifier ?? "App"

        if let d = draft, d.captureIds.contains(where: isDone) { draft = nil }
        let claudeLastActiveAt = app.bundleIdentifier == claudeBundleID ? takenAt : claudeLeftAt
        let to = route(captureId: id, now: takenAt, claudeLastActiveAt: claudeLastActiveAt, sessions: desktopSessions(), draft: draft)

        var session: String?
        if case .recentSession(let s) = to { session = s.cliSessionId }
        let record = CaptureRecord(id: id, takenAt: takenAt, app: appName, window: title,
                                   screenshot: shot ? png.path : nil, text: text, session: session)
        do {
            try JSONEncoder().encode(record).write(to: store.appendingPathComponent("\(id).json"), options: .atomic)
        } catch {
            log.error("could not save capture \(id): \(error)")
            return
        }

        switch to {
        case .recentSession(let s):
            open("claude://code/continue?session=\(s.id)")
        case .newSession(let ids):
            markers[id] = title.isEmpty ? "📸 \(appName) (capture \(id))" : "📸 \(appName) — \"\(title)\" (capture \(id))"
            draft = Draft(captureIds: ids, openedAt: nowMs)
            open("claude://code/new?q=" + encode(ids.compactMap { markers[$0] }.joined(separator: "\n") + "\n"))
        }
        log.info("capture \(id) of \(appName): \(text.count) characters, routed \(String(describing: to))")
        prune()
    }
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

private func isDone(_ id: String) -> Bool {
    FileManager.default.fileExists(atPath: store.appendingPathComponent("\(id).done").path)
}

private func open(_ link: String) {
    if let url = URL(string: link) { NSWorkspace.shared.open(url) }
}

private func encode(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? ""
}

private func prune() {
    let files = (try? FileManager.default.contentsOfDirectory(at: store, includingPropertiesForKeys: [.creationDateKey])) ?? []
    let captures = files.filter { $0.pathExtension == "json" }.map { url in
        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
        return (id: url.deletingPathExtension().lastPathComponent, takenAt: created.timeIntervalSince1970 * 1000)
    }
    for id in capturesToDelete(captures) {
        for ext in ["json", "png", "done"] { try? FileManager.default.removeItem(at: store.appendingPathComponent("\(id).\(ext)")) }
    }
}

/// The Claude Code sessions the desktop app knows about (see docs/adr/0001).
private func desktopSessions() -> [DesktopSession] {
    let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
    return files.filter { $0.lastPathComponent.hasPrefix("local_") && $0.pathExtension == "json" }.compactMap { url in
        guard let data = try? Data(contentsOf: url),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = o["sessionId"] as? String else { return nil }
        return DesktopSession(id: id, cliSessionId: o["cliSessionId"] as? String ?? "",
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
        for kid in kids where budget > 0 && Date() < deadline {
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
