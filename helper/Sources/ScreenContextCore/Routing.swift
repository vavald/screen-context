/// A Claude Code session as the Claude desktop app records it (see docs/adr/0001).
public struct DesktopSession: Equatable, Sendable {
    /// The app's id, `local_…`: what `claude://code/continue?session=` takes.
    public let id: String
    /// The CLI's id: what the Mod running in that session knows itself by.
    public let cliSessionId: String
    /// ms since 1970.
    public let lastFocusedAt: Double
    public let isArchived: Bool

    public init(id: String, cliSessionId: String, lastFocusedAt: Double, isArchived: Bool) {
        self.id = id
        self.cliSessionId = cliSessionId
        self.lastFocusedAt = lastFocusedAt
        self.isArchived = isArchived
    }
}

/// A new session the Helper opened whose Pending captures haven't been sent yet.
public struct Draft: Equatable, Sendable {
    public let captureIds: [String]
    /// ms since 1970.
    public let openedAt: Double

    public init(captureIds: [String], openedAt: Double) {
        self.captureIds = captureIds
        self.openedAt = openedAt
    }
}

public enum Route: Equatable, Sendable {
    case recentSession(DesktopSession)
    /// Every Pending capture the new session's prompt box should list.
    case newSession(captureIds: [String])
}

/// Where a new Capture goes. `claudeLastActiveAt` is when the Claude app was last frontmost (now if it still is).
public func route(captureId: String, now: Double, claudeLastActiveAt: Double?, sessions: [DesktopSession], draft: Draft?) -> Route {
    guard let lastActive = claudeLastActiveAt, now - lastActive < 60_000 else {
        return .newSession(captureIds: [captureId])
    }
    let onScreen = sessions.filter { !$0.isArchived }.max { $0.lastFocusedAt < $1.lastFocusedAt }
    if let draft, draft.openedAt > onScreen?.lastFocusedAt ?? 0 {
        return .newSession(captureIds: draft.captureIds + [captureId])
    }
    guard let onScreen else { return .newSession(captureIds: [captureId]) }
    return .recentSession(onScreen)
}
