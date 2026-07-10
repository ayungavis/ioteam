import Domain
import SwiftUI

struct ChangeDeviceWiFiView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChangeDeviceWiFiViewModel

    init(viewModel: ChangeDeviceWiFiViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("DoseLatch") {
                    if viewModel.discoveredDevices.isEmpty {
                        LabeledContent("Nearby Devices", value: viewModel.isScanning ? "Scanning" : "None Found")
                    } else {
                        ForEach(viewModel.discoveredDevices) { device in
                            Button {
                                viewModel.selectedDeviceID = device.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name)
                                        Text("\(device.rssi) dBm")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if viewModel.selectedDeviceID == device.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Wi-Fi") {
                    TextField("Network name", text: $viewModel.wifiSSID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $viewModel.wifiPassword)
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Change Wi-Fi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.stopScanning()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.selectedDeviceID == nil || viewModel.wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            viewModel.startScanning()
            await viewModel.loadCurrentSSID()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .alert("Wi-Fi Update Failed", isPresented: Binding(
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
