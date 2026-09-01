import AppKit

extension DemoShot {
    private static let scale: CGFloat = 2
    private static let margin: CGFloat = 44
    private static let cornerRadius: CGFloat = 12

    /// วางภาพ popover ลงบนพื้นไล่สีพร้อมมุมมนและเงา ให้ดูเป็นภาพสินค้าไม่ใช่ภาพหลุด
    static func compose(_ popover: NSImage) -> NSImage? {
        let canvas = CGSize(
            width: popover.size.width + margin * 2,
            height: popover.size.height + margin * 2
        )
        guard let context = CGContext(
            data: nil,
            width: Int(canvas.width * scale),
            height: Int(canvas.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)

        drawBackground(in: context, canvas: canvas)

        let cardRect = CGRect(x: margin, y: margin, width: popover.size.width, height: popover.size.height)
        guard let card = popover.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        drawCard(card, in: context, rect: cardRect)

        guard let output = context.makeImage() else { return nil }
        let image = NSImage(cgImage: output, size: canvas)
        return image
    }

    private static func drawBackground(in context: CGContext, canvas: CGSize) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 1.0, green: 0.94, blue: 0.94, alpha: 1),
                CGColor(red: 0.96, green: 0.95, blue: 0.98, alpha: 1),
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: canvas.height),
            end: CGPoint(x: canvas.width, y: 0),
            options: []
        )
    }

    private static func drawCard(_ card: CGImage, in context: CGContext, rect: CGRect) {
        let rounded = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        // วาดเงาโดยถมทรงการ์ดทึบก่อน แล้วค่อยทับด้วยภาพจริง เงาจะได้ตามรูปมุมมนพอดี
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -10),
            blur: 28,
            color: CGColor(red: 0.35, green: 0.1, blue: 0.15, alpha: 0.22)
        )
        context.addPath(rounded)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(rounded)
        context.clip()
        context.draw(card, in: rect)
        context.restoreGState()

        context.saveGState()
        context.addPath(rounded)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.08))
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()
    }

    static func write(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            print("แปลงเป็น PNG ไม่สำเร็จ")
            return
        }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? png.write(to: url)
        print("เขียน \(path) แล้ว")
    }
}
