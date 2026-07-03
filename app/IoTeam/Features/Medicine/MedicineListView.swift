import DesignSystem
import Domain
import SwiftUI

struct MedicineListView: View {
    @Environment(HomeTabRouter.self) private var tabRouter
    @State private var viewModel: MedicineListViewModel
    @State private var isAddPresented = false

    init(viewModel: MedicineListViewModel = MedicineListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack {
                    Spacer()
                    HStack(spacing: 12) {
                        CircleIconButton(iconName: "plus") {
                            isAddPresented = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Headers
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Medicines")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(.brandTextPrimary)

                            Text("Medicines")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.brandTextPrimary)
                        }
                        .padding(.top, 12)

                        // MARK: - Content
                        if viewModel.medicines.isEmpty {
                            Button(action: {
                                isAddPresented = true
                            }) {
                                HStack {
                                    Text("Add medicine")
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
                            VStack(spacing: 16) {
                                ForEach(viewModel.medicines) { medicine in
                                    Button {
                                        tabRouter.navigate(to: .medicineDetail(medicine: medicine), in: .medicine)
                                    } label: {
                                        MedicineCard(medicine: medicine)
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
        .sheet(isPresented: $isAddPresented) {
            MedicineDetailView(mode: .add)
        }
    }
}

// MARK: - Medicine Card

struct MedicineCard: View {
    let medicine: Medicine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medicine.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.brandTextPrimary)
                    if let deviceName = medicine.linkedDeviceName {
                        HStack(spacing: 4) {
                            Image(systemName: "pills")
                                .font(.system(size: 12))
                            Text(deviceName)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.brandTextSecondary)
                    }
                }

                Spacer()

                StatusBadge(status: medicine.status)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining")
                        .font(.system(size: 12))
                        .foregroundColor(.brandTextSecondary)
                    Text("\(medicine.remainingQuantity) / \(medicine.totalQuantity)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.brandTextPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next dose")
                        .font(.system(size: 12))
                        .foregroundColor(.brandTextSecondary)
                    if let nextDose = medicine.nextDoseTime {
                        Text(nextDose, style: .relative)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(medicine.status == .active ? .brandAccent : .brandTextSecondary)
                    } else {
                        Text("—")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.brandTextSecondary)
                    }
                }
            }

            // Schedule info
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(medicine.scheduleTimesText)
                    .font(.system(size: 13))
            }
            .foregroundColor(.brandTextSecondary)
        }
        .padding(20)
        .background(Color.brandCard)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(medicine.status == .disabled ? Color.brandBorder : Color.clear, lineWidth: 1)
        )
        .opacity(medicine.status == .disabled ? 0.6 : 1.0)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: MedicineStatus

    var body: some View {
        Text(status == .active ? "Enabled" : "Disabled")
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        status == .active ? Color.brandSuccess : Color.brandTextSecondary
    }
}

// MARK: - Preview
#Preview("With medicines") {
    MedicineListView()
        .environment(HomeTabRouter())
}

#Preview("Empty") {
    let vm = MedicineListViewModel()
    vm.medicines = []
    return MedicineListView(viewModel: vm)
        .environment(HomeTabRouter())
}
