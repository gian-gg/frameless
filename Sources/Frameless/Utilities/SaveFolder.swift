import Foundation

/// The folder a capture is saved to, and whether it replaced a chosen folder that's gone.
struct SaveFolder: Equatable {
    let url: URL
    let isFallback: Bool

    /// The chosen folder as is if it's still usable; otherwise `<defaultBase>/Frameless`, created if missing.
    static func resolve(chosen: URL?, defaultBase: URL) throws -> SaveFolder {
        if let chosen, isUsable(chosen) {
            return SaveFolder(url: chosen, isFallback: false)
        }
        return SaveFolder(url: try OutputFile.directory(in: defaultBase), isFallback: chosen != nil)
    }

    /// An existing, writable folder.
    static func isUsable(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
            && FileManager.default.isWritableFile(atPath: path)
    }
}
