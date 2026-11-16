# Let an AI agent set up My Keys

> This document is written for an AI agent to follow. The user only needs to say: "Follow this document to organize the API keys on this Mac."

## Hard rules for the agent

1. **Never print secret values.** Don't `cat` the keys file or `echo $XXX`. Only names and masked values appear in chat. Everything `key` prints is already masked.
2. **Values never pass through you.** Collect keys with `key import FILE VAR` (reads the source file directly) or `key add NAME` (reads the clipboard). Don't ask the user to paste keys into chat, and don't write scripts that read values out and write them back.
3. **Ask before touching the user's files.** Before removing plaintext from `.zshrc` or editing MCP configs, show the user exactly what will change, get a yes, and back up first.
4. **When unsure, ask.** If you can't tell which provider a key belongs to or whether it's still used, ask instead of deleting.

## Step 1: Install

```bash
cd <this repo> && ./install.sh          # ./install.sh --cli without Xcode
key check
```

`install.sh` runs `key init`, which:

- creates `~/.config/secrets/keys.env`;
- adds one `source` line to `~/.zshenv`;
- writes a local map at `~/.config/secrets/README.md`.

## Step 2: Find stray plaintext keys

```bash
key scan                       # shell configs plus Claude / Codex / Cursor / Gemini configs
key scan ~/projects ~/code     # .env files in the project folders the user names
```

Show the user a table: file, variable, masked value and your guess at the provider. Entries marked "already in keys.env" only need their plaintext cleaned up (step 5).

## Step 3: Import with good names

Pick names and sections following the [storage conventions](conventions.en.md). The built-in catalog fills in the platform, URL and section for well-known providers.

```bash
key import ~/.zshrc OPENAI_API_KEY --meta purpose='chat for my scripts'
key import ~/.claude.json Authorization --as EXAMPLE_TOKEN   # a "Bearer " prefix is stripped automatically
key import ~/.zshrc OPENAI_BASE_URL                          # auto: config, attached to OPENAI_API_KEY
```

Import each value once even if it appears in several places. `key check` flags two names with identical values; ask the user which to keep.

## Step 4: Complete the notes

Run `key ls`. Fill in whatever you're confident about with `key set`. Set the account and expiry only when the user tells you, or when comments in the source file say so.

```bash
key set OPENAI_API_KEY purpose='chat' tags=paid
key set OPENAI_API_KEY expires=2027-03-01      # Reminders alert 7 days ahead
```

## Step 5: Clean up the original plaintext

- **Shell configs** (`.zshrc`, …): delete the `export XXX=…` line. `keys.env` is sourced by `~/.zshenv` under the same name, so scripts keep working.
- **MCP configs**: switch to fetch-by-name (see `key help mcp`):
  - Claude Code stdio: `"command": "<full path to key>", "args": ["run", "NAME", "--", original command…]`
  - Claude Code HTTP: `"headersHelper": "<full path to key> header NAME"`
  - Codex HTTP: `bearer_token_env_var = "NAME"`
  - Prefer each tool's own commands (e.g. `claude mcp add-json`) over hand-editing JSON that a running app may rewrite.
- **Project `.env` files**: ask whether the project needs its own `.env`. If not, delete the line and let the project read the environment.

Restart each tool after editing and confirm its MCP servers still connect.

## Step 6: One rulebook for every agent

```bash
key agents            # which known agents are installed and wired
key agents --write    # write the rules (only the <!-- mykeys --> block; a .mykeys-bak copy is kept the first time)
```

For agents not in the list (Cursor, Windsurf, Trae…), paste the output of `key agent-rules` into their global rules or user instructions.

## Step 7: Health check and wrap-up

```bash
key check
```

Aim for "all good". For anything left, such as a backup password not yet set, tell the user why and what to do. The user must type the backup password themselves: `key backup`.

Finish with a short summary for the user:

- how many keys were collected, and into how many groups;
- which files changed, and where the backups are;
- how to add new keys from now on: "copy it, then tell me what to name it".
