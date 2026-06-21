<div align="center">

<img src="Resources/logo.png" width="128" alt="NanoPlayer logo">

# NanoPlayer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Apple%20Silicon-lightgrey.svg)](#requirements)
[![Build](https://github.com/Maple728/NanoPlayer/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/Maple728/NanoPlayer/actions/workflows/build.yml)

**极简的 macOS 视频播放器，原生 Dolby Vision / HDR 直通，基于 mpv，专为 Apple Silicon 优化。**<br>
**A dead-simple macOS video player with native Dolby Vision & HDR passthrough. mpv-powered, Apple Silicon optimized.**

`🎞️ Dolby Vision` · `🌈 HDR10 / HLG` · `⚡ VideoToolbox` · `📺 追剧连播 / Binge-watch`

灵感来自 / Inspired by [IINA](https://github.com/iina/iina)

**[中文](#中文) · [English](#english)**

</div>

---

## 中文

NanoPlayer 是一个基于 [libmpv](https://github.com/mpv-player/mpv) 的极简播放器。它只干一件事：**在 macOS 上正确播放 Dolby Vision 与 HDR 视频**——保留 `mpv --vo=gpu-next --target-colorspace-hint=yes`，让 HDR 元数据直通到显示器，而不是被 tone-map 成 SDR。在此之上，再加一点点「追剧」便利。

### ✨ 特性

- 🎞️ **Dolby Vision 直通（核心能力）**：保留 `gpu-next` + `target-colorspace-hint` 渲染管线，**4K Dolby Vision** 在 XDR / HDR 屏上以真实高动态范围呈现，而非被 tone-map 成 SDR。详见下文 **Dolby Vision / HDR** 一节。
- 🌈 **全 HDR 家族**：HDR10、HLG 同样直通；SDR 屏自动 tone-map。
- ⚡ **Apple Silicon 硬解**：`hwdec=videotoolbox`，gpu-next 经 libplacebo / MoltenVK / Metal 渲染。
- 📺 **追剧三件套**：打开任意一集 → **同目录整季按集数自动入列**（识别 `SxxExx`/`1x04`/`E04`/`第04集`）→ **从所选集起播**（用 `insert-at`，不重载不闪烁）→ **播完自动连播下一集**。
- ⌨️ **与 IINA 对齐的快捷键** + 🖱️ **mpv 原生 OSC / 鼠标交互**。
- 🪶 **零臃肿**：纯 Swift + AppKit + libmpv，单文件 `.app`，无 Electron、无第三方框架。

### 🎞️ Dolby Vision / HDR

> **这是 NanoPlayer 的全部意义。** macOS 上能正确、零折损播放 Dolby Vision 的播放器并不多，NanoPlayer 把它列为第一优先级。

- **Dolby Vision**：Profile 5 / 7 / 8（RPU 动态元数据，由 mpv 0.41 + libplacebo 解析）
- **HDR10 / HDR10+ / HLG**：静态/动态元数据直通；HEVC / AV1 等，`.mkv` / `.mp4`
- 原理：`--vo=gpu-next` + `--target-colorspace-hint=yes` 把 PQ/BT.2020 与峰值亮度直通给 macOS；渲染层为 `rgba16Float`（16-bit 浮点 EDR）；`hwdec=videotoolbox` 在媒体引擎上硬解 4K HEVC DV。SDR 屏由 libplacebo 高质量 tone-map。

实测输出（真实 4K Dolby Vision 文件，`NP_LOG=1`）：

```text
● Video --vid=1  '4K Dolby Vision' (hevc 3840x1634 25 fps)
Using hardware decoding (videotoolbox).
Decoder format: 3840x1634 videotoolbox[p010] dolbyvision/bt.2020/pq/full
[vo/gpu-next/mac] Metal layer pixel format changed: rgba16Float
```

### 📦 环境要求

| 项目 | 要求 |
|---|---|
| 系统 | macOS 12+（Apple Silicon） |
| 工具链 | Xcode Command Line Tools（**无需完整 Xcode**）：`xcode-select --install` |
| 运行时 | libmpv（Homebrew）：`brew install mpv` |

### 🔨 安装与构建

```bash
git clone https://github.com/Maple728/NanoPlayer.git
cd NanoPlayer
brew install mpv pkg-config
./build-app.sh
open NanoPlayer.app
```

`build-app.sh` 用 `swiftc` 直接编译（无需完整 Xcode）、组装 `NanoPlayer.app` 并 ad-hoc 签名。路径由 `pkg-config` 定位，故在 Apple Silicon（`/opt/homebrew`）与 Intel（`/usr/local`）上都能构建（各自编译本机架构）。此产物依赖本机 Homebrew libmpv，仅供本机运行。

### 📦 分发（自包含）

```bash
./bundle-dist.sh
```

把 **libmpv 全部递归依赖 + MoltenVK** 打进 `Contents/Frameworks/` 并改写为 `@rpath`，附带 bundle 内 Vulkan ICD 清单——**目标机无需 Homebrew/mpv 即可运行**（实测运行时 0 处引用 `/opt/homebrew`）。产出 `NanoPlayer.app`（~61MB）+ `NanoPlayer.zip`（~27MB）。对外分发需用你的 Apple 开发者账号签名 + 公证（`DEV_ID=... ./bundle-dist.sh` 后 `notarytool` / `stapler`，命令见英文节）。当前为本机单架（`arm64`）；universal 需双架构依赖再 `lipo`。

### ▶️ 使用

- **⌘O / 菜单「文件 → 打开」**：选文件（单文件触发整季展开，从所选集起播）
- **拖文件到窗口** / **Finder「打开方式」**：同样触发整季展开
- 空闲（未播放）时窗口显示 NanoPlayer 自己的 logo（而非 mpv 默认启动画面）

### ⌨️ 快捷键与鼠标

| 操作 | 动作 |
|---|---|
| `Space` | 播放 / 暂停 |
| `F` | 全屏切换 |
| `→` / `←` | 快进 / 后退 5 秒（精确） |
| `⌘→` / `⌘←` | 下一集 / 上一集（`>` / `<` 兜底） |
| `↑` / `↓` | 音量 ±5　·　`M` 静音 |
| 单击 / 双击画面 | 暂停 / 全屏 |
| 鼠标移动 | 唤出 mpv 原生 OSC |

### 🧱 架构

> **关键设计决策**：此 mpv 为 Vulkan/Metal-only，其 macOS 后端**不支持 `--wid` 把视频嵌入宿主视图**（强嵌会自建第二个窗口）。为保住 `gpu-next` + HDR 直通，NanoPlayer 让 **mpv 拥有那唯一的视频窗口**（含原生 OSC 与鼠标），宿主只用 libmpv 叠加行为；键盘由宿主捕获后转发为 mpv 命令（嵌入态下 mpv 窗口收不到键盘，与 IINA 等 libmpv 宿主做法一致）。

```
Sources/
├── Cmpv/                     # libmpv C API 的 Clang 模块（pkg-config 定位）
└── NanoPlayer/
    ├── App/   main.swift / AppDelegate.swift / IconLock.swift / KeyboardHandler.swift
    ├── Core/  MPV.swift              # libmpv C API 的 Swift 薄封装
    ├── Player/ Player.swift          # mpv 驱动：选项、整季展开、事件循环、播放控制
    └── Episode/ EpisodeMatcher.swift # 剧集识别 + 同前缀聚类 + 数值排序（纯函数）
```
另有 `icon/make-icon.swift`（生成 App 图标）与 `scripts/idle-logo.lua`（自定义空闲画面）。所有 libmpv 调用都在 `Player` 的串行队列上，UI/键盘在主线程，二者经命令解耦。

### 🐞 调试

```bash
NP_LOG=1  ./NanoPlayer.app/Contents/MacOS/NanoPlayer movie.mkv           # mpv 完整日志
NP_IPC=/tmp/np.sock ./NanoPlayer.app/Contents/MacOS/NanoPlayer movie.mkv # 开启 JSON IPC
```

### ⚠️ 已知限制

- **编号电影误并**：同目录 `Movie1/Movie2/Movie3` 这类「前缀+数字」无关影片会被当成一个系列。
- 同一已展开系列再次**拖入**单文件不会重新整季（菜单「打开」会）。
- 无自定义可视播放列表面板（mpv 原生 OSC 不含播放列表）。

### 参与 / 许可

欢迎贡献，见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [行为准则](CODE_OF_CONDUCT.md)；安全问题见 [SECURITY.md](SECURITY.md)。本项目链接 libmpv（GPL），以 **GPL-3.0-or-later** 授权，见 [LICENSE](LICENSE)。

---

## English

NanoPlayer is a tiny, no-fuss player built around [libmpv](https://github.com/mpv-player/mpv). Its one job is to play **Dolby Vision and HDR video correctly on macOS** — preserving `mpv --vo=gpu-next --target-colorspace-hint=yes` so HDR metadata passes straight through to the display instead of being tone-mapped down to SDR. On top of that it adds just enough convenience for binge-watching a series.

### ✨ Features

- 🎞️ **Dolby Vision passthrough (the headline feature).** Keeps the `gpu-next` + `target-colorspace-hint` pipeline so **4K Dolby Vision** plays with real HDR on XDR / HDR displays — not tone-mapped to SDR. See the **Dolby Vision / HDR** section below.
- 🌈 **Full HDR family.** HDR10 and HLG pass through too; automatic tone-mapping on SDR screens.
- ⚡ **Apple Silicon hardware decode.** `hwdec=videotoolbox`; `gpu-next` via libplacebo / MoltenVK / Metal.
- 📺 **Binge-watching, done right.** Open any episode → the **whole season in that folder is added, ordered by episode number** (`SxxExx`, `1x04`, `E04`, `第04集`) → **starts from the episode you opened** (`insert-at`, no reload/flicker) → **auto-plays the next episode**.
- ⌨️ **IINA-aligned shortcuts** + 🖱️ **native mpv OSC / mouse control**.
- 🪶 **No bloat.** Pure Swift + AppKit + libmpv. A single `.app`, no Electron.

### 🎞️ Dolby Vision / HDR

> **This is the whole point of NanoPlayer.** Correct, lossless Dolby Vision playback is rare on macOS; NanoPlayer treats it as priority #1.

- **Dolby Vision**: Profiles 5 / 7 / 8 (RPU dynamic metadata, via mpv 0.41 + libplacebo)
- **HDR10 / HDR10+ / HLG**: static & dynamic metadata passthrough; HEVC / AV1, `.mkv` / `.mp4`
- How: `--vo=gpu-next` + `--target-colorspace-hint=yes` forward PQ / BT.2020 + peak brightness to macOS; the render layer is `rgba16Float` (16-bit float EDR); `hwdec=videotoolbox` decodes 4K HEVC DV on the media engine. SDR screens get high-quality tone-mapping from libplacebo.

Verified output (real 4K Dolby Vision file, `NP_LOG=1`):

```text
● Video --vid=1  '4K Dolby Vision' (hevc 3840x1634 25 fps)
Using hardware decoding (videotoolbox).
Decoder format: 3840x1634 videotoolbox[p010] dolbyvision/bt.2020/pq/full
[vo/gpu-next/mac] Metal layer pixel format changed: rgba16Float
```

### Requirements

| Item | Requirement |
|---|---|
| OS | macOS 12+ (Apple Silicon) |
| Toolchain | Xcode Command Line Tools (**no full Xcode**): `xcode-select --install` |
| Runtime | libmpv via Homebrew: `brew install mpv` |

### Install & Build

```bash
git clone https://github.com/Maple728/NanoPlayer.git
cd NanoPlayer
brew install mpv pkg-config
./build-app.sh
open NanoPlayer.app
```

`build-app.sh` compiles with `swiftc` (no full Xcode), assembles `NanoPlayer.app`, and ad-hoc signs it. Paths come from `pkg-config`, so it builds on both Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`). This build depends on the machine's Homebrew libmpv and is for local use.

### Distribution

```bash
./bundle-dist.sh
```

Bundles **libmpv + all (transitive) dependencies + MoltenVK** into `Contents/Frameworks/`, rewrites install names to `@rpath`, and ships a bundle-local Vulkan ICD — so the app runs on Macs **without Homebrew/mpv** (verified: zero runtime `/opt/homebrew` references). Produces `NanoPlayer.app` (~61 MB) and `NanoPlayer.zip` (~27 MB).

Sign & notarize for public distribution (needs your Apple Developer account):

```bash
DEV_ID="Developer ID Application: Your Name (TEAMID)" ./bundle-dist.sh
xcrun notarytool submit NanoPlayer.zip --apple-id you@example.com \
      --team-id TEAMID --password APP_SPECIFIC_PW --wait
xcrun stapler staple NanoPlayer.app
ditto -c -k --keepParent NanoPlayer.app NanoPlayer.zip
```

> Without notarization, recipients must right-click → **Open** once. The build is single-arch (`arm64`); a universal build needs dual-arch dependencies `lipo`-merged.

### Usage

- **⌘O / File → Open**: pick a file (a single file expands the whole season, starting at the chosen episode).
- **Drag onto the window** / **Finder → Open With**: same season expansion.
- When idle, the window shows NanoPlayer's own logo instead of mpv's default splash.

### Keyboard & Mouse

| Input | Action |
|---|---|
| `Space` | Play / pause |
| `F` | Toggle fullscreen |
| `→` / `←` | Seek ±5 s (exact) |
| `⌘→` / `⌘←` | Next / previous episode (`>` / `<` also work) |
| `↑` / `↓` | Volume ±5　·　`M` mute |
| Click / Double-click | Play-pause / fullscreen |
| Mouse move | Reveal the native OSC |

### Architecture

> **Key design decision.** This mpv build is Vulkan/Metal-only and its macOS backend does **not** support embedding the video via `--wid` (forcing it spawns a second window). To keep `gpu-next` + HDR passthrough, mpv **owns the single video window** (native OSC + mouse); the host uses libmpv to layer behavior on top, and captures the keyboard, forwarding it to mpv as commands (an embedded mpv window receives no key events — same as IINA).

```
Sources/
├── Cmpv/                     # Clang module for the libmpv C API (via pkg-config)
└── NanoPlayer/
    ├── App/   main.swift / AppDelegate.swift / IconLock.swift / KeyboardHandler.swift
    ├── Core/  MPV.swift              # thin Swift wrapper over libmpv's C client API
    ├── Player/ Player.swift          # mpv driver: options, season expansion, event loop
    └── Episode/ EpisodeMatcher.swift # episode parsing + same-prefix grouping + numeric sort
```
Plus `icon/make-icon.swift` (app icon) and `scripts/idle-logo.lua` (custom idle screen). Every libmpv call runs on `Player`'s serial queue; UI/keyboard live on the main thread, decoupled via commands.

### Debugging

```bash
NP_LOG=1  ./NanoPlayer.app/Contents/MacOS/NanoPlayer movie.mkv
NP_IPC=/tmp/np.sock ./NanoPlayer.app/Contents/MacOS/NanoPlayer movie.mkv
```

### Known limitations

- **Numbered movies get grouped** — unrelated `Movie1 / Movie2 / Movie3` in one folder are treated as a series.
- Re-**dragging** a single file of an already-expanded series won't re-expand it (the **Open** menu will).
- No custom visual playlist panel (mpv's native OSC has none).

### Contributing / License

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md); security reports in [SECURITY.md](SECURITY.md). Licensed under **GPL-3.0-or-later** (NanoPlayer links GPL libmpv). See [LICENSE](LICENSE).

## Acknowledgements

- [mpv](https://mpv.io) / [libmpv](https://github.com/mpv-player/mpv) — playback & rendering core
- [libplacebo](https://code.videolan.org/videolan/libplacebo) — the `gpu-next` rendering pipeline
- [IINA](https://github.com/iina/iina) — interaction & design reference
