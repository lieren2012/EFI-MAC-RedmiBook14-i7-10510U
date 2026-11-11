#!/bin/bash
# miccheck.sh — 麦克风健康检查（连续 3 次录音 + 引擎客户端泄漏检测）
# 用法: bash miccheck.sh
# 录音期间请持续说话，每次 5 秒，间隔 3 秒
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/bin"
mkdir -p "$BIN"

if [ ! -x "$BIN/miclevel" ]; then
  echo "首次运行，编译测试工具…"
  clang -fobjc-arc -framework Foundation -framework AVFoundation \
        -o "$BIN/miclevel" "$DIR/tools/miclevel.m" || exit 1
  clang -fobjc-arc -framework Foundation -framework CoreAudio \
        -o "$BIN/audioprocs" "$DIR/tools/audioprocs.m" 2>/dev/null
fi

echo "================ 麦克风健康检查 ================"
echo "接下来会连续录 3 次，每次 5 秒，中间停 3 秒。"
echo "请从现在开始，持续对着电脑说话，直到提示全部结束。"
echo

for i in 1 2 3; do
  echo "--- 第 $i 次录音（5 秒，请说话）---"
  "$BIN/miclevel" 5 2>&1 | tail -3
  echo
  if [ "$i" -lt 3 ]; then sleep 3; fi
done

echo "================ 引擎状态 ================"
ioreg -l -w0 -r -c AppleHDAEngineInput 2>/dev/null \
  | grep -E "IOAudioEngineState|IOAudioEngineNumActiveUserClients" | head -2
echo
echo "================ 占用麦克风的进程 ================"
[ -x "$BIN/audioprocs" ] && "$BIN/audioprocs"
echo
echo "判读："
echo "  三次都 MIC_CAPTURES_AUDIO  → 正常"
echo "  第一次正常、后面 MIC_SILENT → 驱动重启输入流有 bug（需报作者）"
echo "  三次都 MIC_SILENT          → 输入通路整体没起来"
echo "  上面若列出 Sound/系统设置    → 声音面板正占着麦克风，关掉它"
