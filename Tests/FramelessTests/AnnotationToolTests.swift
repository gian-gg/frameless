import Testing

@testable import Frameless

struct AnnotationToolTests {
    @Test("every tool has its own key")
    func keysAreUnique() {
        let keys = AnnotationTool.allCases.map(\.key)
        #expect(Set(keys).count == keys.count)
    }

    @Test("finds a tool by its key in either case")
    func findsToolByKey() {
        #expect(AnnotationTool.forKey("r") == .rectangle)
        #expect(AnnotationTool.forKey("A") == .arrow)
        #expect(AnnotationTool.forKey("x") == nil)
        #expect(AnnotationTool.forKey("ra") == nil)
    }
}
