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

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, timeout: Duration) async -> SleeveAnswer {
        var request = URLRequest(url: url)
        request.setValue(MUTHUR.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Double(timeout.components.seconds)
        do {
            let (data, _) = try await session.data(for: request)
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
