import AppKit
import Testing

@testable import Frameless

@MainActor
struct AppDelegateTests {
    @Test("menu ends with a Quit item that terminates the app")
    func menuEndsWithQuit() {
        let quit = AppDelegate().makeMenu().items.last
        #expect(quit?.title == "Quit Frameless")
        #expect(quit?.action == #selector(NSApplication.terminate(_:)))
    }
}
