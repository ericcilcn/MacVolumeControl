import Cocoa
import CoreGraphics

class EventInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private static var scrollAccumulator: Double = 0
    private static var lastScrollTime: TimeInterval = 0

    /// 读取系统自然滚动设置（全局偏好，缓存一次）
    private static let isNaturalScrollingEnabled: Bool = {
        let key = "com.apple.swipescrolldirection" as CFString
        guard let value = CFPreferencesCopyAppValue(key, kCFPreferencesAnyApplication) else {
            return true
        }
        return (value as? Bool) ?? (value as? Int == 1)
    }()

    /// Mos 风格的触控板检测：phase 字段比 isContinuous 更可靠，加采样降开销
    private static var trackpadCheckCount = 0
    private static var trackpadCheckCache = false

    private static func isTrackpadEvent(_ event: CGEvent) -> Bool {
        trackpadCheckCount += 1
        if trackpadCheckCount.isMultiple(of: 3) {
            trackpadCheckCache = false
            if event.getDoubleValueField(.scrollWheelEventMomentumPhase) != 0.0
                || event.getDoubleValueField(.scrollWheelEventScrollPhase) != 0.0
                || event.getDoubleValueField(.scrollWheelEventScrollCount) != 0.0 {
                trackpadCheckCache = true
            }
            if trackpadCheckCache {
                // Logitech Options 可能注入带 phase 的假事件，检查来源进程
                if let logiApp = NSRunningApplication.runningApplications(
                    withBundleIdentifier: "com.logitech.Logi-Options"
                ).first {
                    let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
                    if sourcePID == logiApp.processIdentifier {
                        trackpadCheckCache = false
                    }
                }
            }
            trackpadCheckCount = 0
        }
        return trackpadCheckCache
    }

    /// 缓存从 UserDefaults 读取的设置，避免滚轮热路径上反复 I/O
    private struct CachedSettings {
        var isEnabled = true
        var mouseModifierKey: DisplayManager.ModifierKey = .option
        var trackpadModifierKey: DisplayManager.ModifierKey = .option
        var mouseScrollInDock = true
        var mouseScrollInMenuBar = false
        var trackpadScrollInDock = true
        var trackpadScrollInMenuBar = false
        var mouseScrollWithModifier = false
        var trackpadScrollWithModifier = false
        var mouseDisableSystemScroll = false
        var trackpadDisableSystemScroll = false
        var reverseMouseScroll = false
        var mouseVolumeStepRaw = 5
        var trackpadVolumeStepRaw = 5
        var excludedApps: Set<String> = []
    }
    private static var settings = CachedSettings()

    /// 当前前台 App 的 bundle ID，由 workspace 通知更新
    private static var frontmostAppID: String = ""
    private static var frontmostAppObserver: NSObjectProtocol?

    private static func refreshSettings() {
        let dm = DisplayManager.shared
        settings.isEnabled = dm.isEnabled
        settings.mouseModifierKey = dm.mouseModifierKey
        settings.trackpadModifierKey = dm.trackpadModifierKey
        settings.mouseScrollInDock = dm.mouseScrollInDock
        settings.mouseScrollInMenuBar = dm.mouseScrollInMenuBar
        settings.trackpadScrollInDock = dm.trackpadScrollInDock
        settings.trackpadScrollInMenuBar = dm.trackpadScrollInMenuBar
        settings.mouseScrollWithModifier = dm.mouseScrollWithModifier
        settings.trackpadScrollWithModifier = dm.trackpadScrollWithModifier
        settings.mouseDisableSystemScroll = dm.mouseDisableSystemScroll
        settings.trackpadDisableSystemScroll = dm.trackpadDisableSystemScroll
        settings.reverseMouseScroll = dm.reverseMouseScroll
        settings.mouseVolumeStepRaw = dm.mouseVolumeStep.rawValue
        settings.trackpadVolumeStepRaw = dm.trackpadVolumeStep.rawValue
        settings.excludedApps = Set(dm.reversalExcludedApps)
    }

    private static var settingsObserver: NSObjectProtocol?

    private static func startObservingSettings() {
        guard settingsObserver == nil else { return }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshInterceptorSettings"),
            object: nil,
            queue: nil
        ) { _ in refreshSettings() }
    }

    private static func stopObservingSettings() {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
    }

    func start() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            #if DEBUG
            print("⚠️ 需要辅助功能权限来拦截滚动事件")
            #endif
            #if DEBUG
            print("⚠️ 请在 系统设置 → 隐私与安全性 → 辅助功能 中启用 Rolume")
            #endif
            return false
        }

        Self.refreshSettings()
        Self.startObservingSettings()
        Self.frontmostAppID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        Self.scrollAccumulator = 0
        Self.lastScrollTime = 0
        Self.trackpadCheckCount = 0
        Self.trackpadCheckCache = false

        if let observer = Self.frontmostAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        Self.frontmostAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                Self.frontmostAppID = app.bundleIdentifier ?? ""
            }
        }

        let eventMask = (1 << CGEventType.scrollWheel.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return EventInterceptor.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: nil
        ) else {
            #if DEBUG
            print("❌ 无法创建事件拦截器 - 可能需要辅助功能权限")
            #endif
            return false
        }

        self.eventTap = eventTap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        #if DEBUG
        print("✅ 事件拦截器已启动")
        #endif
        return true
    }

    private static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        let s = settings  // 本地快照，零次 UserDefaults 访问
        guard s.isEnabled else { return Unmanaged.passRetained(event) }

        let isTrackpad = Self.isTrackpadEvent(event)

        let flags = event.flags

        var isModifierPressed = false
        let modifierKey = isTrackpad ? s.trackpadModifierKey : s.mouseModifierKey
        switch modifierKey {
        case .option:    isModifierPressed = flags.contains(.maskAlternate)
        case .command:   isModifierPressed = flags.contains(.maskCommand)
        case .control:   isModifierPressed = flags.contains(.maskControl)
        case .shift:     isModifierPressed = flags.contains(.maskShift)
        }

        let isInDockArea = Self.isMouseInDockArea()
        let isInMenuBarArea = Self.isMouseInMenuBarArea()

        var shouldHandle = false
        if isTrackpad {
            shouldHandle = (s.trackpadScrollInDock && isInDockArea)
                || (s.trackpadScrollInMenuBar && isInMenuBarArea)
                || (s.trackpadScrollWithModifier && isModifierPressed)
        } else {
            shouldHandle = (s.mouseScrollInDock && isInDockArea)
                || (s.mouseScrollInMenuBar && isInMenuBarArea)
                || (s.mouseScrollWithModifier && isModifierPressed)
        }
        let shouldBlockScroll = isTrackpad ? s.trackpadDisableSystemScroll : s.mouseDisableSystemScroll

        let volumeRawDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)

        if s.reverseMouseScroll && !isTrackpad && !s.excludedApps.contains(frontmostAppID) {
            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -deltaY)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -deltaX)

            let pointDeltaY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let pointDeltaX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -pointDeltaY)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -pointDeltaX)
        }

        if shouldHandle {
            // 音量调节使用反转前的物理滚轮方向，保证向上加音量、向下减音量。
            let scrollDelta = isNaturalScrollingEnabled ? -volumeRawDelta : volumeRawDelta

            var volumeChange = 0

            if isTrackpad {
                scrollAccumulator += Double(scrollDelta)
                let threshold = Double(s.trackpadVolumeStepRaw) * 1.0

                if abs(scrollAccumulator) >= threshold {
                    let direction = scrollAccumulator > 0 ? 1 : -1
                    volumeChange = direction * s.trackpadVolumeStepRaw
                    scrollAccumulator = 0
                } else {
                    return shouldBlockScroll ? nil : Unmanaged.passRetained(event)
                }
            } else {
                let now = ProcessInfo.processInfo.systemUptime
                guard now - lastScrollTime >= 0.03 else {
                    return shouldBlockScroll ? nil : Unmanaged.passRetained(event)
                }
                lastScrollTime = now

                if abs(scrollDelta) > 0 {
                    let direction = scrollDelta > 0 ? 1 : -1
                    volumeChange = direction * s.mouseVolumeStepRaw
                }
            }

            if volumeChange != 0 {
                DispatchQueue.main.async {
                    DisplayManager.shared.updateActiveDisplay()
                    DisplayManager.shared.adjustVolume(by: volumeChange)
                    NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
                }
                return shouldBlockScroll ? nil : Unmanaged.passRetained(event)
            }

            return shouldBlockScroll ? nil : Unmanaged.passRetained(event)
        }

        return Unmanaged.passRetained(event)
    }

    private static func isMouseInDockArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
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

    private static func isMouseInMenuBarArea() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            let frame = screen.frame
            let menuBarHeight: CGFloat = 30
            let buffer: CGFloat = 5
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

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        if let observer = Self.frontmostAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            Self.frontmostAppObserver = nil
        }
        Self.stopObservingSettings()
    }

    deinit {
        stop()
    }
}
