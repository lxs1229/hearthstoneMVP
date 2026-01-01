import SwiftUI
import CoreGraphics
import Foundation
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showFullLogPath = false
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("战棋实时辅助")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(model.isCapturing ? "停止" : "开始") {
                    model.isCapturing ? model.stopCapture() : model.startCapture()
                }
                .keyboardShortcut(" ", modifiers: [])
            }

            HStack {
                Toggle("日志模式", isOn: $model.usePowerLog)
                    .font(.system(size: 12))
                Spacer()
            }

            if model.usePowerLog {
                Text("使用 Power.log 解析对局。未更新时请确认已启用日志并重启游戏。")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Text("识别状态：\(statusText())")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                if let last = model.lastUpdate {
                    Text("最近更新：\(Self.timeFormatter.string(from: last))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                if let name = model.localPlayerName {
                    Text("本地玩家：\(name)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                if let path = model.powerLogPath {
                    Text("日志路径：")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Button("复制") {
                            copyToPasteboard(path)
                        }
                        .font(.system(size: 9))

                        Button(showFullLogPath ? "收起" : "展开") {
                            showFullLogPath.toggle()
                        }
                        .font(.system(size: 9))

                        Spacer()
                    }

                    Text(path)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(showFullLogPath ? nil : 2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if !model.usePowerLog && !CGPreflightScreenCaptureAccess() {
                Text("需要屏幕录制权限才能识别游戏界面。")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Button("请求权限") {
                    model.requestScreenRecordingAccess()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(model.advice.headline)
                    .font(.system(size: 14, weight: .medium))
                ForEach(model.advice.details, id: \.self) { item in
                    Text("• \(item)")
                        .font(.system(size: 12))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("对局信息")
                    .font(.system(size: 12, weight: .semibold))
                Text("回合：\(valueText(model.state.turn))")
                Text("金币：\(valueText(model.state.gold))")
                Text("血量：\(valueText(model.state.health))")
                Text("酒馆等级：\(valueText(model.state.tavernTier))")
                Text("阶段：\(phaseText(model.state.phase))")
                Text("模式：\(modeText(model.state.mode))")
                Text("系统步骤：\(stepText(model.state.step))")
            }
            .font(.system(size: 12))

            Divider()

            if !model.usePowerLog {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("校准预览")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Toggle("显示", isOn: $model.showPreview)
                            .labelsHidden()
                    }

                    if model.showPreview {
                        if let image = model.previewImage {
                            CalibrationPreviewView(image: image, regions: model.config.regions)
                        } else {
                            Text("开启捕获后将显示预览画面。")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(model.config.regions.enumerated()), id: \.offset) { _, region in
                                Text("\(region.name)：\(rectText(region.normalizedRect))")
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(Color.black.opacity(0.75))
        .foregroundColor(.white)
        .cornerRadius(10)
        .overlay(
            WindowAccessor { window in
                guard let window else { return }
                OverlayWindowConfigurator.apply(to: window)
            }
            .allowsHitTesting(false)
        )
    }

    private func valueText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    private func rectText(_ rect: CGRect) -> String {
        String(format: "x:%.3f y:%.3f w:%.3f h:%.3f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    }

    private func phaseText(_ phase: GamePhase?) -> String {
        switch phase {
        case .shopping:
            return "招募"
        case .combat:
            return "战斗"
        case .unknown:
            return "未知"
        case .none:
            return "—"
        }
    }

    private func stepText(_ step: String?) -> String {
        guard let step, !step.isEmpty else { return "—" }
        return step
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func statusText() -> String {
        if model.lastUpdate == nil {
            return "等待日志"
        }
        return "已更新"
    }

    private func modeText(_ mode: GameMode?) -> String {
        guard let mode else { return "—" }
        return mode.displayName
    }
}
