import Foundation
import Testing
@testable import BuildkiteNotchCore

private let sampleBuildJSON = """
[{
  "id": "f62a1b4d-10f9-4790-bc1c-e2c3a0c80983",
  "number": 42,
  "state": "running",
  "message": "Deploy API\\n\\nLonger body",
  "branch": "main",
  "commit": "abc123",
  "web_url": "https://buildkite.com/acme/api/builds/42",
  "created_at": "2026-09-24T12:00:00.123Z",
  "started_at": "2026-09-24T12:00:05Z",
  "finished_at": null,
  "creator": {"name": "Ana", "email": "ana@example.com"},
  "pipeline": {"slug": "api", "name": "API"},
  "jobs": [
    {"id": "1", "type": "script", "name": "test", "state": "passed"},
    {"id": "2", "type": "waiter", "state": null},
    {"id": "3", "type": "script", "name": "deploy", "state": "running"},
    {"id": "4", "type": "script", "name": "skipped by if", "state": "broken"},
    {"id": "5", "type": "manual", "label": "Approve", "state": "unblocked"}
  ],
  "some_new_field": true
}]
"""

private func build(
    _ id: String,
    _ state: BuildState,
    created: TimeInterval = 0,
    finished: TimeInterval? = nil
) -> Build {
    Build(
        id: id, number: 1, state: state, message: nil, branch: "main", commit: nil,
        webUrl: "https://buildkite.com/x", createdAt: Date(timeIntervalSince1970: created),
        startedAt: Date(timeIntervalSince1970: created),
        finishedAt: finished.map(Date.init(timeIntervalSince1970:)),
        creator: nil, jobs: nil, pipeline: nil
    )
}

@Test func decodesBuildkiteBuilds() throws {
    let builds = try BuildkiteClient.makeDecoder().decode([Build].self, from: Data(sampleBuildJSON.utf8))
    let b = try #require(builds.first)
    #expect(b.state == .running)
    #expect(b.title == "Deploy API")
    #expect(b.pipeline?.name == "API")
    #expect(b.createdAt != nil)
    #expect(b.finishedAt == nil)
    #expect(b.jobProgress.finished == 1)
    #expect(b.jobProgress.total == 2)
}

@Test func titleIsFirstLineOrNil() {
    #expect(build("a", .passed).title == nil)
}

@Test func unknownStateDecodesAsUnknown() throws {
    let json = #"["brand_new_state"]"#
    let states = try JSONDecoder().decode([BuildState].self, from: Data(json.utf8))
    #expect(states == [.unknown])
}

@Test func parsesNextLink() {
    let header = #"<https://api.buildkite.com/v2/organizations?page=3>; rel="next", <https://api.buildkite.com/v2/organizations?page=9>; rel="last""#
    #expect(nextPageURL(fromLinkHeader: header)?.absoluteString == "https://api.buildkite.com/v2/organizations?page=3")
    #expect(nextPageURL(fromLinkHeader: #"<https://x/?page=1>; rel="prev""#) == nil)
    #expect(nextPageURL(fromLinkHeader: nil) == nil)
}

@Test func firstPollNeverNotifies() {
    #expect(BuildTransitions.events(previous: nil, current: [build("a", .passed)]).isEmpty)
}

@Test func notifiesOnStateChange() {
    let events = BuildTransitions.events(
        previous: [build("a", .running), build("b", .running), build("c", .passed)],
        current: [build("a", .passed), build("b", .running), build("c", .passed)]
    )
    #expect(events.map(\.kind) == [.passed])
    #expect(events.first?.build.id == "a")
}

@Test func notifiesUnseenBuildThatFinishedBetweenPolls() {
    let events = BuildTransitions.events(
        previous: [build("old", .passed, created: 100)],
        current: [build("new", .failed, created: 200), build("older", .passed, created: 50)]
    )
    #expect(events.map(\.build.id) == ["new"])
}

