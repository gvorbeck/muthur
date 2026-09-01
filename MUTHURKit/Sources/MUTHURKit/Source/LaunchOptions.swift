import Foundation

/// The command line, as `player`'s argument loop reads it (`player:329`).
///
/// Parsed here rather than in the app so that every branch — including the ones
/// that refuse — is reachable from the suite without launching anything.
public struct LaunchOptions: Sendable, Equatable {
    /// `--cd`. **Beaten by a path argument**, which is the script's own order:
    /// `if [ -n "$SOURCE_ARG" ] … elif [ "$WANT_CD" -eq 1 ]` (`player:3517`).
    /// Naming a record *and* asking for the disc is not an error, and the record
    /// wins.
    public var wantCD: Bool = false
    /// `--no-mb` (`player:334`).
    public var useMusicBrainz: Bool = true
    /// `-n` / `--dry-run` (`player:331`). Read the record, print it, play
    /// nothing — §12, and `Inspect` is where it happens.
    public var dryRun: Bool = false
    /// `-h` / `--help` (`player:335`). **Nothing after it was parsed**, because
    /// in the script nothing after it was reached: see `parse`.
    public var help: Bool = false
    /// `--check`, which `main.swift` answers before there is an app at all
    /// (§11). Carried so this parse is a complete account of the flag set.
    public var check: Bool = false
    /// The one positional argument, if there was one.
    public var sourcePath: String?

    public init() {}

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case unknownOption(String)
        case severalSources(String)

        public var description: String {
            switch self {
            case .unknownOption(let flag):
                "unknown option: \(flag) (try --help)"
            case .severalSources(let path):
                "one source at a time, got: \(path)"
            }
        }
    }

    /// `player:329`, case for case.
    ///
    /// **`-*` dies rather than being taken for a path.** A file really called
    /// `-n` is not reachable this way and is not reachable in the script either;
    /// this is one of the places where matching the original matters more than
    /// being clever, because the failure mode of guessing is opening something
    /// nobody asked for.
    ///
    /// **`--help` stops the parse where it stands**, and that is not tidiness.
    /// The script's arm is `-h|--help) usage 0 ;;` — `usage` *exits*
    /// (`panel.sh:271`), from inside the loop, so nothing to the right of it was
    /// ever looked at. `player --help --rip` prints the help and leaves 0;
    /// `player --rip --help` dies on `--rip`. A parse that collected everything
    /// first and reported `help` alongside `unknownOption` would have to pick
    /// one, and it would pick the wrong one half the time.
    public static func parse(_ arguments: [String]) throws -> LaunchOptions {
        var options = LaunchOptions()
        for argument in arguments {
            switch argument {
            case "-n", "--dry-run":
                options.dryRun = true
            case "--check":
                options.check = true
            case "--cd":
                options.wantCD = true
            case "--no-mb":
                options.useMusicBrainz = false
            case "-h", "--help":
                options.help = true
                return options
            default:
                if argument.hasPrefix("-") {
                    throw Failure.unknownOption(argument)
                }
                if options.sourcePath != nil {
                    throw Failure.severalSources(argument)
                }
                options.sourcePath = argument
            }
        }
        return options
    }
}
