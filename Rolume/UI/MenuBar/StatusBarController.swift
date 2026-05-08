import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject, ObservableObject, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var eventMonitor: EventMonitor?
    private var eventInterceptor: EventInterceptor?
    private var settingsWindow: NSWindow?
    private var pendingSingleClickWorkItem: DispatchWorkItem?
    private var lastDisplayedVolume: Int?
    private var lastDisplayedMaxVolume: Int?
    private var lastDisplayedMutedState: Bool?

    override init() {
        super.init()
        setupStatusItem()
        setupEventMonitor()
        setupEventInterceptor()
        updateIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayChanged),
            name: NSNotification.Name("DisplayChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reverseMouseScrollChanged),
            name: NSNotification.Name("ReverseMouseScrollChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enabledStateChanged),
            name: NSNotification.Name("EnabledStateChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )

        // 启动时应用启用状态
        if !DisplayManager.shared.isEnabled {
            updateIcon()
        }
    }

    @objc private func reverseMouseScrollChanged() {
        setupEventInterceptor()
    }

    @objc private func languageChanged() {
        settingsWindow?.title = L10n.preferences
    }

    @objc private func enabledStateChanged() {
        updateIcon()
        if DisplayManager.shared.isEnabled {
            setupEventInterceptor()
        } else {
            eventInterceptor?.stop()
            eventInterceptor = nil
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private var lastScrollTime: TimeInterval = 0
    private var scrollAccumulator: Double = 0  // 用于触控板的滚动累积

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            guard DisplayManager.shared.isEnabled else { return event }

            // 检查是否在 dock 区域或在菜单栏区域
            let isInDockArea = self.isMouseInDockArea()
            let isInMenuBarArea = self.isMouseInMenuBarArea()

            // 检测是否是触控板（有滚动阶段）还是鼠标（无阶段）
            let isTrackpad = event.phase != .init(rawValue: 0) || event.momentumPhase != .init(rawValue: 0)

            // 检查是否按住了选定的修饰键（鼠标和触控板独立设置）
            let modifierKey = isTrackpad ? DisplayManager.shared.trackpadModifierKey : DisplayManager.shared.mouseModifierKey
            var isModifierPressed = false
            switch modifierKey {
            case .option:
                isModifierPressed = event.modifierFlags.contains(.option)
            case .command:
                isModifierPressed = event.modifierFlags.contains(.command)
            case .control:
                isModifierPressed = event.modifierFlags.contains(.control)
            case .shift:
                isModifierPressed = event.modifierFlags.contains(.shift)
            }

            // 根据设备类型和设置判断是否应该处理滚轮事件
            var shouldHandle = false

            if isTrackpad {
                // 触控板
                if DisplayManager.shared.trackpadScrollInDock && isInDockArea {
                    shouldHandle = true
                }
                if DisplayManager.shared.trackpadScrollInMenuBar && isInMenuBarArea {
                    shouldHandle = true
                }
                if DisplayManager.shared.trackpadScrollWithModifier && isModifierPressed {
                    shouldHandle = true
                }
            } else {
                // 鼠标
                if DisplayManager.shared.mouseScrollInDock && isInDockArea {
                    shouldHandle = true
                }
                if DisplayManager.shared.mouseScrollInMenuBar && isInMenuBarArea {
                    shouldHandle = true
                }
                if DisplayManager.shared.mouseScrollWithModifier && isModifierPressed {
                    shouldHandle = true
                }
            }

            guard shouldHandle else { return event }

            let now = ProcessInfo.processInfo.systemUptime
            let delta = event.scrollingDeltaY

            // 自然滚动补偿。如果 CGEvent tap 已经反转了鼠标滚轮（reverseMouseScroll 开启），
            // 则跳过此补偿，避免双重反转导致方向错误
            let shouldInvert = event.isDirectionInvertedFromDevice
            let cgEventAlreadyReversed = !isTrackpad && DisplayManager.shared.reverseMouseScroll
            let adjustedDelta = (shouldInvert && !cgEventAlreadyReversed) ? -delta : delta

            var volumeChange = 0

            if isTrackpad {
                // 触控板：累积滚动量，降低灵敏度
                scrollAccumulator += adjustedDelta

                // 使用触控板步进设置
                let threshold = Double(DisplayManager.shared.trackpadVolumeStep.rawValue) * 3.0

                if abs(scrollAccumulator) >= threshold {
                    let direction = scrollAccumulator > 0 ? 1 : -1
                    volumeChange = direction * DisplayManager.shared.trackpadVolumeStep.rawValue
                    scrollAccumulator = 0  // 重置累积
                } else {
                    return nil  // 还未达到阈值，不调节
                }
            } else {
                // 鼠标：直接响应
                guard abs(adjustedDelta) > 0.1 else { return nil }

                // 最小节流：30ms，避免过快触发
                guard now - self.lastScrollTime >= 0.03 else { return nil }

                let direction = adjustedDelta > 0 ? 1 : -1
                volumeChange = direction * DisplayManager.shared.mouseVolumeStep.rawValue
            }

            self.lastScrollTime = now
            DisplayManager.shared.adjustVolume(by: volumeChange)
            self.updateIcon()

            // 只有对应设备的"拦截"开启时才吞掉事件
            let shouldIntercept = isTrackpad ? DisplayManager.shared.trackpadDisableSystemScroll : DisplayManager.shared.mouseDisableSystemScroll
            return shouldIntercept ? nil : event
        }
        eventMonitor?.start()
    }

    private func setupEventInterceptor() {
        guard DisplayManager.shared.isEnabled else { return }

        let needsInterceptor = DisplayManager.shared.mouseDisableSystemScroll || DisplayManager.shared.trackpadDisableSystemScroll || DisplayManager.shared.reverseMouseScroll

        if needsInterceptor {
            eventInterceptor?.stop()
            eventInterceptor = nil
            eventInterceptor = EventInterceptor()
            eventInterceptor?.start()
        } else {
            eventInterceptor?.stop()
            eventInterceptor = nil
        }
    }

    private func isMouseOverStatusItem() -> Bool {
        guard let button = statusItem?.button,
              let window = button.window else { return false }

        let mouseLocation = NSEvent.mouseLocation
        let buttonFrame = window.convertToScreen(button.frame)

        return buttonFrame.contains(mouseLocation)
    }

    private func isMouseInDockArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation

        // 检查所有屏幕，看鼠标是否在任意屏幕底部 80 像素内（dock 区域）
        for screen in NSScreen.screens {
            let frame = screen.frame
            let dockHeight: CGFloat = 80
            let dockArea = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: dockHeight)

            if dockArea.contains(mouseLocation) {
                return true
            }
        }

        return false
    }

    private func isMouseInMenuBarArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation

        // 检查所有屏幕，看鼠标是否在任意屏幕顶部菜单栏区域
        for screen in NSScreen.screens {
            let frame = screen.frame
            let menuBarHeight: CGFloat = 30
            let buffer: CGFloat = 5  // 向上扩展5像素，确保捕获屏幕最顶端
            let menuBarArea = CGRect(
                x: frame.minX,
                y: frame.maxY - menuBarHeight,
                width: frame.width,
                height: menuBarHeight + buffer
            )

            if menuBarArea.contains(mouseLocation) {
                return true
            }
        }

        return false
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil
            showMenu()
            return
        }

        guard event.type == .leftMouseUp else { return }

        if event.clickCount >= 2 {
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil

            if DisplayManager.shared.doubleClickToMute && DisplayManager.shared.isEnabled {
                DisplayManager.shared.toggleMute()
                updateIcon()
            } else {
                showSettings()
            }
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.showSettings()
            self?.pendingSingleClickWorkItem = nil
        }

        pendingSingleClickWorkItem?.cancel()
        pendingSingleClickWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: workItem)
    }

    @objc private func displayChanged() {
        updateIconIfNeeded()
    }

    func updateIcon() {
        updateIcon(force: true)
    }

    private func updateIconIfNeeded() {
        updateIcon(force: false)
    }

    private func updateIcon(force: Bool) {
        guard let display = DisplayManager.shared.activeDisplay else { return }

        if !force,
           lastDisplayedVolume == display.currentVolume,
           lastDisplayedMaxVolume == display.maxVolume,
           lastDisplayedMutedState == display.isMuted {
            return
        }

        lastDisplayedVolume = display.currentVolume
        lastDisplayedMaxVolume = display.maxVolume
        lastDisplayedMutedState = display.isMuted

        let icon = VolumeIconGenerator.generateIcon(
            volume: display.currentVolume,
            maxVolume: display.maxVolume,
            isMuted: display.isMuted
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if DisplayManager.shared.isEnabled {
                self.statusItem?.button?.image = icon
                self.statusItem?.button?.alphaValue = 1.0
            } else {
                self.statusItem?.button?.image = icon
                self.statusItem?.button?.alphaValue = 0.35
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: L10n.enableApp, action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = DisplayManager.shared.isEnabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L10n.preferences, action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleEnabled() {
        let dm = DisplayManager.shared
        dm.isEnabled.toggle()
        updateIcon()
        if dm.isEnabled {
            setupEventInterceptor()
        } else {
            eventInterceptor?.stop()
            eventInterceptor = nil
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc func showSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.settingsWindow == nil {
                let contentView = SettingsView()
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 390, height: 440),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = L10n.preferences
                window.delegate = self
                window.isReleasedWhenClosed = false
                window.contentView = NSHostingView(rootView: contentView)
                window.center()
                self.settingsWindow = window
            }

            self.settingsWindow?.title = L10n.preferences
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            self.settingsWindow?.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        settingsWindow?.orderOut(nil)
    }
}
