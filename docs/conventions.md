# 存储约定

好习惯只有几条，但每条都会让半年后的你（和你的 AI）省很多事。

## 1. 一个值只存一份，存在 keys.env

- 位置：`~/.config/secrets/keys.env`，权限 600，由 `~/.zshenv` 的一行 `source` 自动加载。
- 别的地方（`.zshrc`、MCP 配置、项目 `.env`、聊天记录）都不放明文，只写名字；`key check` 会帮你找出漏网的。
- 网站登录密码、两步验证码放密码管理器，不放这里。SSH 私钥放 `~/.ssh/`，这里最多存它的路径（作为配置）。

## 2. 起名：平台在前，用途在后，全大写

| 好的名字 | 说明 |
|---|---|
| `DEEPSEEK_API_KEY` | 平台 + `_API_KEY`，最常见 |
| `TAVILY_API_KEY_2` | 同一平台的第二个号，加序号 |
| `GITHUB_TOKEN`、`FEISHU_APP_SECRET` | 平台本来就叫 token / secret 的，沿用平台的叫法 |
| `DEEPSEEK_BASE_URL` | 配置：和所属密钥同一个前缀 |

尽量用平台官方文档里的变量名，很多 SDK 会直接读它（比如 `OPENAI_API_KEY`）。

## 3. 分清“密钥”和“配置”

| | 密钥（secret） | 配置（config） |
|---|---|---|
| 是什么 | 泄露了就要去平台作废的 | 接口地址、地域、存储桶名、用户名、应用编号、文件路径 |
| 显示 | 一律打码 | 直接显示 |
| 主列表 | 单独一行 | 挂在所属密钥下面（`group`），不单独占行 |
| 录入 | `key add 名字` | `key add 名字 --kind config --group 所属密钥` |

成对使用的两把钥匙（如 `ACCESS_KEY` + `SECRET_KEY`）：都是密钥，但把较次要的那把挂到另一把下面，让它们在界面上是一组。

## 4. 每个密钥记下这些

| 字段 | 中文 | 什么时候填 |
|---|---|---|
| `platform` | 平台 | 总是填 |
| `url` | 网址 | 去哪里登录、续费、重新生成（API keys 管理页最好） |
| `account` | 账号 | 用哪个账号申请的，多账号时尤其要填 |
| `purpose` | 用途 | 哪些脚本、技能、MCP 在用它 |
| `tags` | 标签 | 逗号分开，如 `常用,付费,免费额度,慎用` |
| `expires` | 到期 | `YYYY-MM-DD`；填了会在“提醒事项”里提前 7 天提醒 |
| `note` | 备注 | 余额、额度、坑 |
| `added` / `rotated` | 录入 / 换新 | `key` 自动记 |
| `kind` / `group` | 类型 / 归属 | 见上一节 |

## 5. 分类

文件里用 `# ===== 分类名 =====` 分段，App 左侧栏就按这些分类显示。默认有“大模型、数据、搜索、工具与服务”四类，按需增删。

## 6. 文件格式（给想手改或写工具的人）

```sh
# ===== 大模型 =====
#: platform=DeepSeek url=https://platform.deepseek.com purpose='对话、联网搜索' tags=常用 added=2026-08-01
export DEEPSEEK_API_KEY='sk-…'
#: kind=config group=DEEPSEEK_API_KEY
export DEEPSEEK_BASE_URL='https://api.deepseek.com'
```

- 每个条目是一行标准的 `export 名字='值'`，任何 shell 都能 `source`。
- 紧挨在上面的 `#: ` 行是它的说明，按 shell 的规则加引号，`source` 时当作注释忽略。
- 分类下、条目上方的普通 `#` 注释会在 App 里显示为“文件里的注释”。
- 建议用 `key` 或 App 修改：它们写之前会留快照、写入是原子的，不会写坏一半。

## 7. 换新和到期

- 平台上重新生成了密钥：`key add 同一个名字`，或在 App 里点“换新值”。名字不变，所有脚本和 MCP 不用改；旧值留在本地快照里。
- 不用的密钥：先去平台上作废，再 `key del`。
