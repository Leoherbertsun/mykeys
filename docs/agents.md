# AI 助手之间怎么协作

目标：不管用哪个 AI 助手、在哪台 Mac 上，它都知道密钥在哪、怎么取、什么不能做，而且大家用的是同一份。

## 一份数据，一套规则，各自的入口

```
                 ~/.config/secrets/keys.env   ← 唯一的一份
                  ▲            ▲            ▲
        source    │     key    │     key    │
   (每个 zsh 进程) │  (命令行)   │  (App 调用) │
     终端 / 脚本   │   AI 助手   │  My Keys.app
```

- **终端和脚本**：`~/.zshenv` 自动加载，直接用 `$名字`。
- **AI 助手**：在 zsh 里跑命令时同样有 `$名字`；查名字用 `key ls`，存新密钥用 `key add`。
- **图形界面启动的程序**（Claude 桌面版、它启动的 MCP 服务、Electron 应用）：它们**不读** `~/.zshenv`，所以环境里没有这些变量。这时用 `key get 名字` 或 `key run 名字 -- 命令` 取值。

## 规则怎么分发

`key agents --write` 把同一段规则写进每个认识的 AI 助手的全局说明：

| 助手 | 文件 |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex（ChatGPT 桌面版、命令行） | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/GEMINI.md` |

- 规则夹在 `<!-- mykeys:start -->` 和 `<!-- mykeys:end -->` 之间，再次运行只替换这一段，不动你写的其他内容。
- 规则跟随系统语言（中文或英文），内容随 `key` 升级而更新：升级后再跑一次 `key agents --write` 即可。
- 其他助手（Cursor、WorkBuddy、Trae……）：运行 `key agent-rules`，把输出贴进它的全局规则或“用户说明”。
- `key` 同时生成 `~/.config/secrets/README.md`：本机的映射文档，写着东西在哪、接入了哪些助手、规则全文。任何助手不确定时都可以读它。

## 给 MCP 服务配密钥

配置文件里只写名字，不写值：

```jsonc
// Claude Code，命令行型：只把它需要的那一个密钥交给它
{ "command": "/Users/你/.local/bin/key", "args": ["run", "EXAMPLE_API_KEY", "--", "npx", "-y", "example-mcp"] }

// Claude Code，HTTP 型：请求头现场生成
{ "type": "http", "url": "https://example.com/mcp", "headersHelper": "/Users/你/.local/bin/key header EXAMPLE_TOKEN" }
```

```toml
# Codex，HTTP 型
[mcp_servers.example]
url = "https://example.com/mcp"
bearer_token_env_var = "EXAMPLE_TOKEN"
```

- 写 `key` 的完整路径：图形界面启动时 `PATH` 很短，找不到 `~/.local/bin`。
- `key run --group 主条目 -- 命令` 会把主密钥和挂在它下面的配置（如接口地址）一起交出去。
- 改完运行 `key check`，确认配置文件里不再有明文。

## 新拿到一个密钥时，AI 应该怎么做

用户说：“我复制了新的 Tavily 密钥，存成 TAVILY_API_KEY_5，这是第 5 个号。”AI 运行：

```bash
key add TAVILY_API_KEY_5 --meta account='第 5 个号' --meta tags=免费额度
```

平台、网址、分类由内置目录自动补上。值从剪贴板直接进文件，剪贴板随即清空；AI 和聊天记录里都只有打码后的值。

## 网页里必须粘贴密钥时

AI 助手通常有安全规则，不会把真实密钥敲进网页输入框，这一条不该绕开。做法是 AI 运行 `key copy 名字` 把值放进剪贴板（45 秒后自动清空），用户自己按 ⌘V。

## 换电脑、分享给别人

- **换电脑**：用“迁移助理”会原样带过去。或者在新电脑上装好 My Keys，再 `key restore 备份.dmg`，然后 `key agents --write`。
- **分享给别人**：只分享这个仓库，不分享 `keys.env`。对方装好后，让他的 AI 按 [setup-with-ai.md](setup-with-ai.md) 从零整理他自己的密钥。
