@preconcurrency import CoreBluetooth
import Domain
import Foundation

struct BLEDeviceInfoPayload: Codable, Sendable, Equatable {
    let deviceId: UUID
    let firmwareVersion: String
    let paired: Bool
    let reedState: DeviceEventType
}

struct BLEPairCommandPayload: Codable, Sendable, Equatable {
    let pairingToken: String
    let familyId: String
    let wifiSSID: String
    let wifiPassword: String
    let backendMode: String
    let backendBaseURL: String?
}

struct BLEDeviceEventPayload: Codable, Sendable, Equatable {
    let deviceId: UUID
    let eventType: DeviceEventType
    let timestamp: Date
    let firmwareVersion: String

    private enum CodingKeys: String, CodingKey {
        case deviceId
        case eventType
        case timestamp
        case firmwareVersion
    }

    init(deviceId: UUID, eventType: DeviceEventType, timestamp: Date, firmwareVersion: String) {
        self.deviceId = deviceId
        self.eventType = eventType
        self.timestamp = timestamp
        self.firmwareVersion = firmwareVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(UUID.self, forKey: .deviceId)
        eventType = try container.decode(DeviceEventType.self, forKey: .eventType)
        firmwareVersion = try container.decode(String.self, forKey: .firmwareVersion)

        if let isoString = try? container.decode(String.self, forKey: .timestamp),
           let isoDate = ISO8601DateFormatter().date(from: isoString) {
            timestamp = isoDate
            return
        }

        if let millisString = try? container.decode(String.self, forKey: .timestamp),
           let milliseconds = Double(millisString) {
            timestamp = Date(timeIntervalSince1970: milliseconds / 1000)
            return
        }

        if let milliseconds = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: milliseconds / 1000)
            return
        }

        timestamp = Date()
    }
}

public enum BLEDeviceProvisioningError: LocalizedError {
    case bluetoothUnavailable
    case deviceNotFound
    case serviceMissing
    case characteristicMissing
    case invalidPayload
    case failedToConnect
    case pairingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return String(
                localized: "Bluetooth is not available on this device.",
                bundle: .module,
                comment: "Shown when the current device cannot use Bluetooth for provisioning."
            )
        case .deviceNotFound:
            return String(
                localized: "The selected DoseLatch device is no longer nearby.",
                bundle: .module,
                comment: "Shown when the selected BLE device disappears before pairing completes."
            )
        case .serviceMissing:
            return String(
                localized: "DoseLatch BLE service was not found on the device.",
                bundle: .module,
                comment: "Shown when the peripheral does not expose the expected provisioning service."
            )
        case .characteristicMissing:
            return String(
                localized: "DoseLatch BLE characteristic is missing.",
                bundle: .module,
                comment: "Shown when the peripheral is missing a required provisioning characteristic."
            )
        case .invalidPayload:
            return String(
                localized: "DoseLatch sent data in an unexpected format.",
                bundle: .module,
                comment: "Shown when the firmware returns malformed provisioning or event data."
            )
        case .failedToConnect:
            return String(
                localized: "Failed to connect to the DoseLatch device.",
                bundle: .module,
                comment: "Shown when CoreBluetooth fails to connect to the selected peripheral."
            )
        case .pairingFailed(let message):
            return message
        }
    }
}

private enum DoseLatchBLE {
    static let serviceUUID = CBUUID(string: "C0DE0001-71A5-4F0D-9E22-5B41E5A00001")
    static let deviceInfoUUID = CBUUID(string: "C0DE0001-71A5-4F0D-9E22-5B41E5A00002")
    static let pairCommandUUID = CBUUID(string: "C0DE0001-71A5-4F0D-9E22-5B41E5A00003")
    static let deviceEventUUID = CBUUID(string: "C0DE0001-71A5-4F0D-9E22-5B41E5A00004")
}

private struct PairingSession {
    let peripheralID: UUID
    let pairingToken: String
    let familyId: String
    let wifiSSID: String
    let wifiPassword: String
    let backendMode: String
    let backendBaseURL: String?
    let continuation: CheckedContinuation<BLEDeviceInfoPayload, Error>
}

