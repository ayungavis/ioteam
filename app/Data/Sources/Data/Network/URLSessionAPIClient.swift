//
//  URLSessionAPIClient.swift
//  Data
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation

private actor AuthCredentialStore {
    static let shared = AuthCredentialStore()
    private var activeBearerToken: String?
    
    func saveToken(_ token: String) {
        activeBearerToken = token
    }
    
    func getToken() -> String? {
        return activeBearerToken
    }
    
    func clearToken() {
        activeBearerToken = nil
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
        await AuthCredentialStore.shared.saveToken(token)
    }
    
    /// Global session flusher method exposed for sign-out flows
    public static func clearSessionToken() async {
        await AuthCredentialStore.shared.clearToken()
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
        if let token = await AuthCredentialStore.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Execute explicit native network connection call
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(statusCode: 0)
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
            await AuthCredentialStore.shared.clearToken()
            throw NetworkError.unauthorized

        default:
            throw NetworkError.badResponse(statusCode: httpResponse.statusCode)
        }
    }
}
