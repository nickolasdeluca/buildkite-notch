import BuildkiteNotchCore
import Foundation
import Observation

enum NotchStyle: String, CaseIterable, Identifiable {
    case liquidGlass, darkGlass, solidBlack

    var id: String { rawValue }
}

struct PipelineSelection: Codable, Hashable, Identifiable {
    let slug: String
    let name: String
    var id: String { slug }
}

/// Everything that changes which builds get polled.
struct PollConfiguration: Hashable {
    let token: String
    let organization: String
    let pipelines: [PipelineSelection]
    let branches: [String]
}

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let organization = "organization"
        static let organizationName = "organizationName"
        static let pipelines = "pipelines"
        static let branchFilter = "branchFilter"
        static let notificationsEnabled = "notificationsEnabled"
        static let placement = "placement"
        static let notchStyle = "notchStyle"
        static let language = "language"
        static let appleLanguages = "AppleLanguages"
        static let tokenAccount = "api-token"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    var token: String {
        didSet { Keychain.save(token, account: Key.tokenAccount) }
    }

    var organization: String {
        didSet { defaults.set(organization, forKey: Key.organization) }
    }

    var organizationName: String {
        didSet { defaults.set(organizationName, forKey: Key.organizationName) }
    }

    var pipelines: [PipelineSelection] {
        didSet { defaults.set(try? JSONEncoder().encode(pipelines), forKey: Key.pipelines) }
    }

    /// Comma-separated branch names; empty means every branch.
    var branchFilter: String {
        didSet { defaults.set(branchFilter, forKey: Key.branchFilter) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }

    var placement: NotchPlacement {
        didSet { defaults.set(try? JSONEncoder().encode(placement), forKey: Key.placement) }
    }

    var notchStyle: NotchStyle {
        didSet { defaults.set(notchStyle.rawValue, forKey: Key.notchStyle) }
    }

    /// Interface language; nil follows macOS.
    var language: Language? {
        didSet {
            guard language != oldValue else { return }
            defaults.set(language?.rawValue, forKey: Key.language)
            // Text drawn by macOS (context menus, system errors) reads this app-level override at launch.
            // It is also where System Settings keeps a per-app language, so "system" clears it.
            defaults.set(language.map { [$0.rawValue] }, forKey: Key.appleLanguages)
        }
    }

    init() {
        token = Keychain.read(account: Key.tokenAccount) ?? ""
        organization = defaults.string(forKey: Key.organization) ?? ""
        organizationName = defaults.string(forKey: Key.organizationName) ?? ""
        pipelines = defaults.data(forKey: Key.pipelines)
            .flatMap { try? JSONDecoder().decode([PipelineSelection].self, from: $0) } ?? []
        branchFilter = defaults.string(forKey: Key.branchFilter) ?? ""
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
        placement = defaults.data(forKey: Key.placement)
            .flatMap { try? JSONDecoder().decode(NotchPlacement.self, from: $0) } ?? .default
        notchStyle = defaults.string(forKey: Key.notchStyle).flatMap(NotchStyle.init) ?? .solidBlack
        language = defaults.string(forKey: Key.language).flatMap(Language.init)
    }

    var strings: any Strings {
        (language ?? .preferred(in: Locale.preferredLanguages)).strings
    }

    var branches: [String] {
        branchFilter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var isConfigured: Bool { !token.isEmpty && !organization.isEmpty && !pipelines.isEmpty }

    var pollConfiguration: PollConfiguration {
        PollConfiguration(token: token, organization: organization, pipelines: pipelines, branches: branches)
    }

    func pipelineName(for slug: String) -> String {
        pipelines.first { $0.slug == slug }?.name ?? slug
    }
}
