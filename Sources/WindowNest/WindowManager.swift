import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum WindowManagerError: LocalizedError {
    case noFrontmostApplication
    case noFocusedWindow
    case unsupportedWindow
    case failedToReadWindowFrame
    case failedToMoveWindow

    var errorDescription: String? {
        switch self {
        case .noFrontmostApplication:
            return AppStrings.noFrontmostApplicationError
        case .noFocusedWindow:
            return AppStrings.noFocusedWindowError
        case .unsupportedWindow:
            return AppStrings.unsupportedWindowError
        case .failedToReadWindowFrame:
            return AppStrings.failedToReadWindowFrameError
        case .failedToMoveWindow:
            return AppStrings.failedToMoveWindowError
        }
    }
}

struct WindowManager {
    func hasResolvableWindowTarget() -> Bool {
        if (try? focusedWindowTarget()) != nil {
            return true
        }

        return targetNearScreenPoint(NSEvent.mouseLocation) != nil
    }

    func canInteractWithWindows() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success else {
            return false
        }

        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        return windowResult == .success
    }

    func apply(layout: WindowLayoutPreset) throws {
        let target = try focusedWindowTarget()
        try apply(layout: layout, to: target)
    }

    func focusedWindowTarget() throws -> ManagedWindowTarget {
        let systemWideElement = AXUIElementCreateSystemWide()

        if
            let window = copyFocusedWindow(from: systemWideElement),
            let currentFrame = readFrame(for: window)
        {
            var pid: pid_t = 0
            AXUIElementGetPid(window, &pid)
            guard pid != ProcessInfo.processInfo.processIdentifier else {
                throw WindowManagerError.noFocusedWindow
            }

            return ManagedWindowTarget(appPID: pid, window: window, frame: currentFrame)
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw WindowManagerError.noFrontmostApplication
        }

        if let target = windowTarget(forAppPID: app.processIdentifier, near: NSEvent.mouseLocation) {
            return target
        }

        throw WindowManagerError.noFocusedWindow
    }

    func targetAtScreenPoint(_ point: CGPoint) -> ManagedWindowTarget? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let axPoint = axPoint(fromAppKitPoint: point)
        let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(axPoint.x), Float(axPoint.y), &element)

        guard result == .success, let element else {
            return nil
        }

        guard let window = enclosingWindow(for: element), let frame = readFrame(for: window) else {
            return nil
        }

        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        guard pid != ProcessInfo.processInfo.processIdentifier else {
            return frontmostWindowTarget(near: point)
        }
        return ManagedWindowTarget(appPID: pid, window: window, frame: frame)
    }

    func targetNearScreenPoint(_ point: CGPoint) -> ManagedWindowTarget? {
        if let exactTarget = targetAtScreenPoint(point) {
            return exactTarget
        }

        if
            let hint = windowHint(at: point),
            let target = windowTarget(forAppPID: hint.appPID, near: point)
        {
            return target
        }

        return nil
    }

    func apply(layout: WindowLayoutPreset, to target: ManagedWindowTarget) throws {
        let refreshedTarget = refreshedTarget(for: target)
        let currentFrame = refreshedTarget.frame
        let targetScreen = bestScreen(for: currentFrame) ?? NSScreen.main
        guard let visibleFrame = targetScreen?.visibleFrame else {
            throw WindowManagerError.failedToReadWindowFrame
        }

        let targetFrame = layout.frame(in: visibleFrame).integral
        try setFrame(targetFrame, for: refreshedTarget.window)
    }

    func apply(layout: WindowLayoutPreset, to target: ManagedWindowTarget, on screen: NSScreen) throws {
        let refreshedTarget = refreshedTarget(for: target)
        let targetFrame = layout.frame(in: screen.visibleFrame).integral
        try setFrame(targetFrame, for: refreshedTarget.window)
    }

    func refreshedTarget(for target: ManagedWindowTarget) -> ManagedWindowTarget {
        guard let currentFrame = readFrame(for: target.window) else {
            return target
        }

        return ManagedWindowTarget(appPID: target.appPID, window: target.window, frame: currentFrame)
    }

    func frontmostWindowTarget(near point: CGPoint) -> ManagedWindowTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        if let target = windowTarget(forAppPID: app.processIdentifier, near: point) {
            return target
        }

        if
            let hint = windowHint(at: point),
            hint.appPID == app.processIdentifier
        {
            return windowTarget(forAppPID: hint.appPID, near: point)
        }

        return nil
    }

    func windowHint(at point: CGPoint) -> WindowScreenHint? {
        bestWindowHint(near: point)
    }

    func windowHint(forAppPID pid: pid_t, near point: CGPoint) -> WindowScreenHint? {
        bestWindowHint(near: point, filterPID: pid)
    }

    func targetForAppPID(_ pid: pid_t, near point: CGPoint) -> ManagedWindowTarget? {
        windowTarget(forAppPID: pid, near: point)
    }

    private func bestWindowHint(near point: CGPoint, filterPID: pid_t? = nil) -> WindowScreenHint? {
        guard
            let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else {
            return nil
        }

        let preferredScreen = screenContaining(point)
        var bestMatch: (hint: WindowScreenHint, distance: CGFloat)?

        for info in infoList {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                filterPID == nil || ownerPID == filterPID,
                ownerPID != ProcessInfo.processInfo.processIdentifier,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                let alpha = info[kCGWindowAlpha as String] as? Double,
                alpha > 0.02,
                let boundsValue = info[kCGWindowBounds as String] as? NSDictionary,
                let rawBounds = CGRect(dictionaryRepresentation: boundsValue),
                rawBounds.width > 120,
                rawBounds.height > 80
            else {
                continue
            }

            for candidateFrame in normalizedWindowListFrames(for: rawBounds, around: point) {
                let hint = WindowScreenHint(appPID: ownerPID, frame: candidateFrame)
                let distance = distance(from: point, to: candidateFrame)
                let sameScreen = preferredScreen.map { $0.frame.intersects(candidateFrame) } ?? true

                if candidateFrame.contains(point) {
                    return hint
                }

                if let currentBest = bestMatch {
                    let currentBestSameScreen = preferredScreen.map { $0.frame.intersects(currentBest.hint.frame) } ?? true
                    if (sameScreen && !currentBestSameScreen) || (sameScreen == currentBestSameScreen && distance < currentBest.distance) {
                        bestMatch = (hint: hint, distance: distance)
                    }
                } else {
                    bestMatch = (hint: hint, distance: distance)
                }
            }
        }

        return bestMatch?.hint
    }

    private func copyWindow(for appElement: AXUIElement) -> AXUIElement? {
        if let focused = copyAttributeElement(kAXFocusedWindowAttribute as CFString, from: appElement) {
            return focused
        }

        if let main = copyAttributeElement(kAXMainWindowAttribute as CFString, from: appElement) {
            return main
        }

        return nil
    }

    private func windowTarget(forAppPID pid: pid_t, near point: CGPoint?) -> ManagedWindowTarget? {
        let appElement = AXUIElementCreateApplication(pid)

        if let window = copyBestWindow(for: appElement, near: point), let frame = readFrame(for: window) {
            return ManagedWindowTarget(appPID: pid, window: window, frame: frame)
        }

        return nil
    }

    private func copyBestWindow(for appElement: AXUIElement, near point: CGPoint?) -> AXUIElement? {
        if let preferred = copyWindow(for: appElement) {
            if let point, let frame = readFrame(for: preferred), frame.insetBy(dx: -40, dy: -40).contains(point) {
                return preferred
            }
            if point == nil {
                return preferred
            }
        }

        let windows = copyWindows(for: appElement)
        guard !windows.isEmpty else {
            return copyWindow(for: appElement)
        }

        if let point {
            if let contained = windows.first(where: { readFrame(for: $0)?.insetBy(dx: -40, dy: -40).contains(point) == true }) {
                return contained
            }

            if let nearest = windows.min(by: { distance(from: point, to: readFrame(for: $0) ?? .null) < distance(from: point, to: readFrame(for: $1) ?? .null) }) {
                return nearest
            }
        }

        return windows.first ?? copyWindow(for: appElement)
    }

    private func copyWindows(for appElement: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &value
        )

        guard result == .success, let value else {
            return []
        }

        guard CFGetTypeID(value) == CFArrayGetTypeID() else {
            return []
        }

        let array = unsafeDowncast(value, to: NSArray.self)
        return array.compactMap { item in
            let cfItem = item as CFTypeRef
            guard CFGetTypeID(cfItem) == AXUIElementGetTypeID() else {
                return nil
            }
            return unsafeBitCast(cfItem, to: AXUIElement.self)
        }
    }

    private func copyAttributeElement(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyFocusedWindow(from systemWideElement: AXUIElement) -> AXUIElement? {
        copyAttributeElement(kAXFocusedWindowAttribute as CFString, from: systemWideElement)
    }

    private func enclosingWindow(for element: AXUIElement) -> AXUIElement? {
        if role(of: element) == kAXWindowRole as String {
            return element
        }

        var current: AXUIElement? = element
        var depth = 0

        while let node = current, depth < 8 {
            if role(of: node) == kAXWindowRole as String {
                return node
            }

            current = parent(of: node)
            depth += 1
        }

        return nil
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }

        return value as? String
    }

    private func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func readFrame(for window: AXUIElement) -> CGRect? {
        guard
            let position = read(pointAttribute: kAXPositionAttribute as CFString, from: window),
            let size = read(sizeAttribute: kAXSizeAttribute as CFString, from: window)
        else {
            return nil
        }

        return appKitFrame(fromAXOrigin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) throws {
        let axOrigin = axOrigin(fromAppKitFrame: frame)
        guard
            let originValue = makeAXValue(.cgPoint, [axOrigin.x, axOrigin.y]),
            let sizeValue = makeAXValue(.cgSize, [frame.size.width, frame.size.height])
        else {
            throw WindowManagerError.unsupportedWindow
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            originValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard positionResult == .success, sizeResult == .success else {
            throw WindowManagerError.failedToMoveWindow
        }
    }

    private func bestScreen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens.max(by: { intersectionArea(lhs: $0.visibleFrame, rhs: frame) < intersectionArea(lhs: $1.visibleFrame, rhs: frame) })
    }

    private func intersectionArea(lhs: CGRect, rhs: CGRect) -> CGFloat {
        lhs.intersection(rhs).isNull ? 0 : lhs.intersection(rhs).width * lhs.intersection(rhs).height
    }

    private func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        guard !frame.isNull else { return .greatestFiniteMagnitude }
        if frame.contains(point) {
            return 0
        }

        let clampedX = min(max(point.x, frame.minX), frame.maxX)
        let clampedY = min(max(point.y, frame.minY), frame.maxY)
        return hypot(point.x - clampedX, point.y - clampedY)
    }

    func screenContaining(_ point: CGPoint) -> NSScreen? {
        if let exact = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return exact
        }

        return NSScreen.screens.min(by: { distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame) }) ?? NSScreen.main
    }

    private func normalizedWindowListFrames(for rawBounds: CGRect, around point: CGPoint) -> [CGRect] {
        let desktop = desktopBounds()
        let flippedBounds = CGRect(
            x: rawBounds.origin.x,
            y: desktop.maxY - rawBounds.origin.y - rawBounds.height,
            width: rawBounds.width,
            height: rawBounds.height
        )

        if abs(flippedBounds.origin.y - rawBounds.origin.y) < 1 {
            return [rawBounds]
        }

        let candidates = [rawBounds, flippedBounds]
        return candidates.sorted { lhs, rhs in
            distance(from: point, to: lhs) < distance(from: point, to: rhs)
        }
    }

    private func axPoint(fromAppKitPoint point: CGPoint) -> CGPoint {
        let desktop = desktopBounds()
        return CGPoint(
            x: point.x,
            y: desktop.maxY - point.y
        )
    }

    private func appKitFrame(fromAXOrigin origin: CGPoint, size: CGSize) -> CGRect {
        let desktop = desktopBounds()

        return CGRect(
            x: origin.x,
            y: desktop.maxY - origin.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func axOrigin(fromAppKitFrame frame: CGRect) -> CGPoint {
        let desktop = desktopBounds()

        return CGPoint(
            x: frame.origin.x,
            y: desktop.maxY - frame.maxY
        )
    }

    private func screenForAXOrigin(_ origin: CGPoint) -> NSScreen? {
        let appKitPoint = CGPoint(x: origin.x, y: desktopBounds().maxY - origin.y - 1)
        return NSScreen.screens.first(where: { $0.frame.contains(appKitPoint) }) ?? NSScreen.main
    }

    private func desktopBounds() -> CGRect {
        NSScreen.screens.reduce(into: NSScreen.main?.frame ?? .zero) { partialResult, screen in
            partialResult = partialResult.union(screen.frame)
        }
    }

    private func read(pointAttribute attribute: CFString, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard
            result == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func read(sizeAttribute attribute: CFString, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard
            result == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }
}

struct ManagedWindowTarget {
    let appPID: pid_t
    let window: AXUIElement
    let frame: CGRect
}

struct WindowScreenHint {
    let appPID: pid_t
    let frame: CGRect
}

private func makeAXValue(_ type: AXValueType, _ components: [CGFloat]) -> AXValue? {
    switch type {
    case .cgPoint:
        guard components.count == 2 else { return nil }
        var point = CGPoint(x: components[0], y: components[1])
        return AXValueCreate(type, &point)
    case .cgSize:
        guard components.count == 2 else { return nil }
        var size = CGSize(width: components[0], height: components[1])
        return AXValueCreate(type, &size)
    default:
        return nil
    }
}
