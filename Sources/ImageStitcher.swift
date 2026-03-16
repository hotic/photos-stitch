import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageStitcher: Sendable {
    func stitch(urls: [URL]) throws -> StitchedImage {
        let images = try urls.map(loadImage(at:))

        guard let firstImage = images.first else {
            throw UserFacingError(
                title: L10n.string("error.no_images.title"),
                message: L10n.string("error.no_images.message")
            )
        }

        let targetWidth = firstImage.image.width
        let scaledHeights = images.map { image in
            max(1, Int(round(Double(image.image.height) * Double(targetWidth) / Double(image.image.width))))
        }
        let totalHeight = scaledHeights.reduce(0, +)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: targetWidth,
                height: totalHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw UserFacingError(
                title: L10n.string("error.canvas_failed.title"),
                message: L10n.string("error.canvas_failed.message")
            )
        }

        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: totalHeight))
        context.interpolationQuality = .high

        var currentTopY = 0

        for (image, scaledHeight) in zip(images, scaledHeights) {
            let drawY = totalHeight - currentTopY - scaledHeight
            let drawRect = CGRect(
                x: 0,
                y: CGFloat(drawY),
                width: CGFloat(targetWidth),
                height: CGFloat(scaledHeight)
            )

            context.draw(image.image, in: drawRect)
            currentTopY += scaledHeight
        }

        guard let compositeImage = context.makeImage() else {
            throw UserFacingError(
                title: L10n.string("error.composite_failed.title"),
                message: L10n.string("error.composite_failed.message")
            )
        }

        return try writeCompositeImage(
            compositeImage,
            preferredCreationDate: images.first?.bestCreationDate
        )
    }

    private func loadImage(at url: URL) throws -> LoadedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw UserFacingError(
                title: L10n.string("error.load_failed.title"),
                message: L10n.string("error.load_failed.not_image", url.lastPathComponent)
            )
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let maxPixelSize = max(width, height)

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(source, 0, nil)

        guard let cgImage else {
            throw UserFacingError(
                title: L10n.string("error.load_failed.title"),
                message: L10n.string("error.load_failed.decode", url.lastPathComponent)
            )
        }

        return LoadedImage(
            sourceURL: url,
            image: cgImage,
            bestCreationDate: bestCreationDate(from: properties, url: url)
        )
    }

    private func writeCompositeImage(
        _ image: CGImage,
        preferredCreationDate: Date?
    ) throws -> StitchedImage {
        if let heicImage = try? write(
            image: image,
            as: .heic,
            quality: 0.82,
            preferredCreationDate: preferredCreationDate
        ) {
            return heicImage
        }

        return try write(
            image: image,
            as: .jpeg,
            quality: 0.9,
            preferredCreationDate: preferredCreationDate
        )
    }

    private func write(
        image: CGImage,
        as type: UTType,
        quality: CGFloat,
        preferredCreationDate: Date?
    ) throws -> StitchedImage {
        let supportedTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []

        guard supportedTypes.contains(type.identifier) else {
            throw UserFacingError(
                title: L10n.string("error.unsupported_format.title"),
                message: L10n.string("error.unsupported_format.message", type.identifier)
            )
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotosStitch", isDirectory: true)

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let prefix = L10n.string("file.stitch_prefix")
        let filename = "\(prefix)-\(Self.timestamp()).\(type.preferredFilenameExtension ?? "jpg")"
        let destinationURL = temporaryDirectory.appendingPathComponent(filename)

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw UserFacingError(
                title: L10n.string("error.write_failed.title"),
                message: L10n.string("error.write_failed.destination", type.identifier)
            )
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw UserFacingError(
                title: L10n.string("error.write_failed.title"),
                message: L10n.string("error.write_failed.finalize")
            )
        }

        return StitchedImage(
            url: destinationURL,
            format: type,
            preferredCreationDate: preferredCreationDate
        )
    }

    private func bestCreationDate(
        from properties: [CFString: Any]?,
        url: URL
    ) -> Date? {
        if
            let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let exifDate = date(
                from: exif[kCGImagePropertyExifDateTimeOriginal] as? String
                    ?? exif[kCGImagePropertyExifDateTimeDigitized] as? String
            )
        {
            return exifDate
        }

        if
            let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
            let tiffDate = date(from: tiff[kCGImagePropertyTIFFDateTime] as? String)
        {
            return tiffDate
        }

        if
            let png = properties?[kCGImagePropertyPNGDictionary] as? [CFString: Any],
            let pngDate = date(from: png[kCGImagePropertyPNGCreationTime] as? String)
        {
            return pngDate
        }

        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        return values?.contentModificationDate ?? values?.creationDate
    }

    private func date(from rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        if let exifDate = Self.exifDateFormatter.date(from: rawValue) {
            return exifDate
        }

        return Self.iso8601DateFormatter.date(from: rawValue)
    }

    private static func timestamp() -> String {
        timestampFormatter.string(from: Date())
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    private static let iso8601DateFormatter = ISO8601DateFormatter()
}

private struct LoadedImage: Sendable {
    let sourceURL: URL
    let image: CGImage
    let bestCreationDate: Date?
}
