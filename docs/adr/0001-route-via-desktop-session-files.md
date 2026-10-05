# Route captures by reading the Claude desktop app's session files

A desktop mod can't tell which session is on screen, so the Helper decides where a Capture goes. It reads `lastFocusedAt` from the app's internal session files (`~/Library/Application Support/Claude/claude-code-sessions/**/local_*.json`) and reopens the Open session with the undocumented `claude://code/continue?session=local_<id>` link. Both the file format and the link are private to the app and can break on any update; we accepted that to put a Capture where you already are.

Every Capture goes to the Open session, however long ago you left Claude. We first copied Codex (a new session unless you left Claude under a minute ago), but a new session runs no mod until its first message, so it can't show the Captures above the prompt; the `claude://code/new?q=` link can only prefill text, and it rewrites the whole prompt box each time.

The files only say which session was focused last, not what is on screen now: from the New screen or the Chat tab, a Capture goes to the last focused session, and the link switches to it. With no session to go to (none yet, or all archived), the Helper drops the Capture and only logs it.
