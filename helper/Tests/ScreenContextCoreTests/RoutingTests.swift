import Testing
import ScreenContextCore

let now = 1_000_000.0  // ms
let onScreen = DesktopSession(id: "local_a", cliSessionId: "cli-a", lastFocusedAt: now - 90_000, isArchived: false)
let older = DesktopSession(id: "local_b", cliSessionId: "cli-b", lastFocusedAt: now - 500_000, isArchived: false)

@Test func goesToANewSessionWhenClaudeWasNotUsedSinceTheHelperStarted() {
    let r = route(captureId: "c1", now: now, claudeLastActiveAt: nil, sessions: [onScreen, older], draft: nil)
    #expect(r == .newSession(captureIds: ["c1"]))
}

@Test func goesToTheSessionOnScreenWhenClaudeWasLeftUnderAMinuteAgo() {
    let r = route(captureId: "c1", now: now, claudeLastActiveAt: now - 59_000, sessions: [older, onScreen], draft: nil)
    #expect(r == .recentSession(onScreen))
}

@Test func goesToANewSessionWhenClaudeWasLeftAMinuteOrMoreAgo() {
    let r = route(captureId: "c1", now: now, claudeLastActiveAt: now - 60_000, sessions: [onScreen], draft: nil)
    #expect(r == .newSession(captureIds: ["c1"]))
}

@Test func neverPicksAnArchivedSession() {
    let archived = DesktopSession(id: "local_z", cliSessionId: "cli-z", lastFocusedAt: now - 1_000, isArchived: true)
    let r = route(captureId: "c1", now: now, claudeLastActiveAt: now, sessions: [onScreen, archived], draft: nil)
    #expect(r == .recentSession(onScreen))
}

@Test func joinsTheOpenDraftWhenTheDraftWasOnScreen() {
    let draft = Draft(captureIds: ["c0"], openedAt: now - 30_000)
    let r = route(captureId: "c1", now: now, claudeLastActiveAt: now - 10_000, sessions: [onScreen], draft: draft)
    #expect(r == .newSession(captureIds: ["c0", "c1"]))
}

@Test func goesToASessionFocusedAfterTheDraftOpened() {
    let draft = Draft(captureIds: ["c0"], openedAt: now - 120_000)
    let r = route(captureId: "c1", now: now, claudeLastActiveAt: now - 10_000, sessions: [onScreen], draft: draft)
    #expect(r == .recentSession(onScreen))
}
