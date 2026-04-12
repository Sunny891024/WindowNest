import AppKit
import SwiftUI

@MainActor
final class SizingHostingController<Content: View>: NSHostingController<Content> {
    var onSizeChange: ((NSSize) -> Void)?
    private var lastReportedSize = NSSize.zero

    override func viewDidLayout() {
        super.viewDidLayout()

        let fittingSize = view.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else {
            return
        }

        guard
            abs(fittingSize.width - lastReportedSize.width) > 0.5 ||
            abs(fittingSize.height - lastReportedSize.height) > 0.5
        else {
            return
        }

        lastReportedSize = fittingSize
        onSizeChange?(fittingSize)
    }
}

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let hostingController: SizingHostingController<AnyView>
    private var eventMonitor: Any?

    init(model: WindowNestModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: ContentView.preferredPopoverWidth, height: 420)

        hostingController = SizingHostingController(
            rootView: AnyView(
                ContentView()
                    .environmentObject(model)
            )
        )
        hostingController.onSizeChange = { [weak self] size in
            self?.updatePopoverContentSize(size)
        }
        popover.contentViewController = hostingController
        DispatchQueue.main.async { [weak self] in
            self?.updatePopoverContentSize(self?.hostingController.view.fittingSize)
        }

        if let button = statusItem.button {
            button.image = makeStatusBarImage()
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else {
                return
            }

            if let button = self.statusItem.button, event.window !== button.window {
                self.popover.performClose(nil)
            }
        }
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            DispatchQueue.main.async { [weak self] in
                self?.updatePopoverContentSize(self?.hostingController.view.fittingSize)
            }
        }
    }

    private func updatePopoverContentSize(_ size: NSSize? = nil) {
        let targetSize = size ?? hostingController.view.fittingSize
        guard targetSize.width > 0, targetSize.height > 0 else {
            return
        }

        if abs(popover.contentSize.width - targetSize.width) > 0.5 || abs(popover.contentSize.height - targetSize.height) > 0.5 {
            popover.contentSize = targetSize
        }
    }

    private func makeStatusBarImage() -> NSImage? {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.labelColor.setStroke()

        let outer = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3.5, width: 10, height: 8.5), xRadius: 2.2, yRadius: 2.2)
        outer.lineWidth = 1.55
        outer.stroke()

        let inner = NSBezierPath(roundedRect: NSRect(x: 6.0, y: 6.0, width: 10.5, height: 8.5), xRadius: 2.2, yRadius: 2.2)
        inner.lineWidth = 1.55
        inner.stroke()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = AppStrings.appName
        return image
    }
}
