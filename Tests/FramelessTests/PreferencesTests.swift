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
        preferences.showsCursor = false

        let reloaded = Preferences(defaults: defaults).recordingOptions
        #expect(reloaded == RecordingOptions(capturesSystemAudio: false, showsCursor: false))
    }
}
