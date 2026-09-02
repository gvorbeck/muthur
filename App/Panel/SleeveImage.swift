import CoreGraphics
import ImageIO
import MUTHURKit
import UniformTypeIdentifiers

/// The cover, turned into pixels. §5 found it, fetched it and cached it; this is
/// the last step, which is a decode and a resample and nothing else.
///
/// **Nothing here touches the network and nothing here waits.** A file that will
/// not decode returns nil and the panel has no sleeve, which is the same answer
/// the script gives and for the same reason: a black square beside the panel is a
/// worse answer than no sleeve at all (`player:3011`).
enum SleeveImage {

    /// How the cover is drawn. A taste call, and the only one in §5.
    enum Treatment: String, Sendable {
        /// The picture as it is. A JPEG in a photo viewer.
        case crisp
        /// The picture as this screen could actually show it: one phosphor,
        /// eight levels of it. See `quantise`.
        case phosphor
    }

    /// Decoded straight to the size it will be drawn at. `kCGImageSourceThumbnail`
    /// rather than a full decode and a scale, because a modern cover is commonly
    /// 1500 px square and the sleeve is a couple of hundred — the full decode is
    /// fifty times the pixels for the same picture.
    ///
    /// Aspect is preserved, which is a **divergence**: the script scales to the
    /// box exactly (`scale=$w:$((h*2))`, `player:2974`) and a cover that is not
    /// square comes out stretched. The script's geometry is written throughout as
    /// if every cover were square — the whole "a cell is twice as tall as it is
    /// wide" argument only makes sense that way — so this is a case it does not
    /// appear to have considered rather than one it decided. Flagged as §18.24,
    /// and answered — the letterboxing stays, D48. Both are in
    /// `docs/decisions.md`, which is where §16 and the answered half of §18 live
    /// since `docs/parity.md` was split into three.
    static func decode(_ url: URL, side: CGFloat, scale: CGFloat) -> CGImage? {
        let pixels = Int((side * scale).rounded(.up))
        guard pixels > 0,
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// How big the picture actually is, read out of the file's header without
    /// decoding it. `MPMediaItemArtwork` wants a bounds size up front, and the
    /// honest answer is what is in the file — promise the system 1024 for a
    /// 500 px cover and it will ask for 1024 and be given 500.
    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else { return nil }
        return CGSize(width: width, height: height)
    }

    // MARK: - The phosphor treatment

    /// A screen with one colour in it, showing a photograph.
    ///
    /// An amber CRT cannot show a red cover and a blue cover differently — it has
    /// one phosphor and the only thing it can vary is how hard the beam hits it.
    /// So the picture goes to luminance and comes back as the panel's own ramp,
    /// which is the same eight steps the meters and the analyser are drawn out of
    /// (`panel.sh:84`). The sleeve stops being a photograph pasted onto the panel
    /// and becomes a thing the panel is capable of displaying.
    ///
    /// Eight levels band badly on a gradient — a sky becomes four stripes — so the
    /// level is chosen with a 4×4 ordered dither before it is quantised. That is
    /// the halftone in a printed sleeve as much as it is a dither, and at this size
    /// it reads as texture rather than as noise.
    static func quantise(_ image: CGImage, ramp: [Ink]) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, ramp.count > 1 else { return nil }

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let steps = ramp.count

        // The ramp as bytes, once, rather than per pixel.
        let table: [(UInt8, UInt8, UInt8)] = ramp.map {
            (UInt8(($0.r * 255).rounded()), UInt8(($0.g * 255).rounded()),
                UInt8(($0.b * 255).rounded()))
        }

        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        // Bayer 4×4, the classic. Values are the fraction of a step to push the
        // level by before rounding, spread so that no two neighbours push the
        // same way.
        let bayer: [Double] = [
            0, 8, 2, 10,
            12, 4, 14, 6,
            3, 11, 1, 9,
            15, 7, 13, 5,
        ].map { ($0 / 16) - 0.5 }

        for y in 0..<height {
            for x in 0..<width {
                let o = y * bytesPerRow + x * 4
                // Rec. 709, on the bytes as they come. No gamma correction and no
                // black-point lift: a dark record is meant to look dark.
                let luma =
                    (0.2126 * Double(pixels[o]) + 0.7152 * Double(pixels[o + 1])
                        + 0.0722 * Double(pixels[o + 2])) / 255
                let nudged = luma * Double(steps - 1) + bayer[(y % 4) * 4 + (x % 4)]
                let level = min(max(Int(nudged.rounded()), 0), steps - 1)
                let stop = table[level]
                pixels[o] = stop.0
                pixels[o + 1] = stop.1
                pixels[o + 2] = stop.2
                pixels[o + 3] = 255
            }
        }

        guard let data = CFDataCreate(nil, pixels, pixels.count),
            let provider = CGDataProvider(data: data)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true,
            intent: .defaultIntent)
    }
}
