import Foundation

/// One request, and the only two answers anything here cares about. §5.
///
/// `body` is whatever came back, believed about nothing: a 404's error page and
/// a sick node's nginx page both arrive here as bytes, and the probe is what
/// says whether they are a picture (§5.2). That is deliberate — it is exactly
/// what `curl -sSL -o` hands the script, and the alternative is trusting a
/// status line that has been seen lying.
///
/// `couldNotAsk` is the distinction the script does not make and §18.4 is
/// about: no route to the host, no DNS, nothing listening. A record that has no
/// cover and a record nobody could ask about look identical from `art_fetch`,
/// and both cost fourteen days of no sleeve.
public enum SleeveAnswer: Sendable, Equatable {
    case body(Data)
    case couldNotAsk
}

public protocol SleeveTransport: Sendable {
    func get(_ url: URL, timeout: Duration) async -> SleeveAnswer
}

/// The real one. The User-Agent is set here and nowhere else, which is what
/// makes "one string, used by every request the app makes" true rather than
/// intended (§4.3).
public struct URLSessionSleeveTransport: SleeveTransport {
    let session: URLSession

    /// What a sleeve is allowed to weigh before it stops being a sleeve.
    ///
    /// `curl -o` streams to a file and the script never had to think about
    /// this; a body read into memory does. Nothing on the other end is
    /// promising anything — the Cover Art Archive answers with a redirect to
    /// archive.org, so the host that actually sends the bytes is not even the
    /// host that was asked — and §5.2's own probe is happy to be handed a
    /// short body that turns out not to be a picture. Thirty-two megabytes is
    /// two orders of magnitude above the largest front cover anybody scans and
    /// still small enough that a bad answer cannot fill the machine.
    public static let ceiling = 32 * 1024 * 1024

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, timeout: Duration) async -> SleeveAnswer {
        var request = URLRequest(url: url)
        request.setValue(MUTHUR.userAgent, forHTTPHeaderField: "User-Agent")
        // Whole seconds are what every caller asks in, but a sub-second
        // timeout must not round down to zero — `URLRequest` reads zero as
        // "use the default", which is sixty seconds, the opposite of what was
        // asked for.
        let seconds = Double(timeout.components.seconds)
        request.timeoutInterval = seconds > 0 ? seconds : 1
        do {
            let (data, response) = try await session.data(for: request)
            // **What this does and does not promise.** A server that declares
            // a body over the ceiling is refused on the declaration, before
            // the bytes are looked at, and one that turns out to have sent
            // more than it said is refused on the way out. A server that lies
            // *low* and then streams is not caught by either, and is not
            // caught here at all: bounding that means reading the response a
            // byte at a time, which was measured at three and a quarter
            // seconds for an ordinary five-hundred-kilobyte cover. A fetch
            // that slow is a fault every single time, to avoid one that has
            // never happened — so the weaker rule is the one written, and this
            // is the note saying why.
            if let http = response as? HTTPURLResponse,
                http.expectedContentLength > Int64(URLSessionSleeveTransport.ceiling)
            {
                return .body(Data())
            }
            guard data.count <= URLSessionSleeveTransport.ceiling else { return .body(Data()) }
            return .body(data)
        } catch {
            return URLSessionSleeveTransport.classify(error)
        }
    }

    /// A transport that never reached the far end, as against a far end that
    /// answered badly. Only the first of the two is `couldNotAsk`.
    static func classify(_ error: any Error) -> SleeveAnswer {
        guard let url = error as? URLError else { return .body(Data()) }
        switch url.code {
        case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost,
            .networkConnectionLost, .dnsLookupFailed, .timedOut,
            .internationalRoamingOff, .dataNotAllowed, .secureConnectionFailed,
            .resourceUnavailable:
            return .couldNotAsk
        default:
            // Something came back and it was not usable. Same as a body that
            // will not decode, and handled the same way.
            return .body(Data())
        }
    }
}

/// A transport with the answers already in it, and a record of what it was
/// asked. Nothing in §5's suites touches the network.
public final class StubSleeveTransport: SleeveTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [(match: String, answer: SleeveAnswer)]
    private var fallback: SleeveAnswer
    private var requested: [URL] = []

    /// `match` is a substring of the URL — a release ID, or `ws/2/release`.
    public init(
        _ answers: [(match: String, answer: SleeveAnswer)] = [],
        otherwise fallback: SleeveAnswer = .body(Data())
    ) {
        self.answers = answers
        self.fallback = fallback
    }

    public func get(_ url: URL, timeout: Duration) async -> SleeveAnswer {
        lock.withLock {
            requested.append(url)
            for answer in answers where url.absoluteString.contains(answer.match) {
                return answer.answer
            }
            return fallback
        }
    }

    public var asked: [URL] {
        lock.withLock { requested }
    }
}

/// A transport that answers nothing, ever, and says so — the machine with its
/// wifi off. The whole of §18.4 is about what this should leave behind.
public struct OfflineSleeveTransport: SleeveTransport {
    public init() {}
    public func get(_ url: URL, timeout: Duration) async -> SleeveAnswer { .couldNotAsk }
}
