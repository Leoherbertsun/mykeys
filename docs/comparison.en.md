# How My Keys compares

> Compiled November 2026. Star counts and activity come from GitHub and will drift.

Managing secrets for AI coding agents became a busy space in 2025–2026. Roughly five groups:

| Group | Projects | Stars | Approach |
|---|---|---|---|
| **AI provider switchers** | [cc-switch](https://github.com/farion1231/cc-switch) | 155k | Desktop app that manages provider configs (key + base URL) for Claude Code, Codex, etc. and switches between them |
| | [Quotio](https://github.com/nguyenphutrong/quotio) | 4.9k | Menu-bar app + local proxy for multiple AI accounts |
| **Project-level .env encryption** | [dotenvx](https://github.com/dotenvx/dotenvx) | 5.9k | Encrypted `.env` you can commit; decrypt at runtime with `dotenvx run` |
| | [varlock](https://github.com/dmno-dev/varlock) | 5.0k | Schemas for `.env`: agents see the schema, humans hold the values |
| | [fnox](https://github.com/jdx/fnox) | 2.4k | age-encrypted config with many backends (Keychain, 1Password…), MCP included |
| | [secretspec](https://github.com/cachix/secretspec) | 1.6k | Declare which secrets a project needs; values come from any provider |
| **Credential proxies for agents** | [Infisical agent-vault](https://github.com/Infisical/agent-vault) | 2.5k | HTTP proxy that attaches credentials so the agent never holds them |
| | [psst](https://github.com/Michaelliv/psst) | 241 | `psst NAME -- cmd` injects into a subprocess, keeps values out of context |
| | [AgentSecrets](https://github.com/The-17/agentsecrets) | 198 | Zero-knowledge proxy that makes calls on the agent's behalf |
| **Local encrypted vault with GUI, CLI and MCP** | [OpenKeylet](https://github.com/omaekumiko2-create/OpenKeylet) | 135 | Local credential store exposed to agents as an MCP server |
| | [Lokalite](https://github.com/RubenGlez/lokalite) | 8 | Swift menu-bar app, CLI and MCP; vault key in Keychain |
| | [Envkeep](https://github.com/jackofshadowz/envkeep) | 9 | age-encrypted vault, native Mac GUI and CLI |
| | keyward, q-ring, tokenstash, keystash, Secret Wallet, akm… | 0–dozens | Mostly "Keychain or encrypted file + MCP", all from 2025–2026 |
| **Classic tools and SaaS** | [envchain](https://github.com/sorah/envchain) (1.3k, largely dormant since 2024), [gopass](https://github.com/gopasspw/gopass) (7.3k), 1Password CLI, Doppler, Bitwarden Secrets Manager | | Keychain, GPG or cloud vault; wrap your commands or sign in to a service |

## Where My Keys stands

**What we do better**

1. **Existing scripts keep working.** Most tools make you wrap commands (`xxx run -- cmd`) or adopt a reference syntax. My Keys is a plain `export` file sourced by `~/.zshenv`, so `$OPENAI_API_KEY` just works.
2. **One rulebook pushed to every agent.** `key agents --write` writes the same rules into Claude Code, Codex and Gemini CLI global instructions. Most alternatives offer an MCP server and hope the agent finds it; we tell each agent where keys live, how to fetch them and what not to do.
3. **Migration comes first.** `key scan` finds plaintext keys in shell configs, MCP configs and project `.env` files; `key import` moves a value straight from the source file, never through the screen or the chat.
4. **Secrets vs. config.** Base URLs, regions and app IDs hang under the key they belong to. The main list stays clean, and scripts still read the config as usual.
5. **Notes fill themselves in.** A built-in catalog of 70+ providers fills in the platform, key-management URL and section from the variable name. `OPENAI_BASE_URL` attaches itself to `OPENAI_API_KEY`.
6. **No dependencies, no daemon.** The CLI uses only the Python that ships with macOS, with no background process, open port or account. Expiry alerts go to the system Reminders app.
7. **Native app, Chinese and English.**

**Where others are stronger (honestly)**

1. **Plaintext at rest**, protected by file mode 600 and FileVault. Lokalite, Envkeep, fnox and 1Password encrypt and unlock with Keychain or Touch ID.
2. **Agents can read values.** Environment variables are visible to programs running as you. For true zero-knowledge, use a proxy such as agent-vault or AgentSecrets.
3. **macOS and single machine only**, with no team sharing or audit.
4. **No MCP server**, only a CLI. We think a CLI plus rules in the agent's global instructions is more direct, but MCP-only clients that cannot run commands are left out.

**Who it's for:** one person, one Mac, dozens of API keys and several AI coding assistants, who wants to store each key once, use it everywhere and never paste it into chat, without changing how scripts run.

## Possible next steps

- Optional encryption at rest: encrypt the file, keep the key in Keychain and decrypt at shell start, at the cost of a few dozen milliseconds per shell.
- Optional MCP server for clients that cannot run commands.
- Homebrew tap and signed releases.
