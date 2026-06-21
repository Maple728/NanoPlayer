# 为 NanoPlayer 贡献

感谢你愿意为 NanoPlayer 出力。NanoPlayer 是一个基于 [libmpv](https://mpv.io) 的
macOS 原生视频播放器（Swift + AppKit），主打 Dolby Vision / HDR 直通，专为 Apple
Silicon 优化。本文档说明如何在本机构建、调试，以及如何提交改动。

## 环境要求

| 项 | 要求 |
|---|---|
| 系统 | macOS 12+（推荐 Apple Silicon；Intel 亦可各自编译本机架构） |
| 工具链 | Xcode Command Line Tools（**无需完整 Xcode**）：`xcode-select --install` |
| 运行时 | libmpv（Homebrew） |

```bash
brew install mpv pkg-config
```

`pkg-config` 用于定位 libmpv 的头文件与库路径，因此构建脚本在
`/opt/homebrew`（Apple Silicon）和 `/usr/local`（Intel）上都能工作，无需硬编码路径。

## 本机构建

```bash
./build-app.sh
```

脚本用 `swiftc` 直接编译 `Sources/NanoPlayer` 下的全部 Swift 源码（绕过 SPM 对完整
Xcode 的依赖），组装出 `NanoPlayer.app` 并做 ad-hoc 签名。产物链接的是本机 Homebrew
的 libmpv，仅供本机运行。构建成功的标志是末尾打印 `==> done: NanoPlayer.app`。

## 自包含分发

如果要把 app 发给没有装 Homebrew / mpv 的人：

```bash
./bundle-dist.sh
```

它会在普通构建之后，把 libmpv 及其全部（递归）依赖、以及 gpu-next 需要的 MoltenVK
打进 `Contents/Frameworks/`，把所有 install name 改写为 `@rpath`，再附一份 bundle 内
Vulkan ICD 清单。产出 `NanoPlayer.app`（~61MB）+ `NanoPlayer.zip`（~27MB）。

> 这两个产物（`NanoPlayer.app/`、`NanoPlayer.zip`）以及 `*.o`、`.DS_Store` 都已在
> `.gitignore` 中忽略，**请勿提交**。

对外正式分发还需用 Developer ID 签名并公证，详见
[`README.md`](README.md) 的「分发」一节与 `bundle-dist.sh` 末尾的提示。

## 运行与调试

通过环境变量开启调试输出：

```bash
# 打印 mpv 完整日志
NP_LOG=1 ./NanoPlayer.app/Contents/MacOS/NanoPlayer movie.mkv

# 开启 mpv 的 JSON IPC（可用 socket 查询/控制属性）
NP_IPC=/tmp/x.sock ./NanoPlayer.app/Contents/MacOS/NanoPlayer movie.mkv
```

IPC 开启后，例如查询当前视频后端与 HDR 直通是否生效：

```bash
printf '{"command":["get_property","current-vo"]}\n'            | nc -U /tmp/x.sock  # gpu-next
printf '{"command":["get_property","video-params/primaries"]}\n' | nc -U /tmp/x.sock  # bt.2020
printf '{"command":["get_property","video-params/gamma"]}\n'     | nc -U /tmp/x.sock  # pq
```

## 代码风格

遵循现有 Swift 源码的约定：

- **缩进**：4 个空格，不用 Tab。
- **注释解释「为什么」，不是「是什么」**。比如 `Player.swift` 里解释了为什么让
  mpv 拥有唯一视频窗口、为什么键盘事件由宿主转发——这类设计取舍的说明是有价值的注释。
- **文件末尾保留一个换行**；不要留行尾空格。仓库提供了 `.editorconfig`，请让你的编辑器
  按它工作。
- 保持现有的分层结构：`App/`（应用层）、`Core/`（libmpv 薄封装）、
  `Player/`（mpv 驱动）、`Episode/`（剧集识别，纯函数）。新代码请放进职责相符的目录。
- 纯函数（如 `EpisodeMatcher`）应保持无副作用、易测试。

## 分支与 PR 流程

1. 从 `main` 切出特性分支：`git checkout -b feature/简短描述` 或 `fix/简短描述`。
2. 改动尽量聚焦单一主题；功能改动与格式整理分开提交。
3. 推送前务必本机跑通 `./build-app.sh`（CI 也会在 macOS 上跑同样的构建）。
4. 发起 PR 时填写 PR 模板，关联相关 issue，并勾选自测清单。

## 提交信息规范

- 第一行是简洁的祈使句摘要（建议 ≤ 72 字符），例如
  `Fix episode sort order for double-digit numbers`。
- 需要时空一行后写正文，解释**为什么**这么改、影响范围、以及如何验证。
- 一个提交只做一件事，便于回溯与回滚。

## 报告问题

提交 bug 前请尽量带上：复现步骤、期望/实际行为、macOS 版本、`mpv --version` 输出，
以及 `NP_LOG=1` 的相关日志片段。详见
[`.github/ISSUE_TEMPLATE/bug_report.md`](.github/ISSUE_TEMPLATE/bug_report.md)。

## 许可

本项目链接 libmpv（GPL），因此以 **GPL-3.0-or-later** 授权。提交贡献即表示你同意你的
改动以同样的许可证发布。
