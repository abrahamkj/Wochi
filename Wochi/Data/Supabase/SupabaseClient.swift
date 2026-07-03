import Foundation

// MARK: - SupabaseClient
//
// Minimal URLSession-based Supabase REST client — no third-party SDK.
// Sends requests to PostgREST with the anon key in the Authorization header.

final class SupabaseClient {
    static let shared = SupabaseClient()

    private let projectURL: String
    private let anonKey: String
    private let session: URLSession

    private init() {
        self.projectURL = Constants.Supabase.projectURL
        self.anonKey    = Constants.Supabase.anonKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - GET

    func get<T: Decodable>(
        from table: String,
        query: [URLQueryItem] = [],
        as type: T.Type
    ) async throws -> T {
        guard var components = URLComponents(string: "\(projectURL)/rest/v1/\(table)") else {
            throw WochiError.networkUnavailable
        }
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else { throw WochiError.networkUnavailable }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Validation

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let underlying = URLError(.badServerResponse)
            throw WochiError.supabaseFetchFailed(underlying: underlying)
        }
    }
}
