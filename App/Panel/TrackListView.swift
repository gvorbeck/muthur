import MUTHURKit
import SwiftUI

/// The track list, and the two marks on it that are not the same mark.
///
/// `♪` is the track the music is coming out of — `‖` when it is held — and the
/// reverse bar with `▶` in the gutter is the row the cursor is on. Usually they
/// agree; when you browse ahead they do not, and the panel has to be able to say
/// so, which is why the playing mark is not a second arrow (`player:2344`).
struct TrackListView: View {
    let model: PanelModel
    let record: Record
    /// How many rows of run-out to lay under the last track. Zero unless the
    /// composition is the one that fills its budget.
    var runout: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.visible), id: \.self) { row in
                TrackRowView(
                    row: row,
                    track: record.tracks[record.order[row]],
                    columns: model.columns,
                    mark: model.mark(for: row),
                    cursor: row == model.cursor.row
                )
                .contentShape(Rectangle())
                // Only the left button gets a gesture at all, which is §6.4's
                // "middle and right mean nothing here" arriving for free rather
                // than as a rule that has to be enforced.
                .onTapGesture { model.click(row: row) }
            }

            if model.below > 0 {
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                    run(Readout.more(model.below), Theme.etch).font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }

            if runout > 0 {
                RunoutField(rows: runout)
            }

            Spacer(minLength: 0)
        }
    }
}

struct TrackRowView: View {
    let row: Int
    let track: Track
    let columns: TrackColumns
    let mark: Readout.Mark
    let cursor: Bool

    /// The body of the row: everything from the playing mark to the duration.
    /// 65 columns, which is `PANEL` less the four the gutter takes — and the
    /// same 65 whether the cursor is here or not, so the reverse bar cannot
    /// nudge a title sideways. A floor rather than a ceiling since D62: every
    /// field but the duration is still pinned to an exact column count, so 65
    /// is what they sum to, but the duration is now sized up past its own
    /// floor for the rare track that needs it (D62), and this row grows with
    /// it rather than clipping the plate at the old fixed edge.
    ///
    /// A run of fields rather than one concatenated line, because the number and
    /// the duration are readouts now and a readout is drawn, not typed.
    private var body65: some View {
        let duration = Readout.mmss(track.duration)
        return HStack(spacing: 0) {
            run(mark.glyph, cursor ? Theme.text : Theme.lit)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(1), alignment: .leading)
            Spacer().frame(width: Grid.columns(1))
            SegmentText(
                text: Readout.rowNumber(row), colour: cursor ? Theme.text : Theme.etch,
                columns: 2, ghosts: !cursor)
            Spacer().frame(width: Grid.columns(2))
            run(track.title, Theme.text, columns: columns.title)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(columns.title), alignment: .leading)

            // The artist field carries its own leading gap, so a record with no
            // artist column leaves no gap where one would have been — the title
            // simply runs on to where the artist used to start (`player:2352`).
            if columns.artist > 0 {
                Spacer().frame(width: Grid.columns(2))
                run(track.artist, Theme.dim, columns: columns.artist, align: .trailing)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(columns.artist), alignment: .leading)
            }

            Spacer().frame(width: Grid.columns(2))
            SegmentText(
                text: duration, colour: cursor ? Theme.text : Theme.etch,
                // 5 is `%5s`'s width (`player:2367`) — a floor here, not a cap. Bash's
                // own `mmss` never grows past `MM:SS`, so 5 was never a truncation risk
                // there; ours folds hours back in past sixty minutes (D60), and a
                // record with an hour-long track is rarer than one that would rather
                // see its true length than an ellipsis.
                columns: max(5, Columns.width(of: duration)), ghosts: !cursor)
            Spacer(minLength: 0)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(cursor ? Readout.cursorGlyph : " ", Theme.lit)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(1), alignment: .leading)
            Spacer().frame(width: Grid.columns(1))
            body65
                // A floor, not an exact width, since D62 — most rows still sum to
                // exactly this, but the rare row whose duration ran past its own
                // floor needs the plate under it to grow too, or the reverse bar
                // stops short of a duration it is supposed to be highlighting.
                .frame(
                    minWidth: Grid.columns(PanelGrid.width - PanelGrid.gutter),
                    alignment: .leading
                )
                .background(cursor ? Theme.cursorPlate : Color.clear)
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
