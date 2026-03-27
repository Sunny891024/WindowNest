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
            return "No frontmost app was found."
        case .noFocusedWindow:
            return "No focused window was found."
        case .unsupportedWindow:
            return "The focused window does not support resizing."
        case .failedToReadWindowFrame:
            return "Unable to read the current window frame."
        case .failedToMoveWindow:
            return "Unable to move the focused window."
        }
    }
}

struct WindowManager {
    func hasResolvableWindowTarget() -> Bool {
        if (try? focusedWindowTarget()) != nil {
            return true
        }

        return targetAtScreenPoint(NSEvent.mouseLocation) != nil
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
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw WindowManagerError.noFrontmostApplication
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = copyWindow(for: appElement) else {
            throw WindowManagerError.noFocusedWindow
        }

        guard let currentFrame = readFrame(for: window) else {
            throw WindowManagerError.failedToReadWindowFrame
        }

        return ManagedWindowTarget(appPID: app.processIdentifier, window: window, frame: currentFrame)
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
            return nil
        }
        return ManagedWindowTarget(appPID: pid, window: window, frame: frame)
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

    func refreshedTarget(for target: ManagedWindowTarget) -> ManagedWindowTarget {
        guard let currentFrame = readFrame(for: target.window) else {
            return target
        }

        return ManagedWindowTarget(appPID: target.appPID, window: target.window, frame: currentFrame)
    }

    private func copyWindow(for appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard result == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
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

    private func axPoint(fromAppKitPoint point: CGPoint) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else {
            return point
        }

        return CGPoint(
            x: point.x,
            y: screen.frame.maxY - point.y
        )
    }

    private func appKitFrame(fromAXOrigin origin: CGPoint, size: CGSize) -> CGRect {
        guard let screen = screenForAXOrigin(origin) ?? NSScreen.main else {
            return CGRect(origin: origin, size: size)
        }

        return CGRect(
            x: origin.x,
            y: screen.frame.maxY - origin.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func axOrigin(fromAppKitFrame frame: CGRect) -> CGPoint {
        guard let screen = bestScreen(for: frame) ?? NSScreen.main else {
            return frame.origin
        }

        return CGPoint(
            x: frame.origin.x,
            y: screen.frame.maxY - frame.maxY
        )
    }

    private func screenForAXOrigin(_ origin: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            origin.x >= screen.frame.minX && origin.x <= screen.frame.maxX
        } ?? NSScreen.main
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
