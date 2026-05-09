import Foundation
import CoreAudio

class SystemAudioManager {
    static let shared = SystemAudioManager()
    private var currentDeviceID: AudioDeviceID?
    private var volumeListener: AudioObjectPropertyListenerProc?

    private init() {
        diagnose()
        startMonitoringVolume()
    }

    /// 启动时诊断音频设备能力
    private func diagnose() {
        guard let deviceID = getDefaultOutputDevice() else {
            #if DEBUG
            print("🔊 Audio: No default output device")
            #endif
            return
        }

        // 获取设备名称
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        let namePtr = withUnsafeMutablePointer(to: &name) { $0 }
        AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, namePtr)
        #if DEBUG
        print("🔊 Audio output: \(name) (deviceID=\(deviceID))")
        #endif

        // 检查各通道的音量支持
        for ch: UInt32 in [0, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            let has = AudioObjectHasProperty(deviceID, &addr)
            var settable: DarwinBoolean = false
            if has {
                AudioObjectIsPropertySettable(deviceID, &addr, &settable)
            }
            #if DEBUG
            print("  Channel \(ch): hasVolume=\(has), settable=\(settable)")
            #endif
        }
    }

    /// 获取默认输出设备的 AudioDeviceID
    private func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    /// 检查设备是否支持主通道音量控制，否则回退到通道 1
    private func getVolumeChannel(for deviceID: AudioDeviceID) -> UInt32 {
        // 先尝试主通道 (element 0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &address) { return kAudioObjectPropertyElementMain }

        // 回退到通道 1
        address.mElement = 1
        if AudioObjectHasProperty(deviceID, &address) { return 1 }

        // 回退到通道 2
        address.mElement = 2
        if AudioObjectHasProperty(deviceID, &address) { return 2 }

        return 1
    }

    private func isVolumeSettable(deviceID: AudioDeviceID, channel: UInt32) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(deviceID, &address, &settable)
        return settable.boolValue
    }

    func canSetVolume() -> Bool {
        guard let deviceID = getDefaultOutputDevice() else { return false }
        let channel = getVolumeChannel(for: deviceID)
        return isVolumeSettable(deviceID: deviceID, channel: channel)
    }

    /// 获取当前系统音量（0.0 ~ 1.0）
    func getVolume() -> Float? {
        guard let deviceID = getDefaultOutputDevice() else { return nil }

        let channel = getVolumeChannel(for: deviceID)
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return volume
    }

    /// 获取当前音频输出设备的传输类型
    func getOutputDeviceTransport() -> String? {
        guard let deviceID = getDefaultOutputDevice() else { return nil }

        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        guard status == noErr else { return nil }

        // 将 FourCharCode 转换为字符串
        let bytes = [
            UInt8((transport >> 24) & 0xFF),
            UInt8((transport >> 16) & 0xFF),
            UInt8((transport >> 8) & 0xFF),
            UInt8(transport & 0xFF)
        ]
        let transportString = String(bytes: bytes, encoding: .ascii)
        #if DEBUG
        print("🔍 Transport type raw: 0x\(String(format: "%08X", transport)), string: \(transportString ?? "nil")")
        #endif
        return transportString
    }

    /// 检查当前输出设备是否是显示器音频
    func isCurrentOutputDisplayAudio() -> Bool {
        guard let transport = getOutputDeviceTransport() else { return false }
        // DisplayPort (dprt), HDMI (hdmi), Thunderbolt 都是显示器音频
        return transport == "dprt" || transport == "hdmi" || transport.hasPrefix("tbl")
    }
    func setVolume(_ volume: Float) -> Bool {
        guard let deviceID = getDefaultOutputDevice() else { return false }

        let channel = getVolumeChannel(for: deviceID)
        guard isVolumeSettable(deviceID: deviceID, channel: channel) else { return false }
        var vol = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )

        // 设置所有可用通道（左右声道同步）
        let status1 = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)

        // 也尝试设置通道 2（右声道）
        var address2 = address
        address2.mElement = (channel == 1) ? 2 : channel
        if AudioObjectHasProperty(deviceID, &address2) {
            AudioObjectSetPropertyData(deviceID, &address2, 0, nil, size, &vol)
        }

        return status1 == noErr
    }

    private func startMonitoringVolume() {
        guard let deviceID = getDefaultOutputDevice() else { return }
        currentDeviceID = deviceID

        let channel = getVolumeChannel(for: deviceID)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )

        let listener: AudioObjectPropertyListenerProc = { _, _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SystemVolumeChanged"), object: nil)
            }
            return noErr
        }
        volumeListener = listener
        AudioObjectAddPropertyListener(deviceID, &address, listener, nil)
    }

    func updateVolumeMonitoring() {
        guard let newDeviceID = getDefaultOutputDevice() else { return }
        guard newDeviceID != currentDeviceID else { return }

        if let oldDeviceID = currentDeviceID, let listener = volumeListener {
            let channel = getVolumeChannel(for: oldDeviceID)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            AudioObjectRemovePropertyListener(oldDeviceID, &address, listener, nil)
        }

        startMonitoringVolume()
    }

    /// 获取当前输出设备名称
    func getDeviceName() -> String {
        guard let deviceID = getDefaultOutputDevice() else { return "音频输出" }

        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        let namePtr = withUnsafeMutablePointer(to: &name) { $0 }
        let status = AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, namePtr)

        return status == noErr ? (name as String) : "音频输出"
    }
}
