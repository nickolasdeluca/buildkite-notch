import BuildkiteNotchCore
import Foundation
import Observation

/// One entry of the collapsed stack: a selected pipeline and the build that represents it.
struct PipelineItem: Identifiable {
    let slug: String
    let name: String
    let build: Build?
    var id: String { slug }
}

/// A pipeline whose last poll failed. Kept raw so the message follows the current language.
struct PollFailure {
    let pipelineName: String
    let error: any Error
}

@MainActor
@Observable
final class BuildStore {
    private(set) var buildsByPipeline: [String: [Build]] = [:]
    private(set) var failures: [PollFailure] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let notifier: Notifier
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    private static let activeInterval: Duration = .seconds(10)
    private static let idleInterval: Duration = .seconds(30)
    private static let backoffInterval: Duration = .seconds(60)

    init(settings: AppSettings, notifier: Notifier) {
        self.settings = settings
        self.notifier = notifier
    }

    /// Selected pipelines in the user's order, each with its most relevant build.
    var pipelineItems: [PipelineItem] {
        settings.pipelines.map { pipeline in
            let builds = buildsByPipeline[pipeline.slug] ?? []
            return PipelineItem(
                slug: pipeline.slug,
                name: pipeline.name,
                build: BuildSelection.sorted(BuildSelection.visible(builds)).first
            )
        }
    }

    /// Builds not already shown as a pipeline headline, newest first.
    var recentBuilds: [Build] {
        let headlines = Set(pipelineItems.compactMap(\.build?.id))
        return BuildSelection.sorted(buildsByPipeline.values.flatMap { $0 })
            .filter { !headlines.contains($0.id) }
    }

    /// One line per failed pipeline.
    var lastError: String? {
        guard !failures.isEmpty else { return nil }
        let strings = settings.strings
        return failures
            .map { "\($0.pipelineName): \(strings.message(for: $0.error))" }
            .sorted()
            .joined(separator: "\n")
    }

    func status(at now: Date) -> NotchStatus {
        BuildSelection.status(of: buildsByPipeline.values.flatMap { $0 }, now: now)
    }

    /// (Re)starts polling. `debounce` absorbs bursts of settings edits.
    func start(debounce: Duration = .zero) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            if debounce > .zero { try? await Task.sleep(for: debounce) }
            while !Task.isCancelled {
                guard let delay = await self?.refresh() else { return }
                try? await Task.sleep(for: delay)
            }
        }
    }

    /// Settings changed: forget old builds so we don't fire stale notifications.
    func restart() {
        buildsByPipeline = [:]
        failures = []
        start(debounce: .milliseconds(600))
    }

    func refreshNow() { start() }

    @discardableResult
    private func refresh() async -> Duration {
        guard settings.isConfigured else {
            buildsByPipeline = [:]
            failures = []
            return Self.idleInterval
        }

        let config = settings.pollConfiguration
        let client = BuildkiteClient(token: config.token)
        isRefreshing = true
        defer { isRefreshing = false }

        var results: [(slug: String, result: Result<[Build], any Error>)] = []
        await withTaskGroup(of: (String, Result<[Build], any Error>).self) { group in
            for pipeline in config.pipelines {
                group.addTask {
                    do {
                        let builds = try await client.builds(
                            organization: config.organization,
                            pipeline: pipeline.slug,
                            branches: config.branches
                        )
                        return (pipeline.slug, .success(builds))
                    } catch {
                        return (pipeline.slug, .failure(error))
                    }
                }
            }
            for await item in group { results.append(item) }
        }

        // Settings changed while we were waiting; drop this round.
        guard !Task.isCancelled, settings.pollConfiguration == config else { return Self.activeInterval }

        var failed: [PollFailure] = []
        var rateLimited = false
        for (slug, result) in results {
            switch result {
            case .success(let builds):
                if settings.notificationsEnabled {
                    for event in BuildTransitions.events(previous: buildsByPipeline[slug], current: builds) {
                        notifier.post(event, pipelineName: settings.pipelineName(for: slug), strings: settings.strings)
                    }
                }
                buildsByPipeline[slug] = builds
            case .failure(let error):
                if (error as? BuildkiteError) == .rateLimited { rateLimited = true }
                failed.append(PollFailure(pipelineName: settings.pipelineName(for: slug), error: error))
            }
        }

        let selected = Set(config.pipelines.map(\.slug))
        buildsByPipeline = buildsByPipeline.filter { selected.contains($0.key) }
        failures = failed
        lastUpdated = .now

        if rateLimited { return Self.backoffInterval }
        let anyActive = buildsByPipeline.values.contains { $0.contains(where: \.state.isActive) }
        return anyActive ? Self.activeInterval : Self.idleInterval
    }
}
