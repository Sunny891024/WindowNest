import AppKit
import Combine
import Foundation

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

@MainActor
final class WindowNestModel: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var windowControlReady = false
    @Published private(set) var statusMessage = AppStrings.initialStatus
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var debugStatus = AppStrings.waitingDrag
    @Published private(set) var debugModeEnabled = false
    @Published private(set) var debugReport = AppStrings.debugSnapshotUnavailable
    @Published private(set) var debugLog: [DebugLogEntry] = []
    @Published private(set) var accessibilityCheckLabel = AppStrings.accessibilityLabel(false)
    @Published private(set) var windowControlLabel = AppStrings.windowControlLabel(accessibilityGranted: false, ready: false)

    let layouts: [WindowLayoutPreset] = [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize]
    let version = "0.4.16"

    private static let debugModeDefaultsKey = "WindowNestDebugMode"
    private static let debugLogLimit = 20

    private let windowManager = WindowManager()
    private let launchAtLoginService = LaunchAtLoginService()
    private var windowDragLayoutService: WindowDragLayoutService?
    private let debugTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init() {
        UserDefaults.standard.set(false, forKey: Self.debugModeDefaultsKey)
        accessibilityGranted = AccessibilityService.isTrusted(prompt: false)
        windowControlReady = windowManager.hasResolvableWindowTarget()
        launchAtLoginEnabled = launchAtLoginService.isEnabled()
        windowDragLayoutService = WindowDragLayoutService(
            onStatusMessage: { [weak self] message in
                self?.statusMessage = message
            },
            onDebugStatusChange: { [weak self] debugStatus in
                self?.debugStatus = debugStatus
                self?.appendDebugLog(debugStatus)
                if self?.debugModeEnabled == true {
                    self?.refreshDebugReport()
                }
            }
        )
        if debugModeEnabled {
            refreshDebugReport()
        }
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

    func toggleDebugMode(_ enabled: Bool) {
        debugModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.debugModeDefaultsKey)

        if enabled {
            refreshDebugReport()
        } else {
            debugReport = AppStrings.debugSnapshotUnavailable
        }
    }

    func refreshDebugReport() {
        guard debugModeEnabled else {
            debugReport = AppStrings.debugSnapshotUnavailable
            return
        }

        let snapshot = windowDragLayoutService?.debugSnapshot()
        debugReport = makeDebugReport(snapshot: snapshot)
    }

    func copyDebugReport() {
        let report = fullDebugReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    func runStartupChecks() {
        refreshPermissions(prompt: false)
        if debugModeEnabled {
            refreshDebugReport()
        }
    }

    var versionLabel: String {
        AppStrings.versionLabel(version)
    }

    private func appendDebugLog(_ message: String) {
        let entry = DebugLogEntry(timestamp: Date(), message: message)
        debugLog.insert(entry, at: 0)
        if debugLog.count > Self.debugLogLimit {
            debugLog.removeLast(debugLog.count - Self.debugLogLimit)
        }
    }

    private func makeDebugReport(snapshot: WindowDragDebugSnapshot?) -> String {
        guard let snapshot else {
            return AppStrings.debugSnapshotUnavailable
        }

        let lines: [String] = [
            "\(AppStrings.versionPrefix): \(version)",
            "\(AppStrings.debugMode): \(debugModeEnabled ? AppStrings.debugModeOn : AppStrings.debugModeOff)",
            "\(AppStrings.accessibilityLabel(accessibilityGranted))",
            "\(AppStrings.windowControlLabel(accessibilityGranted: accessibilityGranted, ready: windowControlReady))",
            "\(AppStrings.debugCurrentStatusTitle): \(statusMessage)",
            "\(AppStrings.debugSummaryTitle): \(debugStatus)",
            "\(AppStrings.debugListenerTitle): tap=\(snapshot.eventTapActive ? "on" : "off"), source=\(snapshot.eventTapRunLoopSourceActive ? "on" : "off"), polling=\(snapshot.pollingTimerActive ? "on" : "off")",
            "\(AppStrings.debugMonitorTitle): global=\(snapshot.globalMonitorCount), workspace=\(snapshot.workspaceObserverCount), app=\(snapshot.applicationObserverCount)",
            "\(AppStrings.debugRecoveryTitle): pending=\(snapshot.pendingRecoveryCount), wake=\(snapshot.wakeEventCount), sleep=\(snapshot.sleepEventCount), health=\(snapshot.healthRecoveryCount), restarts=\(snapshot.listenerRestartCount), starts=\(snapshot.listenerStartCount)",
            "\(AppStrings.debugSessionTitle): active=\(snapshot.sessionActive ? "yes" : "no"), overlay=\(snapshot.overlayVisible ? "yes" : "no"), target=\(snapshot.targetLocked ? "yes" : "no"), movement=\(snapshot.movementObserved ? "yes" : "no"), evidence=\(snapshot.movementEvidenceCount)",
            "\(AppStrings.debugInputTitle): mouseDown=\(snapshot.lastMouseDownState ? "yes" : "no"), lastBegin=\(formatAge(snapshot.lastBeginAttemptAgo)), startedInDragRegion=\(snapshot.startedInDragRegion.map { $0 ? "yes" : "no" } ?? "n/a"), screen=\(snapshot.currentScreenName ?? "n/a")"
        ]

        return lines.joined(separator: "\n")
    }

    private func fullDebugReport() -> String {
        let report = debugReport
        guard !debugLog.isEmpty else {
            return report
        }

        let logHeader = AppStrings.recentEventsTitle
        let logLines = debugLog.map { entry in
            "\(debugTimestampFormatter.string(from: entry.timestamp)) \(entry.message)"
        }

        return ([report, "", logHeader] + logLines).joined(separator: "\n")
    }

    private func formatAge(_ value: TimeInterval?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1fs", value)
    }
}
