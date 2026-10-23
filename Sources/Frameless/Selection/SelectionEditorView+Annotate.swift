import AppKit

// MARK: - Annotation tools

extension SelectionEditorView {
    /// The annotation tools, each tooltip naming its key.
    static var tools: [GlassBar.Tool] {
        AnnotationTool.allCases.map {
            GlassBar.Tool(icon: $0.icon, toolTip: "\($0.name) (\(String($0.key).uppercased()))")
        }
    }

    /// Lays the frozen screenshot under everything else: the whole screen cropped to the selection, or the window.
    func addCanvas(for shot: CapturedImage) {
        let canvas = AnnotationCanvas(shot: shot, frame: isWindow ? rect : bounds)
        canvas.cropRect = isWindow ? canvas.bounds : rect
        canvas.color = markColor
        canvas.weight = markWeight
        addSubview(canvas, positioned: .below, relativeTo: nil)
        self.canvas = canvas
    }

    /// The tool a bare key press picks, for screenshots only.
    func tool(for event: NSEvent) -> AnnotationTool? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        guard purpose == .screenshot, modifiers.isEmpty else { return nil }
        return AnnotationTool.forKey(event.charactersIgnoringModifiers ?? "")
    }

    /// Selects a tool, or none.
    func pick(_ tool: AnnotationTool?) {
        canvas?.commitText()
        self.tool = tool
        toolbar?.selectTool(tool.flatMap { AnnotationTool.allCases.firstIndex(of: $0) })
        canvas?.tool = tool
    }
}

// MARK: - Style

extension SelectionEditorView {
    func styleButtons() -> [GlassBar.Style] {
        [
            GlassBar.Style(sample: .color(markColor.nsColor), toolTip: "Colour") { [weak self] in
                self?.toggleStyleRow(.color)
            },
            GlassBar.Style(sample: .stroke(markWeight.lineWidth), toolTip: "Thickness") { [weak self] in
                self?.toggleStyleRow(.weight)
            },
        ]
    }

    /// Opens the style's row of choices above its button, or closes it if it's already open.
    private func toggleStyleRow(_ style: Style) {
        let wasOpen = openStyle == style
        hideStyleRow()
        guard !wasOpen else { return }
        let row: SampleRow
        switch style {
        case .color:
            row = SampleRow(
                choices: MarkColor.allCases.map { SampleRow.Choice(sample: .color($0.nsColor), toolTip: $0.name) },
                selected: MarkColor.allCases.firstIndex(of: markColor))
            row.onPick = { [weak self] index in self?.pickColor(MarkColor.allCases[index]) }
        case .weight:
            row = SampleRow(
                choices: MarkWeight.allCases.map { SampleRow.Choice(sample: .stroke($0.lineWidth), toolTip: $0.name) },
                selected: MarkWeight.allCases.firstIndex(of: markWeight))
            row.onPick = { [weak self] index in self?.pickWeight(MarkWeight.allCases[index]) }
        }
        addSubview(row)
        styleRow = row
        openStyle = style
        placeStyleRow()
    }

    private func pickColor(_ color: MarkColor) {
        canvas?.restyleSelection(color: color)
        markColor = color
        onMarkColorChange?(color)
        hideStyleRow()
    }

    private func pickWeight(_ weight: MarkWeight) {
        canvas?.restyleSelection(weight: weight)
        markWeight = weight
        onMarkWeightChange?(weight)
        hideStyleRow()
    }

    func hideStyleRow() {
        styleRow?.removeFromSuperview()
        styleRow = nil
        openStyle = nil
    }

    /// Centres the open row just above its style button, kept on screen.
    func placeStyleRow() {
        guard let row = styleRow, let style = openStyle, let toolbar,
            let button = toolbar.styleFrame(at: style.rawValue)
        else { return }
        let anchor = convert(button, from: toolbar)
        let left = min(max(anchor.midX - row.frame.width / 2, bounds.minX), bounds.maxX - row.frame.width)
        let bottom = toolbar.frame.maxY + Config.Bar.styleRowGap
        row.setFrameOrigin(CGPoint(x: left.rounded(), y: bottom.rounded()))
    }
}
