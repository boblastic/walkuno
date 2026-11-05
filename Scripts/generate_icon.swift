import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let artwork = root.appendingPathComponent("Documentation/Identite/Cadence/02-Grande-foulee.svg")
let size = 1024
let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let original = try String(contentsOf: artwork, encoding: .utf8)
// sRGB values match WalkunoTheme.accent and secondaryAccent.
let palettes: [(String, [Double], [Double])] = [
    ("coral", [1, 0.47, 0.28], [0.72, 0.24, 0.16]),
    ("glacier", [0.24, 0.80, 1], [0.10, 0.48, 0.73]),
    ("sunshine", [1, 0.83, 0.23], [0.77, 0.48, 0.10]),
    ("lime", [0.77, 0.965, 0.235], [0.39, 0.65, 0.16]),
    ("rose", [1, 0.44, 0.77], [0.68, 0.23, 0.52]),
    ("violet", [0.75, 0.54, 1], [0.45, 0.30, 0.76]),
    ("indigo", [0.55, 0.61, 1], [0.32, 0.38, 0.76]),
    ("turquoise", [0.13, 0.885, 0.82], [0.06, 0.53, 0.52])
]
func hex(_ components: [Double]) -> String {
    "#" + components.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
}
func png(for svg: String, pixels: Int = 1024) -> Data {
    let size = pixels
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    var proposedRect = bounds
    guard let image = NSImage(data: Data(svg.utf8)),
          let source = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        fatalError("Could not render app icon")
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(source, in: bounds)
    let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
    precondition(!representation.hasAlpha, "App icons must be opaque.")
    return representation.representation(using: .png, properties: [:])!
}

for (directory, platform) in [("Walkuno/Assets.xcassets", "ios"), ("WatchApp/Assets.xcassets", "watchos")] {
    let icon = root.appendingPathComponent(directory).appendingPathComponent("AppIcon.appiconset")
    try FileManager.default.createDirectory(at: icon, withIntermediateDirectories: true)
    try png(for: original).write(to: icon.appendingPathComponent("Icon.png"), options: .atomic)
    let contents: [String: Any] = ["images": [["filename": "Icon.png", "idiom": "universal", "platform": platform, "size": "1024x1024"]],
                                   "info": ["author": "xcode", "version": 1]]
    let manifest = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try manifest.write(to: icon.appendingPathComponent("Contents.json"), options: .atomic)
}
for (name, front, rear) in palettes {
    let svg = original.replacingOccurrences(of: "#A3FF70", with: hex(front))
        .replacingOccurrences(of: "#31B99F", with: hex(rear))
    let icon = root.appendingPathComponent("Walkuno/Assets.xcassets/AppIcon-" + name + ".appiconset")
    try FileManager.default.createDirectory(at: icon, withIntermediateDirectories: true)
    try png(for: svg).write(to: icon.appendingPathComponent("Icon.png"), options: .atomic)
    var images: [[String: String]] = [
        ["filename": "Icon.png", "idiom": "ios-marketing", "size": "1024x1024", "scale": "1x"]
    ]
    for points in [20, 29, 40, 60] {
        for scale in [2, 3] {
            let filename = "Icon-\(points)@\(scale)x.png"
            try png(for: svg, pixels: points * scale).write(to: icon.appendingPathComponent(filename), options: .atomic)
            images.append(["filename": filename, "idiom": "iphone", "size": "\(points)x\(points)", "scale": "\(scale)x"])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: icon.appendingPathComponent("Contents.json"), options: .atomic)
}
print("Generated Grande foulée and eight alternate iOS theme icons.")
