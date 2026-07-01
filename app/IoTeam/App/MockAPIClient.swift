import Domain
import Foundation

#if DEBUG
    public final class MockAPIClient: APIClientProtocol {
        public init() {}

        public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
            try await Task.sleep(for: .milliseconds(800))

            switch (endpoint.path, endpoint.method) {
            case ("auth/apple", .post):
                let userId = parseUserId(from: endpoint.body)
                let token = AuthToken(accessToken: "mock-token-abc123", userId: userId)
                guard let result = token as? T else { throw NetworkError.decodingFailed }
                return result
            case ("tasks", .get):
                let tasks = [
                    TaskItem(
                        id: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F") ?? UUID(),
                        title: "Buy groceries",
                        isCompleted: false
                    ),
                    TaskItem(
                        id: UUID(uuidString: "F4E5D6C7-B8A9-4C3D-2E1F-0A1B2C3D4E5F") ?? UUID(),
                        title: "Walk the dog",
                        isCompleted: true
                    ),
                    TaskItem(
                        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") ?? UUID(),
                        title: "Review pull request",
                        isCompleted: false
                    ),
                ]
                guard let result = tasks as? T else { throw NetworkError.decodingFailed }
                return result
            default:
                throw NetworkError.invalidURL
            }
        }

        private func parseUserId(from body: Data?) -> String {
            guard let body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String]
            else {
                return UUID().uuidString
            }
            return json["user_id"] ?? UUID().uuidString
        }
    }
#endif
