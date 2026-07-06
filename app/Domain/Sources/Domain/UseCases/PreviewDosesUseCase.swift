import Foundation

public final class PreviewDosesUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(quantity: Int, pillPerDose: Int, schedule: ScheduleInput) async throws -> PreviewDosesData {
        let request = PreviewDosesRequest(quantity: quantity, pillPerDose: pillPerDose, schedule: schedule)
        let endpoint = APIEndpoint(path: "medicines/preview-doses", method: .post, body: try DoseLatchEncoder.encode(request))
        let response: PreviewDosesResponse = try await client.request(endpoint)
        return response.data
    }
}
