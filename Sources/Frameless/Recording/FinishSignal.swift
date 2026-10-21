/// One-shot result of a recording file finishing, awaited with a timeout.
@MainActor
final class FinishSignal {
    private var result: Result<Void, Error>?
    private var continuation: CheckedContinuation<Void, Error>?

    /// Hands the result to the waiter, or keeps the first one for a later wait.
    func finish(_ result: Result<Void, Error>) {
        guard let continuation else {
            if self.result == nil { self.result = result }
            return
        }
        self.continuation = nil
        continuation.resume(with: result)
    }

    /// Waits for `finish`, throwing `timeoutError` if it doesn't come within `timeout`.
    func wait(timeout: Duration, timeoutError: Error) async throws {
        if let result {
            return try result.get()
        }
        let timer = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.finish(.failure(timeoutError))
        }
        defer { timer.cancel() }
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
}
