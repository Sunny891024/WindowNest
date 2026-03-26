import AppKit
import Combine
import Foundation

@MainActor
final class WindowNestModel: ObservableObject {
    @Published private(set) var accessibilityGranted = AccessibilityService.isTrusted(prompt: false)
    @Published private(set) var statusMessage = "Choose a layout for the focused window."
    @Published private(set) var launchAtLoginEnabled = false

    let layouts = WindowLayoutPreset.allCases
    let hotKeys = HotKeyDefinition.defaults

    private let windowManager = WindowManager()
    private let launchAtLoginService = LaunchAtLoginService()
    private var hotKeyService: HotKeyService?

    init() {
        launchAtLoginEnabled = launchAtLoginService.isEnabled()
        hotKeyService = HotKeyService { [weak self] layout in
            Task { @MainActor in
                self?.apply(layout)
            }
        }
    }

    func refreshPermissions(prompt: Bool = false) {
        accessibilityGranted = AccessibilityService.isTrusted(prompt: prompt)
        if accessibilityGranted {
            statusMessage = "Accessibility access is enabled."
        } else {
            statusMessage = "Enable Accessibility access to control other apps' windows."
        }
    }

    func requestPermissions() {
        refreshPermissions(prompt: true)
        openAccessibilitySettings()
    }

    func apply(_ layout: WindowLayoutPreset) {
        refreshPermissions(prompt: false)

        guard accessibilityGranted else {
            statusMessage = "Accessibility access is still disabled."
            return
        }

        do {
            try windowManager.apply(layout: layout)
            statusMessage = "\(layout.title) applied to the focused window."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginService.isEnabled()
            statusMessage = launchAtLoginEnabled ? "WindowNest will launch at login." : "Launch at login disabled."
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
}
