import CoreGraphics
import Foundation

/// An on-screen app window, with its frame in global AppKit coordinates.
struct WindowInfo: Equatable, Sendable {
    let id: CGWindowID
    let appName: String
    let title: String
    let frame: CGRect
}

/// Front-to-back snapshot of normal app windows, for picking one to record.
struct WindowList: Equatable, Sendable {
    let windows: [WindowInfo]

    /// The frontmost window containing a global AppKit point.
    func window(at point: CGPoint) -> WindowInfo? {
        windows.first { $0.frame.contains(point) }
    }

    /// Reads the windows currently on screen, skipping this process.
    static func snapshot() -> WindowList {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let descriptions = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return WindowList(
            descriptions: descriptions,
            primaryScreenHeight: CGDisplayBounds(CGMainDisplayID()).height,
            ownPID: ProcessInfo.processInfo.processIdentifier)
    }
}

extension WindowList {
    /// Parses CGWindowList descriptions, keeping their front-to-back order.
    init(descriptions: [[String: Any]], primaryScreenHeight: CGFloat, ownPID: pid_t) {
        windows = descriptions.compactMap {
            WindowInfo(description: $0, primaryScreenHeight: primaryScreenHeight, ownPID: ownPID)
        }
    }
}

extension WindowInfo {
    /// Parses one CGWindowList description; nil for system layers, this process, hidden or tiny windows.
    init?(description: [String: Any], primaryScreenHeight: CGFloat, ownPID: pid_t) {
        guard
            let id = (description[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
            let pid = (description[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != ownPID,
            (description[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
            (description[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0,
            let bounds = description[kCGWindowBounds as String] as? NSDictionary,
            let cgFrame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
            cgFrame.width >= Config.Overlay.minimumWindowSize, cgFrame.height >= Config.Overlay.minimumWindowSize
        else { return nil }

        self.id = id
        appName = description[kCGWindowOwnerName as String] as? String ?? ""
        title = description[kCGWindowName as String] as? String ?? ""
        frame = ScreenGeometry.appKitRect(fromCG: cgFrame, primaryScreenHeight: primaryScreenHeight)
    }
}
