import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowDragLayoutService {
    private struct DragSession {
        var target: ManagedWindowTarget?
        let initialMouseLocation: CGPoint
        let initialFrame: CGRect?
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

    init(
        onStatusMessage: @escaping (String) -> Void,
        onDebugStatusChange: @escaping (String) -> Void
    ) {
        self.onStatusMessage = onStatusMessage
        self.onDebugStatusChange = onDebugStatusChange
        startEventTap()
        startGlobalMonitors()
        startPollingFallback()
    }

    func refreshPermissionsAllowed(_ allowed: Bool) {
        if !allowed {
            onDebugStatusChange("权限检测未通过，仍继续监听")
            return
        }

        if session == nil {
            onDebugStatusChange("等待拖动")
        }
    }

    func showTestOverlay() {
        guard let screen = NSScreen.main else {
            onDebugStatusChange("没有可用屏幕")
            return
        }

        overlayController?.hide()
        overlayController = DragLayoutOverlayController(screen: screen)
        overlayController?.show(on: screen, hoveredTarget: nil)
        onDebugStatusChange("测试浮层已显示")

        testOverlayTimer?.invalidate()
        testOverlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.overlayController?.hide()
                self?.overlayController = nil
                self?.onDebugStatusChange("测试浮层已关闭")
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
            onDebugStatusChange("事件监听创建失败")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        eventTapRunLoopSource = source
        onDebugStatusChange("事件监听已启动")
    }

    private func startPollingFallback() {
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
        let target = resolveDragTarget(at: mouseLocation) ?? fallbackFocusedTarget(near: mouseLocation)
        let referenceFrame = target?.frame ?? windowManager.windowHint(at: mouseLocation)?.frame
        let startedInDragRegion = referenceFrame.map { isLikelyDragStart(location: mouseLocation, for: $0) } ?? false

        guard startedInDragRegion else {
            cancelSession()
            onDebugStatusChange("未命中可拖动窗口区域")
            return
        }

        session = DragSession(
            target: target,
            initialMouseLocation: mouseLocation,
            initialFrame: referenceFrame,
            startedInDragRegion: startedInDragRegion
        )

        if let target {
            installObserver(for: target)
            onDebugStatusChange("已命中窗口顶部区域")
        } else {
            onDebugStatusChange("已识别拖动区域，等待锁定窗口")
        }
    }

    private func updatePotentialDrag() {
        guard var session else { return }

        let currentLocation = NSEvent.mouseLocation
        let distance = hypot(currentLocation.x - session.initialMouseLocation.x, currentLocation.y - session.initialMouseLocation.y)
        guard distance > 28 else { return }

        if session.target == nil {
            let lateTarget = resolveDragTarget(at: currentLocation) ??
                resolveDragTarget(at: session.initialMouseLocation) ??
                fallbackFocusedTarget(near: currentLocation) ??
                windowManager.frontmostWindowTarget(near: currentLocation)
            if let lateTarget {
                session.target = lateTarget
                installObserver(for: lateTarget)
                onDebugStatusChange("拖动中已补抓目标窗口")
            }
        }

        let refreshedTarget = session.target.map { windowManager.refreshedTarget(for: $0) }
        session.target = refreshedTarget
        let movementDetected =
            session.movementObserved ||
            (session.startedInDragRegion && distance > 32) ||
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
            onDebugStatusChange(session.target == nil ? "拖动已开始，但仍未锁定窗口" : "拖动已开始，但还未识别为窗口移动")
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
        onDebugStatusChange(hoveredTarget.map { "浮层显示中：\($0.preset.title)" } ?? "浮层显示中")
    }

    private func finishPotentialDrag() {
        guard let session, session.overlayShown, let screen = session.screen else {
            return
        }

        let location = NSEvent.mouseLocation
        let dropTarget = hoveredTarget(at: location, on: screen) ?? session.hoveredTarget
        guard let dropTarget else {
            onDebugStatusChange("已松手，但没有命中任何布局")
            cancelSession()
            return
        }

        let resolvedTarget = resolveReleaseTarget(for: session, dropLocation: location)
        guard let windowTarget = resolvedTarget else {
            onStatusMessage("已命中布局，但松手时没能锁定目标窗口。请从窗口顶部区域开始拖动后再试。")
            onDebugStatusChange("释放失败：松手时仍未锁定窗口")
            if !windowManager.canInteractWithWindows() {
                onStatusMessage("当前还不能真正控制系统窗口。请确认“辅助功能”已对 WindowNest 生效。")
            }
            cancelSession()
            return
        }

        cancelSession()

        let preset = dropTarget.preset
        onDebugStatusChange("已命中\(preset.title)，准备应用布局")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self else { return }

            do {
                try self.windowManager.apply(layout: preset, to: windowTarget, on: screen)
                self.onStatusMessage("已将窗口移动到\(preset.title)。")
                self.onDebugStatusChange("已释放到\(preset.title)")
            } catch {
                if !self.windowManager.canInteractWithWindows() {
                    self.onStatusMessage("当前还不能真正控制系统窗口。请确认“辅助功能”已对 WindowNest 生效。")
                    self.onDebugStatusChange("释放失败：窗口控制权限未生效")
                } else {
                    self.onStatusMessage(error.localizedDescription)
                    self.onDebugStatusChange("释放失败：\(error.localizedDescription)")
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
            let expandedFrame = focusedTarget.frame.insetBy(dx: -24, dy: -24)
            let expandedDragRegion = draggableRegion(for: focusedTarget.frame).insetBy(dx: -28, dy: -20)
            if expandedFrame.contains(location) || expandedDragRegion.contains(location) {
                return focusedTarget
            }
        }

        return nil
    }

    private func resolveReleaseTarget(for session: DragSession, dropLocation: CGPoint) -> ManagedWindowTarget? {
        if let target = session.target.map({ windowManager.refreshedTarget(for: $0) }) {
            return target
        }

        return resolveDragTarget(at: dropLocation) ??
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

        let expandedFrame = focusedTarget.frame.insetBy(dx: -48, dy: -48)
        let topHalfRegion = CGRect(
            x: expandedFrame.minX,
            y: expandedFrame.midY - 24,
            width: expandedFrame.width,
            height: expandedFrame.maxY - expandedFrame.midY + 24
        )

        guard expandedFrame.contains(location) || topHalfRegion.contains(location) else {
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
            x: frame.minX - 36,
            y: max(frame.midY - 12, frame.minY - 24),
            width: frame.width + 72,
            height: max(frame.maxY - frame.midY + 36, 120)
        )
        return tolerantRegion.contains(location)
    }

    private func draggableRegion(for frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: max(frame.maxY - 140, frame.minY),
            width: frame.width,
            height: min(140, frame.height)
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
        onDebugStatusChange("已收到窗口移动通知")
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
        onDebugStatusChange("等待拖动")
    }
}
