import Cocoa
import CoreGraphics

class EventInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private static var scrollAccumulator: Double = 0  // 触控板滚动累积

    func start() {
        // 检查辅助功能权限（带提示）
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            print("⚠️ 需要辅助功能权限来拦截滚动事件")
            print("⚠️ 请在 系统设置 → 隐私与安全性 → 辅助功能 中启用 MacVolumeControl")
            return
        }

        // 创建事件回调 - 使用 kCGEventTapOptionDefault 来允许修改事件
        let eventMask = (1 << CGEventType.scrollWheel.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,  // 使用 HID 级别的 tap
            place: .headInsertEventTap,
            options: .defaultTap,  // 允许修改和阻止事件
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return EventInterceptor.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: nil
        ) else {
            print("❌ 无法创建事件拦截器 - 可能需要辅助功能权限")
            return
        }

        self.eventTap = eventTap

        // 添加到运行循环
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("✅ 事件拦截器已启动")
    }

    private static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        // 检测是否是触控板（连续滚动）
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        let isTrackpad = isContinuous == 1

        // 检查是否按住了选定的修饰键
        let flags = event.flags
        let selectedKey = DisplayManager.shared.selectedModifierKey

        var isModifierPressed = false
        switch selectedKey {
        case .option:
            isModifierPressed = flags.contains(.maskAlternate)
        case .command:
            isModifierPressed = flags.contains(.maskCommand)
        case .control:
            isModifierPressed = flags.contains(.maskControl)
        case .shift:
            isModifierPressed = flags.contains(.maskShift)
        }

        // 根据设备类型检查对应的设置
        let shouldHandle = isModifierPressed && (isTrackpad ? DisplayManager.shared.trackpadScrollWithModifier : DisplayManager.shared.mouseScrollWithModifier)

        // 检查是否需要禁用系统滚动
        let shouldBlockScroll = isTrackpad ? DisplayManager.shared.trackpadDisableSystemScroll : DisplayManager.shared.mouseDisableSystemScroll

        // 只有在启用了对应设备的"按住修饰键滚动"功能时才处理
        if shouldHandle {

            // 获取滚动增量（取反以匹配正确的方向）
            let scrollDelta = -event.getIntegerValueField(.scrollWheelEventDeltaAxis1)

            var volumeChange = 0

            if isTrackpad {
                // 触控板：累积滚动量
                scrollAccumulator += Double(scrollDelta)

                // 使用触控板步进设置
                let threshold = Double(DisplayManager.shared.trackpadVolumeStep.rawValue) * 1.0

                if abs(scrollAccumulator) >= threshold {
                    let direction = scrollAccumulator > 0 ? 1 : -1
                    volumeChange = direction * DisplayManager.shared.trackpadVolumeStep.rawValue
                    scrollAccumulator = 0
                } else {
                    // 未达到阈值，根据设置决定是否阻止滚动
                    return shouldBlockScroll ? nil : Unmanaged.passRetained(event)
                }
            } else {
                // 鼠标：直接响应
                if abs(scrollDelta) > 0 {
                    let direction = scrollDelta > 0 ? 1 : -1
                    volumeChange = direction * DisplayManager.shared.mouseVolumeStep.rawValue
                }
            }

            if volumeChange != 0 {
                DispatchQueue.main.async {
                    DisplayManager.shared.adjustVolume(by: volumeChange)
                    NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
                }
            }

            // 根据设置决定是否阻止滚动
            return shouldBlockScroll ? nil : Unmanaged.passRetained(event)
        }

        // 否则正常传递事件
        return Unmanaged.passRetained(event)
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
    }
}
