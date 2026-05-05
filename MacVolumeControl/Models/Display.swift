import Foundation
import CoreGraphics

struct Display: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let isExternal: Bool

    var currentVolume: Int = 0
    var maxVolume: Int = 100
    var isMuted: Bool = false
    var volumeBeforeMute: Int = 0  // 静音前的音量
}
