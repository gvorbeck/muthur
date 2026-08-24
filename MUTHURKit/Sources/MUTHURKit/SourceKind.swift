/// Where the record came from. §1's fact, needed here because §6.3 says a
/// different sentence when the files that vanished were an unpacked copy.
///
/// A zip's audio lives in the scratch directory and nothing outside this program
/// is responsible for it, so "the tracks are gone" has a cause and a remedy —
/// quit and play it again. A folder's audio is the user's own, and guessing at
/// why it moved would be presumptuous.
public enum SourceKind: String, Sendable, CaseIterable {
    case folder
    case zip
    case disc
}