@Test func statusPrefersRunningThenBlockedThenRecent() {
    let now = Date(timeIntervalSince1970: 10_000)
    #expect(BuildSelection.status(of: [build("a", .running), build("b", .failing)], now: now)
        == .running(count: 2, failing: true))
    #expect(BuildSelection.status(of: [build("a", .blocked, created: 9_900), build("b", .failed, finished: 9_990)], now: now)
        == .blocked)
    #expect(BuildSelection.status(of: [build("a", .failed, finished: 9_990)], now: now) == .failed)
    #expect(BuildSelection.status(of: [build("a", .failed, finished: 1_000)], now: now) == .idle)
}

@Test func visibleKeepsActiveAndLatest() {
    let builds = [build("r", .running), build("p1", .passed), build("p2", .passed)]
    #expect(BuildSelection.visible(builds).map(\.id) == ["r", "p1"])
}

private let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)

@Test func rectHugsEachEdge() {
    #expect(NotchLayout.rect(for: .init(edge: .top), along: 200, across: 30, in: screen)
        == CGRect(x: 400, y: 570, width: 200, height: 30))
    #expect(NotchLayout.rect(for: .init(edge: .bottom, position: 0.25), along: 200, across: 30, in: screen)
        == CGRect(x: 150, y: 0, width: 200, height: 30))
    #expect(NotchLayout.rect(for: .init(edge: .left, position: 0.5), along: 100, across: 30, in: screen)
        == CGRect(x: 0, y: 250, width: 30, height: 100))
    #expect(NotchLayout.rect(for: .init(edge: .right, position: 0.5), along: 100, across: 30, in: screen)
        == CGRect(x: 970, y: 250, width: 30, height: 100))
}

@Test func rectClampsInsideScreen() {
    #expect(NotchLayout.rect(for: .init(edge: .top, position: 0), along: 200, across: 30, in: screen).minX == 0)
    #expect(NotchLayout.rect(for: .init(edge: .right, position: 1), along: 100, across: 30, in: screen).maxY == 600)
}

@Test func placementPicksNearestEdgeAndSnapsToCenter() {
    let side = NotchLayout.placement(nearest: CGPoint(x: 990, y: 150), in: screen, displayID: 7)
    #expect(side.edge == .right)
    #expect(side.position == 0.25)
    #expect(side.displayID == 7)
    let top = NotchLayout.placement(nearest: CGPoint(x: 510, y: 595), in: screen, displayID: nil)
    #expect(top.edge == .top)
    #expect(top.isCentered)
}

@Test func languageFollowsFirstSupportedPreference() {
    #expect(Language.preferred(in: ["pt-BR", "en-US"]) == .portuguese)
    #expect(Language.preferred(in: ["pt-PT"]) == .portuguese)
    #expect(Language.preferred(in: ["pt_BR"]) == .portuguese)
    #expect(Language.preferred(in: ["en-GB", "pt-BR"]) == .english)
    #expect(Language.preferred(in: ["de-DE", "pt-BR"]) == .portuguese)
    #expect(Language.preferred(in: ["fr-FR", "de"]) == .english)
    #expect(Language.preferred(in: []) == .english)
}

@Test func pollIntervalClampsAndBacksOff() {
    #expect(PollInterval.clamped(1) == 10)
    #expect(PollInterval.clamped(100_000) == 3600)
    #expect(PollInterval.delay(active: 15, idle: 90, anyActive: true, rateLimited: false) == 15)
    #expect(PollInterval.delay(active: 15, idle: 90, anyActive: false, rateLimited: false) == 90)
    #expect(PollInterval.delay(active: 1, idle: 90, anyActive: true, rateLimited: false) == 10)
    #expect(PollInterval.delay(active: 15, idle: 90, anyActive: true, rateLimited: true) == 60)
    #expect(PollInterval.delay(active: 15, idle: 300, anyActive: false, rateLimited: true) == 300)
}
