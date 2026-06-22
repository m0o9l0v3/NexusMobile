import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct APIClient {
    static let shared = APIClient()

    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = APIEnvironment.current.baseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", queryItems: queryItems)
        return try await send(request)
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(_ path: String, body: RequestBody) async throws -> ResponseBody {
        var request = try makeRequest(path: path, method: "POST")
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.encodingError(error.localizedDescription)
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    func health() async throws -> HealthDTO {
        try await get("/health")
    }

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(path)
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw APIError.invalidURL(path)
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: decodeProblemDetail(from: data))
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error.localizedDescription)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as URLError {
            throw APIError.requestFailed(error.localizedDescription)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }
    }

    private func decodeProblemDetail(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data) {
            return problem.detail ?? problem.title
        }
        return String(data: data, encoding: .utf8)
    }
}

enum APIEnvironment {
    case debug
    case release

    static var current: APIEnvironment {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    var baseURL: URL {
        if let override = Bundle.main.object(forInfoDictionaryKey: "NexusAPIBaseURL") as? String,
           let url = URL(string: override), !override.isEmpty {
            return url
        }

        switch self {
        case .debug:
            return URL(string: "http://localhost:5080")!
        case .release:
            return URL(string: "https://api.nexus.example.com")!
        }
    }
}

struct EmptyResponse: Decodable {}

struct HealthDTO: Decodable, Equatable {
    let status: String
}

private struct ProblemDetailsDTO: Decodable {
    let title: String?
    let detail: String?
}
