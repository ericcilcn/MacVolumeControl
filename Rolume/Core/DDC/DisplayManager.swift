import Foundation
import CoreGraphics
import AppKit
import Combine
import CoreAudio

class DisplayManager: ObservableObject {
    static let shared = DisplayManager()
    private let ddcVolumeMaxValue: UInt16 = 100
    private let fallbackDisplayVolume = 25
    private let maxDDCRefreshRetries = 5
    private var pendingDDCRefreshWorkItem: DispatchWorkItem?
    private var ddcRefreshRetryCount = 0

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
            notifyInterceptorRefresh()
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
            notifyInterceptorRefresh()
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
            notifyInterceptorRefresh()
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
            notifyInterceptorRefresh()
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
            notifyInterceptorRefresh()
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

        let displayIDs = Array(onlineDisplays.prefix(Int(displayCount)))
        let externalDisplayIDs = displayIDs.filter { CGDisplayIsBuiltin($0) == 0 }
        DDCManager.shared.configure(displayIDs: externalDisplayIDs)

        let audioDeviceName = SystemAudioManager.shared.getDeviceName()
        let isDisplayAudio = SystemAudioManager.shared.isCurrentOutputDisplayAudio()
        let canSetSystemVolume = SystemAudioManager.shared.canSetVolume()
        #if DEBUG
        print("🔊 Current audio output is display audio: \(isDisplayAudio)")
        print("🔊 Current audio output: \(audioDeviceName), CoreAudio settable: \(canSetSystemVolume)")
        #endif

        for i in 0..<displayIDs.count {
            let displayID = displayIDs[i]
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            #if DEBUG
            print("  Display \(i): ID=\(displayID), isBuiltIn=\(isBuiltIn)")
            #endif

            if !isBuiltIn {
                let name = getDisplayName(displayID)
                var display = Display(id: displayID, name: name, isExternal: true)
                let isAudioTarget = isDisplayAudio && isAudioDeviceName(audioDeviceName, matchingDisplayName: name)

                if let result = DDCManager.shared.readVolume(for: displayID) {
                    resetDDCRefreshRetry()
                    display.currentVolume = safeVolumePercent(
                        current: result.currentValue,
                        max: result.maxValue,
                        displayID: displayID
                    )
                    display.maxVolume = 100
                    display.ddcMaxValue = ddcVolumeMaxValue
                    display.isDDCAvailable = true
                    display.isAudioOutputTarget = isAudioTarget

                    #if DEBUG
                    let route = display.isAudioOutputTarget ? ", audio target" : ""
                    print("📺 External display: \(name), volume: \(display.currentVolume)%, DDC raw: \(result.currentValue)/\(result.maxValue), using max: \(display.ddcMaxValue)\(route)")
                    #endif
                    displayList.append(display)
                    continue
                }

                let hasWriteBackend = DDCManager.shared.hasBackend(for: displayID)
                guard hasWriteBackend || isAudioTarget else {
                    #if DEBUG
                    print("📺 External display: \(name), DDC unavailable")
                    #endif
                    scheduleDDCRefreshRetry(reason: "DDC backend not ready for \(name)")
                    continue
                }

                display.currentVolume = loadSavedVolume(for: displayID) ?? fallbackDisplayVolume
                display.maxVolume = 100
                display.ddcMaxValue = ddcVolumeMaxValue
                display.isDDCAvailable = hasWriteBackend
                display.isAudioOutputTarget = isAudioTarget

                #if DEBUG
                let route = display.isAudioOutputTarget ? ", audio target" : ""
                let state = hasWriteBackend ? "read failed, write backend available" : "waiting for DDC backend"
                print("📺 External display: \(name), \(state), using saved volume: \(display.currentVolume)%\(route)")
                #endif
                displayList.append(display)
                scheduleDDCRefreshRetry(reason: "DDC read not ready for \(name)")
            }
        }

        let hasDisplayAudioTarget = displayList.contains { $0.isAudioOutputTarget }
        #if DEBUG
        print("🔍 DDC displays = \(displayList.count), hasDisplayAudioTarget = \(hasDisplayAudioTarget)")
        #endif

