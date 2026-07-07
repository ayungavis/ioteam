import DesignSystem
import Domain
import SwiftUI

struct ManageDevicesView: View {
    @State private var viewModel: ProfileDevicesViewModel
    init(viewModel: ProfileDevicesViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            Group {
                if viewModel.devices.isEmpty {
                    ContentUnavailableView("No devices connected", systemImage: "antenna.radiowaves.left.and.right")
                } else {
                    List(viewModel.devices) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.brandTextPrimary)
                                Text("Firmware: \(device.firmwareVersion)").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                            }
                            Spacer()
                            Text(device.status == .active ? "Enabled" : "Disabled")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background((device.status == .active ? Color.brandSuccess : Color.brandTextSecondary).opacity(0.15))
                                .foregroundColor(device.status == .active ? Color.brandSuccess : Color.brandTextSecondary)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Manage Devices")
        }
        .task { viewModel.startObserving() }
    }
}
