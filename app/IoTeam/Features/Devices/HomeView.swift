import Data
import DesignSystem
import Domain
import SwiftUI

// MARK: - Main View
struct HomeView: View {
    @Environment(HomeTabRouter.self) private var tabRouter
    @State private var viewModel: HomeViewModel
    private let doseAttentionViewModel: DoseAttentionViewModel?
    private let makeConnectDeviceView: () -> ConnectDeviceView
    @State private var isAddDevicePresented = false

    init(
        viewModel: HomeViewModel,
        doseAttentionViewModel: DoseAttentionViewModel? = nil,
        makeConnectDeviceView: @escaping () -> ConnectDeviceView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.doseAttentionViewModel = doseAttentionViewModel
        self.makeConnectDeviceView = makeConnectDeviceView
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar (Add & Notifications)
                HStack {
                    Spacer()

                    HStack(spacing: 12) {
                        CircleIconButton(iconName: "plus") {
                            isAddDevicePresented = true
                        }

                        CircleIconButton(iconName: "bell") {
                            print("Notifications tapped")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Headers
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Home")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(.brandTextPrimary)

                            Text("Devices")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.brandTextPrimary)
                        }
                        .padding(.top, 12)

                        // MARK: - Doses needing action (due / needs confirmation)
                        if let doseAttentionViewModel {
                            DoseAttentionSection(viewModel: doseAttentionViewModel)
                        }

                        // MARK: - Device Content
                        if viewModel.devices.isEmpty {
                            // Empty State
                            Button(action: {
                                isAddDevicePresented = true
                            }) {
                                HStack {
                                    Text("Add device")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.brandTextPrimary)
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(.brandTextPrimary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .background(Color.brandCard)
                                .cornerRadius(16)
                            }
                        } else {
                            // Populated State (Grid)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                ForEach(viewModel.devices) { device in
                                    Button {
                                        tabRouter.navigate(to: .deviceDetail(id: device.id), in: .home)
                                    } label: {
                                        DeviceCard(
                                            device: device,
                                            onToggle: { Task { await viewModel.toggleEnabled(device) } }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $isAddDevicePresented) {
            makeConnectDeviceView()
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
            viewModel.startObserving()
        }
    }
}

// MARK: - Subcomponents

/// The individual card for a device
struct DeviceCard: View {
    let device: DeviceSummary
    let onToggle: () -> Void

    @State private var isOn: Bool

    init(device: DeviceSummary, onToggle: @escaping () -> Void) {
        self.device = device
        self.onToggle = onToggle
        _isOn = State(initialValue: device.status == .active)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(device.name)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.brandTextPrimary)
                .padding(.top, 16)
                .padding(.horizontal, 16)

            Spacer()

            HStack(alignment: .bottom) {
                CustomToggle(isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        isOn = newValue
                        onToggle()
                    }
                ))

                Spacer()

                Image("medicine-box")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 90)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 170)
        .background(Color.brandCard)
        .cornerRadius(20)
    }
}

// MARK: - Preview

private enum PreviewSamples {
    static let devices: [DeviceSummary] = [
        DeviceSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            peripheralIdentifier: UUID(),
            firmwareVersion: "1.0.0",
            name: "My medicine box",
            status: .active,
            connectionState: .connected,
            lastSeenAt: Date(),
            lastEventType: .open
        ),
        DeviceSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            peripheralIdentifier: UUID(),
            firmwareVersion: "1.0.0",
            name: "Grandma's box",
            status: .disabled,
            connectionState: .disconnected,
            lastSeenAt: Date().addingTimeInterval(-3600),
            lastEventType: .close
        )
    ]
}

#Preview("With devices") {
    HomeView(
        viewModel: HomeViewModel(
            observeDevicesUseCase: ObserveDevicesUseCase(repository: PreviewDeviceRepository()),
            setDeviceEnabledUseCase: SetDeviceEnabledUseCase(repository: PreviewDeviceRepository())
        ),
        makeConnectDeviceView: {
            ConnectDeviceView(
                viewModel: AddDeviceViewModel(
                    startDeviceScanUseCase: StartDeviceScanUseCase(repository: PreviewDeviceRepository()),
                    stopDeviceScanUseCase: StopDeviceScanUseCase(repository: PreviewDeviceRepository()),
                    pairDeviceUseCase: PairDeviceUseCase(repository: PreviewDeviceRepository()),
                    wiFiProvisioningService: PreviewWiFiProvisioningService()
                ),
                onComplete: {}
            )
        }
    )
    .environment(HomeTabRouter())
}

#Preview("Empty state") {
    HomeView(
        viewModel: HomeViewModel(
            observeDevicesUseCase: ObserveDevicesUseCase(repository: PreviewDeviceRepository(empty: true)),
            setDeviceEnabledUseCase: SetDeviceEnabledUseCase(repository: PreviewDeviceRepository(empty: true))
        ),
        makeConnectDeviceView: {
            ConnectDeviceView(
                viewModel: AddDeviceViewModel(
                    startDeviceScanUseCase: StartDeviceScanUseCase(repository: PreviewDeviceRepository(empty: true)),
                    stopDeviceScanUseCase: StopDeviceScanUseCase(repository: PreviewDeviceRepository(empty: true)),
                    pairDeviceUseCase: PairDeviceUseCase(repository: PreviewDeviceRepository(empty: true)),
                    wiFiProvisioningService: PreviewWiFiProvisioningService()
                ),
                onComplete: {}
            )
        }
    )
    .environment(HomeTabRouter())
}

private struct PreviewDeviceRepository: DeviceRepositoryProtocol {
    let empty: Bool

    init(empty: Bool = false) {
        self.empty = empty
    }

    func getDevices() async throws -> [DeviceSummary] {
        empty ? [] : PreviewSamples.devices
    }

    func observeDevices() -> AsyncStream<[DeviceSummary]> {
        AsyncStream { continuation in
            continuation.yield(empty ? [] : PreviewSamples.devices)
        }
    }

    func startScanning() -> AsyncStream<DeviceScanSnapshot> {
        AsyncStream { $0.finish() }
    }

    func stopScanning() {}

    func pairDevice(discoveryID: UUID, provisioningInfo: DeviceProvisioningInfo) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }

    func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }

    func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary {
        guard let device = PreviewSamples.devices.first(where: { $0.id == deviceID }) else {
            throw BLEDeviceProvisioningError.deviceNotFound
        }
        return DeviceSummary(
            id: device.id,
            peripheralIdentifier: device.peripheralIdentifier,
            firmwareVersion: device.firmwareVersion,
            name: device.name,
            status: isEnabled ? .active : .disabled,
            connectionState: device.connectionState,
            lastSeenAt: device.lastSeenAt,
            lastEventType: device.lastEventType
        )
    }

    func deleteDevice(deviceID: UUID) async throws {
        throw BLEDeviceProvisioningError.deviceNotFound
    }
}

private struct PreviewWiFiProvisioningService: WiFiProvisioningServiceProtocol {
    func currentSSID() async -> String? { nil }
    func joinNetworkIfNeeded(ssid: String, passphrase: String) async throws {
        throw WiFiProvisioningError.unsupported
    }
}
