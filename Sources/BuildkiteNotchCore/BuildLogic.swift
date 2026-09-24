import Foundation

public enum BuildEventKind: Sendable, Equatable {
    case passed, failed, blocked, canceled

    init?(_ state: BuildState) {
        switch state {
        case .passed: self = .passed
        case .failed: self = .failed
        case .blocked: self = .blocked
        case .canceled: self = .canceled
        default: return nil
        }
    }
}

public struct BuildEvent: Sendable, Equatable {
    public let kind: BuildEventKind
    public let build: Build
}

public enum BuildTransitions {
    /// Builds that reached a notifiable state since the previous poll of the same pipeline.
    /// `previous == nil` means first poll, which never notifies.
    public static func events(previous: [Build]?, current: [Build]) -> [BuildEvent] {
        guard let previous else { return [] }
        let known = Dictionary(previous.map { ($0.id, $0.state) }, uniquingKeysWith: { first, _ in first })
        let newestKnown = previous.compactMap(\.createdAt).max()

        return current.compactMap { build in
            guard let kind = BuildEventKind(build.state) else { return nil }
            if let before = known[build.id] {
                return before == build.state ? nil : BuildEvent(kind: kind, build: build)
            }
            // Unseen build that started and finished between polls.
            guard let newestKnown, let created = build.createdAt, created > newestKnown else { return nil }
            return BuildEvent(kind: kind, build: build)
        }
    }
}

public enum NotchStatus: Sendable, Equatable {
    case idle
    case running(count: Int, failing: Bool)
    case blocked
    case passed
    case failed
    case canceled
}

public enum BuildSelection {
    /// Per pipeline: every active or blocked build, plus the latest other build.
    public static func visible(_ builds: [Build]) -> [Build] {
        var result = builds.filter { $0.state.isActive || $0.state == .blocked }
        if let latest = builds.first(where: { !result.contains($0) }) {
            result.append(latest)
        }
        return result
    }

    /// Active builds first, then most recent activity first.
    public static func sorted(_ builds: [Build]) -> [Build] {
        builds.sorted { lhs, rhs in
            if lhs.state.isActive != rhs.state.isActive { return lhs.state.isActive }
            return (lhs.lastActivity ?? .distantPast) > (rhs.lastActivity ?? .distantPast)
        }
    }

    /// Summary shown in the collapsed notch.
    public static func status(
        of builds: [Build],
        now: Date,
        recentWindow: TimeInterval = 10 * 60,
        blockedWindow: TimeInterval = 60 * 60
    ) -> NotchStatus {
        let active = builds.filter(\.state.isActive)
        if !active.isEmpty {
            return .running(count: active.count, failing: active.contains { $0.state == .failing })
        }
        func isRecent(_ build: Build, within window: TimeInterval) -> Bool {
            guard let date = build.lastActivity else { return false }
            return now.timeIntervalSince(date) <= window
        }
        if builds.contains(where: { $0.state == .blocked && isRecent($0, within: blockedWindow) }) {
            return .blocked
        }
        let latest = builds
            .filter { BuildEventKind($0.state) != nil && $0.state != .blocked && isRecent($0, within: recentWindow) }
            .max { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }
        switch latest?.state {
        case .passed: return .passed
        case .failed: return .failed
        case .canceled: return .canceled
        default: return .idle
        }
    }
}
