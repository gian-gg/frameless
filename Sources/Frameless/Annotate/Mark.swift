import CoreGraphics

/// One annotation: the tool that made it, its points in selection points from the bottom-left, and its colour.
struct Mark: Equatable {
    let tool: AnnotationTool
    var points: [CGPoint]
    let color: MarkColor
}
