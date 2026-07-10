import Data
import DesignSystem
import Domain
import SwiftUI

// MARK: - Main View
struct HomeView: View {
    @Environment(HomeTabRouter.self) private var tabRouter
    @Environment(AppNotificationManager.self) private var notificationManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: HomeViewModel
    private let doseAttentionViewModel: DoseAttentionViewModel?
    private let scheduleViewModel: ScheduleViewModel?
    private let makeConnectDeviceView: () -> ConnectDeviceView
    @State private var isAddDevicePresented = false

    init(
        viewModel: HomeViewModel,
        doseAttentionViewModel: DoseAttentionViewModel? = nil,
        scheduleViewModel: ScheduleViewModel? = nil,
        makeConnectDeviceView: @escaping () -> ConnectDeviceView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.doseAttentionViewModel = doseAttentionViewModel
        self.scheduleViewModel = scheduleViewModel
        self.makeConnectDeviceView = makeConnectDeviceView
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Title + Actions
                HStack(alignment: .center) {
                    Text("Home")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundColor(.brandTextPrimary)
                    Spacer()
                    CircleIconButton(iconName: "plus") {
                        isAddDevicePresented = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Doses needing action (due / needs confirmation)
                        if let doseAttentionViewModel, !doseAttentionViewModel.attentionDoses.isEmpty {
                            DoseAttentionSection(viewModel: doseAttentionViewModel)
                        }

                        Text("Devices")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.brandTextPrimary)
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

                        // MARK: - Schedule (week strip + doses for the selected day)
                        if let scheduleViewModel {
                            ScheduleSection(viewModel: scheduleViewModel)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.refreshDevices()
                    await doseAttentionViewModel?.load()
                    await scheduleViewModel?.loadDoses()
                }
            }
        }
        .sheet(isPresented: $isAddDevicePresented) {
            makeConnectDeviceView().keyboardDismissal()
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
            // Cross-refresh: confirming a dose in one section immediately updates the
            // other (attention card confirm → schedule shows the check, and vice versa).
            if let doseAttentionViewModel, let scheduleViewModel {
                doseAttentionViewModel.onDoseTaken = { [weak scheduleViewModel] in
                    await scheduleViewModel?.loadDoses()
                }
                scheduleViewModel.onDoseTaken = { [weak doseAttentionViewModel] in
                    await doseAttentionViewModel?.load()
                }
            }
            await doseAttentionViewModel?.load()
        }
        // Keep the attention cards honest while Home stays open: refresh when the app
        // returns to the foreground and when a push notification lands.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await doseAttentionViewModel?.load()
                await scheduleViewModel?.loadDoses()
            }
        }
        .onChange(of: notificationManager.pendingRoute) { _, route in
            guard route != nil else { return }
            Task { await doseAttentionViewModel?.load() }
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
    .environment(HomeTabRouter.shared)
    .environment(AppNotificationManager.shared)
}

#Preview("Devices + dose alerts") {
    HomeView(
        viewModel: HomeViewModel(
            observeDevicesUseCase: ObserveDevicesUseCase(repository: PreviewDeviceRepository()),
            setDeviceEnabledUseCase: SetDeviceEnabledUseCase(repository: PreviewDeviceRepository())
        ),
        doseAttentionViewModel: DoseAttentionViewModel(
            getMedicinesUseCase: GetMedicinesUseCase(client: HomePreviewAPI()),
            getMedicineDosesUseCase: GetMedicineDosesUseCase(client: HomePreviewAPI()),
            markDoseTakenUseCase: MarkDoseTakenUseCase(client: HomePreviewAPI())
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
    .environment(HomeTabRouter.shared)
    .environment(AppNotificationManager.shared)
}

/// Serves canned medicine/dose data so the "Needs attention" cards render in the canvas.
private final class HomePreviewAPI: APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        if endpoint.path == "medicines" {
            let medicines = [
                MedicineItem(id: "med-1", name: "Lisinopril", status: "active", totalQuantity: 30, remainingQuantity: 24, pillPerDose: 1,
                             device: MedicineDeviceSummary(id: "d1", name: "Kitchen Pill Box", status: "active"), nextDoseAt: Date().addingTimeInterval(600)),
                MedicineItem(id: "med-2", name: "Metformin", status: "active", totalQuantity: 60, remainingQuantity: 41, pillPerDose: 2,
                             device: MedicineDeviceSummary(id: "d2", name: "Grandma's box", status: "active"), nextDoseAt: Date().addingTimeInterval(3600))
            ]
            if let response = MedicineListResponse(success: true, data: medicines) as? T { return response }
        }
        if endpoint.path.hasSuffix("/doses") {
            let isFirst = endpoint.path.contains("med-1")
            let dose = DoseItem(
                id: isFirst ? "dose-1" : "dose-2",
                scheduleId: "s1",
                medicineId: isFirst ? "med-1" : "med-2",
                scheduledAt: Date().addingTimeInterval(isFirst ? -300 : -1200),
                windowStartAt: Date().addingTimeInterval(isFirst ? -1200 : -2100),
                windowEndAt: Date().addingTimeInterval(isFirst ? 1500 : 600),
                doseAmount: isFirst ? 1 : 2,
                status: isFirst ? "due" : "needs_confirmation",
                actualTakenAt: nil,
                takenSource: nil
            )
            if let response = DoseListResponse(success: true, data: [dose]) as? T { return response }
        }
        throw NetworkError.invalidURL
    }
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
    .environment(HomeTabRouter.shared)
    .environment(AppNotificationManager.shared)
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

    func reconfigureDeviceWiFi(
        deviceID: UUID,
        discoveryID: UUID,
        provisioningInfo: DeviceProvisioningInfo
    ) async throws -> DeviceSummary {
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
