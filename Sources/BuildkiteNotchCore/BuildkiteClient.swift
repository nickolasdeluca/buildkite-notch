import Foundation

public enum BuildkiteError: Error, LocalizedError, Equatable {
    case unauthorized
    case forbidden(String?)
    case notFound
    case rateLimited
    case http(Int, String?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Token inválido ou revogado."
        case .forbidden(let message): message ?? "Token sem permissão (verifique os escopos)."
        case .notFound: "Recurso não encontrado."
        case .rateLimited: "Limite de requisições da API atingido."
        case .http(let status, let message): message ?? "Erro HTTP \(status)."
        case .invalidResponse: "Resposta inválida da API."
        }
    }
}

/// Minimal client for the Buildkite REST API v2.
public struct BuildkiteClient: Sendable {
    public static let baseURL = URL(string: "https://api.buildkite.com/v2/")!

    public let token: String
    private let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    public func accessToken() async throws -> AccessToken {
        try await get(AccessToken.self, from: url("access-token")).value
    }

    public func organizations() async throws -> [Organization] {
        try await getAllPages(Organization.self, from: url("organizations", [.init(name: "per_page", value: "100")]))
    }

    public func pipelines(organization: String) async throws -> [Pipeline] {
        try await getAllPages(
            Pipeline.self,
            from: url("organizations/\(organization)/pipelines", [.init(name: "per_page", value: "100")])
        )
    }

    public func builds(
        organization: String,
        pipeline: String,
        branches: [String] = [],
        perPage: Int = 5
    ) async throws -> [Build] {
        var query = [URLQueryItem(name: "per_page", value: String(perPage))]
        query += branches.map { URLQueryItem(name: "branch[]", value: $0) }
        let endpoint = url("organizations/\(organization)/pipelines/\(pipeline)/builds", query)
        return try await get([Build].self, from: endpoint).value
    }

    // MARK: - Plumbing

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(raw) { return date }
            if let date = try? Date.ISO8601FormatStyle().parse(raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)"))
        }
        return decoder
    }

    private func url(_ path: String, _ query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }

    private func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> (value: T, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BuildkiteError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            return (try Self.makeDecoder().decode(T.self, from: data), http)
        case 401: throw BuildkiteError.unauthorized
        case 403: throw BuildkiteError.forbidden(Self.apiMessage(in: data))
        case 404: throw BuildkiteError.notFound
        case 429: throw BuildkiteError.rateLimited
        default: throw BuildkiteError.http(http.statusCode, Self.apiMessage(in: data))
        }
    }

    private func getAllPages<T: Decodable>(_ type: T.Type, from url: URL, maxPages: Int = 20) async throws -> [T] {
        var results: [T] = []
        var next: URL? = url
        var pages = 0
        while let current = next, pages < maxPages {
            let (items, response) = try await get([T].self, from: current)
            results += items
            next = nextPageURL(fromLinkHeader: response.value(forHTTPHeaderField: "Link"))
            pages += 1
        }
        return results
    }

    private static func apiMessage(in data: Data) -> String? {
        struct Message: Decodable { let message: String }
        return try? JSONDecoder().decode(Message.self, from: data).message
    }
}

/// Extracts the `rel="next"` URL from an RFC 8288 Link header.
public func nextPageURL(fromLinkHeader header: String?) -> URL? {
    guard let header else { return nil }
    for part in header.split(separator: ",") {
        let segments = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard segments.count >= 2,
              segments.dropFirst().contains(where: { $0 == "rel=\"next\"" }),
              segments[0].hasPrefix("<"), segments[0].hasSuffix(">")
        else { continue }
        return URL(string: String(segments[0].dropFirst().dropLast()))
    }
    return nil
}
