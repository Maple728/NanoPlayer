## 变更说明

<!-- 简要说明这个 PR 做了什么、为什么这么做。 -->

## 关联 issue

<!-- 例如 Closes #123 / Relates to #123 -->

## 改动类型

- [ ] Bug 修复
- [ ] 新功能
- [ ] 重构 / 代码整理（无行为变化）
- [ ] 文档
- [ ] 构建 / CI

## 自测清单

- [ ] `./build-app.sh` 在本机通过（末尾出现 `==> done: NanoPlayer.app`）
- [ ] 手动验证：用真实媒体打开并正常播放
- [ ] 若涉及 HDR / Dolby Vision：在 HDR 屏上确认 `current-vo=gpu-next`、
      `video-params/primaries=bt.2020`、`video-params/gamma=pq`（用 `NP_IPC` 查询）
- [ ] 若涉及剧集识别 / 连播：验证整季入列顺序、从所选集起播、自动连播
- [ ] 代码风格符合 `.editorconfig`（4 空格缩进、文件末尾换行、无行尾空格）
- [ ] 未提交构建产物（`NanoPlayer.app/`、`NanoPlayer.zip`、`*.o`、`.DS_Store`）

## 补充说明

<!-- 截图、需要 reviewer 特别关注的点、已知限制等。 -->
