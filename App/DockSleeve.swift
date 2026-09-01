import AppKit
import MUTHURKit

/// §14's third clause — **album art in the Dock while playing**.
///
/// The other two clauses of that box are declarations and a file: `LSUIElement`
/// false makes the app regular, and `App/MUTHUR.icns` gives it something to be
/// regular *with*. This is the part that is a program, and like everything else
/// in §14 it has no counterpart in `player` — a bash TUI has no tile.
///
/// **The tile, not the application icon.** `NSApp.applicationIconImage` would
/// have been one line, and it would also have replaced the app's Cmd-Tab
/// identity with whatever record happened to be on. The box asks for both at
/// once — an identity *and* the art — so the cover goes on `NSDockTile`, which
/// the Dock draws and the Cmd-Tab switcher does not.
///
/// **Mine: the cover is not put through the phosphor.** The panel draws its
/// sleeve as one amber and eight levels of it, because that is what the screen
/// the panel is imitating could do. The Dock is not that screen. The same
/// argument as `NowPlaying.artwork`, and the two are deliberately the same
/// answer: outside the window, a record looks like the record.
@MainActor
final class DockSleeve {

    /// Nothing about the Dock is worth recomputing sixty thousand times an hour.
    private var showing: URL?
    private var view: NSImageView?

    /// The tile is drawn at 128 pt and the Dock will scale it up when the Dock
    /// is set large and the display is Retina, so the picture is decoded once at
    /// the largest the tile is ever asked for rather than at the size it happens
    /// to be today.
    private static let side: CGFloat = 512

    func show(_ sleeve: Sleeve?) {
        guard showing != sleeve?.url else { return }
        showing = sleeve?.url

        let tile = NSApplication.shared.dockTile
        guard let url = sleeve?.url,
            let decoded = SleeveImage.decode(url, side: Self.side, scale: 1)
        else {
            // Back to `MUTHUR.icns`. `contentView = nil` alone is not enough —
            // the tile keeps drawing the last thing it was given until it is
            // told to redraw.
            view = nil
            tile.contentView = nil
            tile.display()
            return
        }

        let image = NSImage(
            cgImage: decoded, size: CGSize(width: decoded.width, height: decoded.height))
        let host = view ?? NSImageView()
        // Proportionally, which on the square cover and the square tile is the
        // whole tile. A cover that is not square gets bars rather than a
        // stretch — §18.24 is open about which of those the *panel* should do,
        // and until it is answered the Dock does the one that does not lie
        // about the shape of the record.
        host.imageScaling = .scaleProportionallyUpOrDown
        host.image = image
        view = host
        tile.contentView = host
        tile.display()
    }
}
