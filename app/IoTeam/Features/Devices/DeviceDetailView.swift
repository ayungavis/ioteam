import Domain
import SwiftUI

struct DeviceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DeviceDetailViewModel

    init(viewModel: DeviceDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let device = viewModel.device {
                Form {
                    Section("Summary") {
                        LabeledContent("Connection", value: connectionLabel(device.connectionState))
                        LabeledContent("Status", value: device.status == .active ? "Enabled" : "Disabled")
                        LabeledContent("Firmware", value: device.firmwareVersion)
                        if let lastEventType = device.lastEventType {
                            LabeledContent("Last Event", value: lastEventType == .open ? "Open" : "Close")
                        }
                        if let lastSeenAt = device.lastSeenAt {
                            LabeledContent("Last Seen", value: lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }

                    Section("Rename Device") {
                        TextField("Device name", text: $viewModel.draftName)
                            .textInputAutocapitalization(.words)
                        Button("Save Name") {
                            Task {
                                await viewModel.saveName()
                            }
                        }
                        .disabled(viewModel.draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.draftName == device.name)
                    }

                    Section("Controls") {
                        Toggle(
                            "Enabled",
                            isOn: Binding(
                                get: { device.status == .active },
                                set: { isEnabled in
                                    Task {
                                        await viewModel.setEnabled(isEnabled)
                                    }
                                }
                            )
                        )

                        Button("Delete Device", role: .destructive) {
                            Task {
                                if await viewModel.deleteDevice() {
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .navigationTitle(device.name)
                .navigationBarTitleDisplayMode(.inline)
            } else if viewModel.hasReceivedFirstSnapshot {
                ContentUnavailableView("Device not found", systemImage: "exclamationmark.triangle")
            } else {
                ContentUnavailableView {
                    ProgressView()
                } description: {
                    Text("Loading device details...")
                }
            }
        }
        .task {
            viewModel.startObserving()
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

    private func connectionLabel(_ state: DeviceConnectionState) -> String {
        switch state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .paired:
            return "Paired"
        case .scanning:
            return "Scanning"
        case .setupFailed:
            return "Setup Failed"
        case .disconnected:
            return "Disconnected"
        }
    }
}
