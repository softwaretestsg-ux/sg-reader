import AppKit

// Target size in points
let targetWidth: CGFloat = 920
let targetHeight: CGFloat = 170
let scale: CGFloat = 2.0 // Render at 2x for Retina sharpness

let pixelWidth = Int(targetWidth * scale)
let pixelHeight = Int(targetHeight * scale)

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(data: nil,
                          width: pixelWidth,
                          height: pixelHeight,
                          bitsPerComponent: 8,
                          bytesPerRow: 4 * pixelWidth,
                          space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("Failed to create CGContext")
    exit(1)
}

let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx

ctx.scaleBy(x: scale, y: scale)
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// Card Background (#1F1913)
let cardRect = NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
let bgPath = NSBezierPath(roundedRect: cardRect, xRadius: 22, yRadius: 22)
NSColor(calibratedRed: 31/255.0, green: 25/255.0, blue: 19/255.0, alpha: 1.0).setFill()
bgPath.fill()

// Card Border (#362A1F)
let borderPath = NSBezierPath(roundedRect: cardRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 21, yRadius: 21)
NSColor(calibratedRed: 54/255.0, green: 42/255.0, blue: 31/255.0, alpha: 1.0).setStroke()
borderPath.lineWidth = 2.5
borderPath.stroke()

let terraColor = NSColor(calibratedRed: 221/255.0, green: 139/255.0, blue: 83/255.0, alpha: 1.0) // #DD8B53
let lightColor = NSColor(calibratedRed: 242/255.0, green: 236/255.0, blue: 225/255.0, alpha: 1.0) // #F2ECE1
let mutedColor = NSColor(calibratedRed: 168/255.0, green: 159/255.0, blue: 145/255.0, alpha: 1.0) // #A89F91

let pCenter = NSMutableParagraphStyle()
pCenter.alignment = .center

// Line 1: Tagline (English + Hindi with KohinoorDevanagari-Bold native OpenType shaping)
let tagline = NSMutableAttributedString()
let eng = NSAttributedString(string: "Secure to Grow - ", attributes: [
    .font: NSFont.boldSystemFont(ofSize: 28),
    .foregroundColor: terraColor,
    .paragraphStyle: pCenter
])
let hinFont = NSFont(name: "KohinoorDevanagari-Bold", size: 28) ?? NSFont.boldSystemFont(ofSize: 28)
let hin = NSAttributedString(string: "सुरक्षा से ग्रोथ तक", attributes: [
    .font: hinFont,
    .foregroundColor: terraColor,
    .paragraphStyle: pCenter
])
tagline.append(eng)
tagline.append(hin)
tagline.draw(in: NSRect(x: 20, y: 110, width: targetWidth - 40, height: 42))

// Line 2: Helpline with Phone icon
let phoneConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
if let phoneSym = NSImage(systemSymbolName: "phone.fill", accessibilityDescription: nil)?.withSymbolConfiguration(phoneConfig) {
    let tintSym = phoneSym.copy() as! NSImage
    tintSym.lockFocus()
    terraColor.set()
    let iconRect = NSRect(origin: .zero, size: tintSym.size)
    iconRect.fill(using: .sourceAtop)
    tintSym.unlockFocus()
    
    let text = NSAttributedString(string: "  Helpline / WhatsApp: +91 81262 10003", attributes: [
        .font: NSFont.boldSystemFont(ofSize: 24),
        .foregroundColor: lightColor
    ])
    let totalW = tintSym.size.width + text.size().width
    let startX = (targetWidth - totalW) / 2.0
    tintSym.draw(in: NSRect(x: startX, y: 64, width: tintSym.size.width, height: tintSym.size.height))
    text.draw(at: NSPoint(x: startX + tintSym.size.width, y: 62))
}

// Line 3: Official Website with Globe icon
let globeConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
if let globeSym = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?.withSymbolConfiguration(globeConfig) {
    let tintSym = globeSym.copy() as! NSImage
    tintSym.lockFocus()
    mutedColor.set()
    let iconRect = NSRect(origin: .zero, size: tintSym.size)
    iconRect.fill(using: .sourceAtop)
    tintSym.unlockFocus()
    
    let text = NSAttributedString(string: "  Official Website: www.socialgoogol.com", attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .medium),
        .foregroundColor: mutedColor
    ])
    let totalW = tintSym.size.width + text.size().width
    let startX = (targetWidth - totalW) / 2.0
    tintSym.draw(in: NSRect(x: startX, y: 22, width: tintSym.size.width, height: tintSym.size.height))
    text.draw(at: NSPoint(x: startX + tintSym.size.width, y: 20))
}

guard let cgImage = ctx.makeImage() else {
    print("Failed to create CGImage")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: targetWidth, height: targetHeight)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to get PNG data")
    exit(1)
}

let outURL = URL(fileURLWithPath: "/Users/nalin/.gemini/antigravity/scratch/sg_reader/promo/footer_card_920.png")
try? pngData.write(to: outURL)
print("SUCCESS: 920x170 footer card saved to \(outURL.path)")
