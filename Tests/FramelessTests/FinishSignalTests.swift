import Testing

@testable import Frameless

@MainActor
struct FinishSignalTests {
    private struct Failure: Error, Equatable {
        let name: String
    }

    private let timeout = Failure(name: "timeout")

    @Test("returns at once when the file finished before the wait")
    func finishedBeforeWait() async throws {
        let signal = FinishSignal()
        signal.finish(.success(()))
        try await signal.wait(timeout: .seconds(5), timeoutError: timeout)
    }

    @Test("resumes a pending wait when the file finishes")
    func finishedDuringWait() async throws {
        let signal = FinishSignal()
        let waiting = Task { try await signal.wait(timeout: .seconds(5), timeoutError: timeout) }
        await Task.yield()
        signal.finish(.success(()))
        try await waiting.value
    }

    @Test("passes a write failure to the waiter")
    func passesFailure() async {
        let signal = FinishSignal()
        signal.finish(.failure(Failure(name: "write")))
        await #expect(throws: Failure(name: "write")) {
            try await signal.wait(timeout: .seconds(5), timeoutError: timeout)
        }
    }

    @Test("keeps the first result when finished twice before the wait")
    func keepsFirstResult() async {
        let signal = FinishSignal()
        signal.finish(.failure(Failure(name: "write")))
        signal.finish(.success(()))
        await #expect(throws: Failure(name: "write")) {
            try await signal.wait(timeout: .seconds(5), timeoutError: timeout)
        }
    }

    @Test("throws the timeout error when the file never finishes")
    func timesOut() async {
        let signal = FinishSignal()
        await #expect(throws: timeout) {
            try await signal.wait(timeout: .milliseconds(10), timeoutError: timeout)
        }
    }
}
