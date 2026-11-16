#!/bin/zsh
# 自查：不碰真实密钥。
# 1) 在假的 HOME 里把命令行工具的主要流程走一遍；
# 2) 用 test/keys.env 的假数据启动 App，让它自己操作一遍并截图。
# 结果在 /tmp/mykeys-selfcheck/。用法：test/selfcheck.sh [zh|en]（默认中文）
set -e
UI=${1:-zh}
cd "${0:A:h}/.."
ROOT=$PWD
OUT=/tmp/mykeys-selfcheck
rm -rf $OUT && mkdir -p $OUT/home/.claude $OUT/home/.codex

export MYKEYS_LANG=$UI
print "== 命令行（系统自带 Python $(/usr/bin/python3 -V 2>&1 | cut -d' ' -f2)，界面语言 $UI）"
K=(/usr/bin/python3 $ROOT/bin/key)
(
  export HOME=$OUT/home
  print 'export DEMO_API_KEY="sk-demo-fake-1234567890"' > $HOME/.zshrc
  $K init >/dev/null
  $K scan | grep -q 'DEMO_API_KEY' && print "  scan     找到了 .zshrc 里的明文"
  $K import $HOME/.zshrc DEMO_API_KEY --meta platform=Demo >/dev/null && print "  import   收进来了"
  print -n 'sk-fake-openai-123456789' | $K add OPENAI_API_KEY --stdin >/dev/null
  $K ls --json | /usr/bin/python3 -c "import json,sys; d={x['name']:x for x in json.load(sys.stdin)}; assert d['OPENAI_API_KEY']['meta']['platform']=='OpenAI' and d['OPENAI_API_KEY']['section']" && print "  catalog  按名字自动补上了平台和分类"
  print -n 'https://api.demo.com/v1' | $K add DEMO_BASE_URL --stdin --kind config --group DEMO_API_KEY >/dev/null && print "  add      配置挂到了主密钥下"
  $K ls | grep -q '└ DEMO_BASE_URL' && print "  ls       分组显示正常"
  $K agents --write >/dev/null && grep -q 'mykeys:start' $HOME/.claude/CLAUDE.md && print "  agents   规则已写入"
  [[ $($K run --group DEMO_API_KEY -- /usr/bin/env | grep -c '^DEMO_') == 2 ]] && print "  run      按组注入正常"
  zsh -fc "source $HOME/.config/secrets/keys.env && [[ \$DEMO_BASE_URL == https://api.demo.com/v1 ]]" && print "  source   终端加载正常"
)

print "== App"
[[ -d "build/My Keys.app" ]] || ./install.sh --build >/dev/null
FIXTURE=test/keys.env; [[ $UI == en ]] && FIXTURE=test/keys.en.env
T=$OUT/data && mkdir -p $T && cp $FIXTURE $T/keys.env && chmod 600 $T/keys.env
open -n -W --env KEY_FILE=$T/keys.env --env KEY_SNAP_DIR=$T/snap --env KEY_BACKUP_DIR= \
  --env KEY_README=$T/README.md --env KEY_USAGE=$T/usage.json --env MYKEYS_NO_LOCK=1 \
  --env MYKEYS_KEY_BIN=$ROOT/bin/key --env MYKEYS_SELFCHECK_DIR=$OUT/shots --env MYKEYS_LANG=$UI "build/My Keys.app"
sed 's/^/  /' $OUT/shots/8-读写.txt; print
cmp -s $FIXTURE $T/keys.env && print "  数据     跑完后和原来一致" || print "  数据     ✗ 跑完后和原来不一致"
print "截图：$OUT/shots/"
