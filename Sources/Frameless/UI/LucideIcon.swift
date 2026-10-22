// Icon shapes from Lucide v0.460.0 (https://lucide.dev), ISC License.
// Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part of Feather (MIT).
// All other copyright (c) for Lucide are held by Lucide Contributors 2022.
// Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is
// hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE.

import AppKit

/// Every icon in the bars, labels and badges: Lucide's line icons, tinted to any colour.
enum LucideIcon: CaseIterable {
    case square
    case slash
    case moveUpRight
    case pencil
    case squareTinted
    case grid2x2
    case listOrdered
    case type
    case copy
    case download
    case pin
    case circleDot
    case close
    case monitor
    case appWindow
    case squareDashed
    case eraser
    case keyboard
    case triangleAlert
    case play

    @MainActor private static var cache: [LucideIcon: NSImage] = [:]

    /// The icon at `size` points in `color`; `filled` fills its shapes as well as stroking them.
    @MainActor
    func image(size: CGFloat, color: NSColor, filled: Bool = false) -> NSImage {
        let outline = outline(filled: filled)
        return NSImage(size: CGSize(width: size, height: size), flipped: false) { bounds in
            outline?.draw(in: bounds)
            color.set()
            bounds.fill(using: .sourceAtop)
            return true
        }
    }

    @MainActor
    private func outline(filled: Bool) -> NSImage? {
        if !filled, let image = Self.cache[self] { return image }
        let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" \
            fill="\(filled ? "#000" : "none")" stroke="#000" stroke-width="2" stroke-linecap="round" \
            stroke-linejoin="round">\((Self.shapes[self] ?? []).joined())</svg>
            """
        let image = NSImage(data: Data(svg.utf8))
        if !filled { Self.cache[self] = image }
        return image
    }

    /// Each icon's shapes from Lucide v0.460.0; a comment names the Lucide icon where it differs.
    private static let shapes: [LucideIcon: [String]] = [
        .square: [#"<rect width="18" height="18" x="3" y="3" rx="2"/>"#],
        .slash: [#"<path d="M22 2 2 22"/>"#],
        // move-up-right
        .moveUpRight: [#"<path d="M13 5H19V11"/>"#, #"<path d="M19 5L5 19"/>"#],
        .pencil: [
            #"<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83"#
                + #"l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"/>"#,
            #"<path d="m15 5 4 4"/>"#,
        ],
        // square, with a translucent fill
        .squareTinted: [##"<rect width="18" height="18" x="3" y="3" rx="2" fill="#000" fill-opacity="0.35"/>"##],
        .grid2x2: [
            #"<rect width="18" height="18" x="3" y="3" rx="2"/>"#, #"<path d="M3 12h18"/>"#, #"<path d="M12 3v18"/>"#,
        ],
        .listOrdered: [
            #"<path d="M10 12h11"/>"#, #"<path d="M10 18h11"/>"#, #"<path d="M10 6h11"/>"#,
            #"<path d="M4 10h2"/>"#, #"<path d="M4 6h1v4"/>"#, #"<path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>"#,
        ],
        .type: [
            #"<polyline points="4 7 4 4 20 4 20 7"/>"#, #"<line x1="9" x2="15" y1="20" y2="20"/>"#,
            #"<line x1="12" x2="12" y1="4" y2="20"/>"#,
        ],
        .copy: [
            #"<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/>"#,
            #"<path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>"#,
        ],
        .download: [
            #"<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>"#, #"<polyline points="7 10 12 15 17 10"/>"#,
            #"<line x1="12" x2="12" y1="15" y2="3"/>"#,
        ],
        .pin: [
            #"<path d="M12 17v5"/>"#,
            #"<path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12"#
                + #"a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1"#
                + #" 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>"#,
        ],
        .circleDot: [#"<circle cx="12" cy="12" r="10"/>"#, #"<circle cx="12" cy="12" r="1"/>"#],
        // x
        .close: [#"<path d="M18 6 6 18"/>"#, #"<path d="m6 6 12 12"/>"#],
        .monitor: [
            #"<rect width="20" height="14" x="2" y="3" rx="2"/>"#, #"<line x1="8" x2="16" y1="21" y2="21"/>"#,
            #"<line x1="12" x2="12" y1="17" y2="21"/>"#,
        ],
        .appWindow: [
            #"<rect x="2" y="4" width="20" height="16" rx="2"/>"#, #"<path d="M10 4v4"/>"#,
            #"<path d="M2 8h20"/>"#, #"<path d="M6 4v4"/>"#,
        ],
        .squareDashed: [
            #"<path d="M5 3a2 2 0 0 0-2 2"/>"#, #"<path d="M19 3a2 2 0 0 1 2 2"/>"#,
            #"<path d="M21 19a2 2 0 0 1-2 2"/>"#, #"<path d="M5 21a2 2 0 0 1-2-2"/>"#, #"<path d="M9 3h1"/>"#,
            #"<path d="M9 21h1"/>"#, #"<path d="M14 3h1"/>"#, #"<path d="M14 21h1"/>"#, #"<path d="M3 9v1"/>"#,
            #"<path d="M21 9v1"/>"#, #"<path d="M3 14v1"/>"#, #"<path d="M21 14v1"/>"#,
        ],
        .eraser: [
            #"<path d="m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21"/>"#,
            #"<path d="M22 21H7"/>"#, #"<path d="m5 11 9 9"/>"#,
        ],
        .keyboard: [
            #"<path d="M10 8h.01"/>"#, #"<path d="M12 12h.01"/>"#, #"<path d="M14 8h.01"/>"#,
            #"<path d="M16 12h.01"/>"#, #"<path d="M18 8h.01"/>"#, #"<path d="M6 8h.01"/>"#,
            #"<path d="M7 16h10"/>"#, #"<path d="M8 12h.01"/>"#, #"<rect width="20" height="16" x="2" y="4" rx="2"/>"#,
        ],
        .triangleAlert: [
            #"<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/>"#,
            #"<path d="M12 9v4"/>"#, #"<path d="M12 17h.01"/>"#,
        ],
        .play: [#"<polygon points="6 3 20 12 6 21 6 3"/>"#],
    ]
}
