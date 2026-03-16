import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let labels = ["01", "02", "03", "04"]
let sizes = [
    NSSize(width: 1170, height: 420),
    NSSize(width: 900, height: 560),
    NSSize(width: 1170, height: 360),
    NSSize(width: 1400, height: 500)
]
let colors: [NSColor] = [
    NSColor(calibratedRed: 0.96, green: 0.30, blue: 0.25, alpha: 1),
    NSColor(calibratedRed: 0.23, green: 0.54, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.18, green: 0.72, blue: 0.50, alpha: 1),
    NSColor(calibratedRed: 0.96, green: 0.71, blue: 0.19, alpha: 1)
]
let bottomColors: [NSColor] = [
    NSColor(calibratedRed: 0.16, green: 0.49, blue: 0.94, alpha: 1),
    NSColor(calibratedRed: 0.96, green: 0.48, blue: 0.18, alpha: 1),
    NSColor(calibratedRed: 0.56, green: 0.32, blue: 0.93, alpha: 1),
    NSColor(calibratedRed: 0.24, green: 0.69, blue: 0.95, alpha: 1)
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

for index in labels.indices {
    let size = sizes[index]
    let image = NSImage(size: size)
    let halfHeight = size.height / 2

    image.lockFocus()
    colors[index].setFill()
    NSBezierPath(rect: NSRect(x: 0, y: halfHeight, width: size.width, height: halfHeight)).fill()
    bottomColors[index].setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: halfHeight)).fill()

    let text = "Sample \(labels[index])"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 96, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle
    ]

    let textRect = NSRect(
        x: 0,
        y: (size.height - 120) / 2,
        width: size.width,
        height: 120
    )

    text.draw(in: textRect, withAttributes: attributes)
    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("failed to render sample image \(index + 1)\n", stderr)
        exit(1)
    }

    let fileURL = outputDirectory.appendingPathComponent("sample-\(labels[index]).png")
    try pngData.write(to: fileURL)
}
