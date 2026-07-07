import Foundation

/// POST /medicines/{id}/reschedule-preview — previews the future doses a schedule change
/// would produce (pill budget = remaining quantity). Writes nothing.
public final class ReschedulePreviewUseCase: Sendable {
    private struct Request: Encodable { let schedule: ScheduleInput }
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(medicineId: String, schedule: ScheduleInput) async throws -> PreviewDosesData {
        let endpoint = APIEndpoint(path: "medicines/\(medicineId)/reschedule-preview", method: .post, body: try DoseLatchEncoder.encode(Request(schedule: schedule)))
        let response: PreviewDosesResponse = try await client.request(endpoint)
        return response.data
    }
}
