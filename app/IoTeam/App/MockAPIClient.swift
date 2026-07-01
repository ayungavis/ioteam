import Data
import Domain
import Foundation

#if DEBUG
    private actor MockDeviceBackend {
        static let shared = MockDeviceBackend()

        private var devices: [UUID: DeviceSummary] = [:]
        private let familyID = "mock-family-default"

        func createPairingToken() -> PairingTokenResponse {
            PairingTokenResponse(
                pairingToken: "pair-\(UUID().uuidString.lowercased())",
                familyId: familyID
            )
        }

        func registerDevice(
            deviceID: UUID,
            peripheralIdentifier: UUID,
            deviceName: String,
            firmwareVersion: String
        ) throws -> DeviceSummary {
            guard !devices.values.contains(where: { $0.name.caseInsensitiveCompare(deviceName) == .orderedSame }) else {
                throw BLEDeviceProvisioningError.pairingFailed("Device name must be unique in this mock family.")
            }

            let device = DeviceSummary(
                id: deviceID,
                peripheralIdentifier: peripheralIdentifier,
                firmwareVersion: firmwareVersion,
                name: deviceName,
                status: .active,
                connectionState: .connected,
                lastSeenAt: Date(),
                lastEventType: nil
            )

            devices[deviceID] = device
            return device
        }

        func listDevices() -> [DeviceSummary] {
            devices.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        func updateDevice(
            deviceID: UUID,
            name: String?,
            status: DeviceStatus?
        ) throws -> DeviceSummary {
            guard var device = devices[deviceID] else {
                throw NetworkError.badResponse(statusCode: 404)
            }

            if let name, name.caseInsensitiveCompare(device.name) != .orderedSame {
                guard !devices.values.contains(where: { $0.id != deviceID && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
                    throw BLEDeviceProvisioningError.pairingFailed("Device name must be unique in this mock family.")
                }
                device.name = name
            }

            if let status {
                device.status = status
            }

            devices[deviceID] = device
            return device
        }

        func deleteDevice(deviceID: UUID) throws -> DeviceSummary {
            guard let removed = devices.removeValue(forKey: deviceID) else {
                throw NetworkError.badResponse(statusCode: 404)
            }
            return removed
        }
    }

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
            case ("devices/pairing-token", .post):
                let response = await MockDeviceBackend.shared.createPairingToken()
                guard let result = response as? T else { throw NetworkError.decodingFailed }
                return result
            case ("devices/register", .post):
                let payload = try parseJSONObject(from: endpoint.body)
                guard let deviceID = UUID(uuidString: payload["device_id"] as? String ?? ""),
                      let peripheralIdentifier = UUID(uuidString: payload["peripheral_identifier"] as? String ?? ""),
                      let deviceName = payload["device_name"] as? String,
                      let firmwareVersion = payload["firmware_version"] as? String
                else {
                    throw NetworkError.decodingFailed
                }

                let response = try await MockDeviceBackend.shared.registerDevice(
                    deviceID: deviceID,
                    peripheralIdentifier: peripheralIdentifier,
                    deviceName: deviceName,
                    firmwareVersion: firmwareVersion
                )
                guard let result = response as? T else { throw NetworkError.decodingFailed }
                return result
            case ("devices", .get):
                let response = await MockDeviceBackend.shared.listDevices()
                guard let result = response as? T else { throw NetworkError.decodingFailed }
                return result
            default:
                if endpoint.path.hasPrefix("devices/") {
                    return try await handleDeviceMutation(endpoint: endpoint)
                }
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

        private func parseJSONObject(from body: Data?) throws -> [String: Any] {
            guard let body,
                  let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            else {
                throw NetworkError.decodingFailed
            }
            return json
        }

        private func handleDeviceMutation<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
            let components = endpoint.path.split(separator: "/")
            guard components.count == 2, let deviceID = UUID(uuidString: String(components[1])) else {
                throw NetworkError.invalidURL
            }

            switch endpoint.method {
            case .patch:
                let payload = try parseJSONObject(from: endpoint.body)
                let updated = try await MockDeviceBackend.shared.updateDevice(
                    deviceID: deviceID,
                    name: payload["name"] as? String,
                    status: (payload["status"] as? String).flatMap(DeviceStatus.init(rawValue:))
                )
                guard let result = updated as? T else { throw NetworkError.decodingFailed }
                return result
            case .delete:
                let deleted = try await MockDeviceBackend.shared.deleteDevice(deviceID: deviceID)
                guard let result = deleted as? T else { throw NetworkError.decodingFailed }
                return result
            default:
                throw NetworkError.invalidURL
            }
        }
    }
#endif
