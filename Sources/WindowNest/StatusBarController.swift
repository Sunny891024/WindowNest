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
        popover.contentSize = NSSize(width: 360, height: 420)
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
        guard let source = NSApp.applicationIconImage else {
            return NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "窗口巢")
        }
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        source.draw(
            in: NSRect(x: 0, y: 0, width: 18, height: 18),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        image.accessibilityDescription = "窗口巢"
        return image
    }
}
