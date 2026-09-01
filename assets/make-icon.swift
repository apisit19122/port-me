import AppKit

let canvasSize = 1024
let outputURL = URL(fileURLWithPath: "assets/icon-1024.png")

func color(hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

guard let context = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("สร้าง CGContext ไม่ได้") }

// พื้นหลังทรงสี่เหลี่ยมมนตามสัดส่วนไอคอน macOS โดยเว้นขอบไว้เล็กน้อย
let inset = CGFloat(canvasSize) * 0.08
let squircle = CGRect(x: inset, y: inset, width: CGFloat(canvasSize) - inset * 2, height: CGFloat(canvasSize) - inset * 2)
let clip = CGPath(roundedRect: squircle, cornerWidth: squircle.width * 0.23, cornerHeight: squircle.height * 0.23, transform: nil)
context.saveGState()
context.addPath(clip)
context.clip()

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(hex: 0xFF5F6D), color(hex: 0xC1272D)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: squircle.minX, y: squircle.maxY),
    end: CGPoint(x: squircle.maxX, y: squircle.minY),
    options: []
)
context.restoreGState()

// สัญลักษณ์เดียวกับไอคอนบน menu bar เพื่อให้จำได้ว่าเป็นแอปเดียวกัน
let configuration = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold)
guard let symbol = NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(configuration) else { fatalError("ไม่พบ SF Symbol powerplug.fill") }

let tinted = NSImage(size: symbol.size, flipped: false) { rect in
    symbol.draw(in: rect)
    NSColor.white.set()
    rect.fill(using: .sourceAtop)
    return true
}

let symbolRect = CGRect(
    x: (CGFloat(canvasSize) - tinted.size.width) / 2,
    y: (CGFloat(canvasSize) - tinted.size.height) / 2,
    width: tinted.size.width,
    height: tinted.size.height
)
guard let symbolImage = tinted.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("แปลงสัญลักษณ์เป็นบิตแมปไม่ได้")
}
context.draw(symbolImage, in: symbolRect)

guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)
else { fatalError("เขียนไฟล์ไม่ได้") }
CGImageDestinationAddImage(destination, output, nil)
CGImageDestinationFinalize(destination)
print("เขียน \(outputURL.path) แล้ว")
