import Foundation

/// PATCH /medicines/{id} — updates name/status/device and/or adjusts stock by a signed delta.
/// Does not change the schedule structure; use RescheduleMedicineUseCase for that.
public final class UpdateMedicineUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(medicineId: String, request: UpdateMedicineRequest) async throws -> UpdateMedicineData {
        let endpoint = APIEndpoint(path: "medicines/\(medicineId)", method: .patch, body: try DoseLatchEncoder.encode(request))
        let response: UpdateMedicineResponse = try await client.request(endpoint)
        return response.data
    }
}
