import Foundation
import Testing

@testable import Frameless

@MainActor
struct CaptureSoundTests {
    @Test("every capture sound points at a file macOS ships", arguments: CaptureSound.allCases)
    func soundFileExists(sound: CaptureSound) {
        #expect(FileManager.default.fileExists(atPath: sound.url.path(percentEncoded: false)))
    }
}
