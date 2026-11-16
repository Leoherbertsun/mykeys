<p align="center"><img src="app/Resources/icon-1024.png" width="120" alt=""></p>

<h1 align="center">My Keys</h1>

<p align="center">A local API-key manager for macOS: one file holds every key, you browse it in a native app, scripts and AI agents fetch keys by name.<br>
No account, no cloud, no subscription, no background service.</p>

<p align="center"><a href="README.md">中文</a> · English</p>

> The app and CLI messages are currently in Chinese. English UI is on the roadmap; contributions welcome.

![My Keys](docs/images/app.png)

## Why

You get a new API key, then paste it into `.zshrc`, a project's `.env`, three MCP configs, and finally into a chat with your AI assistant. Months later the same key lives in eight places, and nobody remembers which account it belongs to or when it expires.

My Keys keeps it simple:

- **One copy.** Every key lives in `~/.config/secrets/keys.env`, sourced by `~/.zshenv`, so every shell, script and AI agent sees `$NAME`.
- **Two doors, one file.** Humans use **My Keys.app**: Touch ID unlock, search, filters, notes and expiry reminders. Scripts and agents use the **`key`** CLI.
- **Agents fetch by name, never through chat.** New keys go straight from the clipboard into the file. MCP configs reference names (`key run`, `key header`) instead of holding plaintext.
- **One rulebook for every agent.** `key agents --write` writes the same rules into Claude Code, Codex and Gemini CLI global instructions.
- **Secrets vs. config.** Base URLs, regions and app IDs are stored as *config* attached to the key they belong to, so the main list shows only real secrets.

## Install

You need macOS 14+ and Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Leoherbertsun/mykeys.git ~/mykeys
cd ~/mykeys && ./install.sh        # or ./install.sh --cli for the CLI only
```

Then tell your AI assistant: *"Follow `~/mykeys/docs/setup-with-ai.md` to organize the API keys on this Mac."* It will:

- find plaintext keys in shell configs, MCP configs and `.env` files;
- import them without the values ever passing through the chat;
- attach base URLs to their keys and rewrite MCP configs to fetch keys by name;
- wire every agent to the same rules, and run a health check.

## Commands

| Command | What it does |
|---|---|
| `key add NAME` | Add or rotate a key, reading the value from the clipboard |
| `key add NAME --kind config --group PARENT` | Store a config value (e.g. a base URL) under its key |
| `key ls [word]` | List keys grouped, with secrets masked |
| `key set NAME platform=… url=… expires=YYYY-MM-DD` | Edit notes; setting an expiry adds a Reminders alert 7 days ahead |
| `key get NAME` / `key run NAME… -- cmd` | Print a value, or pass only the named keys to one command |
| `key copy NAME` | Copy to the clipboard and auto-clear it after 45 s |
| `key header NAME` | Print an auth header for HTTP MCP servers |
| `key scan` / `key import FILE VAR` | Find stray plaintext keys and import one |
| `key agents --write` | Write the shared rules into each agent's global instructions |
| `key check` | Health check: expiry, duplicates, plaintext copies, shell wiring, backup, agents |
| `key backup` | Make an encrypted disk image you can open by double-clicking |

## Security model

- `keys.env` is plaintext, protected by file mode 600 and FileVault.
- My Keys stops keys from sprawling into configs and chats. It does not protect against malware already running as your user.
- Touch ID in the app only keeps casual onlookers out; it adds no extra encryption.

## License

[MIT](LICENSE)
