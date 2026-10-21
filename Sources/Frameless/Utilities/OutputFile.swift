import Foundation

/// Output folders and timestamped file names shared by recordings and screenshots.
enum OutputFile {
    /// `<base>/Frameless`, created if missing.
    static func directory(in base: URL) throws -> URL {
        let url = base.appending(path: Config.Output.folderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// "Frameless 2026-10-21 at 14.03.22.<ext>", like macOS's own captures.
    static func name(for date: Date, fileExtension: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = Config.Output.dateFormat
        return "\(Config.Output.namePrefix) \(formatter.string(from: date)).\(fileExtension)"
    }
}
