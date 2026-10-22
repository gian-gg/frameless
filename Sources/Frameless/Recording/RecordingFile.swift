import Foundation

/// File names and elapsed-time labels for recordings.
enum RecordingFile {
    static func name(for date: Date, timeZone: TimeZone = .current) -> String {
        OutputFile.name(for: date, fileExtension: Config.Output.recordingExtension, timeZone: timeZone)
    }

    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
