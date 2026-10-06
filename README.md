# Screen Context

Press both ⌘ keys to show Claude what's on your screen. It's [Appshots](https://learn.chatgpt.com/docs/appshots) from OpenAI's Codex, rebuilt for the Claude desktop app.

https://github.com/user-attachments/assets/5900624d-2726-4827-a691-763fb5763d93

Hold left ⌘ and right ⌘ together in any app. Screen Context takes a screenshot of the display you're on, reads the focused window's text, and brings up the Claude desktop app on the Code session you last used, with the capture as a thumbnail above the prompt. Take several and they line up side by side; hover one and press × to drop it. Send your message and the captures go with it: Claude gets the window's text and opens the screenshot.

## Requirements

- macOS 14 or later
- The [Claude desktop app](https://claude.com/download), with at least one session in its Code tab. It needs to run [mods](https://code.claude.com/docs/en/plugins/mods/overview): `/status` in a Code session shows Claude Code 2.1.286 or later.
- [Claude Code](https://code.claude.com/docs) (`claude`) on your PATH
- Xcode or its Command Line Tools (Swift 6), to build the menu-bar app

## Install

1. Build and start the Helper, a small menu-bar app. It starts at login from then on.
   ```bash
   git clone https://github.com/vavald/screen-context.git
   cd screen-context
   helper/install.sh
   ```
2. From its menu-bar icon, allow **Accessibility** (for the shortcut and the window's text) and **Screen Recording** (for the screenshot). Without Screen Recording, captures carry the text alone.
3. Install the plugin:
   ```bash
   claude plugin marketplace add vavald/screen-context
   claude plugin install screen-context@screen-context
   ```
4. Merge this into `~/.claude/settings.json`, so Claude opens your screenshots without asking each time:
   ```json
   { "permissions": { "allow": ["Read(~/.claude/screen-context/**)"] } }
   ```
5. Restart the Claude app.

## Privacy

- Captures stay on your Mac, in `~/.claude/screen-context/`, until you send a message. Only the newest 20 are kept.
- A capture goes to Claude only with the next message you send in its session. Press × to drop it before then.
- Password fields are never read.

## Good to know

- A capture goes to the Code session you last had open, even when the app is on another screen. With no session to go to (none yet, or all archived), nothing happens.
- Finding that session relies on the Claude app's private files and links, so an app update can break it.

## Troubleshooting

- **Nothing happens.** Open the menu-bar icon: it lists any permission still missing. Then watch the Helper's log while you press both ⌘ keys:
  ```bash
  log stream --level info --predicate 'subsystem == "io.github.vavald.ScreenContext"'
  ```
  `pkill -USR1 ScreenContext` takes a capture without the keyboard.
- **The app opens but no thumbnail shows.** In the Code session, `/status` should show Claude Code 2.1.286 or later, and `/plugin` should list screen-context as enabled. Then restart the Claude app.

## Update

```bash
git pull
helper/install.sh
claude plugin marketplace update screen-context
claude plugin update screen-context@screen-context
```

Then restart the Claude app. Without a code-signing certificate, the Helper asks for its permissions again after each update; an Apple Development certificate (free, from Xcode › Settings › Accounts) keeps them.

## Development

Screen Context has two parts: the **Helper** in `helper/`, a Swift menu-bar app that takes the capture, and the **Mod** in `mod/`, a Claude Code plugin that shows it above the prompt and sends it. [GLOSSARY.md](GLOSSARY.md) names things; [docs/adr](docs/adr) records the decisions.

- Test the Helper with `swift test` in `helper/`, the Mod with `claude plugin test .` in `mod/`.
- To try your changes to the Mod, add the marketplace from your clone (`claude plugin marketplace add /path/to/screen-context`). Bump `version` in `mod/.claude-plugin/plugin.json` before each `claude plugin update`, which skips an unchanged version.

## License

[MIT](LICENSE)
