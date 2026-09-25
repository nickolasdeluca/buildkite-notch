import BuildkiteNotchCore

struct EnglishStrings: Strings {
    // MARK: Menus
    let refreshNow = "Refresh Now"
    let settingsMenuItem = "Settings…"
    let quit = "Quit"
    let closeWindow = "Close Window"
    let quitApp = "Quit Buildkite Notch"
    let edit = "Edit"
    let undo = "Undo"
    let redo = "Redo"
    let cut = "Cut"
    let copy = "Copy"
    let paste = "Paste"
    let selectAll = "Select All"

    // MARK: Notch
    let refresh = "Refresh"
    let settings = "Settings"
    let openSettings = "Open Settings"
    let connectAccount = "Connect your Buildkite account"
    let choosePipelines = "Choose pipelines to follow"
    let noRecentBuilds = "No recent builds"
    let noMessage = "(no message)"
    let queued = "queued"
    let queuedShort = "queued"
    let justNow = "now"

    func ago(_ age: String) -> String { "\(age) ago" }

    func jobs(finished: Int, total: Int) -> String { "\(finished)/\(total) jobs" }

    func label(for glyph: Glyph) -> String {
        switch glyph {
        case .idle: "idle"
        case .scheduled: "queued"
        case .running: "running"
        case .failing: "failing"
        case .passed: "passed"
        case .failed: "failed"
        case .blocked: "blocked"
        case .canceled: "canceled"
        }
    }

    // MARK: Notifications
    func title(for event: BuildEventKind) -> String {
        switch event {
        case .passed: "✅ Passed"
        case .failed: "❌ Failed"
        case .blocked: "⏸ Waiting for approval"
        case .canceled: "⛔️ Canceled"
        }
    }

    // MARK: Settings
    let account = "Account"
    let connect = "Connect"
    let disconnect = "Disconnect"
    let organization = "Organization"

    func tokenHelp(scopes: String) -> String {
        "Create a token at buildkite.com/user/api-access-tokens with the scopes \(scopes)."
    }

    func connected(as user: String?, missingScopes: [String]) -> String {
        let status = "Connected: \(user ?? "valid token")"
        return missingScopes.isEmpty ? status : "\(status). Missing scopes: \(missingScopes.joined(separator: ", "))"
    }

    func pipelinesHeader(selected: Int) -> String { "Pipelines (\(selected) selected)" }

    let connectToListPipelines = "Connect an account to list its pipelines."
    let noPipelinesLoaded = "No pipelines loaded."
    let search = "Search"
    let branches = "Branches"
    let branchesHelp = "Comma-separated branches. Leave empty to follow every branch."
    let notchPosition = "Notch Position"
    let edge = "Edge"

    func name(for edge: ScreenEdge) -> String {
        switch edge {
        case .top: "Top"
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }

    let position = "Position"
    let center = "Center"
    let display = "Display"
    let mainDisplay = "Main"
    let dragHint = "Tip: hold ⌥ Option over the notch and drag it to any edge."
    let appearance = "Appearance"
    let notchStyle = "Notch style"

    func name(for style: NotchStyle) -> String {
        switch style {
        case .liquidGlass: "Liquid Glass"
        case .darkGlass: "Dark Glass"
        case .solidBlack: "Solid Black"
        }
    }

    let refreshInterval = "Refresh Interval"
    let whileBuildsRun = "While builds run"
    let whenIdle = "When idle"
    let secondsUnit = "s"

    func pollIntervalHelp(range: ClosedRange<Int>) -> String {
        "Between \(range.lowerBound) and \(range.upperBound) seconds. Short intervals with many pipelines use more of the Buildkite API rate limit."
    }

    let general = "General"
    let language = "Language"
    let systemLanguage = "System default"
    let languageHelp = "Text drawn by macOS, such as context menus, switches the next time the app opens."
    let notifyWhenFinished = "Notify when builds finish"
    let launchAtLogin = "Open at login"

    func loginItemFailed(_ reason: String) -> String { "Couldn't change the login item: \(reason)" }

    // MARK: Errors
    func describe(_ error: BuildkiteError) -> String {
        switch error {
        case .unauthorized: "Invalid or revoked token."
        case .forbidden(let message): message ?? "The token lacks permission (check its scopes)."
        case .notFound: "Resource not found."
        case .rateLimited: "API rate limit reached."
        case .http(let status, let message): message ?? "HTTP error \(status)."
        case .invalidResponse: "Invalid API response."
        }
    }
}
