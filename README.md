# Screen Context

Press both ⌘ keys to show Claude what's on your screen. It's [Appshots](https://learn.chatgpt.com/docs/appshots) from OpenAI's Codex, rebuilt for the Claude desktop app.

https://github.com/user-attachments/assets/5900624d-2726-4827-a691-763fb5763d93

- **Press both ⌘ keys** in any app. Screen Context takes a screenshot and reads the window's text.
- **The Claude app opens** on your last Code session, with the capture above the prompt. Take several, or press × to drop one.
- **Send your message.** Claude gets the window's text and opens the screenshot.

## Requirements

- macOS 14 or later
- The [Claude desktop app](https://claude.com/download), running Claude Code 2.1.286 or later (`/status` in a Code session)
- [Claude Code](https://code.claude.com/docs) (`claude`) on your PATH
- Xcode Command Line Tools

## Install

1. Build the Helper, a menu-bar app that starts at login, and install the plugin:
   ```bash
   git clone https://github.com/vavald/screen-context.git
   cd screen-context
   helper/install.sh
   claude plugin marketplace add vavald/screen-context
   claude plugin install screen-context@screen-context
   ```
2. From the menu-bar icon, allow **Accessibility** and **Screen Recording**.
3. Add this to `~/.claude/settings.json`, so Claude opens screenshots without asking:
   ```json
   { "permissions": { "allow": ["Read(~/.claude/screen-context/**)"] } }
   ```
4. Restart the Claude app.

## Good to know

- Captures stay on your Mac until you send a message. Password fields are never read.
- A capture goes to the Code session you last used. With no session, nothing happens.
- It relies on the Claude app's private files and links, so an app update can break it.

## Troubleshooting

- **Nothing happens:** the menu-bar icon lists missing permissions. To see the Helper's log:
  ```bash
  log stream --level info --predicate 'subsystem == "io.github.vavald.ScreenContext"'
  ```
- **No thumbnail:** check that `/status` shows Claude Code 2.1.286 or later and `/plugin` lists screen-context as enabled, then restart the Claude app.

## Update

```bash
git pull
helper/install.sh
claude plugin marketplace update screen-context
claude plugin update screen-context@screen-context
```

Then restart the Claude app. Without a code-signing certificate, macOS asks for the permissions again after each update. A free Apple Development certificate (Xcode › Settings › Accounts) avoids that.

## Development

The **Helper** (`helper/`, Swift) takes the capture; the **Mod** (`mod/`, a Claude Code plugin) shows and sends it. Test them with `swift test` and `claude plugin test .`. [GLOSSARY.md](GLOSSARY.md) names things, and [docs/adr](docs/adr) records the decisions.

To try changes to the Mod, add the marketplace from your clone and bump `version` in `mod/.claude-plugin/plugin.json` before each `claude plugin update`. `pkill -USR1 ScreenContext` takes a capture without the keyboard.

## License

[MIT](LICENSE)
