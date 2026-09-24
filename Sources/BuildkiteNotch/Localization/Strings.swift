import BuildkiteNotchCore
import SwiftUI

/// Every user-facing string, with one conforming type per language, so a missing translation is a
/// compile error. Brand and product names (Buildkite, Liquid Glass, API Access Token) stay literal.
protocol Strings: Sendable {
    // MARK: Menus
    var refreshNow: String { get }
    var settingsMenuItem: String { get }
    var quit: String { get }
    var closeWindow: String { get }
    var quitApp: String { get }
    var edit: String { get }
    var undo: String { get }
    var redo: String { get }
    var cut: String { get }
    var copy: String { get }
    var paste: String { get }
    var selectAll: String { get }

    // MARK: Notch
    var refresh: String { get }
    var settings: String { get }
    var openSettings: String { get }
    var connectAccount: String { get }
    var choosePipelines: String { get }
    var noRecentBuilds: String { get }
    var noMessage: String { get }
    /// "Queued" next to a build number.
    var queued: String { get }
    /// "Queued" under a ring in the collapsed notch; keep it short.
    var queuedShort: String { get }
    var justNow: String { get }
    /// `age` is already abbreviated, e.g. "13 min".
    func ago(_ age: String) -> String
    func jobs(finished: Int, total: Int) -> String
    func label(for glyph: Glyph) -> String

    // MARK: Notifications
    func title(for event: BuildEventKind) -> String

    // MARK: Settings
    var account: String { get }
    var connect: String { get }
    var disconnect: String { get }
    var organization: String { get }
    func tokenHelp(scopes: String) -> String
    func connected(as user: String?, missingScopes: [String]) -> String
    func pipelinesHeader(selected: Int) -> String
    var connectToListPipelines: String { get }
    var noPipelinesLoaded: String { get }
    var search: String { get }
    var branches: String { get }
    var branchesHelp: String { get }
    var notchPosition: String { get }
    var edge: String { get }
    func name(for edge: ScreenEdge) -> String
    var position: String { get }
    var center: String { get }
    var display: String { get }
    var mainDisplay: String { get }
    var dragHint: String { get }
    var appearance: String { get }
    var notchStyle: String { get }
    func name(for style: NotchStyle) -> String
    var general: String { get }
    var language: String { get }
    var systemLanguage: String { get }
    var languageHelp: String { get }
    var notifyWhenFinished: String { get }
    var launchAtLogin: String { get }
    func loginItemFailed(_ reason: String) -> String

    // MARK: Errors
    func describe(_ error: BuildkiteError) -> String
}

extension Strings {
    func message(for error: any Error) -> String {
        (error as? BuildkiteError).map(describe) ?? error.localizedDescription
    }

    /// "now", "5m", "3h", "2d".
    func compactAge(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        switch seconds {
        case ..<60: return justNow
        case ..<3600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86_400)d"
        }
    }

    /// "13 min ago" style, matching the compact captions.
    func relativeAge(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        switch seconds {
        case ..<60: return justNow
        case ..<3600: return ago("\(seconds / 60) min")
        case ..<86_400: return ago("\(seconds / 3600) h")
        default: return ago("\(seconds / 86_400) d")
        }
    }
}

extension Language {
    var strings: any Strings {
        switch self {
        case .english: EnglishStrings()
        case .portuguese: PortugueseStrings()
        }
    }

    /// Shown untranslated so people can find their language whatever the current one is.
    var nativeName: String {
        switch self {
        case .english: "English (US)"
        case .portuguese: "Português (Brasil)"
        }
    }
}

extension EnvironmentValues {
    @Entry var strings: any Strings = Language.english.strings
}
