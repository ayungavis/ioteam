import Foundation

/// POST /medicines/{id}/reschedule — supersedes the active schedule, drops future pending
/// doses, and regenerates them under the new schedule. Historical doses are preserved.
public final class RescheduleMedicineUseCase: Sendable {
    private struct Request: Encodable { let schedule: ScheduleInput }
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(medicineId: String, schedule: ScheduleInput) async throws -> RescheduleData {
        let endpoint = APIEndpoint(path: "medicines/\(medicineId)/reschedule", method: .post, body: try DoseLatchEncoder.encode(Request(schedule: schedule)))
        let response: RescheduleResponse = try await client.request(endpoint)
        return response.data
    }
}
