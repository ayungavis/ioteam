//
//  APIClientProtocol.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

public struct APIEndpoint {
    public let path: String
    public let method: HTTPMethod
    public let body: Data?
    public let headers: [String: String]
    public let queryItems: [URLQueryItem]?

    public init(path: String, method: HTTPMethod = .get, body: Data? = nil, headers: [String: String] = [:], queryItems: [URLQueryItem]? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.headers = headers
        self.queryItems = queryItems
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

public enum NetworkError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case decodingFailed(underlying: String? = nil)
    case unauthorized(message: String?)
    case badResponse(statusCode: Int, message: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .decodingFailed(let underlying):
            return underlying ?? "Failed to decode the server response."
        case .unauthorized(let message):
            return message ?? "Unauthorized."
        case .badResponse(_, let message):
            return message ?? "The server returned an unexpected response."
        }
    }
}
