import Foundation

/// Output folder, file names and elapsed-time labels for recordings.
enum RecordingFile {
    static func directory() throws -> URL {
        let url = URL.moviesDirectory.appending(path: Config.Output.folderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func name(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = Config.Output.dateFormat
        return "\(Config.Output.namePrefix) \(formatter.string(from: date)).\(Config.Output.fileExtension)"
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
