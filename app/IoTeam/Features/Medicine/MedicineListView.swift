import DesignSystem
import Domain
import SwiftUI

struct MedicineListView: View {
    @Environment(HomeTabRouter.self) private var tabRouter
    @Environment(\.getMedicinesUseCase) private var getMedicinesUseCase
    @State private var viewModel = MedicineListViewModel(getMedicinesUseCase: GetMedicinesUseCase(client: PreviewAPI()))
    @State private var isAddPresented = false

    init(viewModel: MedicineListViewModel? = nil) {
        if let vm = viewModel { _viewModel = State(initialValue: vm) }
    }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            VStack(spacing: 0) {
                // MARK: - Title + Actions
                HStack(alignment: .center) {
                    Text("My Medicines")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundColor(.brandTextPrimary)
                    Spacer()
                    CircleIconButton(iconName: "plus") { isAddPresented = true }
                }
                .padding(.horizontal, 24).padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.isLoading { ProgressView().frame(maxWidth: .infinity).padding(.top, 40) }
                        else if viewModel.medicines.isEmpty {
                            Button { isAddPresented = true } label: {
                                HStack { Text("Add medicine").font(.system(size: 16, weight: .regular)).foregroundColor(.brandTextPrimary)
                                    Spacer(); Image(systemName: "plus").font(.system(size: 18, weight: .regular)).foregroundColor(.brandTextPrimary)
                                }.padding(.horizontal, 20).padding(.vertical, 24).background(Color.brandCard).cornerRadius(16)
                            }
                        } else {
                            VStack(spacing: 16) {
                                ForEach(viewModel.medicines) { item in
                                    Button { tabRouter.navigate(to: .medicineDetail(medicineID: item.id, doseFilter: nil), in: .medicine) } label: { MedicineCard(item: item) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 100)
                }
            }
        }
        .refreshable { await viewModel.loadMedicines() }
        .onAppear { viewModel = MedicineListViewModel(getMedicinesUseCase: getMedicinesUseCase); Task { await viewModel.loadMedicines() } }
        .onChange(of: isAddPresented) { _, newValue in
            if !newValue { Task { await viewModel.loadMedicines() } }
        }
        .sheet(isPresented: $isAddPresented) { MedicineDetailView(mode: .add) }
        .alert("Error", isPresented: Binding(get: { viewModel.alertMessage != nil }, set: { _ in viewModel.alertMessage = nil })) {
            Button("OK") {}
        } message: { Text(viewModel.alertMessage ?? "") }
    }
}

struct MedicineCard: View {
    let item: MedicineItem
    var status: MedicineStatus { MedicineStatus(rawValue: item.status) ?? .active }
    var nextDoseTime: Date? { item.nextDoseAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.system(size: 17, weight: .semibold)).foregroundColor(.brandTextPrimary)
                    if let deviceInfo = item.device { HStack(spacing: 4) { Image(systemName: "pills").font(.system(size: 12)); Text(deviceInfo.name).font(.system(size: 13)) }.foregroundColor(.brandTextSecondary) }
                }
                Spacer(); StatusBadge(status: status)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text("Remaining").font(.system(size: 12)).foregroundColor(.brandTextSecondary); Text("\(item.remainingQuantity) / \(item.totalQuantity)").font(.system(size: 15, weight: .medium)).foregroundColor(.brandTextPrimary) }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) { Text("Next dose").font(.system(size: 12)).foregroundColor(.brandTextSecondary)
                    if let nextDose = nextDoseTime { Text(nextDose, style: .relative).font(.system(size: 15, weight: .medium)).foregroundColor(status == .active ? .brandAccent : .brandTextSecondary) }
                    else { Text("—").font(.system(size: 15, weight: .medium)).foregroundColor(.brandTextSecondary) }
                }
            }
        }
        .padding(20).background(Color.brandCard).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(status == .disabled ? Color.brandBorder : Color.clear, lineWidth: 1))
        .opacity(status == .disabled ? 0.6 : 1.0)
    }
}

struct StatusBadge: View {
    let status: MedicineStatus
    var body: some View {
        Text(status == .active ? String(localized: "Enabled") : String(localized: "Disabled")).font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((status == .active ? Color.brandSuccess : Color.brandTextSecondary).opacity(0.15))
            .foregroundColor(status == .active ? Color.brandSuccess : Color.brandTextSecondary).clipShape(Capsule())
    }
}

#Preview("With medicines") {
    MedicineListView(viewModel: MedicineListViewModel(getMedicinesUseCase: GetMedicinesUseCase(client: PreviewAPI())))
        .environment(HomeTabRouter.shared)
}

#Preview("Empty") { MedicineListView(viewModel: MedicineListViewModel(getMedicinesUseCase: GetMedicinesUseCase(client: PreviewAPI()))).environment(HomeTabRouter.shared) }

final class PreviewAPI: APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T { throw NetworkError.invalidURL }
}
