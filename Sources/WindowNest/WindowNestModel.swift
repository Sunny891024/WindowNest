import AppKit
import Combine
import Foundation

@MainActor
final class WindowNestModel: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var windowControlReady = false
    @Published private(set) var statusMessage = AppStrings.initialStatus
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var debugStatus = AppStrings.waitingDrag
    @Published private(set) var accessibilityCheckLabel = AppStrings.accessibilityLabel(false)
    @Published private(set) var windowControlLabel = AppStrings.windowControlLabel(accessibilityGranted: false, ready: false)

    let layouts: [WindowLayoutPreset] = [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize]
    let version = "0.4.5"

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
        accessibilityCheckLabel = AppStrings.accessibilityLabel(accessibilityGranted)
        windowControlLabel = AppStrings.windowControlLabel(accessibilityGranted: accessibilityGranted, ready: windowControlReady)
        windowDragLayoutService?.refreshPermissionsAllowed(accessibilityGranted)
        if accessibilityGranted && windowControlReady {
            statusMessage = AppStrings.dragReadyStatus
        } else if accessibilityGranted {
            statusMessage = AppStrings.waitingForTargetStatus
        } else {
            statusMessage = AppStrings.missingAccessStatus
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
            statusMessage = AppStrings.layoutApplied(layout.title)
        } catch {
            if !windowManager.canInteractWithWindows() {
                statusMessage = AppStrings.cannotControlWindows
            } else {
                statusMessage = error.localizedDescription
            }
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginService.isEnabled()
            statusMessage = launchAtLoginEnabled ? AppStrings.launchAtLoginEnabledStatus : AppStrings.launchAtLoginDisabledStatus
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
        statusMessage = AppStrings.overlayShowing(nil)
    }

    func runStartupChecks() {
        refreshPermissions(prompt: false)
    }

    var versionLabel: String {
        AppStrings.versionLabel(version)
    }
}
