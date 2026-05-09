import Foundation
import CoreGraphics
import IOKit
import IOKit.graphics
import IOKit.i2c

private func CoreDisplay_DisplayCreateInfoDictionary(_ displayID: CGDirectDisplayID) -> Unmanaged<CFDictionary>? {
    typealias CreateInfoDictionary = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?
    guard let bundle = CFBundleGetBundleWithIdentifier("com.apple.CoreDisplay" as CFString),
          let funcPointer = CFBundleGetFunctionPointerForName(bundle, "CoreDisplay_DisplayCreateInfoDictionary" as CFString) else {
        return nil
    }
    let function = unsafeBitCast(funcPointer, to: CreateInfoDictionary.self)
    return function(displayID)
}

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

private let ddcAddress: UInt8 = 0x37
private let ddcDataAddress: UInt8 = 0x51
private let ddcCommandVolume: UInt8 = 0x62

class DDCManager {
    static let shared = DDCManager()

    private struct IntelBackend {
        let framebuffer: io_service_t
        let replyTransactionType: IOOptionBits
    }

    private enum Backend {
        case arm(service: CFTypeRef)
        case intel(IntelBackend)
    }

    private struct IORegService {
        var avService: CFTypeRef?
        var edidUUID = ""
        var ioDisplayLocation = ""
        var productName = ""
        var serialNumber: Int64 = 0
        var location = ""
        var serviceLocation = 0
    }

    private struct ArmCandidate {
        let displayID: CGDirectDisplayID
        let service: IORegService
        let score: Int
    }

    private let ddcQueue = DispatchQueue(label: "Rolume DDC queue")

    private var backends: [CGDirectDisplayID: Backend] = [:]

    private let writeSleepTime: UInt32 = 10000
    private let numOfWriteCycles = 2
    private let readSleepTime: UInt32 = 50000
    private let numOfRetryAttempts = 4
    private let retrySleepTime: UInt32 = 20000

    private init() {}

    func configure(displayIDs: [CGDirectDisplayID]) {
        ddcQueue.sync {
            clearBackendsLocked()
            configureBackendsLocked(displayIDs: displayIDs)
        }
    }

    func hasBackend(for displayID: CGDirectDisplayID) -> Bool {
        ddcQueue.sync {
            if backends[displayID] == nil {
                configureBackendsLocked(displayIDs: [displayID])
            }
            return backends[displayID] != nil
        }
    }

    func readVolume(for displayID: CGDirectDisplayID) -> DDCReadResult? {
        ddcQueue.sync {
            if backends[displayID] == nil {
                configureBackendsLocked(displayIDs: [displayID])
            }
            guard let backend = backends[displayID],
                  let values = readVolumeLocked(backend: backend) else {
                return nil
            }
            return DDCReadResult(currentValue: values.current, maxValue: values.max)
        }
    }

    /// Writes synchronously so app state, custom OSD, and the display's real volume stay aligned.
    func setVolume(_ value: UInt16, for displayID: CGDirectDisplayID) -> Bool {
        ddcQueue.sync {
            if backends[displayID] == nil {
                configureBackendsLocked(displayIDs: [displayID])
            }
            guard let backend = backends[displayID] else {
                return false
            }
            return writeVolumeLocked(backend: backend, value: value)
        }
    }

    private func clearBackendsLocked() {
        for backend in backends.values {
            if case .intel(let intel) = backend {
                IOObjectRelease(intel.framebuffer)
            }
        }
        backends.removeAll()
    }

    private func configureBackendsLocked(displayIDs: [CGDirectDisplayID]) {
        let externalDisplayIDs = displayIDs.filter { CGDisplayIsBuiltin($0) == 0 }
        guard !externalDisplayIDs.isEmpty else { return }

        configureArmBackendsLocked(displayIDs: externalDisplayIDs)

        for displayID in externalDisplayIDs where backends[displayID] == nil {
            if let intel = makeIntelBackend(for: displayID) {
                backends[displayID] = .intel(intel)
            }
        }
    }

