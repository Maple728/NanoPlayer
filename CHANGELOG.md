# Changelog

本项目所有值得注意的改动都会记录在本文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.1.0] - 2026-06-21

首个公开版本。

### Added

- **Dolby Vision / HDR10 / HLG 直通**：基于 `vo=gpu-next` +
  `target-colorspace-hint=yes`，把片源的 PQ/BT.2020 元数据直通给 macOS 的 EDR 显示
  系统，在 XDR / HDR 屏上呈现真正的高动态范围，SDR 屏自动高质量 tone-map。
- **Apple Silicon VideoToolbox 硬解**：默认 `hwdec=videotoolbox`，gpu-next 经
  libplacebo / MoltenVK / Metal 渲染，低功耗流畅播放 4K HEVC Dolby Vision。
- **同前缀整季自动入列**：打开任意一集，自动把同目录的整季按集数顺序加入播放列表，
  识别 `SxxExx` / `1x04` / `E04` / `第04集` 等命名并做数值排序。
- **从所选集起播 + 自动连播**：用 `insert-at` 插入播放列表，不重载、不闪烁；播完
  自动连播下一集。
- **与 IINA 对齐的快捷键**：空格播放/暂停、F 全屏、方向键精确快进/后退、⌘→/⌘← 切集、
  上下键音量、M 静音等。
- **鼠标交互与 mpv 原生 OSC**：单击播放/暂停、双击全屏、移动鼠标唤出底部 OSC。
- **自定义空闲画面**：无媒体时显示 NanoPlayer logo 空闲画面（`scripts/idle-logo.lua`）。
- **自定义 App 图标**：内置 `Resources/AppIcon.icns`，由 `icon/make-icon.swift` 生成。
- **自包含可分发打包**：`bundle-dist.sh` 把 libmpv 全部递归依赖与 MoltenVK 打进
  bundle 并改写为 `@rpath`，目标机无需安装 Homebrew / mpv 即可运行。

[Unreleased]: https://github.com/Maple728/NanoPlayer/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Maple728/NanoPlayer/releases/tag/v0.1.0
