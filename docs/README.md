# 黑苹果完整记录（红米 RedmiBook 14 增强版 2019 · XMA1901 · macOS Tahoe 26.7.2）

> 备份时间：2026-11-11 16:25
> 目的：重装系统或换盘时，能凭这套文件把机器恢复到「蓝牙 / WiFi / 扬声器 / 麦克风 / 触摸板 / 亮度 / 电池」全可用状态。

## 这套东西里有什么

| 路径 | 内容 |
|---|---|
| `README.md` | 本文件，总索引 |
| `01-机器与系统.md` | 硬件识别、SMBIOS、磁盘分区现状、扩容为什么失败 |
| `02-EFI配置说明.md` | EFI 目录结构、每个 kext / SSDT 的作用、config 关键项逐条解释 |
| `03-修复记录与根因.md` | 每个功能的「现象 → 根因 → 解法 → 验证方法」 |
| `04-重装与恢复.md` | 重装方案、EFI 恢复步骤、避坑清单 |
| `restore-efi.sh` | 一键把 EFI 备份写回 ESP |
| `checksums.txt` | EFI 备份包的 SHA-256 |
| `../efi-backup/EFI-2026-11-11/` | **当前可用 EFI 的完整副本（可直接打开浏览）** |
| `../efi-backup/EFI-2026-11-11.tar.gz` | 同一份 EFI 的压缩包（51 MB，便于拷到 U 盘） |
| `../acpi-src/` | 自建 SSDT 的反编译源码（触摸板 / USB 映射） |
| `../audio-fix/` | 音频测试工具与 bug 报告 |

## 当前状态一览

| 功能 | 状态 | 关键配置 |
|---|---|---|
| 引导 | ✅ | OpenCore 1.0.8 DEBUG，SMBIOS `MacBookPro16,2` |
| 核显 | ✅ 带 QE/CI，1600×900（面板原生 1920×1080） | `AAPL,ig-platform-id = 09009b3e` |
| 亮度 | ✅ 可调 + 快捷键 | `SSDT-PNLF` + `enable-backlight-registers-fix` |
| 电池 | ✅ 电量/充电状态 | `SMCBatteryManager` |
| WiFi | ✅ | `AirportItlwm-Tahoe 2.4.0` |
| 蓝牙 | ✅ | `IntelBluetoothFirmware 2.5.3` + `BlueToolFixup 2.7.1` |
| 扬声器 | ✅ | ALC256，`layout-id = 21`（`alc-layout-id = 0x15`） |
| 麦克风 | ⚠️ 能用，但有坑 | 同上；**不要开着「系统设置 → 声音」面板**，见 03 文档 |
| 触摸板 | ✅ 手势可用 | 原生 `TPD0` + `SSDT-TPDX`（关键：**不要再用假设备**） |
| 键盘/背光 | ✅ | `VoodooPS2Controller` |
| 隔空投送/接力 | ❌ | Intel 网卡，不支持 |

## 三条最重要的经验（重装时别踩）

1. **触摸板**：这台机器的触摸板在 OEM SSDT 里是原生存在的（`I2C1` / `TPD0` / ELAN2304 / 地址 0x15）。缺的只是 `_STA` 里的 `OSYS`、`TPMD` 两个条件在 macOS 下不满足。**正确做法是 110 字节的 `SSDT-TPDX` 覆盖这两个变量**，不是往 `I2C0` 打一个假的 `XTPD` 设备（那样永远 probe 不上）。
2. **音频**：Tahoe 移除了 `AppleHDA.kext`，必须靠 `SimpleHDA` 把原版驱动救回来。声卡是 ALC256，**只有 layout 21 的麦克风通路是对的**（0x09 → 0x22 → 0x19 Boost3），56 只有扬声器、99 麦克风静音。
3. **麦克风最大的坑不是驱动**：macOS 的「系统设置 → 声音」面板会常驻占用内置麦克风的输入流，导致输入引擎永远处于 running 状态。此时任何 App 再录音都只能拿到已经跑偏的 DMA 环，采出来全是 0，而且**只有重启能恢复**。

---
*本记录由实际调试过程整理，所有结论均经 `ioreg` / 音频实测 / ACPI 反编译验证。*
