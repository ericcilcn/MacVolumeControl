import AppKit
import SwiftUI

class CustomOSDWindow {
    private var window: NSWindow?
    private var hideTimer: Timer?
    private var isShowing = false
    private let horizontalScreenInset: CGFloat = 28
    private let verticalScreenInset: CGFloat = 46

    func show(volume: Int, maxVolume: Int, on displayID: CGDirectDisplayID) {
        hideTimer?.invalidate()

        let percentage = maxVolume > 0 ? Double(volume) / Double(maxVolume) : 0.0
        let deviceName = getDeviceName(for: displayID)

        if window == nil {
            let osdWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 66),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            osdWindow.isOpaque = false
            osdWindow.backgroundColor = .clear
            osdWindow.level = .statusBar
            osdWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            osdWindow.hasShadow = true

            let visualEffectView = NSVisualEffectView(frame: osdWindow.contentView!.bounds)
            visualEffectView.autoresizingMask = [.width, .height]
            visualEffectView.material = .hudWindow
            visualEffectView.state = .active
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 24
            visualEffectView.layer?.masksToBounds = true
            visualEffectView.alphaValue = 0.85

            osdWindow.contentView?.addSubview(visualEffectView)

            let hostingView = NSHostingView(rootView: CustomOSDView(percentage: percentage, deviceName: deviceName))
            hostingView.frame = osdWindow.contentView!.bounds
            hostingView.autoresizingMask = [.width, .height]
            osdWindow.contentView?.addSubview(hostingView)

            window = osdWindow
        } else {
            if let hostingView = window?.contentView?.subviews.last as? NSHostingView<CustomOSDView> {
                hostingView.rootView = CustomOSDView(percentage: percentage, deviceName: deviceName)
            }
        }

        positionWindow(on: displayID)

        if !isShowing {
            isShowing = true
            window?.alphaValue = 0
            window?.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                window?.animator().alphaValue = 1
            }
        }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                self.window?.animator().alphaValue = 0
            } completionHandler: {
                self.window?.orderOut(nil)
                self.isShowing = false
            }
        }
    }

    private func positionWindow(on displayID: CGDirectDisplayID) {
        guard let window = window else { return }
        let bounds = CGDisplayBounds(displayID)

        let x = bounds.maxX - window.frame.width - horizontalScreenInset
        let y = bounds.maxY - window.frame.height - verticalScreenInset
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func getDeviceName(for displayID: CGDirectDisplayID) -> String {
        if displayID == 0 {
            return SystemAudioManager.shared.getDeviceName()
        }
        guard let info = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as? [String: Any],
              let names = info["DisplayProductName"] as? [String: String],
              let name = names["zh_CN"] ?? names["en_US"] ?? names.values.first else {
            return "外接显示器"
        }
        return name
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

struct CustomOSDView: View {
    let percentage: Double
    let deviceName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(deviceName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 10) {
                Image(systemName: percentage < 0.01 ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 24)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 6)

                        Capsule()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * percentage, height: 6)
                    }
                }
                .frame(height: 6)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
