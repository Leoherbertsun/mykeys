# 写给 AI 助手

这是 **My Keys**：Mac 上管理 API 密钥的工具，包括命令行工具 `bin/key`（Python 标准库，兼容系统自带的 3.9）和 SwiftUI 应用 `app/`。两者读写的是同一个文件 `~/.config/secrets/keys.env`。

## 用户让你“帮我装好 / 整理密钥”

照 [docs/setup-with-ai.md](docs/setup-with-ai.md) 一步步做。最重要的规则：

- 密钥值永远不出现在聊天里；
- 收集密钥用 `key import` / `key add`，值不经过你；
- 改用户原有的配置文件前先确认、先备份。

## 用户让你改这个项目

| 位置 | 是什么 |
|---|---|
| `bin/key` | 命令行工具，单文件。所有读写逻辑都在这里，App 只调用它（`key ls --json`、`key add --stdin`、`key set`……） |
| `app/Sources/MyKeys/` | Mac 应用。`KeyCLI.swift` 负责调用 `key`，`Store.swift` 是数据，其余是界面 |
| `install.sh` | 编译和安装（`--build` 只编译到 `build/`，`--cli` 只装命令行工具） |
| `test/keys.env` | 自查用的假数据 |
| `test/selfcheck.sh` | 用假数据启动 App，自动操作一遍，截图和结果写到 `/tmp/mykeys-selfcheck/` |
| `docs/` | 给人和 AI 的文档；改了行为要同步改文档 |

约定：

- `key` 只能用 Python 标准库，并且要能在 `/usr/bin/python3`（3.9）上运行：图形界面启动的 App 调用它时用的就是这个解释器。
- 界面和命令行的提示文字是中文；说明字段在文件里用英文键（`platform`、`url`、`expires`……），中文名只出现在界面上。
- 写密钥文件必须经过 `save()`：写之前留快照，再原子替换。
- 改完跑 `test/selfcheck.sh`，并在临时目录里用假的 `HOME` 试一遍 `key init / scan / import / agents`（见 `test/selfcheck.sh` 的末尾）。
