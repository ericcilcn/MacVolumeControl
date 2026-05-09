import AppKit

class VolumeIconGenerator {
    static func generateIcon(volume: Int, maxVolume: Int, isMuted: Bool = false) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()

        let rawPercentage = maxVolume > 0 ? Double(volume) / Double(maxVolume) : 0.0
        let percentage = max(0.0, min(1.0, rawPercentage))

        // 鼠标滚轮尺寸（纵向）
        let wheelWidth: CGFloat = 8
        let wheelHeight: CGFloat = 16
        let x = (size.width - wheelWidth) / 2
        let y = (size.height - wheelHeight) / 2

        // 绘制滚轮外框
        let outerRect = NSRect(x: x, y: y, width: wheelWidth, height: wheelHeight)
        NSColor.labelColor.setStroke()
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 4, yRadius: 4)
        outerPath.lineWidth = 1.5
        outerPath.stroke()

        if isMuted {
            // 静音：画一个斜杠
            let slashPath = NSBezierPath()
            slashPath.move(to: NSPoint(x: x + wheelWidth + 2, y: y - 2))
            slashPath.line(to: NSPoint(x: x - 2, y: y + wheelHeight + 2))
            slashPath.lineWidth = 2
            NSColor.labelColor.setStroke()
            slashPath.stroke()
        } else {
            // 正常：从底部向上填充
            let fillHeight = (wheelHeight - 4) * CGFloat(percentage)
            let fillRect = NSRect(x: x + 2, y: y + 2, width: wheelWidth - 4, height: fillHeight)
            NSColor.labelColor.setFill()
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2)
            fillPath.fill()
        }

        image.unlockFocus()
        image.isTemplate = true

        return image
    }
}
