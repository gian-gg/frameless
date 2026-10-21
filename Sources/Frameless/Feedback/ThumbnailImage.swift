import AVFoundation
import ImageIO

/// Small preview images of saved captures, read from disk at thumbnail size.
enum ThumbnailImage {
    /// The first frame of a recording or a downscaled screenshot; nil when the file can't be read.
    static func load(from url: URL, maxPixelSize: Int) async -> CGImage? {
        if url.pathExtension == Config.Output.recordingExtension {
            return await videoFrame(from: url, maxPixelSize: maxPixelSize)
        }
        return imageThumbnail(from: url, maxPixelSize: maxPixelSize)
    }

    static func imageThumbnail(from url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private static func videoFrame(from url: URL, maxPixelSize: Int) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        return try? await generator.image(at: .zero).image
    }
}
