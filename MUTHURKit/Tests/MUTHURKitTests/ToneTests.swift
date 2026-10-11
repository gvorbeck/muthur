import Foundation
import Testing

@testable import MUTHURKit

@Suite("The mixer")
struct ToneTests {

    @Test("flat is the default, and is what bypasses the filters")
    func flat() {
        #expect(Tone().isFlat)
        #expect(!Tone(bass: Tone.Gain(decibels: 4)).isFlat)
    }

    @Test("a gain is clamped, and the rocker's stops include flat")
    func clamp() {
        #expect(Tone.Gain(decibels: 99).decibels == 12)
        #expect(Tone.Gain(decibels: -99).decibels == -12)
        #expect(Tone.Gain.all.contains(.flat))
    }

    @Test("the tone survives a relaunch, and an older save decodes flat")
    func roundTrip() throws {
        let store = try #require(UserDefaults(suiteName: "muthur.test.\(UUID().uuidString)"))
        var settings = Preferences()
        settings.tone = Tone(bass: Tone.Gain(decibels: 6), treble: Tone.Gain(decibels: -2))
        settings.save(to: store)
        #expect(Preferences.load(from: store, environment: [:]).tone == settings.tone)

        let old = Data(#"{"faults":true}"#.utf8)
        #expect(try JSONDecoder().decode(Preferences.self, from: old).tone.isFlat)
    }
}
