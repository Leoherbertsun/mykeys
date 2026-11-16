# 更新日志 · Changelog

## 1.1.0 — 2026-11-17

- 中英双语：App、命令行、AI 规则、安装脚本、文档都跟随系统语言。Bilingual app, CLI, agent rules, installer and docs (Chinese / English, following the system language).
- 平台目录：内置 70 多个常见平台，录入时按名字自动补平台、管理网址和分类；`key catalog` 查看。Built-in catalog of 70+ providers that fills in platform, key-management URL and section; see `key catalog`.
- 自动识别配置：`_BASE_URL`、`_REGION`、`_APP_ID` 等结尾的名字自动标成配置，挂到同前缀的密钥下。Names like `*_BASE_URL` become config and attach to their key automatically.
- 分类可以随意起名，用到新分类时自动新建；App 添加表单可以新建分类。Free-form sections, created on demand; the app can create new sections.
- 新文档：[和同类项目比](docs/comparison.md)。New doc: [comparison with 20+ similar projects](docs/comparison.en.md).

## 1.0.0 — 2026-11-16

- 首个公开版本：命令行工具 `key`、My Keys.app、密钥与配置分组、扫描导入、给 AI 助手分发规则、到期提醒、加密备份。First public release.
