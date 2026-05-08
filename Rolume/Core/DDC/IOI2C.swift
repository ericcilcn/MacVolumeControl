import Foundation
import IOKit

// IOKit I2C 私有API定义
let kIOI2CSimpleTransactionType: UInt32 = 0
let kIOI2CDDCciReplyTransactionType: UInt32 = 2
let kIOI2CNoTransactionType: UInt32 = 10

struct IOI2CRequest {
    var result: IOReturn = 0
    var completion: UnsafeMutableRawPointer? = nil
    var commFlags: UInt32 = 0

    var minReplyDelay: UInt64 = 0

    var sendAddress: UInt32 = 0
    var sendTransactionType: UInt32 = 0
    var sendBuffer: vm_address_t = 0
    var sendBytes: UInt32 = 0

    var replyAddress: UInt32 = 0
    var replyTransactionType: UInt32 = 0
    var replyBuffer: vm_address_t = 0
    var replyBytes: UInt32 = 0
}

// IOI2C函数声明
@_silgen_name("IOI2CSendRequest")
func IOI2CSendRequest(_ connect: io_service_t, _ options: UInt32, _ request: UnsafeMutablePointer<IOI2CRequest>) -> IOReturn

// Intel framebuffer I2C 私有 API
@_silgen_name("IOFBGetI2CInterfaceCount")
func IOFBGetI2CInterfaceCount(_ service: io_service_t, _ count: UnsafeMutablePointer<IOItemCount>) -> IOReturn

@_silgen_name("IOFBCopyI2CInterfaceForBus")
func IOFBCopyI2CInterfaceForBus(_ service: io_service_t, _ bus: IOOptionBits, _ interface: UnsafeMutablePointer<io_service_t>) -> IOReturn

@_silgen_name("IOI2CInterfaceOpen")
func IOI2CInterfaceOpen(_ service: io_service_t, _ options: IOOptionBits, _ connect: UnsafeMutablePointer<IOI2CConnectRef?>) -> IOReturn

@_silgen_name("IOI2CInterfaceClose")
func IOI2CInterfaceClose(_ connect: IOI2CConnectRef?, _ options: IOOptionBits) -> IOReturn

typealias IOI2CConnectRef = OpaquePointer
