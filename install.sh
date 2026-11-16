#!/bin/zsh
# My Keys 一键安装：命令行工具 key + Mac 应用 My Keys.app，并建好密钥文件、接好终端。
#
#   ./install.sh            全部安装
#   ./install.sh --cli      只装命令行工具（不编译 App，不需要 Xcode）
#   ./install.sh --build    只编译 App 到 build/，不安装（开发用）
#
# 重复运行是安全的：已有的密钥文件不会被覆盖。
set -e
cd "${0:A:h}"
ROOT=$PWD
MODE=${1:-all}
BIN="$HOME/.local/bin"
APP_NAME="My Keys.app"
APP="$ROOT/build/$APP_NAME"

ZH=0; [[ "${MYKEYS_LANG:-$(defaults read -g AppleLanguages 2>/dev/null | sed -n 2p)}" == *zh* ]] && ZH=1
t() { (( ZH )) && print -r -- "$1" || print -r -- "$2"; }
say() { print -P "%F{blue}▸%f $1"; }
fail() { print -P "%F{red}✗%f $1"; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "$(t "My Keys 只支持 macOS" "My Keys only supports macOS")"
/usr/bin/python3 -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null \
  || fail "$(t "需要 Python 3.9 以上。先运行：xcode-select --install" "Python 3.9+ is required. Run: xcode-select --install")"

build_app() {
  command -v swift >/dev/null || fail "$(t "编译 App 需要 Xcode 或命令行工具。先运行：xcode-select --install（或用 --cli 只装命令行）" "Building the app needs Xcode or the Command Line Tools. Run: xcode-select --install (or use --cli for the CLI only)")"
  say "$(t "编译 My Keys.app（第一次约 1 分钟）" "Building My Keys.app (about a minute the first time)")"
  (cd app && swift build -c release 2>&1 | grep -E "error|warning: unre|Compiling|Build" || true)
  [[ -f app/.build/release/MyKeys ]] || fail "$(t "编译失败，看上面的报错" "Build failed, see the errors above")"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp app/.build/release/MyKeys "$APP/Contents/MacOS/MyKeys"
  cp app/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  install -m 755 bin/key "$APP/Contents/Resources/key"   # 自带一份，只下载 App 的人也能用
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>My Keys</string>
  <key>CFBundleDisplayName</key><string>My Keys</string>
  <key>CFBundleIdentifier</key><string>io.github.mykeys</string>
  <key>CFBundleExecutable</key><string>MyKeys</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Creates expiry alerts in Reminders. 用来在“提醒事项”里建密钥到期提醒。</string>
</dict>
</plist>
PLIST
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
  say "$(t "已编译" "Built"): build/$APP_NAME"
}

install_cli() {
  mkdir -p "$BIN"
  install -m 755 bin/key "$BIN/key"
  say "$(t "命令行工具" "CLI"): ~/.local/bin/key"
  # 新电脑上 ~/.local/bin 往往不在 PATH 里，补一行
  if ! grep -qs '.local/bin' "$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.zprofile"; then
    print '\n# My Keys: where the key CLI lives\nexport PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshenv"
    say "$(t "~/.zshenv 加上了 ~/.local/bin" "Added ~/.local/bin to PATH in ~/.zshenv")"
  fi
}

install_app() {
  local dest=/Applications
  [[ -w $dest ]] || dest="$HOME/Applications"
  mkdir -p "$dest"
  rm -rf "$dest/$APP_NAME"
  cp -R "$APP" "$dest/$APP_NAME"
  say "$(t "应用" "App"): $dest/$APP_NAME"
}

case $MODE in
  --build) build_app ;;
  --cli) install_cli; "$BIN/key" init ;;
  all|--all) build_app; install_cli; install_app; "$BIN/key" init ;;
  *) fail "$(t "不认识的参数 $MODE（可用 --cli、--build）" "Unknown option $MODE (use --cli or --build)")" ;;
esac

if [[ $MODE != --build ]]; then
  print
  if (( ZH )); then
    say "装好了。新开一个终端窗口，然后："
    print "    key scan              找散落在各处的明文密钥"
    print "    key agents --write    让本机的 AI 助手都按同一套规则用密钥"
    print "    key check             体检"
    print "  或者直接对你的 AI 助手说：按 $ROOT/docs/setup-with-ai.md 帮我把密钥整理好。"
  else
    say "Done. Open a new terminal window, then:"
    print "    key scan              find stray plaintext keys"
    print "    key agents --write    give every local AI agent the same rules"
    print "    key check             health check"
    print "  Or just tell your AI agent: follow $ROOT/docs/setup-with-ai.en.md to organize my API keys."
  fi
fi
