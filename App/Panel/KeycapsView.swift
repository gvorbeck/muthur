import MUTHURKit
import SwiftUI

/// Two rows of backlit keycaps (`panel.sh:371`).
///
/// A cap is the key on a plate and the label beside it in the open, which is
/// what makes the legend read as a row of switches on the chassis rather than as
/// a line of documentation printed on the screen.
///
/// **And they are switches, so they can be pressed** (D30). The legend was a
/// picture of a keyboard sitting on an instrument that already answered the
/// pointer everywhere else — §6.4 put the meters and the track list under it —
/// and a drawn switch that does nothing when you push it is the one thing on a
/// panel this literal that reads as broken rather than as decoration.
struct KeycapsView: View {
    /// What a press asks for. The view knows which cap was hit and nothing about
    /// what it means; `PanelView` owns that, so a cap and its key cannot drift.
    let press: (Readout.Press) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Readout.legend.enumerated()), id: \.offset) { _, caps in
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.margin)
                    ForEach(Array(caps.enumerated()), id: \.offset) { index, cap in
                        if index > 0 {
                            Spacer().frame(width: Grid.columns(3))
                        }
                        CapView(cap: cap, press: press)
                    }
                    Spacer(minLength: 0)
                }
                .gridLine()
            }
        }
    }
}

/// One cap: the lit plate, and the legend beside it in the open.
///
/// The plate is the chassis's lettering backlit; the legend beside it is the
/// same lettering unlit. One character generator, two levels of drive — and the
/// press is a third, because an illuminated pushbutton lights when the switch
/// closes. Nothing here invents a colour: the whole of it is the panel's own
/// ramp, so a pressed cap is the same phosphor harder.
private struct CapView: View {
    let cap: Readout.Cap
    let press: (Readout.Press) -> Void

    /// Held for as long as the button is down. Nil is at rest.
    @State private var down = false
    @State private var held: Task<Void, Never>?

    private var face: String { " \(cap.key) " }

    var body: some View {
        HStack(spacing: 0) {
            MatrixText(text: face, colour: down ? Theme.capInkDown : Theme.capInk)
                .background(down ? Theme.capPlateDown : Theme.capPlate)
                // The rocker's two ends. `←→` and `↑↓` are two glyphs on one
                // plate, and the plate is split in the order they are drawn, so
                // the half you push is the direction you get. A one-press cap
                // gets a single region and the arithmetic collapses.
                .overlay {
                    HStack(spacing: 0) {
                        ForEach(Array(cap.presses.enumerated()), id: \.offset) { _, which in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(gesture(for: which))
                        }
                    }
                }

            MatrixText(text: " \(cap.label)", colour: Theme.etch)
        }
    }

    /// A press, and a hold that goes on asking.
    ///
    /// `DragGesture(minimumDistance: 0)` is the same press-and-report the meters
    /// use (§6.4): the first `onChanged` is the button going down. A cap acts on
    /// the way down and not on the way up, because that is when a key acts and
    /// the point is that these are the keys.
    private func gesture(for which: Readout.Press) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !down else { return }
                down = true
                fire(which)
                guard Readout.repeats(which) else { return }
                hold(which)
            }
            .onEnded { _ in release() }
    }

    private func fire(_ which: Readout.Press) {
        press(which)
    }

    /// The system's own key repeat, asked for rather than invented. A cap that
    /// repeated at some rate of this panel's choosing would be a different switch
    /// from the key it depicts, and the whole claim being made here is that it is
    /// the same one.
    private func hold(_ which: Readout.Press) {
        held?.cancel()
        held = Task { @MainActor in
            let delay = NSEvent.keyRepeatDelay
            let interval = max(NSEvent.keyRepeatInterval, 0.02)
            try? await Task.sleep(for: .seconds(delay))
            while !Task.isCancelled && down {
                fire(which)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func release() {
        held?.cancel()
        held = nil
        down = false
    }
}

/// The status line. The leading `▪` is what makes a message read as the machine
/// answering rather than as another label on the panel (`player:2702`).
struct StatusView: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(text, Theme.lit).font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
