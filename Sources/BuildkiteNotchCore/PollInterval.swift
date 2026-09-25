import Foundation

/// How long to wait between polls, in whole seconds.
public enum PollInterval {
    /// While any followed build is running or queued.
    public static let defaultActiveSeconds = 10
    /// When every followed build has finished.
    public static let defaultIdleSeconds = 60
    /// Lower bound keeps a handful of pipelines well inside Buildkite's rate limit.
    public static let range = 10...3600
    /// Minimum wait after the API reports a rate limit.
    public static let backoffSeconds = 60

    public static func clamped(_ seconds: Int) -> Int {
        min(max(seconds, range.lowerBound), range.upperBound)
    }

    /// Delay before the next poll: the active or idle interval, stretched to the backoff when rate limited.
    public static func delay(active: Int, idle: Int, anyActive: Bool, rateLimited: Bool) -> Int {
        let interval = clamped(anyActive ? active : idle)
        return rateLimited ? max(interval, backoffSeconds) : interval
    }
}
