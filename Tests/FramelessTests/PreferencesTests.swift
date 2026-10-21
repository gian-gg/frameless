import Foundation
import Testing

@testable import Frameless

@MainActor
struct PreferencesTests {
    private let suiteName = "PreferencesTests.\(UUID().uuidString)"

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    @Test("falls back to config defaults when nothing is saved")
    func usesConfigDefaults() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(Preferences(defaults: defaults).recordingOptions == RecordingOptions())
    }

    @Test("saved values survive a new preferences instance")
    func persistsChanges() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = Preferences(defaults: defaults)
        preferences.capturesSystemAudio = false
        preferences.capturesMicrophone = true
        preferences.showsCursor = false
        preferences.videoCodec = .hevc
        preferences.frameRate = .fps30

        let reloaded = Preferences(defaults: defaults).recordingOptions
        let expected = RecordingOptions(
            capturesSystemAudio: false, capturesMicrophone: true, showsCursor: false, videoCodec: .hevc,
            frameRate: .fps30)
        #expect(reloaded == expected)
    }

    @Test("an unknown saved frame rate falls back to the default")
    func unknownFrameRateFallsBack() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(24, forKey: "frameRate")
        #expect(Preferences(defaults: defaults).frameRate == Config.Recording.frameRate)
    }

    @Test("an unknown saved codec falls back to the default")
    func unknownCodecFallsBack() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("vp9", forKey: "videoCodec")
        #expect(Preferences(defaults: defaults).videoCodec == Config.Recording.videoCodec)
    }
}