public final class BLEDeviceProvisioningClient: NSObject, @unchecked Sendable, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onDiscoveredDevicesChanged: (([DiscoveredDevice]) -> Void)?
    var onDeviceEvent: ((UUID, BLEDeviceEventPayload) -> Void)?
    var onScanStateChanged: ((BLEScanState) -> Void)?

    private lazy var centralManager = CBCentralManager(
        delegate: self,
        queue: .main,
        options: [CBCentralManagerOptionShowPowerAlertKey: true]
    )
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var discoveredDevices: [DiscoveredDevice] = []
    private var stateWaiters: [CheckedContinuation<Void, Error>] = []
    private var characteristicMap: [UUID: [CBUUID: CBCharacteristic]] = [:]
    private var pairingSession: PairingSession?
    private var pendingInfoReads: [UUID: (Result<BLEDeviceInfoPayload, Error>) -> Void] = [:]
    private var shouldResumeScan = false
    private var scanTimeoutTask: Task<Void, Never>?
    private var autoStopScanTask: Task<Void, Never>?

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            shouldResumeScan = true
            publishScanState(for: centralManager.state)
            return
        }

        shouldResumeScan = false
        discoveredDevices = []
        discoveredPeripherals = [:]
        onDiscoveredDevicesChanged?(discoveredDevices)

        let serviceFilter = [DoseLatchBLE.serviceUUID]
        let serviceLabels = serviceFilter.map(\.uuidString)
        centralManager.scanForPeripherals(withServices: serviceFilter, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        onScanStateChanged?(.scanning)
        print("DoseLatch BLE scan started. services=\(serviceLabels)")
        scheduleScanTimeout()
    }

    func stopScanning() {
        shouldResumeScan = false
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        autoStopScanTask?.cancel()
        autoStopScanTask = nil
        centralManager.stopScan()
        onScanStateChanged?(.idle)
    }

    func pairDevice(
        id: UUID,
        pairingToken: String,
        familyId: String,
        wifiSSID: String,
        wifiPassword: String,
        backendMode: String,
        backendBaseURL: String?
    ) async throws -> BLEDeviceInfoPayload {
        try await waitUntilPoweredOn()

        guard let peripheral = discoveredPeripherals[id] else {
            throw BLEDeviceProvisioningError.deviceNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            pairingSession = PairingSession(
                peripheralID: id,
                pairingToken: pairingToken,
                familyId: familyId,
                wifiSSID: wifiSSID,
                wifiPassword: wifiPassword,
                backendMode: backendMode,
                backendBaseURL: backendBaseURL,
                continuation: continuation
            )
            centralManager.connect(peripheral)
        }
    }

    private func waitUntilPoweredOn() async throws {
        if centralManager.state == .poweredOn {
            return
        }

        if centralManager.state == .unsupported || centralManager.state == .unauthorized || centralManager.state == .poweredOff {
            throw BLEDeviceProvisioningError.bluetoothUnavailable
        }

        try await withCheckedThrowingContinuation { continuation in
            stateWaiters.append(continuation)
        }
    }

    private func finishPairing(with result: Result<BLEDeviceInfoPayload, Error>) {
        guard let session = pairingSession else {
            return
        }

        pairingSession = nil

        switch result {
        case .success(let payload):
            session.continuation.resume(returning: payload)
        case .failure(let error):
            session.continuation.resume(throwing: error)
        }
    }

    private func scheduleScanTimeout() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))

            guard !Task.isCancelled else {
                return
            }

            if discoveredDevices.isEmpty {
                centralManager.stopScan()
                onScanStateChanged?(.noDevicesFound)
            }
        }
    }

    private func scheduleAutoStopAfterDiscovery() {
        autoStopScanTask?.cancel()
        autoStopScanTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled else {
                return
            }

            centralManager.stopScan()
            onScanStateChanged?(.deviceFound)
        }
    }

    private func publishScanState(for state: CBManagerState) {
        switch state {
        case .poweredOn:
            onScanStateChanged?(.idle)
        case .poweredOff:
            onScanStateChanged?(.poweredOff)
        case .unauthorized:
            onScanStateChanged?(.unauthorized)
        case .unsupported:
            onScanStateChanged?(.unsupported)
        case .resetting:
            onScanStateChanged?(.resetting)
        case .unknown:
            onScanStateChanged?(.unknown)
        @unknown default:
            onScanStateChanged?(.unknown)
        }
    }

    private func readDeviceInfo(for peripheral: CBPeripheral, completion: @escaping (Result<BLEDeviceInfoPayload, Error>) -> Void) {
        guard let characteristic = characteristicMap[peripheral.identifier]?[DoseLatchBLE.deviceInfoUUID] else {
            completion(.failure(BLEDeviceProvisioningError.characteristicMissing))
            return
        }

        pendingInfoReads[peripheral.identifier] = completion
        peripheral.readValue(for: characteristic)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) throws -> T {
        guard let data else {
            throw BLEDeviceProvisioningError.invalidPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("DoseLatch central state changed: \(central.state.rawValue)")
        publishScanState(for: central.state)

        switch central.state {
        case .poweredOn:
            if shouldResumeScan {
                startScanning()
            }
            let waiters = stateWaiters
            stateWaiters.removeAll()
            waiters.forEach { $0.resume() }
        case .unsupported, .unauthorized, .poweredOff:
            let waiters = stateWaiters
            stateWaiters.removeAll()
            waiters.forEach { $0.resume(throwing: BLEDeviceProvisioningError.bluetoothUnavailable) }
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard hasExpectedService(in: advertisementData) else {
            return
        }

        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "DoseLatch"
        let device = DiscoveredDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        let advertisedServices = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map(\.uuidString)
            .joined(separator: ",")
            ?? "none"

        print(
            "DoseLatch discovered peripheral name=\(name) id=\(peripheral.identifier.uuidString) "
                + "services=\(advertisedServices) rssi=\(RSSI.intValue)"
        )

        discoveredPeripherals[peripheral.identifier] = peripheral

        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }

        discoveredDevices.sort { lhs, rhs in
            if lhs.rssi == rhs.rssi {
                return lhs.name < rhs.name
            }
            return lhs.rssi > rhs.rssi
        }

        onDiscoveredDevicesChanged?(discoveredDevices)
        onScanStateChanged?(.deviceFound)
        scanTimeoutTask?.cancel()
        scheduleAutoStopAfterDiscovery()
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([DoseLatchBLE.serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finishPairing(with: .failure(error ?? BLEDeviceProvisioningError.failedToConnect))
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("DoseLatch disconnected peripheral id=\(peripheral.identifier.uuidString)")
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finishPairing(with: .failure(error))
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == DoseLatchBLE.serviceUUID }) else {
            finishPairing(with: .failure(BLEDeviceProvisioningError.serviceMissing))
            return
        }

        peripheral.discoverCharacteristics(
            [DoseLatchBLE.deviceInfoUUID, DoseLatchBLE.pairCommandUUID, DoseLatchBLE.deviceEventUUID],
            for: service
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            finishPairing(with: .failure(error))
            return
        }

        let characteristics = Dictionary(uniqueKeysWithValues: (service.characteristics ?? []).map { ($0.uuid, $0) })
        characteristicMap[peripheral.identifier] = characteristics

        guard let pairCharacteristic = characteristics[DoseLatchBLE.pairCommandUUID],
              let eventCharacteristic = characteristics[DoseLatchBLE.deviceEventUUID]
        else {
            finishPairing(with: .failure(BLEDeviceProvisioningError.characteristicMissing))
            return
        }

        peripheral.setNotifyValue(true, for: eventCharacteristic)

        if let session = pairingSession, session.peripheralID == peripheral.identifier {
            do {
                let payload = try encode(
                    BLEPairCommandPayload(
                        pairingToken: session.pairingToken,
                        familyId: session.familyId,
                        wifiSSID: session.wifiSSID,
                        wifiPassword: session.wifiPassword,
                        backendMode: session.backendMode,
                        backendBaseURL: session.backendBaseURL
                    )
                )
                peripheral.writeValue(payload, for: pairCharacteristic, type: .withResponse)
            } catch {
                finishPairing(with: .failure(error))
            }
        } else {
            readDeviceInfo(for: peripheral) { _ in }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            finishPairing(with: .failure(error))
            return
        }

        guard characteristic.uuid == DoseLatchBLE.pairCommandUUID else {
            return
        }

        readDeviceInfo(for: peripheral) { [weak self] result in
            self?.finishPairing(with: result)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            if let completion = pendingInfoReads.removeValue(forKey: peripheral.identifier) {
                completion(.failure(error))
            }
            return
        }

        switch characteristic.uuid {
        case DoseLatchBLE.deviceInfoUUID:
            let result: Result<BLEDeviceInfoPayload, Error>
            do {
                result = .success(try decode(BLEDeviceInfoPayload.self, from: characteristic.value))
            } catch {
                result = .failure(error)
            }

            pendingInfoReads.removeValue(forKey: peripheral.identifier)?(result)

        case DoseLatchBLE.deviceEventUUID:
            do {
                let payload = try decode(BLEDeviceEventPayload.self, from: characteristic.value)
                onDeviceEvent?(peripheral.identifier, payload)
            } catch {
                break
            }

        default:
            break
        }
    }

    private func hasExpectedService(in advertisementData: [String: Any]) -> Bool {
        guard let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] else {
            return false
        }

        return serviceUUIDs.contains(DoseLatchBLE.serviceUUID)
    }
}
