import Foundation
@testable import MUTHURKit

/// A reader with the pictures already in it, keyed on the file's name.
struct StubEmbeddedPictureReader: EmbeddedPictureReader {
    let pictures: [String: Data]

    init(_ pictures: [String: Data]) {
        self.pictures = pictures
    }

    func picture(of url: URL) async -> Data? {
        pictures[url.lastPathComponent]
    }
}

/// A reader that never has one. The ordinary case, and the one every test of
/// what happens *after* the tags needs.
struct NoEmbeddedPictures: EmbeddedPictureReader {
    init() {}
    func picture(of url: URL) async -> Data? { nil }
}

/// A probe with the answers already in it, keyed on the file's name.
///
/// Every rule in §5.1 and §5.2 is about *which* picture is picked and what
/// happens when one will not open, and none of them needs a real JPEG to be
/// stated — the same argument as `StubMetadataReader`.
struct StubPictureProbe: PictureProbe {
    let sizes: [String: PictureSize]
    let fallback: PictureSize?

    /// Anything not named here is unreadable, which is the honest default:
    /// most of what this is pointed at is not a picture.
    init(_ sizes: [String: PictureSize]) {
        self.sizes = sizes
        self.fallback = nil
    }

    /// Everything readable, at one size. For the tests that are about order
    /// rather than about the floor.
    init(everythingIs size: PictureSize) {
        self.sizes = [:]
        self.fallback = size
    }

    func size(of url: URL) -> PictureSize? {
        sizes[url.lastPathComponent] ?? fallback
    }
}

/// A transport with the answers already in it, and a record of what it was
/// asked. Nothing in §5's suites touches the network.
final class StubSleeveTransport: SleeveTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [(match: String, answer: SleeveAnswer)]
    private var fallback: SleeveAnswer
    private var requested: [URL] = []

    /// `match` is a substring of the URL — a release ID, or `ws/2/release`.
    init(
        _ answers: [(match: String, answer: SleeveAnswer)] = [],
        otherwise fallback: SleeveAnswer = .body(Data())
    ) {
        self.answers = answers
        self.fallback = fallback
    }

    func get(_ url: URL, timeout: Duration) async -> SleeveAnswer {
        lock.withLock {
            requested.append(url)
            for answer in answers where url.absoluteString.contains(answer.match) {
                return answer.answer
            }
            return fallback
        }
    }

    var asked: [URL] {
        lock.withLock { requested }
    }
}

/// A transport that answers nothing, ever, and says so — the machine with its
/// wifi off. The whole of §18.4 is about what this should leave behind.
struct OfflineSleeveTransport: SleeveTransport {
    init() {}
    func get(_ url: URL, timeout: Duration) async -> SleeveAnswer { .couldNotAsk }
}
