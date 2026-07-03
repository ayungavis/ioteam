//
//  URLSessionAPIClient.swift
//  Data
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation

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
    
    public init(baseURLString: String, session: URLSession = .shared) {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid API configuration baseline URL: \(baseURLString)")
        }
        self.baseURL = url
        self.session = session
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
        // Build and validate URL target paths safely
        let fullURL = baseURL.appendingPathComponent(endpoint.path)
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
                let decoder = JSONDecoder()
                
                // Convert snake_case API standard automatically to native Swift camelCase
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Set ISO8601 formatting to decode server timestamps automatically
                decoder.dateDecodingStrategy = .iso8601
                
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed
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
