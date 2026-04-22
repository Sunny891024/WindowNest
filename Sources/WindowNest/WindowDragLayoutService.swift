import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowDragLayoutService {
    private struct DragSession {
        var target: ManagedWindowTarget?
        let hintAppPID: pid_t?
        let initialMouseLocation: CGPoint
        let startedAt: Date
        var initialFrame: CGRect?
        let startedInDragRegion: Bool
        var overlayShown = false
        var screen: NSScreen?
        var hoveredTarget: DragLayoutDropTarget?
        var movementObserved = false
        var movementEvidenceCount = 0
    }

    private let windowManager = WindowManager()
    private let onStatusMessage: (String) -> Void
    private let onDebugStatusChange: (String) -> Void
    private var session: DragSession?
    private var overlayController: DragLayoutOverlayController?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var pollingTimer: Timer?
    private var lastMouseDownState = false
    private var observer: AXObserver?
    private var observerRunLoopSource: CFRunLoopSource?
    private var observedWindow: AXUIElement?
    private var globalMonitors: [Any] = []
    private var lastBeginAttemptAt = Date.distantPast
    private var healthCheckTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var applicationObservers: [NSObjectProtocol] = []
    private var pendingRecoveryWorkItems: [DispatchWorkItem] = []
    private var listenerStartCount = 0
    private var listenerRestartCount = 0
    private var sleepEventCount = 0
    private var wakeEventCount = 0
    private var healthRecoveryCount = 0
    private var enabledTileKinds: Set<DragLayoutTileKind> = Set(DragLayoutTileKind.allCases)

    init(
        onStatusMessage: @escaping (String) -> Void,
        onDebugStatusChange: @escaping (String) -> Void
    ) {
        self.onStatusMessage = onStatusMessage
        self.onDebugStatusChange = onDebugStatusChange
        startInputMonitoring()
        observeSystemLifecycle()
        startHealthCheckTimer()
    }

    func refreshPermissionsAllowed(_ allowed: Bool) {
        if !allowed {
            onDebugStatusChange(AppStrings.permissionsCheckFailedButListening)
            return
        }

        if session == nil {
            onDebugStatusChange(AppStrings.waitingDrag)
        }
    }

    func updateEnabledLayoutKinds(_ enabledKinds: Set<DragLayoutTileKind>) {
        enabledTileKinds = enabledKinds
        if let overlayController, session?.screen != nil {
            let hoveredTarget = session?.hoveredTarget.flatMap { enabledKinds.contains($0.tileKind) ? $0 : nil }
            overlayController.updateHoveredTarget(hoveredTarget, enabledKinds: enabledKinds)
        }
    }

    private func startEventTap() {
        let mask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passRetained(event)
            }

            let service = Unmanaged<WindowDragLayoutService>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                service.handleEventTap(type: type)
            }
            return Unmanaged.passRetained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onDebugStatusChange(AppStrings.eventTapCreationFailed)
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        eventTapRunLoopSource = source
        onDebugStatusChange(AppStrings.eventTapStarted)
    }

    private func startPollingFallback() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollDragFallback()
            }
        }

        if let pollingTimer {
            RunLoop.main.add(pollingTimer, forMode: .common)
        }
    }

    private func startGlobalMonitors() {
        removeGlobalMonitors()

        let downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.beginPotentialDrag()
            }
        }

        let dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in
                self?.updatePotentialDrag()
            }
        }

        let upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in
                self?.finishPotentialDrag()
            }
        }

        globalMonitors = [downMonitor, dragMonitor, upMonitor].compactMap { $0 }
    }

    private func startInputMonitoring() {
        listenerStartCount += 1
        startEventTap()
        startGlobalMonitors()
        startPollingFallback()
    }

    private func stopInputMonitoring() {
        removeGlobalMonitors()

        pollingTimer?.invalidate()
        pollingTimer = nil

        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        eventTapRunLoopSource = nil
        eventTap = nil
    }

    private func restartInputMonitoring(debugMessage: String? = nil) {
        cancelPendingRecovery()
        cancelSession()
        stopInputMonitoring()
        lastMouseDownState = false
        lastBeginAttemptAt = .distantPast
        listenerRestartCount += 1
        startInputMonitoring()

        if let debugMessage {
            onDebugStatusChange(debugMessage)
        }
    }

    private func removeGlobalMonitors() {
        for monitor in globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitors.removeAll()
    }

    private func observeSystemLifecycle() {
        let center = NSWorkspace.shared.notificationCenter

        let notifications: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]

        workspaceObservers = notifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    if name == NSWorkspace.willSleepNotification {
                        self?.handleSystemSleep()
                    } else {
                        self?.handleSystemWake()
                    }
                }
            }
        }

        let applicationCenter = NotificationCenter.default
        let applicationNotifications: [Notification.Name] = [
            NSApplication.willBecomeActiveNotification,
            NSApplication.didBecomeActiveNotification
        ]

        applicationObservers = applicationNotifications.map { name in
            applicationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    if name == NSApplication.didBecomeActiveNotification {
                        self?.handleSystemWake()
                    } else {
                        self?.onDebugStatusChange(AppStrings.wakeRecoveryStarted)
                    }
                }
            }
        }
    }

    private func removeSystemLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        let applicationCenter = NotificationCenter.default
        for observer in applicationObservers {
            applicationCenter.removeObserver(observer)
        }
        applicationObservers.removeAll()
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performListenerHealthCheck()
            }
        }

        if let healthCheckTimer {
            RunLoop.main.add(healthCheckTimer, forMode: .common)
        }
    }

    private func performListenerHealthCheck() {
        guard session == nil else { return }

        guard needsListenerRecovery() else { return }
        healthRecoveryCount += 1
        restartInputMonitoring(debugMessage: AppStrings.listenerHealthCheckRecovered)
    }

    private func handleSystemWake() {
        wakeEventCount += 1
        onDebugStatusChange(AppStrings.wakeRecoveryStarted)
        scheduleWakeRecoveryAttempts()
    }

    private func handleSystemSleep() {
        sleepEventCount += 1
        cancelPendingRecovery()
        cancelSession()
        stopInputMonitoring()
        lastMouseDownState = false
        lastBeginAttemptAt = .distantPast
        onDebugStatusChange(AppStrings.systemSleepDetected)
    }

    private func scheduleWakeRecoveryAttempts() {
        cancelPendingRecovery()

        let delays: [TimeInterval] = [0.0, 1.0, 4.0]
        for delay in delays {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.session == nil else { return }
                self.restartInputMonitoring(debugMessage: AppStrings.eventTapRecovered)
            }

            pendingRecoveryWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func cancelPendingRecovery() {
        for workItem in pendingRecoveryWorkItems {
            workItem.cancel()
        }
        pendingRecoveryWorkItems.removeAll()
    }

    private func needsListenerRecovery() -> Bool {
        eventTap == nil ||
        eventTapRunLoopSource == nil ||
        pollingTimer?.isValid != true ||
        globalMonitors.count < 3 ||
        (eventTap.map { !CGEvent.tapIsEnabled(tap: $0) } ?? true)
    }

    private func pollDragFallback() {
        let mouseDown = CGEventSource.buttonState(.combinedSessionState, button: .left)

        if mouseDown && !lastMouseDownState {
            if session == nil {
                beginPotentialDrag()
            }
        } else if mouseDown && lastMouseDownState {
            if session != nil {
                updatePotentialDrag()
            }
        } else if !mouseDown && lastMouseDownState {
            if session != nil {
                finishPotentialDrag()
            }
        }

        lastMouseDownState = mouseDown
    }

    private func handleEventTap(type: CGEventType) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            restartInputMonitoring(debugMessage: AppStrings.eventTapRecovered)
        case .leftMouseDown:
            beginPotentialDrag()
        case .leftMouseDragged:
            updatePotentialDrag()
        case .leftMouseUp:
            finishPotentialDrag()
        default:
            break
        }
    }

    private func beginPotentialDrag() {
        guard session == nil else { return }

        let now = Date()
        guard now.timeIntervalSince(lastBeginAttemptAt) > 0.08 else { return }
        lastBeginAttemptAt = now

        let mouseLocation = NSEvent.mouseLocation
        let initialHint = windowManager.windowHint(at: mouseLocation)
        let dragStartProbe = windowManager.dragStartProbe(at: mouseLocation)

        let target: ManagedWindowTarget?
        let referenceFrame: CGRect?
        let startedInDragRegion: Bool
        let probeSummary: String

        switch dragStartProbe {
        case .allowed(let resolvedTarget, let roles):
            target = resolvedTarget
            referenceFrame = resolvedTarget.frame
            startedInDragRegion = true
            probeSummary = "allowed roles=\(describeRoles(roles))"
        case .blocked(let roles):
            onDebugStatusChange("Drag start probe: blocked roles=\(describeRoles(roles))")
            cancelSession()
            onDebugStatusChange(AppStrings.noDraggableWindowRegionHit)
            return
        case .unavailable:
            let fallbackTarget = fallbackFocusedTarget(near: mouseLocation)
            target = fallbackTarget
            referenceFrame = fallbackTarget?.frame ?? initialHint?.frame
            startedInDragRegion = fallbackTarget.map { isLikelyDragStart(location: mouseLocation, for: $0.frame) } ?? false
            probeSummary = fallbackTarget == nil ? "unavailable" : "unavailable:fallback"
        }

        guard startedInDragRegion else {
            cancelSession()
            onDebugStatusChange(AppStrings.noDraggableWindowRegionHit)
            return
        }

        onDebugStatusChange(
            "Drag start probe: \(probeSummary), target=\(target.map { "\($0.appPID)" } ?? "nil"), frame=\(referenceFrame.map { describe($0) } ?? "nil")"
        )

        session = DragSession(
            target: target,
            hintAppPID: target?.appPID ?? initialHint?.appPID,
            initialMouseLocation: mouseLocation,
            startedAt: now,
            initialFrame: referenceFrame,
            startedInDragRegion: startedInDragRegion
        )

        if let target {
            installObserver(for: target)
            onDebugStatusChange(AppStrings.hitWindowTitlebar)
        } else {
            onDebugStatusChange(AppStrings.dragRegionRecognizedAwaitingWindow)
        }
    }

    private func updatePotentialDrag() {
        guard var session else { return }

        let currentLocation = NSEvent.mouseLocation
        let distance = hypot(currentLocation.x - session.initialMouseLocation.x, currentLocation.y - session.initialMouseLocation.y)
        guard distance > 16 else { return }
        let elapsed = Date().timeIntervalSince(session.startedAt)

        if session.target == nil {
            let lateTarget =
                session.hintAppPID.flatMap { windowManager.targetForAppPID($0, near: currentLocation) } ??
                resolveDragTarget(at: currentLocation) ??
                resolveDragTarget(at: session.initialMouseLocation) ??
                fallbackFocusedTarget(near: currentLocation) ??
                windowManager.frontmostWindowTarget(near: currentLocation)
            if let lateTarget {
                session.target = lateTarget
                session.initialFrame = lateTarget.frame
                session.movementEvidenceCount = 0
                installObserver(for: lateTarget)
                onDebugStatusChange(AppStrings.dragCapturedWindow)
            }
        }

        let refreshedTarget = session.target.map { windowManager.refreshedTarget(for: $0) }
        session.target = refreshedTarget
        let directMovementDetected = refreshedTarget.map { target in
            guard let initialFrame = session.initialFrame else { return false }
            return isWindowActuallyMoving(initialFrame: initialFrame, currentFrame: target.frame)
        } ?? false

        if !session.movementObserved {
            if directMovementDetected {
                session.movementEvidenceCount += 1
                if session.movementEvidenceCount >= 2 {
                    session.movementObserved = true
                }
            } else {
                if shouldConfirmDragMovement(distance: distance, elapsed: elapsed, session: session) {
                    session.movementObserved = true
                    session.movementEvidenceCount = max(session.movementEvidenceCount, 2)
                    onDebugStatusChange(AppStrings.dragMovementConfirmed)
                } else {
                    session.movementEvidenceCount = 0
                }
            }
        }

        let likelyWindowDrag = session.startedInDragRegion && session.movementObserved
        if !likelyWindowDrag {
            onDebugStatusChange(session.target == nil ? AppStrings.dragStartedWindowNotLocked : AppStrings.dragStartedButNoWindowMovement)
            self.session = session
            return
        }

        guard let screen = windowManager.screenContaining(currentLocation) else {
            return
        }

        if overlayController == nil || session.screen !== screen {
            overlayController?.hide()
            overlayController = DragLayoutOverlayController(screen: screen, enabledKinds: enabledTileKinds)
            session.screen = screen
        }

        let hoveredTarget = hoveredTarget(at: currentLocation, on: screen)
        overlayController?.show(on: screen, hoveredTarget: hoveredTarget, enabledKinds: enabledTileKinds)

        session.overlayShown = true
        session.hoveredTarget = hoveredTarget
        self.session = session
        onDebugStatusChange(AppStrings.overlayShowing(hoveredTarget?.preset.title))
    }

    private func finishPotentialDrag() {
        guard let session else {
            return
        }

        guard session.overlayShown, let screen = session.screen else {
            cancelSession()
            return
        }

        let location = NSEvent.mouseLocation
        let dropTarget = hoveredTarget(at: location, on: screen) ?? session.hoveredTarget
        guard let dropTarget else {
            onDebugStatusChange(AppStrings.releasedWithoutLayout)
            cancelSession()
            return
        }

        let resolvedTarget = resolveReleaseTarget(for: session, dropLocation: location)
        guard let windowTarget = resolvedTarget else {
            onStatusMessage(AppStrings.releaseFailedNoWindowLocked)
            onDebugStatusChange(AppStrings.releaseFailedNoWindowLocked)
            if !windowManager.canInteractWithWindows() {
                onStatusMessage(AppStrings.cannotControlWindows)
            }
            cancelSession()
            return
        }

        cancelSession()

        let preset = dropTarget.preset
        onDebugStatusChange(AppStrings.preparingToApply(preset.title))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self else { return }

            do {
                try self.windowManager.apply(layout: preset, to: windowTarget, on: screen)
                self.onStatusMessage(AppStrings.movedWindow(to: preset.title))
                self.onDebugStatusChange(AppStrings.releasedTo(preset.title))
            } catch {
                if !self.windowManager.canInteractWithWindows() {
                    self.onStatusMessage(AppStrings.cannotControlWindows)
                    self.onDebugStatusChange(AppStrings.releaseFailedPermission)
                } else {
                    self.onStatusMessage(error.localizedDescription)
                    self.onDebugStatusChange(AppStrings.releaseFailed(error.localizedDescription))
                }
            }
        }
    }

    private func hoveredTarget(at mouseLocation: CGPoint, on screen: NSScreen) -> DragLayoutDropTarget? {
        let leftRightFrame = globalFrame(for: .leftRight, on: screen)
        if enabledTileKinds.contains(.leftRight), leftRightFrame.contains(mouseLocation) {
            return mouseLocation.x < leftRightFrame.midX ? .leftHalf : .rightHalf
        }

        let fullscreenFrame = globalFrame(for: .fullscreen, on: screen)
        if enabledTileKinds.contains(.fullscreen), fullscreenFrame.contains(mouseLocation) {
            return .maximize
        }

        let topBottomFrame = globalFrame(for: .topBottom, on: screen)
        if enabledTileKinds.contains(.topBottom), topBottomFrame.contains(mouseLocation) {
            return mouseLocation.y > topBottomFrame.midY ? .topHalf : .bottomHalf
        }

        let centerFrame = globalFrame(for: .center, on: screen)
        if enabledTileKinds.contains(.center), centerFrame.contains(mouseLocation) {
            return .center
        }

        return nil
    }

    private func globalFrame(for kind: DragLayoutTileKind, on screen: NSScreen) -> CGRect {
        let visibleKinds = DragLayoutTileKind.allCases.filter { enabledTileKinds.contains($0) }
        let localFrame = DragLayoutOverlayMetrics.tileFrame(for: kind, visibleKinds: visibleKinds, in: screen.frame.size)
        return CGRect(
            x: screen.frame.minX + localFrame.minX,
            y: screen.frame.maxY - localFrame.maxY,
            width: localFrame.width,
            height: localFrame.height
        )
    }

    private func isWindowActuallyMoving(initialFrame: CGRect, currentFrame: CGRect) -> Bool {
        let originDelta = hypot(currentFrame.origin.x - initialFrame.origin.x, currentFrame.origin.y - initialFrame.origin.y)
        let sizeDelta = abs(currentFrame.width - initialFrame.width) + abs(currentFrame.height - initialFrame.height)
        return originDelta > 10 || sizeDelta > 10
    }

    private func shouldConfirmDragMovement(distance: CGFloat, elapsed: TimeInterval, session: DragSession) -> Bool {
        guard session.startedInDragRegion, session.target != nil else {
            return false
        }

        if elapsed >= 0.15 && distance >= 22 {
            return true
        }

        if elapsed >= 0.35 && distance >= 16 {
            return true
        }

        return false
    }

    private func resolveDragTarget(at location: CGPoint) -> ManagedWindowTarget? {
        let probeOffsets: [CGFloat] = [0, -20, -40, 20]
        for offset in probeOffsets {
            let probePoint = CGPoint(x: location.x, y: location.y + offset)
            if let hitTarget = windowManager.targetNearScreenPoint(probePoint) {
                return hitTarget
            }
        }

        if
            let focusedTarget = try? windowManager.focusedWindowTarget(),
            focusedTarget.appPID != ProcessInfo.processInfo.processIdentifier
        {
            let expandedDragRegion = draggableRegion(for: focusedTarget.frame).insetBy(dx: -22, dy: -10)
            if expandedDragRegion.contains(location) {
                return focusedTarget
            }
        }

        return nil
    }

    private func resolveReleaseTarget(for session: DragSession, dropLocation: CGPoint) -> ManagedWindowTarget? {
        if let target = session.target.map({ windowManager.refreshedTarget(for: $0) }) {
            return target
        }

        return session.hintAppPID.flatMap { windowManager.targetForAppPID($0, near: dropLocation) } ??
            session.hintAppPID.flatMap { windowManager.targetForAppPID($0, near: session.initialMouseLocation) } ??
            resolveDragTarget(at: dropLocation) ??
            resolveDragTarget(at: session.initialMouseLocation) ??
            fallbackFocusedTarget(near: dropLocation) ??
            fallbackFocusedTarget(near: session.initialMouseLocation) ??
            windowManager.frontmostWindowTarget(near: dropLocation) ??
            windowManager.frontmostWindowTarget(near: session.initialMouseLocation) ??
            (try? windowManager.focusedWindowTarget())
    }

    private func fallbackFocusedTarget(near location: CGPoint) -> ManagedWindowTarget? {
        guard
            let focusedTarget = try? windowManager.focusedWindowTarget(),
            focusedTarget.appPID != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }

        let strictRegion = draggableRegion(for: focusedTarget.frame)

        guard strictRegion.contains(location) else {
            return nil
        }

        return focusedTarget
    }

    private func isLikelyDragStart(location: CGPoint, for frame: CGRect) -> Bool {
        draggableRegion(for: frame).contains(location)
    }

    private func draggableRegion(for frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: max(frame.maxY - 32, frame.minY),
            width: frame.width,
            height: min(32, frame.height)
        )
    }

    private func installObserver(for target: ManagedWindowTarget) {
        removeObserver()

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let service = Unmanaged<WindowDragLayoutService>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                service.handleAXNotification(element: element, notification: notification as String)
            }
        }

        let result = AXObserverCreate(target.appPID, callback, &observer)
        guard result == .success, let observer else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, target.window, kAXMovedNotification as CFString, refcon)
        AXObserverAddNotification(observer, target.window, kAXResizedNotification as CFString, refcon)

        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        self.observer = observer
        observerRunLoopSource = source
        observedWindow = target.window
    }

    private func handleAXNotification(element: AXUIElement, notification: String) {
        guard let session else { return }
        guard let target = session.target else { return }
        guard CFEqual(element, target.window) else { return }
        guard notification == kAXMovedNotification as String || notification == kAXResizedNotification as String else { return }
        self.session?.movementObserved = true
        self.session?.movementEvidenceCount = 2
        onDebugStatusChange(AppStrings.windowMovedNotificationReceived)
    }

    private func removeObserver() {
        if let observer, let observedWindow {
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            AXObserverRemoveNotification(observer, observedWindow, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(observer, observedWindow, kAXResizedNotification as CFString)
            _ = refcon
        }

        if let observerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observerRunLoopSource, .commonModes)
        }

        observer = nil
        observerRunLoopSource = nil
        observedWindow = nil
    }

    private func cancelSession() {
        overlayController?.hide()
        overlayController = nil
        removeObserver()
        session = nil
        onDebugStatusChange(AppStrings.waitingDrag)
    }

    private func describe(_ frame: CGRect) -> String {
        String(
            format: "x=%.0f y=%.0f w=%.0f h=%.0f",
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height
        )
    }

    private func describeRoles(_ roles: [String]) -> String {
        if roles.isEmpty {
            return "[]"
        }

        return "[\(roles.joined(separator: " > "))]"
    }
}
