import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        DisplayManager.shared.refreshDisplays()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