    private func configureArmBackendsLocked(displayIDs: [CGDirectDisplayID]) {
        #if arch(arm64)
        let services = collectArmServices()
        guard !services.isEmpty else { return }

        if displayIDs.count == 1,
           services.count == 1,
           let service = services[0].avService {
            backends[displayIDs[0]] = .arm(service: service)
            return
        }

        var candidates: [ArmCandidate] = []
        for displayID in displayIDs {
            for service in services where service.avService != nil {
                let score = armMatchScore(displayID: displayID, service: service)
                if score > 0 {
                    candidates.append(ArmCandidate(displayID: displayID, service: service, score: score))
                }
            }
        }

        var usedDisplays = Set<CGDirectDisplayID>()
        var usedServiceLocations = Set<Int>()

        for candidate in candidates.sorted(by: { $0.score > $1.score }) {
            guard !usedDisplays.contains(candidate.displayID),
                  !usedServiceLocations.contains(candidate.service.serviceLocation),
                  let service = candidate.service.avService else {
                continue
            }
            backends[candidate.displayID] = .arm(service: service)
            usedDisplays.insert(candidate.displayID)
            usedServiceLocations.insert(candidate.service.serviceLocation)
        }
        #endif
    }

    private func collectArmServices() -> [IORegService] {
        guard let createFunc = _IOAVServiceCreateWithService else { return [] }

        var results: [IORegService] = []
        var serviceLocation = 0
        var current = IORegService()

        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != IO_OBJECT_NULL else { return [] }
        defer { IOObjectRelease(root) }

        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(
            root,
            kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        ) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != IO_OBJECT_NULL else { break }
            defer { IOObjectRelease(entry) }

            let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
            defer { nameBuffer.deallocate() }

            guard IORegistryEntryGetName(entry, nameBuffer) == KERN_SUCCESS else { continue }
            let entryName = String(cString: nameBuffer)

            if entryName.contains("AppleCLCD2") || entryName.contains("IOMobileFramebufferShim") {
                current = readArmDisplayProperties(entry: entry)
                serviceLocation += 1
                current.serviceLocation = serviceLocation
            } else if entryName.contains("DCPAVServiceProxy") {
                guard let unmanagedLocation = IORegistryEntryCreateCFProperty(
                    entry,
                    "Location" as CFString,
                    kCFAllocatorDefault,
                    IOOptionBits(kIORegistryIterateRecursively)
                ) else {
                    continue
                }

                current.location = unmanagedLocation.takeRetainedValue() as? String ?? ""
                if current.location == "External" {
                    current.avService = createFunc(kCFAllocatorDefault, entry)?.takeRetainedValue()
                    if current.avService != nil {
                        results.append(current)
                    }
                }
            }
        }

