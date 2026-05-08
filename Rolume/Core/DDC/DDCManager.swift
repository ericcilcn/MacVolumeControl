import Foundation
import CoreGraphics
import IOKit

// CoreDisplay 私有 API
private func CoreDisplay_DisplayCreateInfoDictionary(_ displayID: CGDirectDisplayID) -> Unmanaged<CFDictionary>? {
    typealias CreateInfoDictionary = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?
    guard let bundle = CFBundleGetBundleWithIdentifier("com.apple.CoreDisplay" as CFString),
          let funcPointer = CFBundleGetFunctionPointerForName(bundle, "CoreDisplay_DisplayCreateInfoDictionary" as CFString) else {
        return nil
    }
    let function = unsafeBitCast(funcPointer, to: CreateInfoDictionary.self)
    return function(displayID)
}

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

    private let writeSleepTime: UInt32 = 10000
    private let numOfWriteCycles: Int = 2
    private let readSleepTime: UInt32 = 50000
    private let numOfRetryAttempts: Int = 4
    private let retrySleepTime: UInt32 = 20000

    private init() {}

    // MARK: - Public

    func readVolume(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        // 优先 Apple Silicon IOAVService
        if let avService = getAVService(for: displayID) {
            var current: UInt32 = 0
            var max: UInt32 = 0
            if ddcReadARM(avService: avService, command: 0x62, current: &current, max: &max) {
                return DDCReadResult(currentValue: UInt16(current), maxValue: UInt16(max))
            }
        }

        // 回退 Intel framebuffer I2C
        if let fbService = getFramebufferService(for: displayID) {
            var current: UInt32 = 0
            var max: UInt32 = 0
            if ddcReadIntel(framebuffer: fbService, command: 0x62, current: &current, max: &max) {
                return DDCReadResult(currentValue: UInt16(current), maxValue: UInt16(max))
            }
        }

        return nil
    }

    func setVolume(_ value: UInt16, for displayID: CGDirectDisplayID) -> Bool {
        if let avService = getAVService(for: displayID) {
            if ddcWriteARM(avService: avService, command: 0x62, value: value) {
                return true
            }
        }

        if let fbService = getFramebufferService(for: displayID) {
            return ddcWriteIntel(framebuffer: fbService, command: 0x62, value: UInt32(value))
        }

        return false
    }

    // MARK: - Apple Silicon (IOAVService)

    private func getAVService(for displayID: CGDirectDisplayID) -> CFTypeRef? {
        guard let createFunc = _IOAVServiceCreateWithService else { return nil }

        // 枚举所有 DCPAVServiceProxy，用 EDID 评分匹配到正确的显示器
        let services = enumerateDCPAVServiceProxies()
        if services.isEmpty { return nil }

        // 多显示器：评分匹配；单显示器：直接用第一个 External
        let bestService: io_service_t
        if services.count > 1 {
            bestService = matchDisplayService(displayID: displayID, from: services) ?? services.first(where: { $0.location == "External" })?.service ?? services[0].service
        } else {
            bestService = services[0].service
        }

        let avServiceUnmanaged = createFunc(kCFAllocatorDefault, bestService)
        for s in services { IOObjectRelease(s.service) }

        return avServiceUnmanaged?.takeRetainedValue() as CFTypeRef?
    }

    private struct DCPAVServiceInfo {
        let service: io_service_t
        let location: String
        let edidUUID: String
    }

    private func enumerateDCPAVServiceProxies() -> [DCPAVServiceInfo] {
        var results: [DCPAVServiceInfo] = []
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("DCPAVServiceProxy") else { return results }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return results
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let properties = props?.takeRetainedValue() as? [String: Any] {
                let location = properties["Location"] as? String ?? "Unknown"
                let edidUUID: String
                if let unmanaged = IORegistryEntryCreateCFProperty(service, "EDID UUID" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) {
                    edidUUID = unmanaged.takeRetainedValue() as? String ?? ""
                } else {
                    edidUUID = ""
                }
                results.append(DCPAVServiceInfo(service: service, location: location, edidUUID: edidUUID))
            } else {
                IOObjectRelease(service)
            }
            service = IOIteratorNext(iterator)
        }
        return results
    }

    /// 仿 MonitorControl：通过 EDID UUID 中的 Vendor/Product/Date/Size 做评分匹配
    private func matchDisplayService(displayID: CGDirectDisplayID, from services: [DCPAVServiceInfo]) -> io_service_t? {
        guard let dict = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary? else {
            return nil
        }
        var bestScore = 0
        var bestService: io_service_t?

        for svc in services where svc.location == "External" && !svc.edidUUID.isEmpty {
            var score = 0
            // Vendor ID (EDID UUID 位置 0-3)
            if let vendorID = dict[kDisplayVendorID] as? Int64 {
                let hex = String(format: "%04x", UInt16(max(0, min(vendorID, 0xFFFF)))).uppercased()
                if hex == svc.edidUUID.prefix(4) { score += 1 }
            }
            // Product ID (EDID UUID 位置 4-7)
            if let productID = dict[kDisplayProductID] as? Int64 {
                let hi = String(format: "%02x", UInt8((UInt16(productID) >> 0) & 0xFF)).uppercased()
                let lo = String(format: "%02x", UInt8((UInt16(productID) >> 8) & 0xFF)).uppercased()
                if hi + lo == svc.edidUUID.dropFirst(4).prefix(4) { score += 1 }
            }
            // Display location matches → strong signal
            if let ioLocation = dict[kIODisplayLocationKey] as? String {
                let svcPath = getServicePath(svc.service)
                if svcPath.contains(ioLocation) {
                    score += 10
                }
            }
            if score > bestScore {
                bestScore = score
                bestService = svc.service
            }
        }
        return bestService
    }

    private func getServicePath(_ service: io_service_t) -> String {
        let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
        defer { cpath.deallocate() }
        IORegistryEntryGetPath(service, kIOServicePlane, cpath)
        return String(cString: cpath)
    }

    private func ddcReadARM(avService: CFTypeRef, command: UInt8, current: inout UInt32, max: inout UInt32) -> Bool {
        guard let writeFunc = _IOAVServiceWriteI2C, let readFunc = _IOAVServiceReadI2C else { return false }

        var writeData: [UInt8] = [0x51, 0x82, 0x01, command]
        let checksum: UInt8 = 0x6E ^ writeData[0] ^ writeData[1] ^ writeData[2] ^ writeData[3]
        writeData.append(checksum)

        let readSize = 12
        let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: readSize)
        defer { readBuffer.deallocate() }

        for _ in 0..<numOfRetryAttempts {
            var writeSuccess = false
            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                let writeResult = writeData.withUnsafeBytes { ptr in
                    writeFunc(avService, 0x37, 0x51, ptr.baseAddress!, UInt32(writeData.count))
                }
                if writeResult == kIOReturnSuccess { writeSuccess = true }
            }
            if !writeSuccess { usleep(retrySleepTime); continue }

            usleep(readSleepTime)
            readBuffer.initialize(repeating: 0, count: readSize)
            let readResult = readFunc(avService, 0x37, 0x6F, readBuffer, UInt32(readSize))

            if readResult == kIOReturnSuccess {
                let readData = Array(UnsafeBufferPointer(start: readBuffer, count: readSize))
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

    private func ddcWriteARM(avService: CFTypeRef, command: UInt8, value: UInt16) -> Bool {
        guard let writeFunc = _IOAVServiceWriteI2C else { return false }

        let high = UInt8((value >> 8) & 0xFF)
        let low = UInt8(value & 0xFF)
        var packet: [UInt8] = [0x84, 0x03, command, high, low, 0x00]
        var chk: UInt8 = 0x6E ^ 0x51
        for i in 0..<(packet.count - 1) { chk ^= packet[i] }
        packet[packet.count - 1] = chk

        for _ in 0..<numOfRetryAttempts {
            var success = false
            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                let result = packet.withUnsafeBytes { ptr in
                    writeFunc(avService, 0x37, 0x51, ptr.baseAddress!, UInt32(packet.count))
                }
                if result == kIOReturnSuccess { success = true }
            }
            if success { return true }
            usleep(retrySleepTime)
        }
        return false
    }

    // MARK: - Intel Framebuffer I2C（回退路径）

    private func getFramebufferService(for displayID: CGDirectDisplayID) -> io_service_t? {
        if CGDisplayIsBuiltin(displayID) != 0 { return nil }

        // 尝试 CGSServiceForDisplayNumber（私有 API）
        var cgsService: io_service_t = 0
        let cgsFunc = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSServiceForDisplayNumber")
        if let cgsFunc = cgsFunc {
            typealias CGSServiceForDisplayNumberFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<io_service_t>) -> Void
            let fn = unsafeBitCast(cgsFunc, to: CGSServiceForDisplayNumberFunc.self)
            fn(displayID, &cgsService)
        }

        if cgsService != 0 {
            var busCount: IOItemCount = 0
            if IOFBGetI2CInterfaceCount(cgsService, &busCount) == KERN_SUCCESS, busCount >= 1 {
                return cgsService
            }
        }

        return nil
    }

    private func i2cSend(request: inout IOI2CRequest, to framebuffer: io_service_t) -> Bool {
        return IOI2CSendRequest(framebuffer, 0, &request) == KERN_SUCCESS
    }

    private func ddcReadIntel(framebuffer: io_service_t, command: UInt8, current: inout UInt32, max: inout UInt32) -> Bool {
        var data: [UInt8] = [0x51, 0x82, 0x01, command]
        data.append(0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3])
        var replyData = [UInt8](repeating: 0, count: 11)

        for _ in 0..<numOfRetryAttempts {
            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                var request = IOI2CRequest()
                request.sendAddress = 0x6E
                request.sendTransactionType = UInt32(kIOI2CSimpleTransactionType)
                request.sendBuffer = vm_address_t(bitPattern: data.withUnsafeBytes { $0.baseAddress })
                request.sendBytes = UInt32(data.count)
                request.replyAddress = 0x6F
                request.replyTransactionType = UInt32(kIOI2CDDCciReplyTransactionType)
                request.replyBytes = UInt32(replyData.count)
                request.replyBuffer = vm_address_t(bitPattern: replyData.withUnsafeMutableBytes { $0.baseAddress })

                guard i2cSend(request: &request, to: framebuffer) else { continue }

                if replyData.count >= 10 && replyData[2] == 0x02 {
                    max = UInt32(replyData[6]) << 8 | UInt32(replyData[7])
                    current = UInt32(replyData[8]) << 8 | UInt32(replyData[9])
                    if max > 0 { return true }
                }
            }
            usleep(retrySleepTime)
        }
        return false
    }

    private func ddcWriteIntel(framebuffer: io_service_t, command: UInt8, value: UInt32) -> Bool {
        let high = UInt8((value >> 8) & 0xFF)
        let low = UInt8(value & 0xFF)
        var data: [UInt8] = [0x51, 0x84, 0x03, command, high, low, 0x00]
        data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5]

        for _ in 0..<numOfRetryAttempts {
            var success = false
            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                var request = IOI2CRequest()
                request.sendAddress = 0x6E
                request.sendTransactionType = UInt32(kIOI2CSimpleTransactionType)
                request.sendBuffer = vm_address_t(bitPattern: data.withUnsafeBytes { $0.baseAddress })
                request.sendBytes = UInt32(data.count)
                request.replyTransactionType = UInt32(kIOI2CNoTransactionType)
                request.replyBytes = 0

                if i2cSend(request: &request, to: framebuffer) { success = true }
            }
            if success { return true }
            usleep(retrySleepTime)
        }
        return false
    }
}
