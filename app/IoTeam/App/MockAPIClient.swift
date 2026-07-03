import Data
import Domain
import Foundation

#if DEBUG
    private actor MockDeviceBackend {
        static let shared = MockDeviceBackend()

        private var devices: [UUID: DeviceSummary] = [:]
        private let familyID = "mock-family-default"
        private var currentUser = AuthenticatedUser(
            id: UUID().uuidString,
            email: "mock.user@ioteam.app",
            fullName: "Mock User",
            dateOfBirth: nil,
            onboardingCompleted: false
        )

        func createPairingToken() -> PairingTokenResponse {
            PairingTokenResponse(
                pairingToken: "pair-\(UUID().uuidString.lowercased())",
                familyId: familyID
            )
        }

        func getCurrentUser() -> AuthenticatedUser {
            currentUser
        }

        func updateCurrentUser(fullName: String, dateOfBirth: String) -> AuthenticatedUser {
            currentUser = AuthenticatedUser(
                id: currentUser.id,
                email: currentUser.email,
                fullName: fullName,
                dateOfBirth: dateOfBirth,
                onboardingCompleted: currentUser.onboardingCompleted
            )
            return currentUser
        }

        func completeOnboarding() -> OnboardingCompletion {
            currentUser = AuthenticatedUser(
                id: currentUser.id,
                email: currentUser.email,
                fullName: currentUser.fullName,
                dateOfBirth: currentUser.dateOfBirth,
                onboardingCompleted: true
            )
            return OnboardingCompletion(id: currentUser.id, onboardingCompleted: true)
        }

        func createFamily(name: String) -> FamilySummary {
            FamilySummary(id: UUID().uuidString, name: name, inviteCode: "ABC123")
        }

        func joinFamily(inviteCode: String) -> FamilySummary {
            FamilySummary(id: UUID().uuidString, name: "Joined Family", inviteCode: inviteCode)
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
                throw NetworkError.badResponse(statusCode: 404, message: nil)
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
                throw NetworkError.badResponse(statusCode: 404, message: nil)
            }
            return removed
        }
    }

    public final class MockAPIClient: APIClientProtocol {
        public init() {}

        public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
            try await Task.sleep(for: .milliseconds(800))

            if let onboardingResponse: T = try await handleOnboardingRequest(endpoint: endpoint) {
                return onboardingResponse
            }

            if let notificationResponse: T = try await handleNotificationRequest(endpoint: endpoint) {
                return notificationResponse
            }

            if let deviceResponse: T = try await handleDeviceRequest(endpoint: endpoint) {
                return deviceResponse
            }

            throw NetworkError.invalidURL
        }

        private func parseJSONObject(from body: Data?) throws -> [String: Any] {
            guard let body,
                  let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            else {
                throw NetworkError.decodingFailed
            }
            return json
        }

        private func castResult<T: Decodable>(_ value: some Decodable) throws -> T {
            guard let result = value as? T else {
                throw NetworkError.decodingFailed
            }
            return result
        }

        private func handleOnboardingRequest<T: Decodable>(endpoint: APIEndpoint) async throws -> T? {
            switch (endpoint.path, endpoint.method) {
            case ("auth/apple", .post):
                let response = AuthSessionResponse(
                    success: true,
                    data: AuthSession(
                        accessToken: "mock-token-abc123",
                        user: await MockDeviceBackend.shared.getCurrentUser()
                    )
                )
                return try castResult(response)
            case ("me", .get):
                let response = UserProfileResponse(
                    success: true,
                    data: await MockDeviceBackend.shared.getCurrentUser()
                )
                return try castResult(response)
            case ("me", .patch):
                let payload = try parseJSONObject(from: endpoint.body)
                guard let fullName = payload["fullName"] as? String,
                      let dateOfBirth = payload["dateOfBirth"] as? String
                else {
                    throw NetworkError.decodingFailed
                }
                let response = UserProfileResponse(
                    success: true,
                    data: await MockDeviceBackend.shared.updateCurrentUser(
                        fullName: fullName,
                        dateOfBirth: dateOfBirth
                    )
                )
                return try castResult(response)
            case ("families", .post):
                let payload = try parseJSONObject(from: endpoint.body)
                guard let name = payload["name"] as? String else {
                    throw NetworkError.decodingFailed
                }
                let response = FamilySummaryResponse(
                    success: true,
                    data: await MockDeviceBackend.shared.createFamily(name: name)
                )
                return try castResult(response)
            case ("families/join", .post):
                let payload = try parseJSONObject(from: endpoint.body)
                guard let inviteCode = payload["inviteCode"] as? String else {
                    throw NetworkError.decodingFailed
                }
                let response = FamilySummaryResponse(
                    success: true,
                    data: await MockDeviceBackend.shared.joinFamily(inviteCode: inviteCode)
                )
                return try castResult(response)
            case ("onboarding/complete", .post):
                let response = OnboardingCompletionResponse(
                    success: true,
                    data: await MockDeviceBackend.shared.completeOnboarding()
                )
                return try castResult(response)
            default:
                return nil
            }
        }

        private func handleNotificationRequest<T: Decodable>(endpoint: APIEndpoint) async throws -> T? {
            guard endpoint.path == "notifications/tokens", endpoint.method == .post else {
                return nil
            }
            let response = PushTokenRegistrationResponse(
                success: true,
                data: PushTokenRegistration(id: UUID().uuidString)
            )
            return try castResult(response)
        }

        private func handleDeviceRequest<T: Decodable>(endpoint: APIEndpoint) async throws -> T? {
            switch (endpoint.path, endpoint.method) {
            case ("devices/pairing-token", .post):
                let response = await MockDeviceBackend.shared.createPairingToken()
                return try castResult(response)
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
                return try castResult(response)
            case ("devices", .get):
                let response = await MockDeviceBackend.shared.listDevices()
                return try castResult(response)
            default:
                if endpoint.path.hasPrefix("devices/") {
                    return try await handleDeviceMutation(endpoint: endpoint)
                }
                return nil
            }
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
