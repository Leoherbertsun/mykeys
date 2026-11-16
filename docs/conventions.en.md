# Storage conventions

A handful of habits that will save future you (and your agents) a lot of time.

## 1. One value, one copy, in keys.env

- Location: `~/.config/secrets/keys.env`, mode 600, loaded by a single `source` line in `~/.zshenv`.
- Nowhere else holds plaintext: not `.zshrc`, not MCP configs, not project `.env` files, not chat logs. Use names only; `key check` finds stragglers.
- Website passwords and 2FA codes belong in a password manager. SSH private keys stay in `~/.ssh/`; at most store their path here as config.

## 2. Naming: platform first, upper case

| Good name | Why |
|---|---|
| `DEEPSEEK_API_KEY` | Platform + `_API_KEY`, the common case |
| `TAVILY_API_KEY_2` | Second account on the same platform |
| `GITHUB_TOKEN`, `FEISHU_APP_SECRET` | Keep the platform's own wording |
| `DEEPSEEK_BASE_URL` | Config shares its key's prefix |

Prefer the variable name from the provider's docs; many SDKs read it automatically (e.g. `OPENAI_API_KEY`).

## 3. Secret vs. config

| | Secret | Config |
|---|---|---|
| What | Anything you'd have to revoke if leaked | Base URLs, regions, bucket names, usernames, app/client IDs, file paths |
| Display | Always masked | Shown in full |
| Main list | Its own row | Attached under its key (`group`) |
| Add with | `key add NAME` | `key add NAME --kind config --group PARENT` |

For keys that only work in pairs (`ACCESS_KEY` + `SECRET_KEY`), keep both as secrets but attach the minor one to the other so they show up as one group.

If you deliberately keep one value under two names (say, two scripts expect different variable names), attach one to the other and `key check` stops flagging it as a duplicate.

## 4. Notes worth keeping

| Field | When |
|---|---|
| `platform` | Always |
| `url` | Where to sign in, top up or regenerate (ideally the API-keys page) |
| `account` | Which account owns it; essential when you have several |
| `purpose` | Which scripts, skills or MCP servers use it |
| `tags` | Comma separated, e.g. `daily,paid,free-tier,careful` |
| `expires` | `YYYY-MM-DD`; adds a Reminders alert 7 days ahead |
| `note` | Balance, quota, gotchas |
| `added` / `rotated` | Filled in by `key` |
| `kind` / `group` | See above |

## 5. Sections, the catalog and auto-fill

- `# ===== Section =====` lines split the file, and the app's sidebar follows them. Name them however you like. A fresh install starts with AI Models, Search, Data, Cloud & Dev, and Tools & Services; a new section such as Payments is created at the end of the file the first time it's needed.
- `key` ships with a catalog of 70+ providers (see `key catalog`: OpenAI, Anthropic, DeepSeek, GitHub, AWS, Stripe, Slack…). When you add a new name, the prefix fills in the platform, the key-management URL and the section.
  - The section reuses your closest existing one, so "LLM" matches AI Models, and is created otherwise.
  - Names ending in `_BASE_URL`, `_URL`, `_REGION`, `_HOST`, `_APP_ID`, `_CLIENT_ID`, etc. become config and attach to the secret with the same prefix.
  - Wrong guess? Fix it with `key set`. Don't want guessing? Pass `--no-guess`.
- Providers missing from the catalog work fine; you just fill the notes yourself. PRs welcome: add a line to `CATALOG` in `bin/key`.

## 6. File format

```sh
# ===== AI Models =====
#: platform=DeepSeek url=https://platform.deepseek.com purpose='chat, web search' tags=daily added=2026-08-01
export DEEPSEEK_API_KEY='sk-…'
#: kind=config group=DEEPSEEK_API_KEY
export DEEPSEEK_BASE_URL='https://api.deepseek.com'
```

- Every entry is a standard `export NAME='value'` line any shell can `source`.
- The `#: ` line right above it holds its notes, quoted shell-style, and is ignored as a comment.
- Plain `#` comments inside a section show up in the app as "Comments in file".
- Prefer editing through `key` or the app: they snapshot first and write atomically.

## 7. Rotation and expiry

- Regenerated a key on the provider? `key add SAME_NAME`, or "Replace value" in the app. The name stays, so nothing else changes; the old value stays in a local snapshot.
- Retiring a key: revoke it on the provider first, then `key del`.
