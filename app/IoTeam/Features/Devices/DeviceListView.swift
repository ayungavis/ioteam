import Domain
import SwiftUI

struct DeviceListView: View {
    @Environment(HomeTabRouter.self) private var tabRouter
    @State private var viewModel: DeviceListViewModel
    private let makeAddDeviceView: () -> AddDeviceView
    @State private var isAddDevicePresented = false

    init(viewModel: DeviceListViewModel, makeAddDeviceView: @escaping () -> AddDeviceView) {
        _viewModel = State(initialValue: viewModel)
        self.makeAddDeviceView = makeAddDeviceView
    }

    var body: some View {
        Group {
            if viewModel.devices.isEmpty {
                ContentUnavailableView {
                    Label("No medicine box connected yet.", systemImage: "pills.circle")
                } description: {
                    Text("Pair a nearby DoseLatch device over Bluetooth to start tracking box activity.")
                } actions: {
                    Button("Add Device") {
                        isAddDevicePresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List(viewModel.devices) { device in
                    Button {
                        tabRouter.navigate(to: .deviceDetail(id: device.id), in: .home)
                    } label: {
                        DeviceRowView(device: device)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddDevicePresented = true
                } label: {
                    Label("Add Device", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddDevicePresented) {
            makeAddDeviceView()
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
        .task {
            await viewModel.loadData()
        }
    }
}

private struct DeviceRowView: View {
    let device: DeviceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(device.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(connectionLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(connectionColor.opacity(0.15))
                    .foregroundStyle(connectionColor)
                    .clipShape(Capsule())
            }

            HStack {
                Text(device.status == .active ? "Enabled" : "Disabled")
                Spacer()
                if let lastEventType = device.lastEventType {
                    Text(lastEventType == .open ? "Last event: Open" : "Last event: Close")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let lastSeenAt = device.lastSeenAt {
                Text("Last seen \(lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var connectionLabel: String {
        switch device.connectionState {
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

    private var connectionColor: Color {
        switch device.connectionState {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .orange
        case .paired:
            return .blue
        case .setupFailed:
            return .red
        case .disconnected:
            return .secondary
        }
    }
}
