# Screen Context

Press both ⌘ keys anywhere on the Mac and land in Claude Code with what you were looking at already in the conversation. [GLOSSARY.md](GLOSSARY.md) has the words, [docs/adr](docs/adr) the decisions.

## Install

1. Build and start the Helper. It starts at login from then on.
   ```bash
   helper/install.sh
   ```
2. From its menu-bar icon, allow Accessibility and Screen Recording.
3. Install the Mod from this repo's marketplace:
   ```bash
   claude plugin marketplace add ~/Github/screen-context
   claude plugin install screen-context@screen-context
   ```
4. In `~/.claude/settings.json`, switch on function hooks (the Mod is one) and let Claude open Screenshots without asking:
   ```json
   "env": { "CLAUDE_CODE_ENABLE_FUNCTION_HOOKS": "1" },
   "permissions": { "allow": ["Read(~/.claude/screen-context/**)"] }
   ```
5. Restart the Claude app: a session already running when the Mod was installed doesn't have it.

## Update

After changing the Helper, run `helper/install.sh` again. After changing the Mod, bump `version` in `mod/.claude-plugin/plugin.json` (an update skips an unchanged version), then:

```bash
claude plugin marketplace update screen-context
claude plugin update screen-context@screen-context
```

## When nothing happens

`log stream --predicate 'subsystem == "io.github.vavald.ScreenContext"'` shows each Capture and where it went; `pkill -USR1 ScreenContext` takes one without the keyboard.
