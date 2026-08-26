import Foundation

/// §8 — a real CSV walk.
///
/// `"riot grrrl, compilation, punk rock"` is one field with two commas in it,
/// and anything that splits on commas alone makes it three (`player:1649`).
/// So the script walks the line a character at a time with a single flag for
/// *inside a quoted field*, and a doubled `""` inside quotes is one quote
/// (`player:1663`). This is that walk.
///
/// **One thing here goes past the script, and it goes past rather than away.**
/// `csvsplit` is handed one line at a time by awk, so `player:1651` says
/// outright that a quoted field containing a newline would defeat it and that
/// none of the ways the catalogue is produced can make one — an acknowledged
/// gap rather than a judgement. The flag that decides whether a comma is a
/// separator is the same flag that decides whether a newline is the end of the
/// record, so reading the file as one stream costs nothing and is the shorter
/// thing to write here anyway. On every file the script parses correctly the
/// two agree field for field; the only file they disagree about is one the
/// script's own comment says it cannot read.
public enum CSV {

    /// Split a whole file into records of fields.
    ///
    /// A trailing newline does not make an extra empty record, which is what
    /// awk does with `RS`. A short row stays short — the reader asking for
    /// column six of a four-field row gets nothing back rather than an error,
    /// exactly as `r[6]` does in awk.
    ///
    /// LF, CRLF and a bare CR all end a record when they are not inside quotes.
    /// **The real catalogue is a CRLF file** and awk splits on `\n` alone, so
    /// the script leaves a `\r` on the end of every record's last field — which
    /// is `Barcode`, a column it never reads. It gets away with it by accident,
    /// and `norm()` would have thrown the `\r` away in any case. Here `"\r\n"`
    /// is a single `Character`, so a walk watching only for `"\n"` would read
    /// all 248 rows as one; a bare CR is the same superset as the quoted
    /// newline below, and costs nothing.
    public static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        // Whether anything at all has been seen since the last record ended.
        // This is what keeps the newline at the end of the file from becoming a
        // record with one empty field in it.
        var started = false

        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                    started = true
                case ",":
                    fields.append(field)
                    field = ""
                    started = true
                // `"\r\n"` is one `Character` in Swift, not two — a grapheme
                // cluster — and the real catalogue is a CRLF file, so a walk
                // that only watched for `"\n"` would read all 248 rows as one.
                case "\n", "\r\n", "\r":
                    fields.append(field)
                    field = ""
                    rows.append(fields)
                    fields = []
                    started = false
                default:
                    field.append(character)
                    started = true
                }
            }
            index += 1
        }

        if started || !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            rows.append(fields)
        }
        return rows
    }
}
