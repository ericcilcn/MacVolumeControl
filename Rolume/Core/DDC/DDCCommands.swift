import Foundation

enum DDCCommand: UInt8 {
    case volume = 0x62
}

struct DDCReadResult {
    let currentValue: UInt16
    let maxValue: UInt16
}
