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
