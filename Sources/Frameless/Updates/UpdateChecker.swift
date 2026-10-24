import Foundation

/// Asks GitHub for the newest release, at launch and then daily while automatic checks are on.
@MainActor
final class UpdateChecker {
    /// A release newer than the running app.
    struct Release: Equatable {
        let version: String
        let page: URL
    }

    /// The newer release found by the last check, if any.
    private(set) var available: Release? {
        didSet {
            if available != oldValue { onChange?() }
        }
    }
    var onChange: (@MainActor () -> Void)?
    private var timer: Timer?

    /// Checks now and once a day after, quietly, or stops checking.
    func schedule(_ isOn: Bool) {
        timer?.invalidate()
        timer = nil
        guard isOn else { return }
        Task { _ = try? await check() }
        let timer = Timer(timeInterval: Config.Updates.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in _ = try? await self?.check() }
        }
        timer.tolerance = Config.Updates.interval / 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Fetches the latest release, giving it when it's newer than this app.
    func check() async throws -> Release? {
        guard let url = URL(string: Config.Updates.latestRelease) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: break
        case 404: return nil
        default: throw URLError(.badServerResponse)
        }
        let latest = try JSONDecoder().decode(LatestRelease.self, from: data)
        let version = String(latest.tagName.trimmingPrefix("v"))
        available =
            Self.isNewer(version, than: Self.currentVersion) ? Release(version: version, page: latest.htmlURL) : nil
        return available
    }

    /// The running app's version, such as "1.0.0".
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Whether `version` comes after `current`, comparing their numbers part by part.
    static func isNewer(_ version: String, than current: String) -> Bool {
        let newer = numbers(version)
        let older = numbers(current)
        for index in 0..<max(newer.count, older.count) {
            let part = index < newer.count ? newer[index] : 0
            let currentPart = index < older.count ? older[index] : 0
            if part != currentPart { return part > currentPart }
        }
        return false
    }

    private static func numbers(_ version: String) -> [Int] {
        version.trimmingPrefix("v").split(separator: ".").map { Int($0) ?? 0 }
    }
}

/// The parts of GitHub's latest-release answer that matter here.
private struct LatestRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
