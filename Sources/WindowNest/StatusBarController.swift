import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var eventMonitor: Any?

    init(model: WindowNestModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 368, height: 332)
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(model)
        )

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
