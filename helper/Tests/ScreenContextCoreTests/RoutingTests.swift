import Testing
import ScreenContextCore

let open = DesktopSession(id: "local_a", cliSessionId: "cli-a", lastFocusedAt: 910_000, isArchived: false)
let older = DesktopSession(id: "local_b", cliSessionId: "cli-b", lastFocusedAt: 500_000, isArchived: false)

@Test func goesToTheSessionFocusedLast() {
    #expect(route(sessions: [older, open]) == open)
}

@Test func neverPicksAnArchivedSession() {
    let archived = DesktopSession(id: "local_z", cliSessionId: "cli-z", lastFocusedAt: 999_000, isArchived: true)
    #expect(route(sessions: [open, archived]) == open)
}
