#!/bin/bash
# fetch-kexts.sh — 下载仓库中不包含的第三方 kext
#
# 只有 SimpleHDA 需要手动获取：作者未声明开源许可证，因此本仓库不分发它的二进制，
# 仅提供从作者官方 release 下载的方式。其余 kext 均已随仓库提供。
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
KEXTS="$HERE/EFI/OC/Kexts"
MIRROR="${GH_MIRROR:-https://ghfast.top/}"   # GitHub 直连 502 时用镜像

echo "目标目录: $KEXTS"
[ -d "$KEXTS" ] || { echo "❌ 找不到 $KEXTS"; exit 1; }

if [ -d "$KEXTS/SimpleHDA.kext" ]; then
  echo "✅ SimpleHDA.kext 已存在，跳过"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ 查询 SimpleHDA 最新 release..."
URL=$(curl -s --max-time 30 https://api.github.com/repos/laobamac/SimpleHDA/releases/latest \
      | python3 -c "
import json,sys
d=json.load(sys.stdin)
for a in d.get('assets',[]):
    n=a['name'].lower()
    if n.endswith('.zip') and 'release' in n and 'debug' not in n:
        print(a['browser_download_url']); break
")
[ -n "${URL:-}" ] || { echo "❌ 未找到 release 资产，请手动到 https://github.com/laobamac/SimpleHDA/releases 下载"; exit 1; }
echo "  $URL"

echo "→ 下载..."
curl -L --max-time 180 -o "$TMP/shda.zip" "${MIRROR}${URL}" || curl -L --max-time 180 -o "$TMP/shda.zip" "$URL"

echo "→ 解压..."
unzip -q "$TMP/shda.zip" -d "$TMP/x"

SRC=$(find "$TMP/x" -name "SimpleHDA.kext" -maxdepth 4 -type d | head -1)
[ -n "$SRC" ] || { echo "❌ 压缩包里没找到 SimpleHDA.kext"; ls -R "$TMP/x" | head -20; exit 1; }

cp -R "$SRC" "$KEXTS/"
echo "✅ 已安装到 $KEXTS/SimpleHDA.kext"

echo "→ 在 config.plist 中启用 SimpleHDA 条目..."
python3 - "$HERE/EFI/OC/config.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
c = plistlib.load(open(p, 'rb'))
found = False
for e in c['Kernel']['Add']:
    if 'SimpleHDA' in e['BundlePath']:
        e['Enabled'] = True
        found = True
plistlib.dump(c, open(p, 'wb'))
print('   已启用' if found else '   ⚠️ config 里没有 SimpleHDA 条目，请手动添加')
PY

echo
echo "注意："
echo "  1. 若下载的是 DEBUG 包，日常使用建议换成 RELEASE"
echo "  2. config.plist 必须保留 Kernel → Quirks → DisableLinkeditJettison = True"
echo "  3. Misc → Security → SecureBootModel 必须为 Disabled"
