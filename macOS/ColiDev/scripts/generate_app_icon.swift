// Draws the Cause & Course app icon with CoreGraphics and writes every size of AppIcon.appiconset.
// Рисует значок Cause & Course через CoreGraphics и записывает все размеры в AppIcon.appiconset.
//
// Usage / Запуск: swift macOS/ColiDev/scripts/generate_app_icon.swift macOS/ColiDev/App/Assets.xcassets/AppIcon.appiconset
import AppKit
import CoreText
import Foundation

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: stops.map(\.1) as CFArray,
        locations: stops.map(\.0)
    )!
}

/// A superellipse: closer to the macOS icon shape than a rounded rectangle.
/// Суперэллипс: ближе к форме значка macOS, чем прямоугольник со скруглением.
func squircle(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let exponent: CGFloat = 2.0 / 5.0
    for step in 0...360 {
        let angle = CGFloat(step) * .pi / 180
        let cosine: CGFloat = cos(angle)
        let sine: CGFloat = sin(angle)
        let x: CGFloat = rect.midX + rect.width / 2 * (cosine < 0 ? -1 : 1) * pow(abs(cosine), exponent)
        let y: CGFloat = rect.midY + rect.height / 2 * (sine < 0 ? -1 : 1) * pow(abs(sine), exponent)
        if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// The ampersand from the name, as a vector path centered on `center`.
/// Амперсанд из имени в виде векторного контура с центром в `center`.
func ampersand(size: CGFloat, center: CGPoint) -> CGPath {
    let font = CTFontCreateWithName("Georgia-Bold" as CFString, size, nil)
    var unichar: UniChar = 0x26
    var glyph: CGGlyph = 0
    CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
    let outline = CTFontCreatePathForGlyph(font, glyph, nil)!
    let box = outline.boundingBoxOfPath
    var move = CGAffineTransform(translationX: center.x - box.midX, y: center.y - box.midY)
    return outline.copy(using: &move)!
}

/// Draws on a 1024-unit canvas; small sizes get a larger mark and no fine detail.
/// Рисует на холсте в 1024 единицы; в малых размерах знак крупнее, а мелких деталей нет.
func draw(in context: CGContext, small: Bool) {
    let inset: CGFloat = small ? 60 : 100
    let body = CGRect(x: inset, y: inset, width: 1024 - 2 * inset, height: 1024 - 2 * inset)
    let shape = squircle(in: body)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -16), blur: 34, color: rgb(0x000000, 0.42))
    context.addPath(shape)
    context.setFillColor(rgb(0x1B1763))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.drawLinearGradient(
        gradient([(0, rgb(0x4B46E5)), (0.5, rgb(0x2B238F)), (1, rgb(0x120E45))]),
        start: CGPoint(x: body.minX, y: body.maxY),
        end: CGPoint(x: body.maxX, y: body.minY),
        options: []
    )
    // A cold light from above and a warm one from below give the body volume.
    // Холодный свет сверху и тёплый снизу придают корпусу объём.
    context.drawRadialGradient(
        gradient([(0, rgb(0x8C9BFF, 0.62)), (1, rgb(0x8C9BFF, 0))]),
        startCenter: CGPoint(x: 300, y: 860), startRadius: 0,
        endCenter: CGPoint(x: 300, y: 860), endRadius: 560,
        options: []
    )
    context.drawRadialGradient(
        gradient([(0, rgb(0xFF7A45, 0.34)), (1, rgb(0xFF7A45, 0))]),
        startCenter: CGPoint(x: 800, y: 170), startRadius: 0,
        endCenter: CGPoint(x: 800, y: 170), endRadius: 520,
        options: []
    )
    if !small {
        // The course: a light arc running behind the sign. / Курс: светлая дуга за знаком.
        context.setLineCap(.round)
        context.setLineWidth(15)
        context.setStrokeColor(rgb(0xFFFFFF, 0.16))
        context.addArc(center: CGPoint(x: 512, y: 512), radius: 318, startAngle: 0.55 * .pi, endAngle: 2.1 * .pi, clockwise: false)
        context.strokePath()
        context.setFillColor(rgb(0xFFD27A))
        context.fillEllipse(in: CGRect(x: 512 + 318 * cos(0.1 * .pi) - 24, y: 512 + 318 * sin(0.1 * .pi) - 24, width: 48, height: 48))
    }
    context.restoreGState()

    let glyphSize: CGFloat = small ? 850 : 690
    let center = CGPoint(x: small ? 497 : 500, y: small ? 525 : 530)
    let depth = small ? 16 : 34
    let unit: CGFloat = 1.05

    context.saveGState()
    context.setShadow(offset: CGSize(width: 12, height: -26), blur: 34, color: rgb(0x05031F, 0.62))
    context.addPath(ampersand(size: glyphSize, center: CGPoint(x: center.x + CGFloat(depth) * unit, y: center.y - CGFloat(depth) * unit)))
    context.setFillColor(rgb(0x5E1E10))
    context.fillPath()
    context.restoreGState()

    // Extruded side: the same outline stacked toward the viewer, dark to warm.
    // Боковая грань: тот же контур, сложенный слоями к зрителю, от тёмного к тёплому.
    for layer in stride(from: depth, through: 1, by: -1) {
        let share = CGFloat(depth - layer) / CGFloat(depth)
        let offset = CGFloat(layer) * unit
        context.addPath(ampersand(size: glyphSize, center: CGPoint(x: center.x + offset, y: center.y - offset)))
        context.setFillColor(CGColor(
            srgbRed: 0.40 + 0.42 * share,
            green: 0.12 + 0.20 * share,
            blue: 0.07 + 0.05 * share,
            alpha: 1
        ))
        context.fillPath()
    }

    let face = ampersand(size: glyphSize, center: center)
    let box = face.boundingBoxOfPath
    context.saveGState()
    context.addPath(face)
    context.clip()
    context.drawLinearGradient(
        gradient([(0, rgb(0xFFF0B8)), (0.42, rgb(0xFFC04D)), (1, rgb(0xFF6A3D))]),
        start: CGPoint(x: box.minX, y: box.maxY),
        end: CGPoint(x: box.maxX, y: box.minY),
        options: []
    )
    if !small {
        // A thin lit edge on the upper-left side of every stroke.
        // Тонкая освещённая кромка с верхне-левой стороны каждого штриха.
        context.setLineWidth(9)
        context.setStrokeColor(rgb(0xFFFFFF, 0.55))
        context.addPath(ampersand(size: glyphSize, center: CGPoint(x: center.x + 4, y: center.y - 4)))
        context.strokePath()
    }
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.setLineWidth(small ? 10 : 7)
    context.setStrokeColor(rgb(0xFFFFFF, 0.14))
    context.strokePath()
    context.restoreGState()
}

func writeIcon(pixels: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw CocoaError(.fileWriteUnknown) }
    context.interpolationQuality = .high
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    draw(in: context, small: pixels <= 48)
    let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
    representation.size = NSSize(width: pixels, height: pixels)
    try representation.representation(using: .png, properties: [:])!.write(to: url)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        try writeIcon(pixels: points * factor, to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(factor)x", "filename": name])
    }
}
let catalog: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
