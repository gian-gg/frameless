import CoreGraphics

/// One annotation: the tool that made it, its points in selection points from the bottom-left, its colour and
/// its line thickness.
struct Mark: Equatable {
    let tool: AnnotationTool
    var points: [CGPoint]
    let color: MarkColor
    var weight = Config.Annotate.defaultWeight
}
