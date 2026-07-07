import Data
import DesignSystem
import Domain
import SwiftUI

// MARK: - Enums for State Management
enum ConnectionPhase {
    case selectDevice
    case namingDevice
    case connecting
    case connected
}

// MARK: - Main View
struct ConnectDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddDeviceViewModel
    @State private var currentPhase: ConnectionPhase = .selectDevice
    private let onComplete: () -> Void

    init(viewModel: AddDeviceViewModel, onComplete: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Progress Indicator
                ProgressIndicatorView(
                    step1: "Select Device", state1: step1State,
                    step2: "Name Device", state2: step2State,
                    step3: "Connect", state3: step3State
                )
                .padding(.top, 32)
                .padding(.bottom, 40)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch currentPhase {
                        case .selectDevice:
                            SelectDevicePhase(
                                visibleDevices: viewModel.visibleDevices,
                                scanState: viewModel.scanState,
                                onSelect: { device in
                                    viewModel.selectDevice(device)
                                    withAnimation(.easeInOut) {
                                        currentPhase = .namingDevice
                                    }
                                }
                            )

                        case .namingDevice:
                            NamingDevicePhase(
                                deviceName: $viewModel.customName,
                                wifiSSID: $viewModel.wifiSSID,
                                wifiPassword: $viewModel.wifiPassword,
                                currentWiFiSSID: viewModel.currentWiFiSSID,
                                isDetectingWiFi: viewModel.isDetectingWiFi,
                                isPairing: viewModel.isPairing,
                                canAdd: canAdd,
                                onAdd: { Task { await runPairing() } }
                            )

                        case .connecting:
                            ConnectionStatusPhase(
                                title: viewModel.selectedDeviceName ?? "DoseLatch",
                                isConnected: false
                            )

                        case .connected:
                            ConnectionStatusPhase(
                                title: viewModel.customName.isEmpty ? "DoseLatch" : viewModel.customName,
                                isConnected: true
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .alert("Device Error", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.alertMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "Unknown error")
        }
    }

    // MARK: - Step States
    private var step1State: StepState {
        switch currentPhase {
        case .selectDevice: return .active
        default: return .completed
        }
    }

    private var step2State: StepState {
        switch currentPhase {
        case .selectDevice: return .upcoming
        case .namingDevice: return .active
        default: return .completed
        }
    }

    private var step3State: StepState {
        switch currentPhase {
        case .connecting: return .active
        case .connected: return .completed
        default: return .upcoming
        }
    }

    private var canAdd: Bool {
        !viewModel.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isPairing
    }

    // MARK: - Flow Logic
    @MainActor
    private func runPairing() async {
        withAnimation(.easeInOut) {
            currentPhase = .connecting
        }

        let success = await viewModel.pairSelectedDevice()

        if success {
            withAnimation(.easeInOut) {
                currentPhase = .connected
            }

            try? await Task.sleep(for: .seconds(1.2))
            onComplete()
            dismiss()
        } else {
            withAnimation(.easeInOut) {
                currentPhase = .namingDevice
            }
        }
    }
}

// MARK: - Phase Subviews

/// Step 1: Select Device List
struct SelectDevicePhase: View {
    let visibleDevices: [DiscoveredDevice]
    let scanState: BLEScanState
    let onSelect: (DiscoveredDevice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nearby Devices")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.brandTextPrimary)
                .padding(.bottom, 8)

            if visibleDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scanStatusTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.brandTextPrimary)
                    Text("Only devices advertising the DoseLatch BLE service are shown.")
                        .font(.system(size: 14))
                        .foregroundColor(.brandTextSecondary)
                }
            } else {
                ForEach(visibleDevices, id: \.id) { device in
                    DeviceListCard(
                        name: device.name,
                        signalText: signalLabel(for: device.rssi),
                        signalColor: signalColor(for: device.rssi),
                        onConnect: { onSelect(device) }
                    )
                }
            }

            Button(action: {
                print("Can't find device tapped")
            }) {
                Text("Can't find your device?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brandAccent)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 40)
        }
    }

    private var scanStatusTitle: String {
        switch scanState {
        case .scanning: return "Scanning for nearby BLE devices..."
        case .poweredOff: return "Bluetooth is turned off on this iPhone."
        case .unauthorized: return "Bluetooth permission is not granted for DoseLatch."
        case .unsupported: return "This runtime does not support Bluetooth LE scanning."
        case .resetting: return "Bluetooth is resetting. Try again in a moment."
        case .unknown: return "Waiting for Bluetooth to become ready."
        case .noDevicesFound: return "No nearby DoseLatch device was found."
        case .idle: return "Tap Scan Again to search for a nearby ESP32."
        case .deviceFound: return visibleDevices.isEmpty ? "Scanning for nearby BLE devices..." : "DoseLatch device ready to pair."
        }
    }

    private func signalLabel(for rssi: Int) -> String {
        rssi >= -60 ? "Signal Strong" : "Signal Weak"
    }

    private func signalColor(for rssi: Int) -> Color {
        rssi >= -60 ? Color.brandSuccess : Color.red
    }
}

