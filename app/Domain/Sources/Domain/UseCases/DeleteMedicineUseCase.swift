import Foundation

public final class DeleteMedicineUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(medicineId: String) async throws -> DeleteMedicineData {
        let response: DeleteMedicineResponse = try await client.request(APIEndpoint(path: "medicines/\(medicineId)", method: .delete))
        return response.data
    }
}
