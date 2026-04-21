import AppKit
import Foundation

@MainActor
final class WindowNestModel: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var windowControlReady = false
    @Published private(set) var statusMessage = AppStrings.initialStatus
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var accessibilityCheckLabel = AppStrings.accessibilityLabel(false)
    @Published private(set) var windowControlLabel = AppStrings.windowControlLabel(accessibilityGranted: false, ready: false)
    @Published private(set) var enabledLayoutKinds: Set<DragLayoutTileKind> = []

    let version = "0.4.22"

    private let windowManager = WindowManager()
    private let launchAtLoginService = LaunchAtLoginService()
    private var windowDragLayoutService: WindowDragLayoutService?
    private static let enabledLayoutKindsDefaultsKey = "WindowNestEnabledLayoutKinds"
    private static let defaultLayoutKinds: Set<DragLayoutTileKind> = Set(DragLayoutTileKind.allCases)

    init() {
        accessibilityGranted = AccessibilityService.isTrusted(prompt: false)
        windowControlReady = windowManager.hasResolvableWindowTarget()
        launchAtLoginEnabled = launchAtLoginService.isEnabled()
        enabledLayoutKinds = Self.loadEnabledLayoutKinds()
        windowDragLayoutService = WindowDragLayoutService(
            onStatusMessage: { [weak self] message in
                self?.statusMessage = message
            },
            onDebugStatusChange: { _ in }
        )
        windowDragLayoutService?.updateEnabledLayoutKinds(enabledLayoutKinds)
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

    func isLayoutKindEnabled(_ kind: DragLayoutTileKind) -> Bool {
        enabledLayoutKinds.contains(kind)
    }

    func setLayoutKind(_ kind: DragLayoutTileKind, enabled: Bool) {
        if enabled {
            enabledLayoutKinds.insert(kind)
        } else {
            enabledLayoutKinds.remove(kind)
        }

        persistEnabledLayoutKinds()
        windowDragLayoutService?.updateEnabledLayoutKinds(enabledLayoutKinds)
    }

    func openAccessibilitySettings() {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    var versionLabel: String {
        AppStrings.versionLabel(version)
    }

    var layouts: [WindowLayoutPreset] {
        DragLayoutTileKind.allCases
            .filter { enabledLayoutKinds.contains($0) }
            .flatMap { $0.presets }
    }

    var layoutKinds: [DragLayoutTileKind] {
        DragLayoutTileKind.allCases
    }

    private static func loadEnabledLayoutKinds() -> Set<DragLayoutTileKind> {
        guard let rawValues = UserDefaults.standard.array(forKey: enabledLayoutKindsDefaultsKey) as? [String] else {
            return defaultLayoutKinds
        }

        let resolved = Set(rawValues.compactMap(DragLayoutTileKind.init(rawValue:)))
        return resolved.isEmpty ? defaultLayoutKinds : resolved
    }

    private func persistEnabledLayoutKinds() {
        let rawValues = DragLayoutTileKind.allCases
            .filter { enabledLayoutKinds.contains($0) }
            .map(\.rawValue)
        UserDefaults.standard.set(rawValues, forKey: Self.enabledLayoutKindsDefaultsKey)
    }
}
