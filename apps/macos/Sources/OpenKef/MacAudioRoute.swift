import CoreAudio
import Foundation

/// Public CoreAudio check (MET-11 spike): is the Mac's default output an AirPlay device?
/// macOS only creates the AirPlay device once the user picks a route, so this is the signal for
/// "AirPlay from this Mac". It can't tell which AirPlay speaker; the window says the speaker's name.
enum MacAudioRoute {
    static func defaultOutputIsAirPlay() -> Bool {
        var dev = AudioObjectID(0); var sz = UInt32(MemoryLayout<AudioObjectID>.size)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &sz, &dev) == noErr else { return false }
        var tt = UInt32(0); sz = UInt32(MemoryLayout<UInt32>.size)
        a.mSelector = kAudioDevicePropertyTransportType
        guard AudioObjectGetPropertyData(dev, &a, 0, nil, &sz, &tt) == noErr else { return false }
        return tt == kAudioDeviceTransportTypeAirPlay
    }
}
