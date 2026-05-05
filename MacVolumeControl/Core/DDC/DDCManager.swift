import Foundation
import CoreGraphics
import IOKit

// MARK: - Apple Silicon 私有 API (通过 dlsym 动态加载)

private let ioKitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)

private typealias IOAVServiceCreateWithServiceFunc = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
private typealias IOAVServiceReadI2CFunc = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
private typealias IOAVServiceWriteI2CFunc = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeRawPointer, UInt32) -> IOReturn

private let _IOAVServiceCreateWithService: IOAVServiceCreateWithServiceFunc? = {
    guard let handle = ioKitHandle, let sym = dlsym(handle, "IOAVServiceCreateWithService") else { return nil }
    return unsafeBitCast(sym, to: IOAVServiceCreateWithServiceFunc.self)
}()

private let _IOAVServiceReadI2C: IOAVServiceReadI2CFunc? = {
    guard let handle = ioKitHandle, let sym = dlsym(handle, "IOAVServiceReadI2C") else { return nil }
    return unsafeBitCast(sym, to: IOAVServiceReadI2CFunc.self)
}()

private let _IOAVServiceWriteI2C: IOAVServiceWriteI2CFunc? = {
    guard let handle = ioKitHandle, let sym = dlsym(handle, "IOAVServiceWriteI2C") else { return nil }
    return unsafeBitCast(sym, to: IOAVServiceWriteI2CFunc.self)
}()

// MARK: - DDC Manager

class DDCManager {
    static let shared = DDCManager()

    // 可配置的重试参数（参考 MonitorControl）
    private let writeSleepTime: UInt32 = 10000      // 10ms - 写入周期间延迟
    private let numOfWriteCycles: Int = 2            // 每次尝试写入2次
    private let readSleepTime: UInt32 = 50000        // 50ms - 写入后等待读取
    private let numOfRetryAttempts: Int = 4          // 重试次数
    private let retrySleepTime: UInt32 = 20000       // 20ms - 重试间延迟

    private init() {
        print("🔧 DDCManager init:")
        print("  IOAVServiceCreateWithService: \(_IOAVServiceCreateWithService != nil ? "✅ loaded" : "❌ not found")")
        print("  IOAVServiceReadI2C: \(_IOAVServiceReadI2C != nil ? "✅ loaded" : "❌ not found")")
        print("  IOAVServiceWriteI2C: \(_IOAVServiceWriteI2C != nil ? "✅ loaded" : "❌ not found")")
    }

    func readVolume(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        guard let avService = getAVService(for: displayID) else { return nil }

        var current: UInt32 = 0
        var max: UInt32 = 0

        if ddcRead(avService: avService, command: 0x62, current: &current, max: &max) {
            return DDCReadResult(currentValue: UInt16(current), maxValue: UInt16(max))
        }

        return nil
    }

    func setVolume(_ value: UInt16, for displayID: CGDirectDisplayID) -> Bool {
        guard let avService = getAVService(for: displayID) else { return false }

        return ddcWrite(avService: avService, command: 0x62, value: value)
    }

    // MARK: - 获取 IOAVService

    private func getAVService(for displayID: CGDirectDisplayID) -> CFTypeRef? {
        guard let createFunc = _IOAVServiceCreateWithService else { return nil }
        guard let service = findExternalDCPAVServiceProxy() else { return nil }

        let avServiceUnmanaged = createFunc(kCFAllocatorDefault, service)
        IOObjectRelease(service)

        guard let avService = avServiceUnmanaged?.takeRetainedValue() else { return nil }
        return avService
    }

    private func findExternalDCPAVServiceProxy() -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("DCPAVServiceProxy") else { return nil }

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let properties = props?.takeRetainedValue() as? [String: Any] {
                let location = properties["Location"] as? String ?? "Unknown"
                if location == "External" {
                    return service
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    // MARK: - DDC Read

    private func ddcRead(avService: CFTypeRef, command: UInt8, current: inout UInt32, max: inout UInt32) -> Bool {
        guard let writeFunc = _IOAVServiceWriteI2C, let readFunc = _IOAVServiceReadI2C else { return false }

        // 构建 DDC 请求包
        var writeData: [UInt8] = [0x51, 0x82, 0x01, command]
        let checksum: UInt8 = 0x6E ^ writeData[0] ^ writeData[1] ^ writeData[2] ^ writeData[3]
        writeData.append(checksum)

        let readSize = 12
        let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: readSize)
        defer { readBuffer.deallocate() }

        // 使用 MonitorControl 的重试逻辑
        for _ in 0..<numOfRetryAttempts {
            var writeSuccess = false

            // 多次写入循环
            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                let writeResult = writeData.withUnsafeBytes { ptr in
                    writeFunc(avService, 0x37, 0x51, ptr.baseAddress!, UInt32(writeData.count))
                }
                if writeResult == kIOReturnSuccess {
                    writeSuccess = true
                }
            }

            if !writeSuccess {
                usleep(retrySleepTime)
                continue
            }

            // 等待显示器准备响应
            usleep(readSleepTime)

            readBuffer.initialize(repeating: 0, count: readSize)
            let readResult = readFunc(avService, 0x37, 0x6F, readBuffer, UInt32(readSize))

            if readResult == kIOReturnSuccess {
                let readData = Array(UnsafeBufferPointer(start: readBuffer, count: readSize))

                // 验证响应并提取数值
                if readData.count >= 11 && readData[2] == 0x02 {
                    max = UInt32(readData[6]) << 8 | UInt32(readData[7])
                    current = UInt32(readData[8]) << 8 | UInt32(readData[9])
                    if max > 0 { return true }
                }
            }

            usleep(retrySleepTime)
        }

        return false
    }

    // MARK: - DDC Write

    private func ddcWrite(avService: CFTypeRef, command: UInt8, value: UInt16) -> Bool {
        guard let writeFunc = _IOAVServiceWriteI2C else { return false }

        let high = UInt8((value >> 8) & 0xFF)
        let low = UInt8(value & 0xFF)

        var packet: [UInt8] = [0x84, 0x03, command, high, low, 0x00]
        var chk: UInt8 = 0x6E ^ 0x51
        for i in 0..<(packet.count - 1) { chk ^= packet[i] }
        packet[packet.count - 1] = chk

        // 使用 MonitorControl 的重试逻辑
        for _ in 0..<numOfRetryAttempts {
            var success = false

            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                let result = packet.withUnsafeBytes { ptr in
                    writeFunc(avService, 0x37, 0x51, ptr.baseAddress!, UInt32(packet.count))
                }
                if result == kIOReturnSuccess {
                    success = true
                }
            }

            if success { return true }
            usleep(retrySleepTime)
        }

        return false
    }
}
