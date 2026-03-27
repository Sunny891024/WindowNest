import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let model = WindowNestModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(model: model)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.model.runStartupChecks()
        }
    }
}

@main
struct WindowNestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
