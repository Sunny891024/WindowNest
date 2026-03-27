import AppKit
import Combine
import Foundation

@MainActor
final class WindowNestModel: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var windowControlReady = false
    @Published private(set) var statusMessage = "拖动窗口时会显示浮动布局板，松手后即可自动贴靠。"
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var debugStatus = "等待拖动"
    @Published private(set) var accessibilityCheckLabel = "辅助功能授权：未知"
    @Published private(set) var windowControlLabel = "窗口控制能力：未知"

    let layouts: [WindowLayoutPreset] = [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize]
    let versionLabel = "版本 0.3.0"

    private let windowManager = WindowManager()
    private let launchAtLoginService = LaunchAtLoginService()
    private var windowDragLayoutService: WindowDragLayoutService?

    init() {
        accessibilityGranted = AccessibilityService.isTrusted(prompt: false)
        windowControlReady = windowManager.hasResolvableWindowTarget()
        launchAtLoginEnabled = launchAtLoginService.isEnabled()
        windowDragLayoutService = WindowDragLayoutService(
            onStatusMessage: { [weak self] message in
                self?.statusMessage = message
            },
            onDebugStatusChange: { [weak self] debugStatus in
                self?.debugStatus = debugStatus
            }
        )
    }

    func refreshPermissions(prompt: Bool = false) {
        if prompt {
            AccessibilityService.requestTrustIfNeeded()
        }

        accessibilityGranted = AccessibilityService.isTrusted(prompt: false)
        windowControlReady = windowManager.hasResolvableWindowTarget()
        accessibilityCheckLabel = "辅助功能授权：\(accessibilityGranted ? "已开启" : "未开启")"
        windowControlLabel = accessibilityGranted
            ? "窗口控制状态：\(windowControlReady ? "已找到目标窗口" : "等待目标窗口")"
            : "窗口控制状态：权限未开启"
        windowDragLayoutService?.refreshPermissionsAllowed(accessibilityGranted)
        if accessibilityGranted && windowControlReady {
            statusMessage = "拖动窗口时会显示“左/右屏、全屏、上/下屏”三个浮动区域。"
        } else if accessibilityGranted {
            statusMessage = "辅助功能已授权。当前只是还没锁定目标窗口，先点一下要操作的窗口再试。"
        } else {
            statusMessage = "当前辅助功能未开启。浮层可能出现，但贴靠不会真正生效。"
        }
    }

    func requestPermissions() {
        refreshPermissions(prompt: true)
        openAccessibilitySettings()
    }

    func apply(_ layout: WindowLayoutPreset) {
        refreshPermissions(prompt: false)

        do {
            try windowManager.apply(layout: layout)
            statusMessage = "已应用\(layout.title)。"
        } catch {
            if !windowManager.canInteractWithWindows() {
                statusMessage = "当前还不能真正控制系统窗口。请确认“辅助功能”已对 WindowNest 生效。"
            } else {
                statusMessage = error.localizedDescription
            }
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginService.isEnabled()
            statusMessage = launchAtLoginEnabled ? "已开启开机启动。" : "已关闭开机启动。"
        } catch {
            launchAtLoginEnabled = launchAtLoginService.isEnabled()
            statusMessage = error.localizedDescription
        }
    }

    func openAccessibilitySettings() {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func showTestOverlay() {
        windowDragLayoutService?.showTestOverlay()
        statusMessage = "已手动显示浮层 3 秒。"
    }

    func runStartupChecks() {
        refreshPermissions(prompt: true)
        if !accessibilityGranted {
            openAccessibilitySettings()
        }
    }
}
