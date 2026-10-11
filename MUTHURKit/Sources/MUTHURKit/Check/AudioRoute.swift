import CoreAudio
import Foundation

/// Where the sound is going. §11, §14.
///
/// Nothing in `player` corresponds to this: a terminal hands its audio to mpv
/// and mpv hands it to the system, and neither of them is in a position to say
/// what happened next. The native stack knows, and "why is mine not working"
/// is answered by the name of a device more often than by anything else on the
/// check screen.
///
/// `CoreAudio` and not `AVAudioSession` — that type is iOS's. On macOS the
/// question is which device the system has made default, and the answer is two
/// property reads.
public enum AudioRoute {

    /// The default output device's name, or nil where CoreAudio would not say —
    /// a machine with every output unplugged answers `kAudioObjectUnknown`, and
    /// that is a real state and not an error.
    public static func current() -> String? {
        guard let device = defaultOutputDevice() else { return nil }
        return name(of: device)
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        guard status == noErr, device != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return device
    }

    private static func name(of device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let name = name as String? else { return nil }
        return name.isEmpty ? nil : name
    }

    // MARK: - The device's rate

    /// The default output device's nominal rate, or nil where CoreAudio would
    /// not say.
    public static func nominalRate() -> Double? {
        guard let device = defaultOutputDevice() else { return nil }
        var address = rateAddress(kAudioDevicePropertyNominalSampleRate)
        var rate = Float64(0)
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &rate) == noErr, rate > 0
        else { return nil }
        return rate
    }

    /// Put the default output on `rate` **if the device lists it** and return
    /// whether it moved. A device that does not offer the rate is left alone —
    /// the engine resamples to whatever the hardware is at, which is the
    /// ordinary case and not a failure. Only what the device itself advertises
    /// is asked for: a rate it did not list is a guess.
    @discardableResult
    public static func setNominalRate(_ rate: Double) -> Bool {
        guard let device = defaultOutputDevice(), nominalRate() != rate else { return false }
        var listed = rateAddress(kAudioDevicePropertyAvailableNominalSampleRates)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(device, &listed, 0, nil, &size) == noErr, size > 0
        else { return false }
        var ranges = [AudioValueRange](
            repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
        guard AudioObjectGetPropertyData(device, &listed, 0, nil, &size, &ranges) == noErr,
            ranges.contains(where: { $0.mMinimum <= rate && rate <= $0.mMaximum })
        else { return false }
        var address = rateAddress(kAudioDevicePropertyNominalSampleRate)
        var wanted = Float64(rate)
        return AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float64>.size), &wanted) == noErr
    }

    private static func rateAddress(_ selector: AudioObjectPropertySelector)
        -> AudioObjectPropertyAddress
    {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
