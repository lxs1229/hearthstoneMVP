### 对话记录摘要（2024-12-31）

目标：做一款 macOS 原生的《炉石传说》酒馆战棋对局内实时辅助工具，功能强优先，中文提示，完全自动识别游戏界面。

阶段一完成内容（骨架）：
- Swift/SwiftUI 原生应用，使用 SwiftPM 构建。
- ScreenCaptureKit 捕获屏幕。
- Vision OCR 识别金币/回合/血量/酒馆等级。
- 简版策略引擎：节奏与保血提示。
- 悬浮置顶提示窗（可拖动）。

关键文件位置：
- 入口：Sources/HearthstoneMVP/HearthstoneMVPApp.swift
- UI：Sources/HearthstoneMVP/UI/ContentView.swift
- 捕获与OCR：Sources/HearthstoneMVP/Capture/CaptureManager.swift
- 识别区域配置：Sources/HearthstoneMVP/Capture/CaptureConfig.swift
- 策略引擎：Sources/HearthstoneMVP/Strategy/StrategyEngine.swift
- 说明文档：README.md

运行方式：
1) macOS 13+
2) 授权“屏幕录制”权限
3) swift build / swift run

下一步建议：
1) 校准识别区域（CaptureConfig 中的 normalizedRect）
2) 跑起来验证 OCR 准确率
3) 继续扩展：商店随从识别与推荐逻辑

### 对话记录摘要（补充）

新增与修复：
- 添加 `.gitignore` 忽略 `.build/`，避免快照提示。
- 增加“校准预览”功能：悬浮窗显示实时截图并叠加识别区域框。
- 支持预览开关与预览图像流转，便于调整 `normalizedRect`。
- 修复窗口无法点击：让 `WindowAccessor` overlay 不拦截鼠标事件。

新/改动文件：
- `.gitignore`
- `Sources/HearthstoneMVP/Capture/CaptureManager.swift`
- `Sources/HearthstoneMVP/Model/AppModel.swift`
- `Sources/HearthstoneMVP/UI/CalibrationPreviewView.swift`
- `Sources/HearthstoneMVP/UI/ContentView.swift`

运行与测试反馈：
- `swift run` 编译成功（有一条 OCR 相关警告，未处理）。
- 程序启动后悬浮窗出现，但最初无法点击，已修复。
