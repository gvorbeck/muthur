import Foundation

/// Who this program says it is, on every request it makes.
///
/// Not decoration. MusicBrainz requires an identifying User-Agent and blocks
/// generic ones, and the script sends the same string on all three requests it
/// makes — the release search (`player:1827`), the Cover Art Archive fetch
/// (`player:1915`) and the disc-ID lookup (`player:2180`). One string, set
/// once, used by everything, so there is no second place for it to go stale.
///
/// The URL has to resolve; an unreachable one is the same as no contact at all
/// from the far end's point of view.
public enum MUTHUR {
    public static let version = "1.0"
    public static let contact = "https://github.com/gvorbeck"
    public static let userAgent = "MUTHUR/\(version) ( \(contact) )"
}
