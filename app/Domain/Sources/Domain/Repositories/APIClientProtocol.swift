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

    public init(path: String, method: HTTPMethod = .get, body: Data? = nil, headers: [String: String] = [:]) {
        self.path = path
        self.method = method
        self.body = body
        self.headers = headers
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
    case decodingFailed
    case unauthorized
    case badResponse(statusCode: Int)
}
