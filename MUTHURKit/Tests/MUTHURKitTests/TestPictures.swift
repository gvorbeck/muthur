import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Real pictures, made on the spot.
///
/// §5's size floor and §5.2's "can a decoder read these bytes" are both
/// questions about actual image data, and a fixture of zero-byte files cannot
/// ask either. These are a few hundred bytes each and are generated rather than
/// committed, so a 3000×3000 scan costs nothing in the repository.
enum TestPictures {

    /// A solid square, JPEG, exactly the size asked for.
    static func jpeg(_ side: Int) -> Data {
        jpeg(width: side, height: side)
    }

    static func jpeg(width: Int, height: Int) -> Data {
        png(width: width, height: height, type: .jpeg)
    }

    static func png(width: Int, height: Int, type: UTType = .png) -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(red: 0.1, green: 0.8, blue: 0.3, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!

        let out = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            out, type.identifier as CFString, 1, nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return out as Data
    }

    /// The nginx error page served under a 200 and labelled `image/jpeg` —
    /// §5.2's whole reason for probing rather than believing the response.
    static let notAPicture = Data("<html><body>502 Bad Gateway</body></html>".utf8)
}

/// `/var` is a symlink to `/private/var`, and the directory enumerator resolves
/// it where a URL built by hand does not. Two names for one file.
func samePath(_ a: URL?, _ b: URL?) -> Bool {
    a?.resolvingSymlinksInPath().standardizedFileURL
        == b?.resolvingSymlinksInPath().standardizedFileURL
}

/// §2's throwaway directory, taught to hold pictures.
extension TempDirectory {

    /// A picture of the given size, at a path relative to the directory.
    /// Intermediate directories are made, so `"Scans/CD1/front.jpg"` works.
    @discardableResult
    func picture(_ path: String, side: Int = 600) throws -> URL {
        try write(path, TestPictures.jpeg(side))
    }

    @discardableResult
    func picture(_ path: String, width: Int, height: Int) throws -> URL {
        try write(path, TestPictures.jpeg(width: width, height: height))
    }

    @discardableResult
    func write(_ path: String, _ data: Data) throws -> URL {
        let file = url.appending(path: path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: file)
        return file
    }
}
