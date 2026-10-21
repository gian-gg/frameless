import Foundation
import Testing

@testable import Frameless

struct RecordingFileTests {
    @Test("file name follows the native screen recording pattern")
    func fileName() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let components = DateComponents(year: 2026, month: 10, day: 21, hour: 14, minute: 3, second: 22)
        let date = try #require(calendar.date(from: components))
        #expect(RecordingFile.name(for: date, timeZone: utc) == "Frameless 2026-10-21 at 14.03.22.mp4")
    }

    @Test(
        "elapsed label drops hours under an hour",
        arguments: [(0.0, "0:00"), (7.9, "0:07"), (754, "12:34"), (3723, "1:02:03")])
    func elapsedLabel(seconds: TimeInterval, label: String) {
        #expect(RecordingFile.elapsed(seconds) == label)
    }
}
