import Foundation
import CoreGraphics
import AppKit
import Combine
import CoreAudio

class DisplayManager: ObservableObject {
    static let shared = DisplayManager()

    @Published var displays: [Display] = []
    @Published var activeDisplay: Display?

    // 修饰键选项
    enum ModifierKey: String, CaseIterable {
        case option = "option"
        case command = "command"
        case control = "control"
        case shift = "shift"

        var displayName: String {
            switch self {
            case .option: return "Option (⌥)"
            case .command: return "Command (⌘)"
            case .control: return "Control (⌃)"
            case .shift: return "Shift (⇧)"
            }
        }
    }

    // 步进幅度选项
    enum VolumeStep: Int, CaseIterable {
        case small = 2      // 2%
        case medium = 5     // 5%
        case large = 10     // 10%

        var displayName: String {
            switch self {
            case .small: return "2%"
            case .medium: return "5%"
            case .large: return "10%"
            }
        }
    }

    var volumeStep: VolumeStep {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: "volumeStep")
            return VolumeStep(rawValue: rawValue) ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "volumeStep")
        }
    }

    var mouseVolumeStep: VolumeStep {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: "mouseVolumeStep")
            return VolumeStep(rawValue: rawValue) ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "mouseVolumeStep")
            notifyInterceptorRefresh()
        }
    }

    var trackpadVolumeStep: VolumeStep {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: "trackpadVolumeStep")
            return VolumeStep(rawValue: rawValue) ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "trackpadVolumeStep")
            notifyInterceptorRefresh()
        }
    }

    var showOSD: Bool {
        get {
            // 默认开启
            if UserDefaults.standard.object(forKey: "showOSD") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "showOSD")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showOSD")
        }
    }

    var doubleClickToMute: Bool {
        get {
            // 默认开启
            if UserDefaults.standard.object(forKey: "doubleClickToMute") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "doubleClickToMute")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "doubleClickToMute")
        }
    }

    var scrollInDock: Bool {
        get {
            if UserDefaults.standard.object(forKey: "scrollInDock") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "scrollInDock")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "scrollInDock")
        }
    }

    var scrollInMenuBar: Bool {
        get {
            if UserDefaults.standard.object(forKey: "scrollInMenuBar") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "scrollInMenuBar")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "scrollInMenuBar")
        }
    }

    var scrollWithOption: Bool {
        get {
            if UserDefaults.standard.object(forKey: "scrollWithOption") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "scrollWithOption")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "scrollWithOption")
        }
    }

    // 鼠标设置
    var mouseScrollInDock: Bool {
        get {
            if UserDefaults.standard.object(forKey: "mouseScrollInDock") == nil {
                return true  // 默认开启
            }
            return UserDefaults.standard.bool(forKey: "mouseScrollInDock")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mouseScrollInDock")
        }
    }

    var mouseScrollInMenuBar: Bool {
        get {
            if UserDefaults.standard.object(forKey: "mouseScrollInMenuBar") == nil {
                return false  // 默认关闭
            }
            return UserDefaults.standard.bool(forKey: "mouseScrollInMenuBar")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mouseScrollInMenuBar")
        }
    }

    var mouseScrollWithModifier: Bool {
        get {
            if UserDefaults.standard.object(forKey: "mouseScrollWithModifier") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "mouseScrollWithModifier")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mouseScrollWithModifier")
            notifyInterceptorRefresh()
        }
    }

    var mouseDisableSystemScroll: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "mouseDisableSystemScroll")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mouseDisableSystemScroll")
            NotificationCenter.default.post(name: NSNotification.Name("ReverseMouseScrollChanged"), object: nil)
        }
    }

    // 触控板设置
    var trackpadScrollInDock: Bool {
        get {
            if UserDefaults.standard.object(forKey: "trackpadScrollInDock") == nil {
                return true  // 默认开启
            }
            return UserDefaults.standard.bool(forKey: "trackpadScrollInDock")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "trackpadScrollInDock")
        }
    }

    var trackpadScrollInMenuBar: Bool {
        get {
            if UserDefaults.standard.object(forKey: "trackpadScrollInMenuBar") == nil {
                return false  // 默认关闭
            }
            return UserDefaults.standard.bool(forKey: "trackpadScrollInMenuBar")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "trackpadScrollInMenuBar")
        }
    }

    var trackpadScrollWithModifier: Bool {
        get {
            if UserDefaults.standard.object(forKey: "trackpadScrollWithModifier") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "trackpadScrollWithModifier")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "trackpadScrollWithModifier")
            notifyInterceptorRefresh()
        }
    }

    var trackpadDisableSystemScroll: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "trackpadDisableSystemScroll")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "trackpadDisableSystemScroll")
            NotificationCenter.default.post(name: NSNotification.Name("ReverseMouseScrollChanged"), object: nil)
        }
    }

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isEnabled") == nil {
                return true  // 默认启用
            }
            return UserDefaults.standard.bool(forKey: "isEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isEnabled")
            NotificationCenter.default.post(name: NSNotification.Name("EnabledStateChanged"), object: nil)
        }
    }

    var showDockIcon: Bool {
        get {
            if UserDefaults.standard.object(forKey: "showDockIcon") == nil {
                return false  // 默认不显示 Dock 图标
            }
            return UserDefaults.standard.bool(forKey: "showDockIcon")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showDockIcon")
            applyDockIconSetting(newValue)
        }
    }

    private func notifyInterceptorRefresh() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshInterceptorSettings"), object: nil)
    }

    private func applyDockIconSetting(_ show: Bool) {
        if show {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: false)
        } else {
            let visibleWindows = NSApp.windows.filter { $0.isVisible }
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                for window in visibleWindows {
                    window.orderFrontRegardless()
                    window.makeKey()
                }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    var reversalExcludedApps: [String] {
        get {
            return UserDefaults.standard.stringArray(forKey: "reversalExcludedApps") ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "reversalExcludedApps")
        }
    }

    var reverseMouseScroll: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "reverseMouseScroll")  // 默认关闭
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "reverseMouseScroll")
            NotificationCenter.default.post(name: NSNotification.Name("ReverseMouseScrollChanged"), object: nil)
        }
    }

    var mouseModifierKey: ModifierKey {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "mouseModifierKey") ?? ModifierKey.option.rawValue
            return ModifierKey(rawValue: rawValue) ?? .option
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "mouseModifierKey")
            notifyInterceptorRefresh()
        }
    }

    var trackpadModifierKey: ModifierKey {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "trackpadModifierKey") ?? ModifierKey.option.rawValue
            return ModifierKey(rawValue: rawValue) ?? .option
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "trackpadModifierKey")
            notifyInterceptorRefresh()
        }
    }

    private init() {
        refreshDisplays()
        startMonitoring()
    }

    func refreshDisplays() {
        var displayList: [Display] = []

        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        guard CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success else {
            #if DEBUG
            print("❌ Failed to get display list")
            #endif
            return
        }

        #if DEBUG
        print("🔍 Detected \(displayCount) online display(s)")
        #endif

        // 检查当前音频输出是否是显示器音频
        let isDisplayAudio = SystemAudioManager.shared.isCurrentOutputDisplayAudio()
        #if DEBUG
        print("🔊 Current audio output is display audio: \(isDisplayAudio)")
        #endif

        var hasExternal = false
        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplays[i]
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            #if DEBUG
            print("  Display \(i): ID=\(displayID), isBuiltIn=\(isBuiltIn)")
            #endif

            if !isBuiltIn {
                hasExternal = true
                let name = getDisplayName(displayID)
                var display = Display(id: displayID, name: name, isExternal: true)

                // 读取真实音量
                if let result = DDCManager.shared.readVolume(for: displayID) {
                    display.currentVolume = Int(result.currentValue)
                    display.maxVolume = Int(result.maxValue)
                    #if DEBUG
                    print("📺 External display: \(name), volume: \(display.currentVolume)/\(display.maxVolume)")
                    #endif
                } else {
                    // 尝试从 UserDefaults 加载上次保存的音量
                    display.currentVolume = loadSavedVolume(for: displayID) ?? 50
                    display.maxVolume = 100
                    #if DEBUG
                    print("📺 External display: \(name), using saved volume: \(display.currentVolume)")
                    #endif
                }

                displayList.append(display)
            }
        }

        #if DEBUG
        print("🔍 hasExternal = \(hasExternal)")
        #endif

        // 如果音频输出不是显示器，或者没有外接显示器，使用系统音频控制
        if !isDisplayAudio || !hasExternal {
            #if DEBUG
            print("🔍 Creating audio output device...")
            #endif
            let deviceName = SystemAudioManager.shared.getDeviceName()
            var audioDevice = Display(id: 0, name: deviceName, isExternal: false)
            if let volume = SystemAudioManager.shared.getVolume() {
                audioDevice.currentVolume = Int(volume * 100)
                audioDevice.maxVolume = 100
                #if DEBUG
                print("🔊 Audio output: volume: \(audioDevice.currentVolume)/\(audioDevice.maxVolume)")
                #endif
            } else {
                audioDevice.currentVolume = loadSavedVolume(for: 0) ?? 50
                audioDevice.maxVolume = 100
                #if DEBUG
                print("🔊 Audio output: using saved volume: \(audioDevice.currentVolume)")
                #endif
            }
            displayList.append(audioDevice)
        }

        displays = displayList
        #if DEBUG
        print("✅ Total displays: \(displays.count)")
        #endif
        updateActiveDisplay()
    }

    func updateActiveDisplay() {
        // 如果只有一个显示器，直接设为活跃
        if displays.count == 1 {
            activeDisplay = displays.first
            return
        }

        // 如果有音频输出设备（非显示器音频），优先使用它
        if let audioDevice = displays.first(where: { !$0.isExternal }) {
            activeDisplay = audioDevice
            #if DEBUG
            print("🎯 Active display set to: \(audioDevice.name)")
            #endif
            return
        }

        // 否则根据鼠标位置选择显示器
        guard let mouseLocation = NSEvent.mouseLocation as CGPoint? else {
            activeDisplay = displays.first
            return
        }

        for display in displays {
            if let bounds = getDisplayBounds(display.id),
               bounds.contains(mouseLocation) {
                activeDisplay = display
                return
            }
        }

        if activeDisplay == nil && !displays.isEmpty {
            activeDisplay = displays.first
        }
    }

    func adjustVolume(by delta: Int) {
        guard let active = activeDisplay else {
            #if DEBUG
            print("⚠️ No active display")
            #endif
            return
        }

        let newVolume = max(0, min(active.maxVolume, active.currentVolume + delta))
        guard newVolume != active.currentVolume else { return }

        #if DEBUG
        print("🎚️ Adjusting volume: \(active.name) from \(active.currentVolume) to \(newVolume)")
        #endif

        var success = false
        if active.isExternal {
            success = DDCManager.shared.setVolume(UInt16(newVolume), for: active.id)
            #if DEBUG
            print("  DDC result: \(success ? "✅" : "❌")")
            #endif
        } else {
            success = SystemAudioManager.shared.setVolume(Float(newVolume) / 100.0)
            #if DEBUG
            print("  CoreAudio result: \(success ? "✅" : "❌")")
            #endif
        }

        if success {
            if let index = displays.firstIndex(where: { $0.id == active.id }) {
                displays[index].currentVolume = newVolume
                displays[index].isMuted = false
                activeDisplay = displays[index]

                // 保存音量到 UserDefaults
                saveVolume(newVolume, for: active.id)

                // 显示 OSD（如果启用）
                if showOSD {
                    OSDManager.shared.showOSD(
                        volume: newVolume,
                        maxVolume: active.maxVolume,
                        isExternal: active.isExternal,
                        displayID: active.id
                    )
                }
            }
        }
    }

    private func saveVolume(_ volume: Int, for displayID: CGDirectDisplayID) {
        let key = "volume_\(displayID)"
        UserDefaults.standard.set(volume, forKey: key)
    }

    private func loadSavedVolume(for displayID: CGDirectDisplayID) -> Int? {
        let key = "volume_\(displayID)"
        let volume = UserDefaults.standard.integer(forKey: key)
        return volume > 0 ? volume : nil
    }

    func toggleMute() {
        guard let active = activeDisplay else { return }
        guard let index = displays.firstIndex(where: { $0.id == active.id }) else { return }

        if active.isMuted {
            // 取消静音：恢复之前的音量
            let restoreVolume = active.volumeBeforeMute > 0 ? active.volumeBeforeMute : 50

            var success = false
            if active.isExternal {
                success = DDCManager.shared.setVolume(UInt16(restoreVolume), for: active.id)
            } else {
                success = SystemAudioManager.shared.setVolume(Float(restoreVolume) / 100.0)
            }

            if success {
                displays[index].currentVolume = restoreVolume
                displays[index].isMuted = false
                activeDisplay = displays[index]
            }
        } else {
            // 静音：保存当前音量，然后设为 0
            displays[index].volumeBeforeMute = active.currentVolume

            var success = false
            if active.isExternal {
                success = DDCManager.shared.setVolume(0, for: active.id)
            } else {
                success = SystemAudioManager.shared.setVolume(0.0)
            }

            if success {
                displays[index].currentVolume = 0
                displays[index].isMuted = true
                activeDisplay = displays[index]
            }
        }
    }

    private func getDisplayName(_ displayID: CGDirectDisplayID) -> String {
        guard let info = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as? [String: Any],
              let names = info["DisplayProductName"] as? [String: String],
              let name = names["en_US"] ?? names.values.first else {
            return "External Display"
        }
        return name
    }

    private func getDisplayBounds(_ displayID: CGDirectDisplayID) -> CGRect? {
        return CGDisplayBounds(displayID)
    }

    private func startMonitoring() {
        // 监听显示器变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        #if DEBUG
        print("👀 Started monitoring display changes")
        #endif

        // 监听音频输出设备变化
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            { (objectID, numAddresses, addresses, clientData) -> OSStatus in
                guard let clientData = clientData else { return noErr }
                let manager = Unmanaged<DisplayManager>.fromOpaque(clientData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.audioDeviceChanged()
                }
                return noErr
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
        #if DEBUG
        print("👀 Started monitoring audio device changes")
        #endif

        // 监听系统音量变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemVolumeChanged),
            name: NSNotification.Name("SystemVolumeChanged"),
            object: nil
        )
        #if DEBUG
        print("👀 Started monitoring system volume changes")
        #endif
    }

    @objc private func audioDeviceChanged() {
        #if DEBUG
        print("🔄 Audio output device changed, refreshing...")
        #endif
        SystemAudioManager.shared.updateVolumeMonitoring()
        refreshDisplays()
        NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
        #if DEBUG
        print("🔄 Refresh complete. Active display: \(activeDisplay?.name ?? "none")")
        #endif
    }

    @objc private func systemVolumeChanged() {
        guard let active = activeDisplay, !active.isExternal else { return }
        if let volume = SystemAudioManager.shared.getVolume() {
            let newVolume = Int(volume * 100)
            if let index = displays.firstIndex(where: { $0.id == active.id }) {
                guard displays[index].currentVolume != newVolume else { return }
                displays[index].currentVolume = newVolume
                activeDisplay = displays[index]
                NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
            }
        }
    }

    @objc private func displaysChanged() {
        #if DEBUG
        print("🔄 Display configuration changed, refreshing...")
        #endif
        refreshDisplays()
        // 通知 StatusBarController 更新图标
        NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
        #if DEBUG
        print("🔄 Refresh complete. Active display: \(activeDisplay?.name ?? "none")")
        #endif
    }
}

private func CoreDisplay_DisplayCreateInfoDictionary(_ displayID: CGDirectDisplayID) -> Unmanaged<CFDictionary>? {
    typealias CreateInfoDictionary = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?

    guard let bundle = CFBundleGetBundleWithIdentifier("com.apple.CoreDisplay" as CFString),
          let funcPointer = CFBundleGetFunctionPointerForName(bundle, "CoreDisplay_DisplayCreateInfoDictionary" as CFString) else {
        return nil
    }

    let function = unsafeBitCast(funcPointer, to: CreateInfoDictionary.self)
    return function(displayID)
}
