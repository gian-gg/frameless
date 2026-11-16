import Foundation
import Testing

@testable import Frameless

struct SaveFolderTests {
    private func makeTemporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "SaveFolderTests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("uses Frameless/ under the default base when no folder is chosen")
    func usesDefault() throws {
        let base = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: base) }

        let folder = try SaveFolder.resolve(chosen: nil, defaultBase: base)

        #expect(folder.url == base.appending(path: Config.Output.folderName, directoryHint: .isDirectory))
        #expect(!folder.isFallback)
        #expect(SaveFolder.isUsable(folder.url))
    }

    @Test("uses a chosen folder as is, without a Frameless subfolder")
    func usesChosenFolder() throws {
        let base = try makeTemporaryFolder()
        let chosen = try makeTemporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: base)
            try? FileManager.default.removeItem(at: chosen)
        }

        let folder = try SaveFolder.resolve(chosen: chosen, defaultBase: base)

        #expect(folder == SaveFolder(url: chosen, isFallback: false))
    }

    @Test("falls back to the default without recreating a chosen folder that's gone")
    func fallsBackWhenMissing() throws {
        let base = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: base) }
        let missing = FileManager.default.temporaryDirectory.appending(path: "SaveFolderTests.\(UUID().uuidString)")

        let folder = try SaveFolder.resolve(chosen: missing, defaultBase: base)

        #expect(folder.url == base.appending(path: Config.Output.folderName, directoryHint: .isDirectory))
        #expect(folder.isFallback)
        #expect(!FileManager.default.fileExists(atPath: missing.path(percentEncoded: false)))
    }

    @Test("a file is not a usable folder")
    func rejectsFile() throws {
        let base = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appending(path: "file.txt")
        try Data().write(to: file)

        #expect(!SaveFolder.isUsable(file))
    }
}
