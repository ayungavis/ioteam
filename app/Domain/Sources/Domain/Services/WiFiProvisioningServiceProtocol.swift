import Foundation

public protocol WiFiProvisioningServiceProtocol: Sendable {
    func currentSSID() async -> String?
    func joinNetworkIfNeeded(ssid: String, passphrase: String) async throws
}

public enum WiFiProvisioningError: LocalizedError, Sendable {
    case missingSSID
    case unsupported
    case joinFailed(String)
    case joinTimedOut(String)

    public var errorDescription: String? {
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
