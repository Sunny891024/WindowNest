import AppKit
import SwiftUI

@MainActor
final class DragLayoutOverlayController {
    private let panel: NSPanel
    private let hostingController: NSHostingController<DragLayoutOverlayView>

    init(screen: NSScreen, enabledKinds: Set<DragLayoutTileKind>) {
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
                hoveredTarget: nil,
                enabledKinds: enabledKinds
            )
        )
        hostingController.view.frame = panel.contentView?.bounds ?? .zero
        hostingController.view.autoresizingMask = [.width, .height]
        panel.contentViewController = hostingController
    }

    func show(on screen: NSScreen, hoveredTarget: DragLayoutDropTarget?, enabledKinds: Set<DragLayoutTileKind>) {
        if panel.screen != screen || panel.frame != screen.frame {
            panel.setFrame(screen.frame, display: false)
        }

        updateHoveredTarget(hoveredTarget, enabledKinds: enabledKinds)

        guard !panel.isVisible else { return }
        panel.orderFrontRegardless()
    }

    func updateHoveredTarget(_ target: DragLayoutDropTarget?, enabledKinds: Set<DragLayoutTileKind>) {
        hostingController.rootView = DragLayoutOverlayView(
            hoveredTarget: target,
            enabledKinds: enabledKinds
        )
    }

    func hide() {
        panel.orderOut(nil)
    }
}
