import AppKit
import SwiftUI

@MainActor
final class DragLayoutOverlayController {
    private let panel: NSPanel
    private let hostingController: NSHostingController<DragLayoutOverlayView>

    init(screen: NSScreen) {
        panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        hostingController = NSHostingController(
            rootView: DragLayoutOverlayView(
                hoveredTarget: nil
            )
        )
        hostingController.view.frame = panel.contentView?.bounds ?? .zero
        hostingController.view.autoresizingMask = [.width, .height]
        panel.contentViewController = hostingController
    }

    func show(on screen: NSScreen, hoveredTarget: DragLayoutDropTarget?) {
        if panel.screen != screen || panel.frame != screen.frame {
            panel.setFrame(screen.frame, display: false)
        }

        updateHoveredTarget(hoveredTarget)

        guard !panel.isVisible else { return }
        panel.orderFrontRegardless()
    }

    func updateHoveredTarget(_ target: DragLayoutDropTarget?) {
        hostingController.rootView = DragLayoutOverlayView(
            hoveredTarget: target
        )
    }

    func hide() {
        panel.orderOut(nil)
    }
}
