import Testing

@testable import Frameless

struct MarkColorTests {
    @Test("black gets a light halo and the bright colours a dark one")
    func halosContrast() {
        #expect(MarkColor.black.halo.components?.first == 1)
        for color in [MarkColor.white, .red, .yellow, .green, .blue] {
            #expect(color.halo.components?.first == 0)
        }
    }
}
