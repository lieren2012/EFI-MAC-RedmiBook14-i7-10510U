# EFI-MAC-RedmiBook14-i7-10510U

> 红米 **RedmiBook 14 增强版（2019，XMA1901）** · Intel **i7-10510U**（Comet Lake-U / 4C8T）· 核显 **UHD 620**（`0x9B3E`）· **macOS Tahoe 26.7.2**
> 蓝牙 / WiFi / 扬声器 / 麦克风 / 触摸板手势 / 亮度 / 电池 / 休眠 全部可用，且 **SIP 可以全开**。

**English**: OpenCore EFI and full write-up for Xiaomi **RedmiBook 14 Enhanced Edition (2019, XMA1901)**, i7-10510U / Comet Lake-U, running macOS Tahoe 26.7.2. Bluetooth, Wi-Fi, audio (speaker + built-in mic), I2C touchpad gestures, brightness, battery and sleep all work with SIP fully enabled.

---

## 机器配置

| 项目 | 型号 |
|---|---|
| 机型 | 红米 RedmiBook 14 增强版 2019（XMA1901）——ACPI `OEMID XMCC` / `OEMTableID XMCC1901`，声卡 `subsystem 1D72:1901` |
| CPU | Intel Core i7-10510U（Comet Lake-U，4C8T） |
| 核显 | Intel UHD 620（`0x9B3E`） |
| 独显 | NVIDIA MX250 2GB（Darwin 下由 `SSDT-DDGPU` 屏蔽） |
| 屏幕 | 14" 1920×1080（面板 `LM140LF2`），当前以 1600×900 非 HiDPI 运行 |
| 声卡 | Realtek ALC256（`10EC:0256`） |
| 触摸板 | ELAN2304（`PNP0C50`），I2C1 / 地址 `0x15` / GPIO pin 0 |
| 无线 | Intel Wireless-AC 9560（WiFi `8086:02A4` CNVi，蓝牙 `8087:0AAA`） |
| 摄像头 | 无（该型号出厂不带摄像头） |
| 系统 | macOS 26.7.2 Tahoe（25G332） |
| 引导 | OpenCore **1.0.8 DEBUG** |
| SMBIOS | `MacBookPro16,2`（**序列号已抹除，请自行生成**） |

> **机型是怎么认定的**（三条互相独立的证据）：① 声卡 `subsystem-vendor-id = 0x1D72` = Xiaomi、`subsystem-id = 0x1901` = XMA1901；② 30 张 ACPI 表全部 `OEMID = XMCC` / `OEMTableID = XMCC1901`；③ 电池型号 `R14B01W`（RedmiBook 14 专用）。
> 项目早期曾把这台机器误判成「华为 MateBook D14 2020」（错把 `0x1D72` 当华为，华为实际是 `0x19E5`），并因此按 MateBook 的方案给触摸板注入了错误的假设备，绕了很大一圈。**认错机器，后面所有 SSDT 都是白做**——这条写在这里给后来人提个醒。

## 功能状态

| 功能 | 状态 | 说明 |
|---|---|---|
| 核显 QE/CI | ✅ | `AAPL,ig-platform-id = 09009b3e` |
| 亮度调节 | ✅ | `SSDT-PNLF` + 快捷键 |
| 电池 | ✅ | 电量 / 充电状态 |
| WiFi | ✅ | `AirportItlwm-Tahoe 2.4.0` |
| 蓝牙 | ✅ | 需 Tahoe 重编的 `IntelBluetoothFirmware 2.5.3` |
| 扬声器 | ✅ | ALC256，`layout-id = 21` |
| 内建麦克风 | ✅ | 同上；**有坑，见下文** |
| 触摸板 + 手势 | ✅ | 原生设备 + `SSDT-TPDX` |
| 键盘 / 背光 | ✅ |  |
| 休眠唤醒 | ✅ | `SSDT-GPRW` + `HibernationFixup` |
| 隔空投送 / 接力 | ❌ | Intel 网卡不支持 |
| 读卡器 | ❌ | 未适配 |

---

## 三个关键点（这套 EFI 的价值所在）

### 1. 触摸板：不要再注入假设备

这台机器的触摸板**一直存在**于 OEM SSDT 里（`\_SB.PCI0.I2C1.TPD0`，ELAN2304，地址 `0x15`），只是 `_STA` 有三重门挡着：