/// Step 2: Naming the Device
struct NamingDevicePhase: View {
    @Binding var deviceName: String
    @Binding var wifiSSID: String
    @Binding var wifiPassword: String
    let currentWiFiSSID: String?
    let isDetectingWiFi: Bool
    let isPairing: Bool
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("medicine-box")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 120)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Name Device")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.brandTextPrimary)
                    Spacer()
                    Image(systemName: "pencil")
                        .foregroundColor(.brandTextPrimary)
                }
                .padding(.top, 16)

                TextField("DoseLatch - 001", text: $deviceName)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.brandCard)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Home Wi-Fi", text: $wifiSSID)
                        .font(.system(size: 16))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.brandCard)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )

                    SecureField("Wi-Fi Password", text: $wifiPassword)
                        .font(.system(size: 16))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.brandCard)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )

                    if isDetectingWiFi {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Detecting current Wi-Fi...")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                    } else if let currentWiFiSSID {
                        Text("Detected Wi-Fi: \(currentWiFiSSID)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brandTextSecondary)
                    } else {
                        Text("Current Wi-Fi is unavailable on this device.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                }

                Button(action: onAdd) {
                    HStack(spacing: 8) {
                        if isPairing {
                            ProgressView().tint(.white)
                        }
                        Text(isPairing ? "Connecting..." : "Add Device")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandSuccess)
                    .cornerRadius(8)
                }
                .disabled(!canAdd)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandCard)
        .cornerRadius(16)
    }
}

/// Step 3: Connecting & Connected states
struct ConnectionStatusPhase: View {
    let title: String
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image("medicine-box")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 120)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brandTextPrimary)

                if isConnected {
                    HStack {
                        Text("Connected")
                        Image(systemName: "checkmark")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandSuccess)
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Connecting")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandAccent)
                    .cornerRadius(8)
                }
            }
            .padding(.trailing, 16)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandCard)
        .cornerRadius(16)
    }
}

// MARK: - Reusable Components

struct DeviceListCard: View {
    let name: String
    let signalText: String
    let signalColor: Color
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image("medicine-box")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 120)

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brandTextPrimary)
                Text(signalText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(signalColor)
            }

            Spacer()

            Button(action: onConnect) {
                Text("Connect")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.brandAccent)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.brandCard)
        .cornerRadius(16)
    }
}

// MARK: - Preview
#Preview {
    ConnectDeviceView(
        viewModel: AddDeviceViewModel(
            startDeviceScanUseCase: StartDeviceScanUseCase(repository: PreviewRepo()),
            stopDeviceScanUseCase: StopDeviceScanUseCase(repository: PreviewRepo()),
            pairDeviceUseCase: PairDeviceUseCase(repository: PreviewRepo()),
            wiFiProvisioningService: PreviewWiFi()
        ),
        onComplete: {}
    )
}

private struct PreviewRepo: DeviceRepositoryProtocol {
    func getDevices() async throws -> [DeviceSummary] { [] }
    func observeDevices() -> AsyncStream<[DeviceSummary]> { AsyncStream { $0.finish() } }
    func startScanning() -> AsyncStream<DeviceScanSnapshot> { AsyncStream { $0.finish() } }
    func stopScanning() {}
    func pairDevice(discoveryID: UUID, provisioningInfo: DeviceProvisioningInfo) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }
    func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }
    func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }
    func deleteDevice(deviceID: UUID) async throws {
        throw BLEDeviceProvisioningError.deviceNotFound
    }
}

private struct PreviewWiFi: WiFiProvisioningServiceProtocol {
    func currentSSID() async -> String? { nil }
    func joinNetworkIfNeeded(ssid: String, passphrase: String) async throws {
        throw WiFiProvisioningError.unsupported
    }
}
