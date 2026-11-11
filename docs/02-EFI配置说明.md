# 02 · EFI 配置说明

## 目录结构

```
EFI/
├─ BOOT/BOOTx64.efi           24KB 跳板，不要替换
└─ OC/
   ├─ OpenCore.efi            OpenCore 1.0.8 DEBUG (868,352 B)
   ├─ config.plist
   ├─ ACPI/                   19 个 AML（18 启用 / 3 禁用）
   ├─ Kexts/                  26 个 kext（含多版本 AirportItlwm）
   ├─ Drivers/                OpenRuntime / HfsPlus 等
   ├─ Resources/
   └─ Tools/
EFI/SysReport/                ← DEBUG 版生成的 ACPI 全表倾倒（诊断用，可删）
```

## Kext 清单与作用

| kext | 版本 | 作用 |
|---|---|---|
| `Lilu.kext` | 1.7.1 | 所有 Acidanthera 补丁的框架，必须第一 |
| `VirtualSMC.kext` | 1.3.7 | SMC 模拟，系统能启动的前提 |
| `SMCProcessor.kext` | 1.3.7 | CPU 温度/频率 |
| `SMCBatteryManager.kext` | 1.3.7 | 电池电量、充电状态 |
| `SMCLightSensor.kext` | 1.3.7 | 环境光传感器 |
| `WhateverGreen.kext` | 1.7.0 | 核显帧缓冲补丁、HDMI 音频、背光 |
| `AppleALC.kext` | 1.9.8 | 声卡 layout 注入（**必须是完整版 3.7MB，不是 87KB 的残废版**） |
| `SimpleHDA.kext` | 1.0.1 | **Tahoe 专用**：把 Apple 删掉的 AppleHDA 救回来 |
| `AirportItlwm-Tahoe.kext` | 2.4.0 | Intel 无线网卡（同目录还有 6 个旧版本 kext，靠 `MinKernel/MaxKernel` 互斥，别删） |
| `IntelBluetoothFirmware.kext` | 2.5.3 | Intel 蓝牙固件（**必须 Tahoe 重编版**，旧版在 26.x 上不加载） |
| `IntelBTPatcher.kext` | 2.5.3 | 蓝牙补丁（同上，必须新版） |
| `BlueToolFixup.kext` | 2.7.1 | 蓝牙协议栈修复 |
| `IntelBluetoothInjector.kext` | 2.5.3 | 只在 ≤ Big Sur 生效（`MaxKernel 20.9.9`），留着无害 |
| `HibernationFixup.kext` | 1.5.4 | 休眠修复 |
| `RestrictEvents.kext` | 1.1.6 | 屏蔽内存/CPU 相关的系统提示 |
| `NoTouchID.kext` | 1.0.4 | `MaxKernel 19.9.9`，Tahoe 上不加载，纯遗留 |
| `NullEthernet.kext` | 1.0.8 | 假网卡，保证 App Store / iCloud 正常 |
| `VoodooI2C.kext` | 2.9.1 | I2C 触摸板总线驱动 |
| `VoodooI2CHID.kext` | 1.0 | HID-over-I2C 设备驱动（触摸板真正干活的那个） |
| `VoodooGPIO` / `VoodooI2CServices` / `VoodooInput` | 内置插件 | GPIO 引脚控制 / 服务 / 指针事件 |
| `VoodooPS2Controller.kext` + `VoodooPS2Keyboard` | 2.3.8 | 内建键盘 |

**加载顺序很关键**：Lilu → VirtualSMC 系 → WhateverGreen → AppleALC → SimpleHDA → 无线/蓝牙 → I2C 系（Services → GPIO → VoodooI2C → HID → Input）。顺序错了会 panic 或设备不加载。

## ACPI 清单（`OC/ACPI/`）

