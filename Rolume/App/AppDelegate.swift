import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        DisplayManager.shared.refreshDisplays()

        // 启动时应用 Dock 图标设置
        let showDock = DisplayManager.shared.showDockIcon
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击 Dock 图标时显示设置窗口
        statusBarController?.showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