        return results
    }

    private func readArmDisplayProperties(entry: io_service_t) -> IORegService {
        var service = IORegService()

        if let unmanaged = IORegistryEntryCreateCFProperty(
            entry,
            "EDID UUID" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        ) {
            service.edidUUID = unmanaged.takeRetainedValue() as? String ?? ""
        }

        let path = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
        defer { path.deallocate() }
        if IORegistryEntryGetPath(entry, kIOServicePlane, path) == KERN_SUCCESS {
            service.ioDisplayLocation = String(cString: path)
        }

        if let unmanaged = IORegistryEntryCreateCFProperty(
            entry,
            "DisplayAttributes" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        ), let attrs = unmanaged.takeRetainedValue() as? NSDictionary,
           let productAttrs = attrs["ProductAttributes"] as? NSDictionary {
            service.productName = productAttrs["ProductName"] as? String ?? ""
            service.serialNumber = int64Value(productAttrs["SerialNumber"]) ?? 0
        }

        return service
    }

    private func armMatchScore(displayID: CGDirectDisplayID, service: IORegService) -> Int {
        guard let dict = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary? else {
            return 0
        }

        var score = 0
        let edid = service.edidUUID

        if !edid.isEmpty {
            if let vendorID = int64Value(dict[kDisplayVendorID]) {
                let vendor = String(format: "%04x", UInt16(max(0, min(vendorID, 0xFFFF)))).uppercased()
                if edid.prefix(4) == vendor { score += 1 }
            }

            if let productID = int64Value(dict[kDisplayProductID]) {
                let clamped = UInt16(max(0, min(productID, 0xFFFF)))
                let product = String(format: "%02x", UInt8(clamped & 0xFF)).uppercased()
                    + String(format: "%02x", UInt8((clamped >> 8) & 0xFF)).uppercased()
                if edid.dropFirst(4).prefix(4) == product { score += 1 }
            }

            if let week = int64Value(dict[kDisplayWeekOfManufacture]),
               let year = int64Value(dict[kDisplayYearOfManufacture]) {
                let date = String(format: "%02x", UInt8(max(0, min(week, 0xFF)))).uppercased()
                    + String(format: "%02x", UInt8(max(0, min(year - 1990, 0xFF)))).uppercased()
                if edid.dropFirst(19).prefix(4) == date { score += 1 }
            }

            if let horizontal = int64Value(dict[kDisplayHorizontalImageSize]),
               let vertical = int64Value(dict[kDisplayVerticalImageSize]) {
                let size = String(format: "%02x", UInt8(max(0, min(horizontal / 10, 0xFF)))).uppercased()
                    + String(format: "%02x", UInt8(max(0, min(vertical / 10, 0xFF)))).uppercased()
                if edid.dropFirst(30).prefix(4) == size { score += 1 }
            }
        }

        if let location = dict[kIODisplayLocationKey] as? String,
           !service.ioDisplayLocation.isEmpty,
           service.ioDisplayLocation == location {
            score += 10
        }

        if !service.productName.isEmpty,
           let names = dict["DisplayProductName"] as? [String: String],
           let name = names["en_US"] ?? names.values.first,
           name.caseInsensitiveCompare(service.productName) == .orderedSame {
            score += 1
        }

        if service.serialNumber != 0,
           let serial = int64Value(dict[kDisplaySerialNumber]),
           serial == service.serialNumber {
            score += 1
        }

        return score
    }

    private func makeIntelBackend(for displayID: CGDirectDisplayID) -> IntelBackend? {
        guard let framebuffer = framebufferService(for: displayID),
              let replyType = supportedIntelReplyTransactionType() else {
            return nil
        }
        return IntelBackend(framebuffer: framebuffer, replyTransactionType: replyType)
    }

    private func supportedIntelReplyTransactionType() -> IOOptionBits? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceNameMatching("IOFramebufferI2CInterface"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != IO_OBJECT_NULL else { break }
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = props?.takeRetainedValue() as? [String: Any],
                  let types = properties[kIOI2CTransactionTypesKey] as? UInt64 else {
                continue
            }

            if (1 << kIOI2CDDCciReplyTransactionType) & types != 0 {
                return IOOptionBits(kIOI2CDDCciReplyTransactionType)
            }
            if (1 << kIOI2CSimpleTransactionType) & types != 0 {
                return IOOptionBits(kIOI2CSimpleTransactionType)
            }
        }

        return nil
    }

    private func framebufferService(for displayID: CGDirectDisplayID) -> io_service_t? {
        guard CGDisplayIsBuiltin(displayID) == 0 else { return nil }

        if let cgsFunc = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSServiceForDisplayNumber") {
            typealias CGSServiceForDisplayNumberFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<io_service_t>) -> Void
            let fn = unsafeBitCast(cgsFunc, to: CGSServiceForDisplayNumberFunc.self)
            var service: io_service_t = 0
            fn(displayID, &service)
            if service != IO_OBJECT_NULL {
                var busCount: IOItemCount = 0
                if IOFBGetI2CInterfaceCount(service, &busCount) == KERN_SUCCESS, busCount >= 1 {
                    return service
                }
            }
        }

        return framebufferServiceByDisplayProperties(displayID: displayID)
    }

    private func framebufferServiceByDisplayProperties(displayID: CGDirectDisplayID) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let port = IOIteratorNext(iterator)
            guard port != IO_OBJECT_NULL else { break }

            guard let dict = IODisplayCreateInfoDictionary(
                port,
                IOOptionBits(kIODisplayOnlyPreferredName)
            )?.takeRetainedValue() as NSDictionary? else {
                IOObjectRelease(port)
                continue
            }

            let vendor = uint32Value(dict[kDisplayVendorID])
            let product = uint32Value(dict[kDisplayProductID])
            let serial = uint32Value(dict[kDisplaySerialNumber])

            guard vendor == CGDisplayVendorNumber(displayID),
                  product == CGDisplayModelNumber(displayID),
                  serial == CGDisplaySerialNumber(displayID) else {
                IOObjectRelease(port)
                continue
            }

            if let displayLocation = dict[kIODisplayLocationKey] as? String,
               let unitNumber = displayLocation.split(separator: "@").last.flatMap({ UInt32($0.prefix { $0.isNumber }) }),
               unitNumber != CGDisplayUnitNumber(displayID) {
                IOObjectRelease(port)
                continue
            }

            var busCount: IOItemCount = 0
            guard IOFBGetI2CInterfaceCount(port, &busCount) == KERN_SUCCESS, busCount >= 1 else {
                IOObjectRelease(port)
                continue
            }

            return port
        }

        return nil
    }

    private func readVolumeLocked(backend: Backend) -> (current: UInt16, max: UInt16)? {
        switch backend {
        case .arm(let service):
            return readARM(service: service, command: ddcCommandVolume)
        case .intel(let intel):
            return readIntel(backend: intel, command: ddcCommandVolume)
        }
    }

    private func writeVolumeLocked(backend: Backend, value: UInt16) -> Bool {
        switch backend {
        case .arm(let service):
            return writeARM(service: service, command: ddcCommandVolume, value: value)
        case .intel(let intel):
            return writeIntel(backend: intel, command: ddcCommandVolume, value: value)
        }
    }

    private func readARM(service: CFTypeRef, command: UInt8) -> (current: UInt16, max: UInt16)? {
        guard let writeFunc = _IOAVServiceWriteI2C, let readFunc = _IOAVServiceReadI2C else { return nil }

        var send: [UInt8] = [command]
        var reply = [UInt8](repeating: 0, count: 11)

        guard performARMCommunication(
            service: service,
            send: &send,
            reply: &reply,
            writeFunc: writeFunc,
            readFunc: readFunc
        ), reply[2] == 0x02, reply[3] == 0x00 else {
            return nil
        }

        let maxValue = UInt16(reply[6]) << 8 | UInt16(reply[7])
        let currentValue = UInt16(reply[8]) << 8 | UInt16(reply[9])
        return maxValue > 0 ? (currentValue, maxValue) : nil
    }

    private func writeARM(service: CFTypeRef, command: UInt8, value: UInt16) -> Bool {
        guard let writeFunc = _IOAVServiceWriteI2C else { return false }

        var send: [UInt8] = [
            command,
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        var reply: [UInt8] = []

        return performARMCommunication(
            service: service,
            send: &send,
            reply: &reply,
            writeFunc: writeFunc,
            readFunc: nil
        )
    }

    private func performARMCommunication(
        service: CFTypeRef,
        send: inout [UInt8],
        reply: inout [UInt8],
        writeFunc: IOAVServiceWriteI2CFunc,
        readFunc: IOAVServiceReadI2CFunc?
    ) -> Bool {
        var packet = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send + [0]
        let checksumSeed = send.count == 1 ? (ddcAddress << 1) : ((ddcAddress << 1) ^ ddcDataAddress)
        packet[packet.count - 1] = checksum(seed: checksumSeed, data: packet, end: packet.count - 2)

        for _ in 0..<numOfRetryAttempts {
            var writeSuccess = false
            for _ in 0..<numOfWriteCycles {
                usleep(writeSleepTime)
                let result = packet.withUnsafeBytes { bytes in
                    writeFunc(service, UInt32(ddcAddress), UInt32(ddcDataAddress), bytes.baseAddress!, UInt32(packet.count))
                }
                if result == kIOReturnSuccess {
                    writeSuccess = true
                }
            }

            guard writeSuccess else {
                usleep(retrySleepTime)
                continue
            }

            if reply.isEmpty {
                return true
            }

            guard let readFunc = readFunc else { return false }
            usleep(readSleepTime)
            for index in reply.indices {
                reply[index] = 0
            }

            let replyByteCount = UInt32(reply.count)
            let readResult = reply.withUnsafeMutableBytes { bytes in
                readFunc(service, UInt32(ddcAddress), 0, bytes.baseAddress!, replyByteCount)
            }
            if readResult == kIOReturnSuccess,
               checksum(seed: 0x50, data: reply, end: reply.count - 2) == reply[reply.count - 1] {
                return true
            }

            usleep(retrySleepTime)
        }

        return false
    }

    private func readIntel(backend: IntelBackend, command: UInt8) -> (current: UInt16, max: UInt16)? {
        var data: [UInt8] = [0x51, 0x82, 0x01, command, 0]
        data[4] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3]
        var reply = [UInt8](repeating: 0, count: 11)

        for _ in 0..<numOfRetryAttempts {
            usleep(writeSleepTime)
            let sendByteCount = UInt32(data.count)
            let replyByteCount = UInt32(reply.count)
            let success = data.withUnsafeBufferPointer { sendBuffer in
                reply.withUnsafeMutableBufferPointer { replyBuffer in
                    var request = IOI2CRequest()
                    request.commFlags = 0
                    request.sendAddress = 0x6E
                    request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
                    request.sendBuffer = vm_address_t(bitPattern: sendBuffer.baseAddress)
                    request.sendBytes = sendByteCount
                    request.minReplyDelay = 10
                    request.replyAddress = 0x6F
                    request.replySubAddress = 0x51
                    request.replyTransactionType = backend.replyTransactionType
                    request.replyBuffer = vm_address_t(bitPattern: replyBuffer.baseAddress)
                    request.replyBytes = replyByteCount
                    return sendIntel(request: &request, to: backend.framebuffer)
                }
            }

            guard success else {
                usleep(retrySleepTime)
                continue
            }

            let replyChecksum = reply[reply.count - 1]
            guard checksum(seed: 0x50, data: reply, end: reply.count - 2) == replyChecksum,
                  reply[2] == 0x02,
                  reply[3] == 0x00 else {
                usleep(retrySleepTime)
                continue
            }

            let maxValue = UInt16(reply[6]) << 8 | UInt16(reply[7])
            let currentValue = UInt16(reply[8]) << 8 | UInt16(reply[9])
            return maxValue > 0 ? (currentValue, maxValue) : nil
        }

        return nil
    }

    private func writeIntel(backend: IntelBackend, command: UInt8, value: UInt16) -> Bool {
        var data: [UInt8] = [
            0x51,
            0x84,
            0x03,
            command,
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
            0
        ]
        data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5]

        var success = false
        for _ in 0..<numOfWriteCycles {
            usleep(writeSleepTime)
            let sendByteCount = UInt32(data.count)
            let cycleSuccess = data.withUnsafeBufferPointer { sendBuffer in
                var request = IOI2CRequest()
                request.commFlags = 0
                request.sendAddress = 0x6E
                request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
                request.sendBuffer = vm_address_t(bitPattern: sendBuffer.baseAddress)
                request.sendBytes = sendByteCount
                request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
                request.replyBytes = 0
                return sendIntel(request: &request, to: backend.framebuffer, errorRecoveryWaitTime: 2000)
            }
            if cycleSuccess {
                success = true
            }
        }
        return success
    }

    private func sendIntel(
        request: inout IOI2CRequest,
        to framebuffer: io_service_t,
        errorRecoveryWaitTime: UInt32? = nil
    ) -> Bool {
        if let errorRecoveryWaitTime = errorRecoveryWaitTime {
            usleep(errorRecoveryWaitTime)
        }

        var busCount: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS else {
            return false
        }

        for bus in 0..<busCount {
            var interface: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(framebuffer, IOOptionBits(bus), &interface) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(interface) }

            var connect: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(interface, IOOptionBits(), &connect) == KERN_SUCCESS else {
                continue
            }
            defer { IOI2CInterfaceClose(connect, IOOptionBits()) }

            guard IOI2CSendRequest(connect, IOOptionBits(), &request) == KERN_SUCCESS,
                  request.result == KERN_SUCCESS else {
                continue
            }

            return true
        }

        return false
    }

    private func checksum(seed: UInt8, data: [UInt8], end: Int) -> UInt8 {
        guard end >= 0 else { return seed }
        var result = seed
        for index in 0...end {
            result ^= data[index]
        }
        return result
    }

    private func int64Value(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? UInt32 { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    private func uint32Value(_ value: Any?) -> UInt32 {
        if let value = value as? UInt32 { return value }
        if let value = value as? Int { return UInt32(max(0, value)) }
        if let value = value as? NSNumber { return value.uint32Value }
        return 0
    }
}
