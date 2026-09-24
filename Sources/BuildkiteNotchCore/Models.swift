import Foundation

public enum BuildState: String, Codable, Sendable, CaseIterable {
    case creating, scheduled, running, passed, failing, failed, blocked, canceling, canceled, skipped
    case notRun = "not_run"
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BuildState(rawValue: raw) ?? .unknown
    }

    /// Build still has work in progress.
    public var isActive: Bool {
        switch self {
        case .creating, .scheduled, .running, .failing, .canceling: true
        default: false
        }
    }
}

public struct Job: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let type: String
    public let name: String?
    public let label: String?
    public let state: String?

    public init(id: String, type: String, name: String?, label: String?, state: String?) {
        self.id = id
        self.type = type
        self.name = name
        self.label = label
        self.state = state
    }

    private static let finishedStates: Set<String> = [
        "passed", "failed", "canceled", "timed_out", "skipped", "finished", "expired",
    ]

    /// Script jobs that will actually run; "broken" jobs were skipped by conditions.
    public var countsTowardProgress: Bool { type == "script" && state != "broken" }
    public var isFinished: Bool { state.map(Self.finishedStates.contains) ?? false }
}

public struct Creator: Codable, Sendable, Hashable {
    public let name: String?
    public let email: String?

    public init(name: String?, email: String?) {
        self.name = name
        self.email = email
    }
}

public struct PipelineRef: Codable, Sendable, Hashable {
    public let slug: String
    public let name: String

    public init(slug: String, name: String) {
        self.slug = slug
        self.name = name
    }
}

public struct Build: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let number: Int
    public let state: BuildState
    public let message: String?
    public let branch: String?
    public let commit: String?
    public let webUrl: String
    public let createdAt: Date?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let creator: Creator?
    public let jobs: [Job]?
    public let pipeline: PipelineRef?

    public init(
        id: String, number: Int, state: BuildState, message: String?, branch: String?, commit: String?,
        webUrl: String, createdAt: Date?, startedAt: Date?, finishedAt: Date?,
        creator: Creator?, jobs: [Job]?, pipeline: PipelineRef?
    ) {
        self.id = id
        self.number = number
        self.state = state
        self.message = message
        self.branch = branch
        self.commit = commit
        self.webUrl = webUrl
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.creator = creator
        self.jobs = jobs
        self.pipeline = pipeline
    }

    public var url: URL? { URL(string: webUrl) }

    public var title: String {
        let firstLine = message?.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "(sem mensagem)" : firstLine
    }

    public var jobProgress: (finished: Int, total: Int) {
        let counted = (jobs ?? []).filter(\.countsTowardProgress)
        return (counted.filter(\.isFinished).count, counted.count)
    }

    public func duration(at now: Date) -> TimeInterval? {
        guard let startedAt else { return nil }
        return (finishedAt ?? now).timeIntervalSince(startedAt)
    }

    /// Most recent moment the build changed, used to decide what counts as "recent".
    public var lastActivity: Date? { finishedAt ?? startedAt ?? createdAt }
}

public struct Organization: Codable, Sendable, Hashable, Identifiable {
    public let slug: String
    public let name: String
    public var id: String { slug }
}

public struct Pipeline: Codable, Sendable, Hashable, Identifiable {
    public let slug: String
    public let name: String
    public let defaultBranch: String?
    public var id: String { slug }
}

public struct AccessToken: Codable, Sendable {
    public struct User: Codable, Sendable {
        public let name: String?
        public let email: String?
    }

    public let uuid: String
    public let scopes: [String]
    public let user: User?
}
