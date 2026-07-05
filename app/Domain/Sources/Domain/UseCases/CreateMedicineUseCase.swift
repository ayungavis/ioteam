import Foundation

public final class CreateMedicineUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(name: String, deviceId: String, quantity: Int, schedule: ScheduleInput) async throws -> CreateMedicineData {
        let request = CreateMedicineRequest(name: name, deviceId: deviceId, quantity: quantity, pillPerDose: 1, schedule: schedule)
        let endpoint = APIEndpoint(path: "medicines", method: .post, body: try DoseLatchEncoder.encode(request))
        let response: CreateMedicineResponse = try await client.request(endpoint)
        return response.data
    }
}
