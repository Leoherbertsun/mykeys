# 让 AI 帮你配置 My Keys

> 这份文档是写给 AI 助手照着做的。用户只要对 AI 说一句：“按这份文档帮我把本机的 API 密钥整理好。”

## 给 AI 的硬规则（全程遵守）

1. **不把密钥值打印出来。** 不 `cat` 密钥文件，不 `echo $XXX`，聊天里只出现名字和打码后的值。`key` 的所有输出都已打码，放心用它。
2. **值不经过你。** 收集密钥用 `key import 文件 变量名`（直接从原文件读）或 `key add 名字`（从剪贴板读）。不要让用户把密钥贴进聊天，也不要自己写脚本读出值再写进去。
3. **改用户原有的文件前先确认。** 删掉 `.zshrc` 里的明文、改 MCP 配置之前，把要改的地方列给用户看，得到同意再动，并先备份。
4. **不确定就问。** 不知道某个密钥属于哪个平台、还在不在用，就问用户，不要猜着删。

## 第 1 步：安装

```bash
cd <这个仓库> && ./install.sh          # 没有 Xcode 时用 ./install.sh --cli
key check
```

`install.sh` 会运行 `key init`，做三件事：建好 `~/.config/secrets/keys.env`，在 `~/.zshenv` 里加一行自动加载，生成本机说明 `~/.config/secrets/README.md`。

## 第 2 步：找出散落的明文密钥

```bash
key scan                       # 查常见位置：shell 配置、Claude / Codex / Cursor / Gemini 的配置
key scan ~/projects ~/code     # 再查用户说的项目目录里的 .env 文件
```

把结果整理成一张表给用户看：在哪个文件、变量名、打码后的值、你判断是哪个平台。标“已在 keys.env”的说明已经收过了，只需要清理原处的明文（第 5 步）。

## 第 3 步：收进来，并起好名字

按 [存储约定](conventions.md) 起名、分类，然后逐条导入：

```bash
key import ~/.zshrc OPENAI_API_KEY --section 大模型 \
  --meta platform=OpenAI --meta url=https://platform.openai.com/api-keys --meta purpose=…
key import ~/.claude.json Authorization --as EXAMPLE_TOKEN   # 去掉 "Bearer " 前缀会自动处理
```

接口地址、地域、存储桶名、用户名这类**不是秘密的配置**，存成配置并挂到所属密钥下：

```bash
key import ~/.zshrc OPENAI_BASE_URL --kind config --group OPENAI_API_KEY
```

同一个值在多处出现时只收一次。`key check` 会提示值完全相同的两个名字，请用户确认是不是存重了。

## 第 4 步：补全说明

`key ls` 看一遍。凡是你有把握的，都用 `key set` 补上平台、网址、用途；登录账号和到期日只在用户告诉你或原文件注释里写明时才填。

```bash
key set OPENAI_API_KEY platform=OpenAI url=https://platform.openai.com/api-keys purpose='大模型对话' tags=付费
key set OPENAI_API_KEY expires=2027-03-01      # 会在“提醒事项”里提前 7 天提醒
```

## 第 5 步：清理原处的明文

明文清理按位置分三种：

- **shell 配置**（`.zshrc` 等）：删掉对应的 `export XXX=…` 行。`keys.env` 已经通过 `~/.zshenv` 加载，变量名不变，脚本不受影响。
- **MCP 配置**：把明文换成按名字取，写法见 `key help mcp`。
  - Claude Code 的命令行型：`"command": "<key 的完整路径>", "args": ["run", "名字", "--", 原命令…]`
  - Claude Code 的 HTTP 型：`"headersHelper": "<key 的完整路径> header 名字"`
  - Codex 的 HTTP 型：`bearer_token_env_var = "名字"`
  - 推荐用各工具自带的命令改配置（如 `claude mcp add-json`），不要直接手改正在被程序读写的 JSON。
- **项目里的 `.env`**：问用户这个项目是否需要独立的 `.env`。不需要的话删掉对应行，让项目直接读环境变量。

每处改完都重启对应工具，确认 MCP 还能连上。

## 第 6 步：让所有 AI 助手守同一套规则

```bash
key agents            # 看本机装了哪些认识的助手、是否已接入
key agents --write    # 写入规则（只改带 <!-- mykeys --> 标记的一段，第一次会留 .mykeys-bak 备份）
```

不在列表里的助手（Cursor、WorkBuddy、Trae……）：把 `key agent-rules` 的输出贴进它的全局规则或“用户说明”里。

## 第 7 步：体检和收尾

```bash
key check
```

目标是“一切正常”。如果还有项目没处理，比如没设置备份密码，告诉用户原因和该怎么做；备份密码要用户自己在终端里输入：`key backup`。

最后给用户一份简短的总结：

- 收了多少个密钥，分成几组；
- 改了哪些文件，备份在哪；
- 以后新拿到密钥怎么说（“复制它，然后告诉我存成什么名字”）。