| 条件 | macOS 下的值 |
|---|---|
| `I2CD == 1` | ✅ 满足 |
| `OSYS >= 0x07DD` | ❌ 不够 |
| `TPMD == 1` | ❌ 为 0 |

正确做法是 110 字节的 `SSDT-TPDX`，在原生设备作用域内覆盖这两个变量：

```asl
Scope (\_SB.PCI0.I2C1.TPD0)
{
    If (_OSI ("Darwin"))
    {
        Name (OSYS, 0x07DF)
        Name (TPMD, One)
    }
}
```

> ⚠️ 网上不少方案会在 `I2C0` 上注入一个 `XTPD` 假设备（ELAN2303）。**总线编号和型号都是错的，probe 永远失败。** 这是本项目走过最长的弯路。

### 2. 音频：Tahoe 需要 SimpleHDA，layout 只能是 21

macOS Tahoe 移除了 `AppleHDA.kext`，必须靠 [SimpleHDA](https://github.com/laobamac/SimpleHDA) 把原版驱动救回来。

ALC256 在本机的实测结果（都是真机验证，不是推测）：

| layout | 来源 | 扬声器 | 麦克风 |
|---|---|---|---|
| 56 | Dell 系 | ✅ | ❌ 无 0x19 路径 |
| 69 | 小米 Pro | ❌ | ❌ |
| 99 | XiaoMiPro 2020 | ✅ | ❌ 电平全零 |
| **21** | Dell 5570（社区经验来自 MateBook 13/14 项目） | ✅ | ✅ |

原因：layout 21 的麦克风通路是 `0x09 → 0x22 → 0x19 (Boost 3)`，与 56/99 的 `0x08 → 0x23` 完全不同。

### 3. 麦克风最大的坑不是驱动，是「系统设置 → 声音」

`系统设置 → 声音` 面板（`Sound.appex`）为了画输入电平表，会**常驻占用内置麦克风的输入流**：

```
ioreg -r -c AppleHDAEngineInput
  IOAudioEngineState = 1                    ← 永远在跑
  IOAudioEngineNumActiveUserClients = 1     ← 一直有客户端
```

此时任何 App 再开录音，拿到的都是已经跑偏的 DMA 环，采出来全是 0，**而且只有重启能恢复**（`killall coreaudiod`、切输入源、切采样率全都无效）。

**所以：不要一边开着声音面板一边录音/语音通话。** 要看电平用仓库里的 `tools/miccheck.sh`。

---

## 快速开始

```bash
git clone https://github.com/<your-name>/EFI-MAC-RedmiBook14-i7-10510U.git
cd EFI-MAC-RedmiBook14-i7-10510U

# 1. 补齐不随仓库分发的 kext（SimpleHDA，作者未声明许可证）
#    脚本会下载后自动在 config.plist 中启用该条目（仓库里默认是禁用的）
bash scripts/fetch-kexts.sh

# 2. 生成你自己的 SMBIOS（仓库里的序列号已抹除）
#    用 GenSMBIOS 生成 MacBookPro16,2 的 SN / MLB / UUID / ROM，
#    填入 EFI/OC/config.plist → PlatformInfo → Generic

# 3. 写回 ESP
bash tools/restore-efi.sh
```

**装完必须检查 3 项：**

1. `Misc → Security → SecureBootModel = Disabled`（否则 SimpleHDA 起不来）
2. `Kernel → Quirks → DisableLinkeditJettison = True`（SimpleHDA 1.0.1 硬性要求）
3. `boot-args` 保留 `-ibtcompatbeta`（Tahoe 蓝牙必需）和 `-vi2c-force-polling`（触摸板必需）

详细说明见 [`docs/`](docs/)：

| 文档 | 内容 |
|---|---|
| [01-机器与系统](docs/01-机器与系统.md) | 硬件怎么认定的、分区布局、扩容为什么失败 |
| [02-EFI配置说明](docs/02-EFI配置说明.md) | 每个 kext / SSDT 的作用、boot-args 逐条解释 |
| [03-修复记录与根因](docs/03-修复记录与根因.md) | 六大功能的「现象 → 根因 → 解法 → 验证」 |
| [04-重装与恢复](docs/04-重装与恢复.md) | 重装方案、EFI 恢复、8 条避坑清单 |

## 目录结构

```
EFI/BOOT/          引导跳板（24KB，不要替换）
EFI/OC/            config.plist / ACPI / Kexts / Drivers
acpi-src/          自建 SSDT 的 ASL 源码（SSDT-TPDX、SSDT-USB）
docs/              完整中文文档
scripts/           fetch-kexts.sh（下载 SimpleHDA）
tools/             restore-efi.sh、miccheck.sh、音频诊断工具（CoreAudio / AVAudioEngine 实测）
```

## boot-args（当前为排查状态，日常可精简）

```
darkwake=0 ps2kbdonly=1 -v alcverbs=1 -ibtcompatbeta -shdahaloff -shdadbg -liludbgall -vi2c-force-polling msgbuf=1048576 voodooi2c-logging-level=2
```

日常使用建议精简为：

```
darkwake=0 ps2kbdonly=1 alcverbs=1 -ibtcompatbeta -vi2c-force-polling msgbuf=1048576
```

（去掉 `-v` 和三个调试参数；若希望启用 SimpleHDA 的 HAL 插件，也可以去掉 `-shdahaloff`）

## 版本

| 组件 | 版本 |
|---|---|
| macOS | 26.7.2 (25G332) |
| OpenCore | 1.0.8 DEBUG |
| Lilu | 1.7.1 |
| VirtualSMC | 1.3.7 |
| WhateverGreen | 1.7.0 |
| AppleALC | 1.9.8 |
| SimpleHDA | 1.0.1（需自行下载） |
| AirportItlwm | 2.4.0 (Tahoe) |
| IntelBluetoothFirmware / BTPatcher | 2.5.3（Tahoe 重编版） |
| VoodooI2C | 2.9.1 |
| VoodooPS2Controller | 2.3.8 |

## 已知问题

- **SimpleHDA 输入流并发问题**：多个 App 同时录音、或输入流重启时，DMA 环会被打死，只能重启恢复。已整理报告在 issue 区，等待作者修复。
- **Intel 无线网卡**不支持隔空投送 / 接力 / 随航。
- 触摸板走轮询（`-vi2c-force-polling`），闲置功耗略高，但比 GPIO 中断稳定。

## 鸣谢

[OpenCore](https://github.com/acidanthera/OpenCorePkg) · [Lilu](https://github.com/acidanthera/Lilu) · [VirtualSMC](https://github.com/acidanthera/VirtualSMC) · [WhateverGreen](https://github.com/acidanthera/WhateverGreen) · [AppleALC](https://github.com/acidanthera/AppleALC) · [SimpleHDA](https://github.com/laobamac/SimpleHDA) · [AirportItlwm](https://github.com/OpenIntelWireless/itlwm) · [IntelBluetoothFirmware](https://github.com/OpenIntelWireless/IntelBluetoothFirmware) · [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C) · [VoodooPS2](https://github.com/acidanthera/VoodooPS2) · [Hackintool](https://github.com/headkaze/Hackintool)

参考过的同机型 / 同芯片 EFI：
- [lolisaikou/Redmibook14-hackintosh](https://github.com/lolisaikou/Redmibook14-hackintosh) —— RedmiBook 14 增强版（i5-10210U），**与本机同模具**
- [michitta/Redmibook14-EE-hackintosh](https://github.com/michitta/Redmibook14-EE-hackintosh) —— RedmiBook 14 EE（10 代 Intel），同机型
- 音频 layout 参考（不同机型，仅 ALC256 麦通路的旁证）：[k-vx/Matebook_13_14_2020_Hackintosh_OpenCore](https://github.com/k-vx/Matebook_13_14_2020_Hackintosh_OpenCore)、[Rallo00/Hackintosh-MatebookD14-2020-Ventura](https://github.com/Rallo00/Hackintosh-MatebookD14-2020-Ventura)

## 许可证与免责

- 本仓库的文档、配置、自建 SSDT 源码以 **MIT** 发布。
- `EFI/OC/Kexts/` 下的第三方 kext **版权归各自作者**，遵循其原始许可证（BSD-3 / GPL-2.0 等），本仓库仅作整合分发。
- `SimpleHDA` 作者未声明开源许可证，因此**不在本仓库分发**，请通过 `scripts/fetch-kexts.sh` 从其官方 release 获取。
- 黑苹果违反 Apple 的软件许可协议，仅供学习研究。使用本配置造成的任何数据丢失或硬件问题，作者不承担责任。**务必先备份。**
