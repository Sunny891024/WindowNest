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
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "窗口巢")
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
}
