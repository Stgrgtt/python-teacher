import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let size = CGFloat(pixels)
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let inset = size * 0.055
        let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2), xRadius: size * 0.20, yRadius: size * 0.20)
        NSGradient(starting: NSColor(red: 0.07, green: 0.35, blue: 0.39, alpha: 1), ending: NSColor(red: 0.08, green: 0.65, blue: 0.59, alpha: 1))!.draw(in: tile, angle: 60)
        let glyph = "{ }" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: size * 0.43, weight: .medium), .foregroundColor: NSColor.white]
        let measured = glyph.size(withAttributes: attributes)
        glyph.draw(at: NSPoint(x: (size - measured.width) / 2, y: (size - measured.height) / 2 + size * 0.06), withAttributes: attributes)
        let underline = NSBezierPath(roundedRect: NSRect(x: size * 0.36, y: size * 0.24, width: size * 0.28, height: size * 0.035), xRadius: size * 0.017, yRadius: size * 0.017)
        NSColor.white.withAlphaComponent(0.75).setFill()
        underline.fill()
        image.unlockFocus()
        let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let data = representation.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: destination.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
