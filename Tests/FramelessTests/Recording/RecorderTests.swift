import Foundation
import ScreenCaptureKit
import Testing

@testable import Frameless

@MainActor
struct RecorderTests {
    @Test("stopping from the macOS recording indicator gives no reason to report")
    func userStopHasNoReason() {
        #expect(Recorder.stopReason(for: SCStreamError(.userStopped)) == nil)
    }

    @Test("any other stop is reported with its error")
    func otherStopKeepsReason() {
        let reason = Recorder.stopReason(for: SCStreamError(.attemptToStopStreamState))
        #expect((reason as? SCStreamError)?.code == .attemptToStopStreamState)
    }
}
