import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowDragLayoutService {
    private struct DragSession {
        var target: ManagedWindowTarget?
        let hintAppPID: pid_t?
        let initialMouseLocation: CGPoint
        var initialFrame: CGRect?
        let startedInDragRegion: Bool
        var overlayShown = false
        var screen: NSScreen?
        var hoveredTarget: DragLayoutDropTarget?
        var movementObserved = false
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
    private var testOverlayTimer: Timer?
    private var globalMonitors: [Any] = []
    private var lastBeginAttemptAt = Date.distantPast
    private var healthCheckTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

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

    func showTestOverlay() {
        guard let screen = NSScreen.main else {
            onDebugStatusChange(AppStrings.noAvailableScreen)
            return
        }

        overlayController?.hide()
        overlayController = DragLayoutOverlayController(screen: screen)
        overlayController?.show(on: screen, hoveredTarget: nil)
        onDebugStatusChange(AppStrings.overlayShowing(nil))

        testOverlayTimer?.invalidate()
        testOverlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.overlayController?.hide()
                self?.overlayController = nil
                self?.onDebugStatusChange(AppStrings.waitingDrag)
            }
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
        cancelSession()
        stopInputMonitoring()
        lastMouseDownState = false
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
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]

        workspaceObservers = notifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSystemWake()
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

        let needsRecovery =
            eventTap == nil ||
            eventTapRunLoopSource == nil ||
            pollingTimer?.isValid != true ||
            globalMonitors.count < 3 ||
            (eventTap.map { !CGEvent.tapIsEnabled(tap: $0) } ?? true)

        guard needsRecovery else { return }
        restartInputMonitoring(debugMessage: AppStrings.listenerHealthCheckRecovered)
    }

    private func handleSystemWake() {
        onDebugStatusChange(AppStrings.wakeRecoveryStarted)
        restartInputMonitoring(debugMessage: AppStrings.eventTapRecovered)
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
        let target = resolveDragTarget(at: mouseLocation) ?? fallbackFocusedTarget(near: mouseLocation)
        let referenceFrame = target?.frame ?? initialHint?.frame
        let startedInDragRegion = referenceFrame.map { isLikelyDragStart(location: mouseLocation, for: $0) } ?? false

        guard startedInDragRegion else {
            cancelSession()
            onDebugStatusChange(AppStrings.noDraggableWindowRegionHit)
            return
        }

        session = DragSession(
            target: target,
            hintAppPID: target?.appPID ?? initialHint?.appPID,
            initialMouseLocation: mouseLocation,
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

        let hintedTarget = session.hintAppPID.flatMap { windowManager.windowHint(forAppPID: $0, near: currentLocation) }
        let hintedMovementDetected = hintedTarget.map { currentHint in
            guard let initialFrame = session.initialFrame else { return false }
            return isWindowActuallyMoving(initialFrame: initialFrame, currentFrame: currentHint.frame)
        } ?? false

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
                installObserver(for: lateTarget)
                onDebugStatusChange(AppStrings.dragCapturedWindow)
            }
        }

        let refreshedTarget = session.target.map { windowManager.refreshedTarget(for: $0) }
        session.target = refreshedTarget
        let movementDetected =
            session.movementObserved ||
            hintedMovementDetected ||
            refreshedTarget.map { target in
                if let initialFrame = session.initialFrame {
                    return isWindowActuallyMoving(initialFrame: initialFrame, currentFrame: target.frame)
                }
                return true
            } ??
            false
        session.movementObserved = movementDetected

        let likelyWindowDrag = session.startedInDragRegion && movementDetected
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
            overlayController = DragLayoutOverlayController(screen: screen)
            session.screen = screen
        }

        let hoveredTarget = hoveredTarget(at: currentLocation, on: screen)
        overlayController?.show(on: screen, hoveredTarget: hoveredTarget)

        session.overlayShown = true
        session.hoveredTarget = hoveredTarget
        self.session = session
        onDebugStatusChange(AppStrings.overlayShowing(hoveredTarget?.preset.title))
    }

    private func finishPotentialDrag() {
        guard let session, session.overlayShown, let screen = session.screen else {
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
        if leftRightFrame.contains(mouseLocation) {
            return mouseLocation.x < leftRightFrame.midX ? .leftHalf : .rightHalf
        }

        let fullscreenFrame = globalFrame(for: .fullscreen, on: screen)
        if fullscreenFrame.contains(mouseLocation) {
            return .maximize
        }

        let topBottomFrame = globalFrame(for: .topBottom, on: screen)
        if topBottomFrame.contains(mouseLocation) {
            return mouseLocation.y > topBottomFrame.midY ? .topHalf : .bottomHalf
        }

        return nil
    }

    private func globalFrame(for kind: DragLayoutTileKind, on screen: NSScreen) -> CGRect {
        let localFrame = DragLayoutOverlayMetrics.tileFrame(for: kind, in: screen.frame.size)
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

        let expandedDragRegion = draggableRegion(for: focusedTarget.frame).insetBy(dx: -18, dy: -10)

        guard expandedDragRegion.contains(location) else {
            return nil
        }

        return focusedTarget
    }

    private func isLikelyDragStart(location: CGPoint, for frame: CGRect) -> Bool {
        let strictRegion = draggableRegion(for: frame)
        if strictRegion.contains(location) {
            return true
        }

        let tolerantRegion = CGRect(
            x: frame.minX - 18,
            y: max(frame.maxY - 92, frame.minY - 8),
            width: frame.width + 36,
            height: min(108, frame.height + 20)
        )
        return tolerantRegion.contains(location)
    }

    private func draggableRegion(for frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: max(frame.maxY - 82, frame.minY),
            width: frame.width,
            height: min(82, frame.height)
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
}