        // 显示器音频匹配到 DDC 屏时优先控制显示器；否则保留系统音频项，避免误控另一台屏。
        if !hasDisplayAudioTarget {
            #if DEBUG
            print("🔍 Creating audio output device...")
            #endif
            var audioDevice = Display(id: 0, name: audioDeviceName, isExternal: false)
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
        if displays.count == 1 {
            activeDisplay = displays.first
            return
        }

        if let audioDevice = displays.first(where: { !$0.isExternal }) {
            activeDisplay = audioDevice
            #if DEBUG
            print("🎯 Active display set to: \(audioDevice.name)")
            #endif
            return
        }

        if let audioTarget = displays.first(where: { $0.isAudioOutputTarget }) {
            activeDisplay = audioTarget
            #if DEBUG
            print("🎯 Active display set to audio target: \(audioTarget.name)")
            #endif
            return
        }

        let mouseLocation = NSEvent.mouseLocation
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
            let ddcValue = ddcValue(forPercent: newVolume, display: active)
            success = DDCManager.shared.setVolume(ddcValue, for: active.id)
            #if DEBUG
            print("  DDC result: \(success ? "✅" : "❌"), raw value: \(ddcValue)")
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
                displays[index].maxVolume = 100
                displays[index].isDDCAvailable = active.isExternal ? true : displays[index].isDDCAvailable
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

                NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
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
                let ddcValue = ddcValue(forPercent: restoreVolume, display: active)
                success = DDCManager.shared.setVolume(ddcValue, for: active.id)
            } else {
                success = SystemAudioManager.shared.setVolume(Float(restoreVolume) / 100.0)
            }

            if success {
                displays[index].currentVolume = restoreVolume
                displays[index].maxVolume = 100
                displays[index].isDDCAvailable = active.isExternal ? true : displays[index].isDDCAvailable
                displays[index].isMuted = false
                activeDisplay = displays[index]
                NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
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
                displays[index].maxVolume = 100
                displays[index].isDDCAvailable = active.isExternal ? true : displays[index].isDDCAvailable
                displays[index].isMuted = true
                activeDisplay = displays[index]
                NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
            }
        }
    }

    private func safeVolumePercent(current: UInt16, max: UInt16, displayID: CGDirectDisplayID) -> Int {
        if (1...ddcVolumeMaxValue).contains(max), current <= max {
            return volumePercent(current: current, max: max)
        }

        if current <= ddcVolumeMaxValue {
            return Int(current)
        }

        let saved = loadSavedVolume(for: displayID)
        #if DEBUG
        print("⚠️ Ignoring suspicious DDC volume range: \(current)/\(max), fallback: \(saved ?? fallbackDisplayVolume)%")
        #endif
        return saved ?? fallbackDisplayVolume
    }

    private func volumePercent(current: UInt16, max: UInt16) -> Int {
        guard max > 0 else { return fallbackDisplayVolume }
        let percent = (Double(current) / Double(max) * 100.0).rounded()
        return Swift.max(0, Swift.min(100, Int(percent)))
    }

    private func ddcValue(forPercent percent: Int, display: Display) -> UInt16 {
        let clampedPercent = Swift.max(0, Swift.min(100, percent))
        let rawMax = Swift.max(1, Swift.min(Int(ddcVolumeMaxValue), Int(display.ddcMaxValue)))
        let rawValue = (Double(clampedPercent) / 100.0 * Double(rawMax)).rounded()
        let boundedRawValue = UInt16(Swift.max(0, Swift.min(rawMax, Int(rawValue))))
        return clampedPercent > 0 ? Swift.max(1, boundedRawValue) : 0
    }

    private func scheduleDDCRefreshRetry(reason: String) {
        guard ddcRefreshRetryCount < maxDDCRefreshRetries else {
            #if DEBUG
            print("⏸️ DDC refresh retry budget exhausted: \(reason)")
            #endif
            return
        }

        pendingDDCRefreshWorkItem?.cancel()
        ddcRefreshRetryCount += 1

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            print("🔁 Retrying display refresh: \(reason)")
            #endif
            self.refreshDisplays()
            NotificationCenter.default.post(name: NSNotification.Name("DisplayChanged"), object: nil)
        }

        pendingDDCRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func resetDDCRefreshRetry() {
        pendingDDCRefreshWorkItem?.cancel()
        pendingDDCRefreshWorkItem = nil
        ddcRefreshRetryCount = 0
    }

    private func isAudioDeviceName(_ deviceName: String, matchingDisplayName displayName: String) -> Bool {
        let device = normalizedAudioName(deviceName)
        let display = normalizedAudioName(displayName)
        guard !device.isEmpty, !display.isEmpty else { return false }
        return device == display || device.contains(display) || display.contains(device)
    }

    private func normalizedAudioName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
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
        resetDDCRefreshRetry()
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
        resetDDCRefreshRetry()
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
