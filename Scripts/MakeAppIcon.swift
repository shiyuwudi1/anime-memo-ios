import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.06, blue: 0.16, alpha: 1),
    NSColor(calibratedRed: 0.31, green: 0.13, blue: 0.42, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.34, alpha: 1)
])!
gradient.draw(in: rect, angle: -45)

NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 560, y: 600, width: 520, height: 520)).fill()

NSColor.black.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: -120, y: -100, width: 520, height: 520)).fill()

let card = NSBezierPath(
    roundedRect: NSRect(x: 196, y: 196, width: 632, height: 632),
    xRadius: 168,
    yRadius: 168
)
NSColor.white.withAlphaComponent(0.14).setFill()
card.fill()
NSColor.white.withAlphaComponent(0.38).setStroke()
card.lineWidth = 6
card.stroke()

let triangle = NSBezierPath()
triangle.move(to: NSPoint(x: 430, y: 338))
triangle.line(to: NSPoint(x: 430, y: 686))
triangle.line(to: NSPoint(x: 718, y: 512))
triangle.close()
NSColor.white.setFill()
triangle.fill()

NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.34, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 700, y: 700, width: 74, height: 74)).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not render app icon")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)
print("Wrote \(output.path)")
