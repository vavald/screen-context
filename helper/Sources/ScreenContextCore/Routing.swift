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

/// Where a Capture goes: the Open session, the one focused last in the Code tab; nil when there is none.
public func route(sessions: [DesktopSession]) -> DesktopSession? {
    sessions.filter { !$0.isArchived }.max { $0.lastFocusedAt < $1.lastFocusedAt }
}
