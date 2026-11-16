# 和同类项目比

> 2026 年 11 月整理。星数和更新时间取自 GitHub，会变化。

这两年“给 AI 编程助手管密钥”成了一个很热的方向，同类项目不少。粗分为五类：

| 类别 | 代表项目 | 星数 | 做法 |
|---|---|---|---|
| **AI 助手供应商切换** | [cc-switch](https://github.com/farion1231/cc-switch) | 15.5 万 | 桌面应用，管理 Claude Code、Codex 等的供应商配置（密钥加接口地址），一键切换 |
| | [Quotio](https://github.com/nguyenphutrong/quotio) | 4.9k | 菜单栏应用加本地代理，统一接入多个 AI 账号 |
| **项目级 .env 加密** | [dotenvx](https://github.com/dotenvx/dotenvx) | 5.9k | 加密的 `.env` 可以提交到 git，运行时 `dotenvx run` 解密 |
| | [varlock](https://github.com/dmno-dev/varlock) | 5.0k | 给 `.env` 加类型声明，AI 看声明、人管值 |
| | [fnox](https://github.com/jdx/fnox) | 2.4k | age 加密配置加多种后端（钥匙串、1Password……），带 MCP |
| | [secretspec](https://github.com/cachix/secretspec) | 1.6k | 声明项目需要哪些密钥，值从各种后端取 |
| **给 AI 的凭据代理** | [Infisical agent-vault](https://github.com/Infisical/agent-vault) | 2.5k | HTTP 代理替 AI 带上凭据，AI 拿不到值 |
| | [psst](https://github.com/Michaelliv/psst) | 241 | `psst 名字 -- 命令`，值注入子进程，不进上下文 |
| | [AgentSecrets](https://github.com/The-17/agentsecrets) | 198 | 零知识代理，替 AI 发请求 |
| **本地加密库，带界面、命令行和 MCP** | [OpenKeylet](https://github.com/omaekumiko2-create/OpenKeylet) | 135 | 本地凭据库，以 MCP 服务的形式给 AI 用 |
| | [Lokalite](https://github.com/RubenGlez/lokalite) | 8 | Swift 菜单栏应用、命令行加 MCP，加密库的钥匙存在钥匙串 |
| | [Envkeep](https://github.com/jackofshadowz/envkeep) | 9 | age 加密库，原生 Mac 界面加命令行 |
| | keyward、q-ring、tokenstash、keystash、Secret Wallet、akm…… | 个位数到几十 | 大多是“钥匙串或加密文件加 MCP”，2025–2026 年才出现 |
| **传统工具和商业服务** | [envchain](https://github.com/sorah/envchain)（1.3k，2024 年后基本没更新）、[gopass](https://github.com/gopasspw/gopass)（7.3k）、1Password CLI、Doppler、Bitwarden Secrets Manager | | 钥匙串、GPG 或云端保管，要包一层命令或登录账号 |

## My Keys 的位置

**我们做得更好的：**

1. **现有脚本一行不改。** 别的工具大多要把命令包一层（`xxx run -- 命令`），或者改用它们的引用语法。My Keys 只是一个被 `~/.zshenv` 加载的普通 `export` 文件，`$OPENAI_API_KEY` 照常可用。
2. **把规则发给所有 AI 助手。** `key agents --write` 把同一段规则写进 Claude Code、Codex、Gemini 的全局说明。同类项目大多只提供一个 MCP 服务，等 AI 自己发现；我们是直接告诉每个 AI 密钥在哪、怎么取、什么不能做。
3. **迁移是第一步，不是作业。** `key scan` 能找出散落在 shell 配置、各家 MCP 配置、项目 `.env` 里的明文，`key import` 把值直接从原文件搬进来，屏幕和聊天里都不出现。
4. **密钥和配置分开。** 接口地址、地域、应用编号挂在所属密钥下面。主列表只放真正的秘密，脚本照常能读到配置。
5. **自动补说明。** 内置 70 多个常见平台的目录。录入 `OPENAI_API_KEY` 会自动填上平台、去哪里管理密钥的网址和分类；录入 `OPENAI_BASE_URL` 会自动挂到 `OPENAI_API_KEY` 下。
6. **零依赖、零后台。** 命令行工具只用 macOS 自带的 Python，不常驻进程、不开端口、不用账号；到期提醒交给系统的“提醒事项”。
7. **原生界面，中英双语。**

**我们不如别人的（如实说）：**

1. **磁盘上是明文**，靠 600 权限和 FileVault 保护。Lokalite、Envkeep、fnox、1Password 都把密钥加密存储，用钥匙串或 Touch ID 解锁。
2. **AI 能读到值。** 环境变量对同一用户下的程序都可见。想让 AI 完全碰不到值，要用 agent-vault、AgentSecrets 这类代理方案。
3. **只支持 macOS 和单机**，不做团队共享和权限审计。
4. **不提供 MCP 服务**，只有命令行。我们认为对 AI 来说，命令行加上写进全局说明的规则更直接。但只认 MCP、不能跑命令的客户端用不了。

**适合谁：** 一个人、一台 Mac、几十个 API 密钥，同时用好几个 AI 编程助手，希望“存一次，到处能用，不贴进聊天”，又不想引入新的运行方式。

## 后续可能做的

- 可选的加密存储：文件加密，钥匙放在钥匙串里，终端启动时解密。代价是每个 shell 启动慢几十毫秒。
- 可选的 MCP 服务，给不能执行命令的客户端用。
- 通过 Homebrew 安装，发布签名版本。
