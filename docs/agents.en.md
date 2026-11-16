# How AI agents work together

Goal: whichever AI agent you use, on whichever Mac, it knows where keys live, how to fetch them and what it must not do, and every agent uses the same copy.

## One file, one rulebook, several doors

```
                 ~/.config/secrets/keys.env   ← the only copy
                  ▲            ▲            ▲
        source    │     key    │     key    │
  (every zsh)     │   (CLI)    │ (from app) │
   shells/scripts │  AI agents │ My Keys.app
```

- **Shells and scripts**: loaded by `~/.zshenv`, so `$NAME` just works.
- **AI agents**: have `$NAME` too when they run commands in zsh. They look names up with `key ls` and store new keys with `key add`.
- **GUI-launched programs** (Claude Desktop, the MCP servers it spawns, Electron apps) do **not** read `~/.zshenv`. Use `key get NAME` or `key run NAME -- cmd`.

## How the rules are distributed

`key agents --write` writes the same rules into each known agent's global instructions:

| Agent | File |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex (ChatGPT desktop and CLI) | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/GEMINI.md` |

- The rules sit between `<!-- mykeys:start -->` and `<!-- mykeys:end -->`. Re-running replaces only that block and leaves the rest of your file alone.
- The rules follow your system language. After upgrading `key`, run `key agents --write` again.
- For other agents (Cursor, WorkBuddy, Trae…), paste the output of `key agent-rules` into their global rules.
- `key` also maintains `~/.config/secrets/README.md`, a local map of where everything is, which agents are wired, and the full rules. Any agent in doubt can read it.

## Wiring MCP servers

Configs hold names, never values:

```jsonc
// Claude Code, stdio: hand the server only the key it needs
{ "command": "/Users/you/.local/bin/key", "args": ["run", "EXAMPLE_API_KEY", "--", "npx", "-y", "example-mcp"] }

// Claude Code, HTTP: header generated on the fly
{ "type": "http", "url": "https://example.com/mcp", "headersHelper": "/Users/you/.local/bin/key header EXAMPLE_TOKEN" }
```

```toml
# Codex, HTTP
[mcp_servers.example]
url = "https://example.com/mcp"
bearer_token_env_var = "EXAMPLE_TOKEN"
```

- Use the full path to `key`: GUI apps have a short `PATH` that misses `~/.local/bin`.
- `key run --group PARENT -- cmd` passes a key together with its attached config (e.g. its base URL).
- Run `key check` afterwards to confirm no plaintext is left in configs.

## What an agent does with a new key

The user says: "I copied a new Tavily key, save it as TAVILY_API_KEY_5, it's my fifth account." The agent runs:

```bash
key add TAVILY_API_KEY_5 --meta account='5th account' --meta tags=free-tier
```

The catalog fills in the platform, URL and section. The value goes from the clipboard into the file and the clipboard is cleared; the agent and the chat only ever see a masked value.

## When a web page needs the key

AI agents usually refuse to type real secrets into web forms, and that rule shouldn't be bypassed. The agent runs `key copy NAME` (the clipboard clears after 45 seconds) and the user presses ⌘V.

## New Mac, or sharing with others

- **New Mac**: Migration Assistant carries everything over. Or install My Keys, run `key restore backup.dmg`, then `key agents --write`.
- **Sharing**: share this repository, never `keys.env`. The other person installs it and asks their agent to follow [setup-with-ai.en.md](setup-with-ai.en.md) to organize their own keys from scratch.
