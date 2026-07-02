import Domain
import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddDeviceViewModel

    init(viewModel: AddDeviceViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nearby DoseLatch devices") {
                    if viewModel.visibleDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(scanStatusTitle)
                            Text(scanStatusDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(viewModel.visibleDevices, id: \.id) { device in
                            Button {
                                viewModel.selectDevice(device)
                            } label: {
                                NearbyDeviceRow(
                                    device: device,
                                    isSelected: viewModel.selectedDeviceID == device.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Device name") {
                    TextField("DoseLatch Bedroom", text: $viewModel.customName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button("Scan Again") {
                        viewModel.startScanning()
                    }

                    Button {
                        Task {
                            let success = await viewModel.pairSelectedDevice()
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isPairing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(viewModel.isPairing ? "Pairing..." : "Pair Device")
                        }
                    }
                    .disabled(!canPair)
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel.stopScanning()
                        dismiss()
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
    }

    private var canPair: Bool {
        viewModel.selectedDeviceID != nil
            && !viewModel.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isPairing
    }

    private var scanStatusTitle: String {
        switch viewModel.scanState {
        case .scanning:
            return "Scanning for nearby BLE devices..."
        case .poweredOff:
            return "Bluetooth is turned off on this iPhone."
        case .unauthorized:
            return "Bluetooth permission is not granted for DoseLatch."
        case .unsupported:
            return "This runtime does not support Bluetooth LE scanning."
        case .resetting:
            return "Bluetooth is resetting. Try again in a moment."
        case .unknown:
            return "Waiting for Bluetooth to become ready."
        case .noDevicesFound:
            return "No nearby DoseLatch device was found."
        case .idle:
            return "Tap Scan Again to search for a nearby ESP32."
        case .deviceFound:
            return viewModel.visibleDevices.isEmpty ? "Scanning for nearby BLE devices..." : "DoseLatch device ready to pair."
        }
    }

    private var scanStatusDetail: String {
        switch viewModel.scanState {
        case .unauthorized:
            return "Open Settings > Privacy & Security > Bluetooth and allow access for DoseLatch."
        case .poweredOff:
            return "Turn Bluetooth on in Control Center or Settings, then scan again."
        case .unsupported:
            return "Run the app on a physical iPhone. Simulator BLE discovery is not supported here."
        case .noDevicesFound:
            return "The firmware must be advertising as DoseLatch or DoseLatch Setup and stay powered nearby."
        default:
            return "Only devices advertising the DoseLatch BLE service are shown."
        }
    }
}

private struct NearbyDeviceRow: View {
    let device: DiscoveredDevice
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .foregroundStyle(.primary)
                Text("RSSI \(device.rssi.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}
