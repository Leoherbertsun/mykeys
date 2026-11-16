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

say() { print -P "%F{blue}▸%f $1"; }
fail() { print -P "%F{red}✗%f $1"; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "My Keys 只支持 macOS"
/usr/bin/python3 -c 'import sys; assert sys.version_info >= (3, 9)' 2>/dev/null \
  || fail "需要 Python 3.9 以上。先运行：xcode-select --install"

build_app() {
  command -v swift >/dev/null || fail "编译 App 需要 Xcode 或命令行工具。先运行：xcode-select --install（或用 --cli 只装命令行）"
  say "编译 My Keys.app（第一次约 1 分钟）"
  (cd app && swift build -c release 2>&1 | grep -E "error|warning: unre|Compiling|Build" || true)
  [[ -f app/.build/release/MyKeys ]] || fail "编译失败，看上面的报错"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp app/.build/release/MyKeys "$APP/Contents/MacOS/MyKeys"
  cp app/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
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
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleLocalizations</key><array><string>zh-Hans</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>用来在“提醒事项”里建密钥到期提醒。</string>
</dict>
</plist>
PLIST
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
  say "已编译：build/$APP_NAME"
}

install_cli() {
  mkdir -p "$BIN"
  install -m 755 bin/key "$BIN/key"
  say "命令行工具：~/.local/bin/key"
  # 新电脑上 ~/.local/bin 往往不在 PATH 里，补一行
  if ! grep -qs '.local/bin' "$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.zprofile"; then
    print '\n# My Keys：命令行工具 key 的位置\nexport PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshenv"
    say "~/.zshenv 加上了 ~/.local/bin"
  fi
}

install_app() {
  local dest=/Applications
  [[ -w $dest ]] || dest="$HOME/Applications"
  mkdir -p "$dest"
  rm -rf "$dest/$APP_NAME"
  cp -R "$APP" "$dest/$APP_NAME"
  say "应用：$dest/$APP_NAME"
}

case $MODE in
  --build) build_app ;;
  --cli) install_cli; "$BIN/key" init ;;
  all|--all) build_app; install_cli; install_app; "$BIN/key" init ;;
  *) fail "不认识的参数 $MODE（可用 --cli、--build）" ;;
esac

if [[ $MODE != --build ]]; then
  print
  say "装好了。新开一个终端窗口，然后："
  print "    key scan              找散落在各处的明文密钥"
  print "    key agents --write    让本机的 AI 助手都按同一套规则用密钥"
  print "    key check             体检"
  print "  或者直接对你的 AI 助手说：按 docs/setup-with-ai.md 帮我把密钥整理好。"
fi
