import CoreLocation
import Foundation
import NetworkExtension

protocol WiFiProvisioningServiceProtocol {
    func currentSSID() async -> String?
    func joinNetworkIfNeeded(ssid: String, passphrase: String) async throws
}

enum WiFiProvisioningError: LocalizedError {
    case missingSSID
    case unsupported
    case joinFailed(String)
    case joinTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .missingSSID:
            return String(
                localized: "Enter a Wi-Fi network name before pairing.",
                comment: "Shown when the user tries to pair without a Wi-Fi SSID."
            )
        case .unsupported:
            return String(
                localized: "This device cannot manage Wi-Fi configuration.",
                comment: "Shown when the current device cannot use the Wi-Fi join APIs."
            )
        case .joinFailed(let message):
            return message
        case .joinTimedOut(let ssid):
            return String(
                localized: "The iPhone did not finish joining \"\(ssid)\" in time.",
                comment: "Shown when Wi-Fi join does not complete before pairing continues."
            )
        }
    }
}

@MainActor
final class WiFiProvisioningService: NSObject, WiFiProvisioningServiceProtocol, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationAuthorizationContinuations: [CheckedContinuation<Bool, Never>] = []

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func currentSSID() async -> String? {
        guard await ensureLocationAccess() else {
            return nil
        }

        return await fetchCurrentSSID()
    }

    func joinNetworkIfNeeded(ssid: String, passphrase: String) async throws {
        let targetSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetSSID.isEmpty else {
            throw WiFiProvisioningError.missingSSID
        }

        if let currentSSID = await fetchCurrentSSID(), currentSSID == targetSSID {
            return
        }

        try await applyNetworkConfiguration(ssid: targetSSID, passphrase: passphrase)

        if await ensureLocationAccess() {
            try await waitForAssociation(with: targetSSID)
            return
        }

        try await Task.sleep(for: .seconds(2))
    }

    private func ensureLocationAccess() async -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined:
            return await requestWhenInUseAuthorization()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestWhenInUseAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            let shouldRequestAuthorization = locationAuthorizationContinuations.isEmpty
            locationAuthorizationContinuations.append(continuation)

            if shouldRequestAuthorization {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    private func fetchCurrentSSID() async -> String? {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network?.ssid)
            }
        }
    }

    private func applyNetworkConfiguration(ssid: String, passphrase: String) async throws {
        guard #available(iOS 11.0, *) else {
            throw WiFiProvisioningError.unsupported
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let configuration: NEHotspotConfiguration
            let trimmedPassphrase = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedPassphrase.isEmpty {
                configuration = NEHotspotConfiguration(ssid: ssid)
            } else {
                configuration = NEHotspotConfiguration(ssid: ssid, passphrase: trimmedPassphrase, isWEP: false)
            }

            configuration.joinOnce = true

            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == NEHotspotConfigurationErrorDomain,
                       nsError.code == 13 {
                        continuation.resume()
                        return
                    }

                    continuation.resume(throwing: Self.mapJoinError(error))
                    return
                }

                continuation.resume()
            }
        }
    }

    private func waitForAssociation(with targetSSID: String) async throws {
        let timeout = Date().addingTimeInterval(8)

        while Date() < timeout {
            if let currentSSID = await fetchCurrentSSID(), currentSSID == targetSSID {
                return
            }

            try await Task.sleep(for: .milliseconds(500))
        }

        throw WiFiProvisioningError.joinTimedOut(targetSSID)
    }

    private static func mapJoinError(_ error: Error) -> WiFiProvisioningError {
        let nsError = error as NSError

        guard nsError.domain == NEHotspotConfigurationErrorDomain else {
            return .joinFailed(nsError.localizedDescription)
        }

        switch nsError.code {
        case 7:
            return .joinFailed(
                String(
                    localized: "Wi-Fi join was denied by the user.",
                    comment: "Shown when the system hotspot prompt is denied."
                )
            )
        default:
            return .joinFailed(nsError.localizedDescription)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !locationAuthorizationContinuations.isEmpty else {
            return
        }

        let continuations = locationAuthorizationContinuations
        locationAuthorizationContinuations.removeAll()

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            continuations.forEach { $0.resume(returning: true) }
        case .denied, .restricted:
            continuations.forEach { $0.resume(returning: false) }
        case .notDetermined:
            locationAuthorizationContinuations = continuations + locationAuthorizationContinuations
        @unknown default:
            continuations.forEach { $0.resume(returning: false) }
        }
    }
}
