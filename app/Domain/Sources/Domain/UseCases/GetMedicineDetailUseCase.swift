import Foundation

public final class GetMedicineDetailUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(medicineId: String) async throws -> MedicineDetailData {
        let response: MedicineDetailResponse = try await client.request(APIEndpoint(path: "medicines/\(medicineId)", method: .get))
        return response.data
    }
}