| 文件 | 状态 | 作用 |
|---|---|---|
| `SSDT-TPDX.aml` | **启用** | ⭐ 触摸板命门：在原生 `TPD0` 作用域内让 `OSYS=0x07DF`、`TPMD=1`，骗过 `_STA` 的三重门 |
| `SSDT-USB.aml` | **启用** | ⭐ USB 端口映射（14 口，蓝牙所在口标 internal） |
| `SSDT-TPD0.aml` | **禁用** | ❌ 旧的「假触摸板」设备（挂 I2C0 / ELAN2303），**这是过去所有失败的根源，永远不要再启用** |
| `SSDT-USB-USBBT.aml` / `SSDT-USB-FingerBT.aml` | 禁用 | 早期蓝牙实验版本，已废弃 |
| `SSDT-LGPA350.aml` | 禁用 | 备选背光方案，未采用 |
| `SSDT-HPET.aml` | 启用 | IRQ 冲突修复，**AppleHDA 出声的前提** |
| `SSDT-PLUG.aml` | 启用 | CPU 原生电源管理 |
| `SSDT-PNLF.aml` | 启用 | 背光调节 |
| `SSDT-EC-USBX.aml` | 启用 | 建 EC 设备 + USB 供电属性（电池充电） |
| `SSDT-AWAC-DISABLE.aml` | 启用 | 强制走传统 RTC，避免 AWAC 冲突 |
| `SSDT-GPRW.aml` | 启用 | 修复「一睡就醒」 |
| `SSDT-PMC.aml` | 启用 | 原生 NVRAM |
| `SSDT-MCHC.aml` | 启用 | 内存控制器节点 |
| `SSDT-DDGPU.aml` | 启用 | 屏蔽独显（本机无独显，留着无害） |
| `SSDT-ALS0.aml` | 启用 | 环境光传感器节点 |
| `SSDT-PS2K.aml` | 启用 | 键盘 PS2 节点 |
| `SSDT-RMNE.aml` | 启用 | 给 NullEthernet 一个 MAC 地址 |

自建的两个 SSDT 源码在 `../acpi-src/`（`SSDT-TPDX.dsl`、`SSDT-USB.dsl`），改完用 `.tools/acpica-R2025_04_04/generate/unix/bin/iasl` 编译回 AML。

## config.plist 关键项

### DeviceProperties → `PciRoot(0x0)/Pci(0x1f,0x3)`（声卡）

| 键 | 值 | 说明 |
|---|---|---|
| `layout-id` | `21` | ALC256 唯一麦克风通路正确的 layout |
| `AFGLowPowerState` | `01000000` | 这里写 1 会被 AppleALC 的 layout 数据覆盖成 3，属正常 |
| `No-idle-support` | `0` | 不阻止空闲 |
| `hda-gfx` | `onboard-1` | 与核显 HDMI 音频配对 |
| `model` | `Intel Comet Lake PCH-LP cAVS` | 仅显示用 |

### DeviceProperties → `PciRoot(0x0)/Pci(0x2,0x0)`（核显）

| 键 | 值 | 说明 |
|---|---|---|
| `AAPL,ig-platform-id` | `09009b3e` | UHD 620 笔记本帧缓冲 |
| `device-id` | `9b3e0000` | 伪装成 UHD 620 |
| `framebuffer-flags` | `0f1bf300` | 修正花屏/黑屏 |
| `framebuffer-con1-*` / `con2-*` | — | 内屏 + 外接口映射 |
| `framebuffer-stolenmem` | `0000e001` | 显存 32MB |
| `enable-backlight-registers-fix` | `1` | 背光寄存器修正 |
| `enable-max-pixel-clock-override` | `1` | 解除像素时钟限制 |

### boot-args（当前值）

```
darkwake=0 ps2kbdonly=1 -v alcverbs=1 -ibtcompatbeta -shdahaloff -shdadbg -liludbgall -vi2c-force-polling msgbuf=1048576 voodooi2c-logging-level=2
```

| 参数 | 作用 | 重装后建议 |
|---|---|---|
| `darkwake=0` | 简化暗唤醒 | 保留 |
| `ps2kbdonly=1` | 只加载 PS2 键盘驱动 | 保留 |
| `alcverbs=1` | 允许 AppleALC 下发自定义 codec 指令 | 保留 |
| `-ibtcompatbeta` | 解除 IntelBTPatcher 的版本上限 | 保留（Tahoe 必需） |
| `-vi2c-force-polling` | 触摸板走轮询而非 GPIO 中断 | **保留**（中断在本机不稳） |
| `msgbuf=1048576` | 放大内核日志缓冲 | 可选 |
| `-v` | 啰嗦模式 | 排查完可去掉 |
| `-shdahaloff` | 旁路 SimpleHDA 的 HAL 插件 | **建议去掉**，让 HAL 插件接管（官方推荐路径） |
| `-shdadbg` / `-liludbgall` / `voodooi2c-logging-level=2` | 调试日志 | 排查完去掉 |

### Kernel → Quirks（对这台机器必要的）

`AppleXcpmCfgLock`、`DisableIoMapper`（VT-d 关不掉时必需）、`DisableLinkeditJettison`（**SimpleHDA 1.0.1 的硬性要求**）、`DisableRtcChecksum`、`PanicNoKextDump`、`PowerTimeoutKernelPanic`、`SetApfsTrimTimeout = -1`、`ThirdPartyDrives`、`CustomSMBIOSGuid`

### Misc

- `PickerMode = External`、`Timeout = 5000`、`HideAuxiliary = True`
- `SecureBootModel = Disabled`（不关的话 SimpleHDA 会导致无法启动）
- `Vault = Optional`
