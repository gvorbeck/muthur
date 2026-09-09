import Foundation

/// §20 stage 3 — the seam the real drive arrives at.
///
/// Everything above this line is finished: the panel, the parser, the phase
/// machine, the invocation. What is missing is the thing that answers, and this
/// is the shape of the hole it goes in. `FakeDrive` fills it now; at stage 3b a
/// second conformance spawns `cdrecord` with the vector `Cdrecord` already
/// builds, reads its output on the carriage returns, and hands the same chunks
/// to the same panel. That is the whole of the remaining work — swapping one
/// implementation for another, with nothing left to design.
///
/// The script has this seam too, and in the same place: `--demo` pipes
/// `fake_cdrecord` into `render` where a burn pipes `cdrecord` into `render`
/// (`burncd:2592`). One `render`, two things upstream of it.
public protocol Drive: Sendable {

    /// What the panel should be told the disc holds, in whole megabytes.
    ///
    /// **The two branches disagree here and only here.** A real burn divides the
    /// image by 1,048,576; the stand-in sizes itself like a disc rather than from
    /// the files in front of it, and adds a megabyte a track for the rounding
    /// arrears a real burn has. Neither is the other's business, so the drive
    /// says which it is.
    func totalMegabytes(bytes: Int, tracks: Int) -> Int

    /// Write one disc, filling the panel as it goes.
    ///
    /// `frame` sees every frame in order, which is what a view draws and what a
    /// test reads. The `Cdrecord` value is what *would* be run — the stand-in
    /// does not run it, and says so by ignoring it.
    func write(
        _ invocation: Cdrecord,
        into panel: inout BurnPanel,
        frame: (BurnPanel) -> Void
    ) throws
}
