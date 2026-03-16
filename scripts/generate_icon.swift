import AppKit

struct IconSpec {
    let filename: String
    let pixels: CGFloat
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let specs: [IconSpec] = [
    .init(filename: "icon_16x16.png", pixels: 16),
    .init(filename: "icon_16x16@2x.png", pixels: 32),
    .init(filename: "icon_32x32.png", pixels: 32),
    .init(filename: "icon_32x32@2x.png", pixels: 64),
    .init(filename: "icon_128x128.png", pixels: 128),
    .init(filename: "icon_128x128@2x.png", pixels: 256),
    .init(filename: "icon_256x256.png", pixels: 256),
    .init(filename: "icon_256x256@2x.png", pixels: 512),
    .init(filename: "icon_512x512.png", pixels: 512),
    .init(filename: "icon_512x512@2x.png", pixels: 1024)
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let image = NSImage(size: NSSize(width: spec.pixels, height: spec.pixels))
    image.lockFocus()

    let canvas = CGRect(origin: .zero, size: CGSize(width: spec.pixels, height: spec.pixels))
    let cornerRadius = spec.pixels * 0.23
    let backgroundRect = canvas.insetBy(dx: spec.pixels * 0.07, dy: spec.pixels * 0.07)
    let backgroundPath = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )

    if let shadowPath = backgroundPath.copy() as? NSBezierPath {
        var transform = AffineTransform()
        transform.translate(x: 0, y: -spec.pixels * 0.02)
        shadowPath.transform(using: transform)
        NSColor(calibratedWhite: 0, alpha: 0.14).setFill()
        shadowPath.fill()
    }

    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.98, green: 0.53, blue: 0.27, alpha: 1),
            NSColor(calibratedRed: 0.96, green: 0.33, blue: 0.36, alpha: 1),
            NSColor(calibratedRed: 0.83, green: 0.22, blue: 0.42, alpha: 1)
        ],
        atLocations: [0.0, 0.55, 1.0],
        colorSpace: .deviceRGB
    )!
    gradient.draw(in: backgroundPath, angle: 90)

    let glowPath = NSBezierPath(
        roundedRect: CGRect(
            x: backgroundRect.minX + spec.pixels * 0.08,
            y: backgroundRect.maxY - spec.pixels * 0.28,
            width: spec.pixels * 0.45,
            height: spec.pixels * 0.16
        ),
        xRadius: spec.pixels * 0.08,
        yRadius: spec.pixels * 0.08
    )
    NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
    glowPath.fill()

    drawCard(
        in: CGRect(
            x: spec.pixels * 0.18,
            y: spec.pixels * 0.40,
            width: spec.pixels * 0.24,
            height: spec.pixels * 0.34
        ),
        rotation: -11,
        baseColor: NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.86, alpha: 0.95),
        accentColor: NSColor(calibratedRed: 0.27, green: 0.67, blue: 0.95, alpha: 1),
        lineColor: NSColor(calibratedWhite: 0.25, alpha: 0.4)
    )

    drawCard(
        in: CGRect(
            x: spec.pixels * 0.58,
            y: spec.pixels * 0.30,
            width: spec.pixels * 0.20,
            height: spec.pixels * 0.30
        ),
        rotation: 10,
        baseColor: NSColor(calibratedRed: 0.87, green: 0.95, blue: 1, alpha: 0.92),
        accentColor: NSColor(calibratedRed: 0.17, green: 0.73, blue: 0.57, alpha: 1),
        lineColor: NSColor(calibratedWhite: 0.20, alpha: 0.35)
    )

    drawCard(
        in: CGRect(
            x: spec.pixels * 0.35,
            y: spec.pixels * 0.17,
            width: spec.pixels * 0.30,
            height: spec.pixels * 0.66
        ),
        rotation: 0,
        baseColor: NSColor(calibratedWhite: 0.99, alpha: 1),
        accentColor: NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.97, alpha: 1),
        lineColor: NSColor(calibratedWhite: 0.22, alpha: 0.50),
        isPrimary: true
    )

    drawMergeMark(in: canvas, size: spec.pixels)

    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("failed to render icon \(spec.filename)")
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(spec.filename))
}

private func drawCard(
    in rect: CGRect,
    rotation: CGFloat,
    baseColor: NSColor,
    accentColor: NSColor,
    lineColor: NSColor,
    isPrimary: Bool = false
) {
    NSGraphicsContext.saveGraphicsState()

    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -rect.midX, yBy: -rect.midY)
    transform.concat()

    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.04)
    shadow.shadowBlurRadius = rect.width * 0.10
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: isPrimary ? 0.22 : 0.14)
    shadow.set()

    let path = NSBezierPath(
        roundedRect: rect,
        xRadius: rect.width * 0.18,
        yRadius: rect.width * 0.18
    )
    baseColor.setFill()
    path.fill()

    NSColor(calibratedWhite: 1, alpha: isPrimary ? 0.75 : 0.55).setStroke()
    path.lineWidth = max(1, rect.width * 0.03)
    path.stroke()

    let accentRect = CGRect(
        x: rect.minX + rect.width * 0.14,
        y: rect.maxY - rect.height * 0.20,
        width: rect.width * 0.72,
        height: rect.height * 0.08
    )
    let accentPath = NSBezierPath(
        roundedRect: accentRect,
        xRadius: accentRect.height / 2,
        yRadius: accentRect.height / 2
    )
    accentColor.setFill()
    accentPath.fill()

    let lineStartY = rect.maxY - rect.height * 0.34
    for index in 0..<4 {
        let widthScale: CGFloat = index == 3 ? 0.42 : 0.70
        let lineRect = CGRect(
            x: rect.minX + rect.width * 0.14,
            y: lineStartY - CGFloat(index) * rect.height * 0.12,
            width: rect.width * widthScale,
            height: rect.height * 0.05
        )
        let linePath = NSBezierPath(
            roundedRect: lineRect,
            xRadius: lineRect.height / 2,
            yRadius: lineRect.height / 2
        )
        lineColor.setFill()
        linePath.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
}

private func drawMergeMark(in canvas: CGRect, size: CGFloat) {
    let markRect = CGRect(
        x: canvas.midX - size * 0.10,
        y: canvas.midY - size * 0.07,
        width: size * 0.20,
        height: size * 0.14
    )
    let lineWidth = max(2, size * 0.018)

    let path = NSBezierPath()
    path.move(to: CGPoint(x: markRect.minX, y: markRect.midY))
    path.line(to: CGPoint(x: markRect.maxX, y: markRect.midY))
    path.move(to: CGPoint(x: markRect.maxX - size * 0.04, y: markRect.midY + size * 0.04))
    path.line(to: CGPoint(x: markRect.maxX, y: markRect.midY))
    path.line(to: CGPoint(x: markRect.maxX - size * 0.04, y: markRect.midY - size * 0.04))
    NSColor(calibratedWhite: 1, alpha: 0.92).setStroke()
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}
