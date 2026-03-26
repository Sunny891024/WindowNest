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
    func apply(layout: WindowLayoutPreset) throws {
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

        let targetScreen = bestScreen(for: currentFrame) ?? NSScreen.main
        guard let visibleFrame = targetScreen?.visibleFrame else {
            throw WindowManagerError.failedToReadWindowFrame
        }

        let targetFrame = layout.frame(in: visibleFrame).integral
        try setFrame(targetFrame, for: window)
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

    private func readFrame(for window: AXUIElement) -> CGRect? {
        guard
            let position = read(pointAttribute: kAXPositionAttribute as CFString, from: window),
            let size = read(sizeAttribute: kAXSizeAttribute as CFString, from: window)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) throws {
        guard
            let originValue = makeAXValue(.cgPoint, [frame.origin.x, frame.origin.y]),
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
