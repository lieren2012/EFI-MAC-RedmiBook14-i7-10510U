#!/bin/bash
# restore-efi.sh — 把备份的 EFI 写回 ESP
# 用法: bash restore-efi.sh [disk0s1]
# 特性: 覆盖前先把现有 EFI 打包到 /tmp 作为回滚点；覆盖后校验 config.plist 哈希
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../efi-backup/EFI-2026-11-11"
ESP="${1:-disk0s1}"
MNT="/tmp/efi-restore"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$SRC/OC" ]; then
  echo "❌ 找不到备份目录: $SRC"
  exit 1
fi

echo "================================================"
echo " EFI 恢复"
echo " 来源: $SRC"
echo " 目标: /dev/$ESP"
echo "================================================"
echo
echo "将执行:"
echo "  1. 挂载 /dev/$ESP 到 $MNT"
echo "  2. 把现有 EFI 打包到 /tmp/EFI-rollback-$STAMP.tar.gz"
echo "  3. 用备份覆盖 $MNT/EFI/OC 和 $MNT/EFI/BOOT"
echo "  4. 校验 config.plist 的 SHA-256"
echo
printf "确认继续? [y/N] "
read -r ans
[ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "已取消"; exit 0; }

sudo mkdir -p "$MNT"
if ! mount | grep -q "on $MNT "; then
  sudo mount -t msdos "/dev/$ESP" "$MNT" || {
    echo "❌ 挂载失败。若提示权限问题，确认磁盘标识是否为 $ESP（diskutil list 查看）"
    exit 1
  }
fi

# 回滚点
echo "→ 备份现有 EFI..."
sudo tar -czf "/tmp/EFI-rollback-$STAMP.tar.gz" -C "$MNT" EFI 2>/dev/null
echo "  已保存: /tmp/EFI-rollback-$STAMP.tar.gz"

# 检查空间
NEED=$(du -sm "$SRC" | awk '{print $1}')
FREE=$(df -m "$MNT" | tail -1 | awk '{print $4}')
echo "→ 需要 ${NEED}MB，可用 ${FREE}MB"
if [ "$FREE" -lt "$NEED" ]; then
  echo "❌ ESP 空间不足（需要至少 ${NEED}MB）。可先清理 EFI/SysReport 再试。"
  exit 1
fi

# 覆盖
echo "→ 覆盖 EFI/OC ..."
sudo rm -rf "$MNT/EFI/OC"
sudo cp -R "$SRC/OC" "$MNT/EFI/OC"
echo "→ 覆盖 EFI/BOOT ..."
sudo rm -rf "$MNT/EFI/BOOT"
sudo cp -R "$SRC/BOOT" "$MNT/EFI/BOOT"

# 校验
echo "→ 校验..."
A=$(shasum -a 256 "$SRC/OC/config.plist" | awk '{print $1}')
B=$(sudo shasum -a 256 "$MNT/EFI/OC/config.plist" | awk '{print $1}')
if [ "$A" = "$B" ]; then
  echo "  ✅ config.plist 一致 ($A)"
else
  echo "  ❌ 校验失败: $A vs $B"
  echo "  回滚: sudo tar -xzf /tmp/EFI-rollback-$STAMP.tar.gz -C $MNT"
  exit 1
fi

KEYS=$(sudo ls "$MNT/EFI/OC/Kexts" | wc -l | tr -d ' ')
echo "  ✅ Kexts 目录 $KEYS 项"

sync
sudo umount "$MNT" 2>/dev/null
echo
echo "完成。请重启。"
echo "若要回滚: sudo mount -t msdos /dev/$ESP $MNT && sudo rm -rf $MNT/EFI && sudo tar -xzf /tmp/EFI-rollback-$STAMP.tar.gz -C $MNT"
