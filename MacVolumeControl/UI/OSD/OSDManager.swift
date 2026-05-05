import AppKit
import CoreGraphics

class OSDManager {
    static let shared = OSDManager()
    private var customOSDWindow: CustomOSDWindow?

    private init() {}

    /// 显示 OSD
    func showOSD(volume: Int, maxVolume: Int, isExternal: Bool, displayID: CGDirectDisplayID) {
        // 统一使用自定义 OSD
        if customOSDWindow == nil {
            customOSDWindow = CustomOSDWindow()
        }
        customOSDWindow?.show(volume: volume, maxVolume: maxVolume, on: displayID)
    }
}
