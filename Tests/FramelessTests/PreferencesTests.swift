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
        preferences.resolution = .p1080
        preferences.playsSounds = false

        let reloaded = Preferences(defaults: defaults).recordingOptions
        let expected = RecordingOptions(
            capturesSystemAudio: false, capturesMicrophone: true, showsCursor: false, videoCodec: .hevc,
            frameRate: .fps30, resolution: .p1080)
        #expect(reloaded == expected)
        #expect(Preferences(defaults: defaults).playsSounds == false)
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

    @Test("shortcuts default until changed, and stay cleared once cleared")
    func storesShortcuts() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = Preferences(defaults: defaults)
        #expect(preferences.shortcut(for: .screenshot) == Config.Shortcuts.screenshot)

        let custom = Shortcut(keyCode: 15, modifiers: [.control, .option])
        preferences.setShortcut(custom, for: .screenshot)
        preferences.setShortcut(nil, for: .record)

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.shortcut(for: .screenshot) == custom)
        #expect(reloaded.shortcut(for: .record) == nil)
    }

    @Test("save folders are unset by default, persist once chosen, and clear back to unset")
    func storesSaveFolders() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = Preferences(defaults: defaults)
        #expect(preferences.saveFolder(for: .screenshot) == nil)

        let folder = URL(filePath: "/Users/someone/Desktop/Shots", directoryHint: .isDirectory)
        preferences.setSaveFolder(folder, for: .screenshot)
        #expect(Preferences(defaults: defaults).saveFolder(for: .screenshot) == folder)
        #expect(Preferences(defaults: defaults).saveFolder(for: .recording) == nil)

        preferences.setSaveFolder(nil, for: .screenshot)
        #expect(Preferences(defaults: defaults).saveFolder(for: .screenshot) == nil)
    }
}
