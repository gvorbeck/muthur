import MUTHURKit
import Observation
import SwiftUI

/// The one live copy of `Preferences`, and the reason it is a class (**D105**).
///
/// The settings it holds were `static let`s on `Theme`, read from the
/// environment once at launch, which is all a variable ever needed to be. A
/// switch is different: the panel has to change *while you are looking at it*,
/// or the screen is a form you fill in and then relaunch to see the results of,
/// which is not a settings screen.
///
/// **`@Observable` is what makes that work without threading a value through
/// forty views.** `Theme.lettering` is still the one place the panel asks, and
/// it now reads through here — so any view that asks during its `body` has
/// registered a dependency and is redrawn when the answer changes. The two
/// places that ask from inside a `Canvas` closure had to hoist the read into
/// the body to get that, and they say so at the line.
///
/// One instance, because there is one panel and one set of settings. Not a
/// global for convenience — a second copy would be a second answer to *is the
/// tube allowed to fault*, and the panel would be drawing half of each.
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    /// Loaded once, at the first ask: defaults, then what was saved, then the
    /// environment (`Preferences.load`).
    private(set) var preferences: Preferences

    private init(preferences: Preferences = Preferences.load()) {
        self.preferences = preferences
    }

    /// **Written through to disk on every change**, D85's rule and D97's after
    /// it: a setting chosen now has to survive the app being closed a second
    /// later. There is no Apply button and there is not going to be one.
    func edit(_ change: (inout Preferences) -> Void) {
        var next = preferences
        change(&next)
        guard next != preferences else { return }
        preferences = next
        next.save()
    }
}
