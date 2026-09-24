import Foundation

/// Languages the interface is translated to.
public enum Language: String, CaseIterable, Identifiable, Sendable {
    case english = "en-US"
    case portuguese = "pt-BR"

    public var id: String { rawValue }

    /// First of `identifiers` (BCP 47, most preferred first) the app supports; English otherwise.
    public static func preferred(in identifiers: [String]) -> Language {
        for identifier in identifiers {
            switch Locale.Language(identifier: identifier).languageCode {
            case .portuguese: return .portuguese
            case .english: return .english
            default: continue
            }
        }
        return .english
    }
}
