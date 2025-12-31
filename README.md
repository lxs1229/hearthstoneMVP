# hearthstoneMVP
这是一个开源的 macOS 版本的炉石传说酒馆战棋辅助工具（阶段一：屏幕识别 + 基础策略提示）。

## 运行方式
1. macOS 13+（使用 ScreenCaptureKit）。
2. 需要授予“屏幕录制”权限。
3. 使用 SwiftPM 构建运行：

```bash
swift build
swift run
```

## 当前已实现
- 屏幕捕获与 OCR（金币/回合/血量/酒馆等级）。
- 简版策略引擎：节奏与保血提示。
- 悬浮提示窗口（置顶、可拖动）。

## 配置
默认识别区域在 `Sources/HearthstoneMVP/Capture/CaptureConfig.swift`，请根据实际分辨率与 UI 位置调整 `normalizedRect`。
