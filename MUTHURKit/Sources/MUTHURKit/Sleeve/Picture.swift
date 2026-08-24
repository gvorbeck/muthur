import Foundation
import ImageIO

/// Whether what came back is actually a picture. §5.2.
///
/// The Cover Art Archive answers with a redirect to an Internet Archive node,
/// and those nodes are not always well. A sick one has been seen serving an
/// nginx error page under a 200 — and serving it labelled `image/jpeg`. Neither
/// the status line nor the content type can be believed, so **whether a decoder
/// can read the bytes is the only test worth making**, and that is the test
/// (`player:1858`).
///
/// A protocol for the same reason `MetadataReader` is one: the rules in §5.1
/// and §5.2 are about which picture is chosen and when, and they are only
/// testable if the answer to "is this a 500×500 JPEG" can be stated rather than
/// manufactured.
public protocol PictureProbe: Sendable {
    /// The picture's size, or nil if nothing here can read it.
    func size(of url: URL) -> PictureSize?
}

public struct PictureSize: Sendable, Equatable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

extension PictureProbe {
    /// `art_ok <file> [min-side]` (`player:1866`).
    ///
    /// The floor is optional because it is only for the pictures found lying
    /// next to the record, where a logo or a thumbnail is as likely as a scan.
    /// The archive only ever sends one size, so nothing is asked of it.
    public func isPicture(_ url: URL, minimumSide: Int? = nil) -> Bool {
        guard let size = size(of: url) else { return false }
        guard let minimumSide else { return true }
        return size.width >= minimumSide && size.height >= minimumSide
    }
}

/// The real one. ImageIO replaces the script's `ffprobe -select_streams v:0
/// -show_entries stream=width,height`, and answers the same question: can this
/// be opened, and how big is it.
///
/// This reads the header and stops, as `ffprobe -show_entries stream=width,
/// height` does. Bytes that are not an image at all are caught; a JPEG whose
/// header is intact and whose data stops early is not, because its declared
/// size is right there in the header and neither decoder looks further. That is
/// the script's behaviour and it is deliberately kept: the alternative is fully
/// decoding every candidate beside the record before the panel's first frame,
/// to catch a case the `.part` file in §5.2 already prevents from the other end.
public struct ImageIOPictureProbe: PictureProbe {

    public init() {}

    public func size(of url: URL) -> PictureSize? {
        // Empty file: `[ -s "$1" ]`, and worth answering before ImageIO is
        // asked to make sense of nothing.
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard bytes > 0 else { return nil }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
            CGImageSourceGetCount(source) > 0,
            CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            // ffprobe prints `0,0` for something it opened and could not
            // measure, which is why the script cannot just look for a digit
            // (`player:1870`). The same answer is possible here.
            width > 0, height > 0
        else { return nil }

        return PictureSize(width: width, height: height)
    }
}

/// A probe with the answers already in it, keyed on the file's name.
///
/// Every rule in §5.1 and §5.2 is about *which* picture is picked and what
/// happens when one will not open, and none of them needs a real JPEG to be
/// stated — the same argument as `StubMetadataReader`.
public struct StubPictureProbe: PictureProbe {
    let sizes: [String: PictureSize]
    let fallback: PictureSize?

    /// Anything not named here is unreadable, which is the honest default:
    /// most of what this is pointed at is not a picture.
    public init(_ sizes: [String: PictureSize]) {
        self.sizes = sizes
        self.fallback = nil
    }

    /// Everything readable, at one size. For the tests that are about order
    /// rather than about the floor.
    public init(everythingIs size: PictureSize) {
        self.sizes = [:]
        self.fallback = size
    }

    public func size(of url: URL) -> PictureSize? {
        sizes[url.lastPathComponent] ?? fallback
    }
}
