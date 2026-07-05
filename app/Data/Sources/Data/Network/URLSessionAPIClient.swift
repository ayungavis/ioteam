//
//  URLSessionAPIClient.swift
//  Data
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation

nonisolated(unsafe) private let sharedDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(abbreviation: "UTC")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return f
}()

/// Returns a JSONDecoder configured for the DoseLatch API (snake_case keys, ISO8601 dates)
private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .formatted(sharedDateFormatter)
    return decoder
}

private struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}

private final class AuthCredentialStore: @unchecked Sendable {
    static let shared = AuthCredentialStore()
    
    private let lock = NSLock()
    private var activeBearerToken: String?
    
    private init() {}
    
    func saveToken(_ token: String) {
        lock.lock()
        activeBearerToken = token
        lock.unlock()
    }
    
    func getToken() -> String? {
        lock.lock()
        let token = activeBearerToken
        lock.unlock()
        return token
    }
    
    func clearToken() {
        lock.lock()
        activeBearerToken = nil
        lock.unlock()
    }
}

public final class URLSessionAPIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    
    public init(baseURLString: String, session: URLSession? = nil) {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid API configuration baseline URL: \(baseURLString)")
        }
        self.baseURL = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = session ?? URLSession(configuration: config)
    }
    
    /// Global token updater method exposed for login flows to store incoming sessions
    public static func updateSessionToken(_ token: String) async {
        AuthCredentialStore.shared.saveToken(token)
    }
    
    /// Global session flusher method exposed for sign-out flows
    public static func clearSessionToken() async {
        AuthCredentialStore.shared.clearToken()
    }
    
    public static func bootstrapSessionToken(_ token: String) {
        AuthCredentialStore.shared.saveToken(token)
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var path = components?.path ?? ""
        if path.hasSuffix("/") { path = String(path.dropLast()) }
        components?.path = path + "/\(endpoint.path)"
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let fullURL = components?.url else {
            throw NetworkError.invalidURL
        }
        var urlRequest = URLRequest(url: fullURL)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.httpBody = endpoint.body
        
        // Set globally unified JSON standards
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Inject any explicit user/feature endpoint headers
        endpoint.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        
        // AUTOMATIC BEARER TOKEN INTERCEPTION LAYER
        // Reads token securely without stalling or blocking parallel concurrent background threads
        if let token = AuthCredentialStore.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Execute explicit native network connection call
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(statusCode: 0, message: nil)
        }
        
        // Inspect Server Verification Handshakes
        switch httpResponse.statusCode {
        case 200 ... 299:
            do {
                let response = try makeDecoder().decode(T.self, from: data)
                return response
            } catch {
                throw NetworkError.decodingFailed(underlying: error.localizedDescription)
            }
            
        case 401:
            // Wipe the runtime session memory token clean
            AuthCredentialStore.shared.clearToken()
            throw NetworkError.unauthorized(message: decodeErrorMessage(from: data))

        default:
            throw NetworkError.badResponse(
                statusCode: httpResponse.statusCode,
                message: decodeErrorMessage(from: data)
            )
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(APIErrorResponse.self, from: data) else {
            return nil
        }
        return response.error ?? response.message
    }
}
