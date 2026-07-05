import DesignSystem
import Domain
import SwiftUI

struct MedicineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.previewDosesUseCase) private var previewDosesUseCase
    @Environment(\.createMedicineUseCase) private var createMedicineUseCase
    @Environment(\.getMedicineDosesUseCase) private var getMedicineDosesUseCase
    @State private var viewModel: MedicineDetailViewModel
    @State private var isDeleteAlertPresented = false
    @State private var dosePreviewViewModel: DosePreviewViewModel?
    @State private var showErrorAlert = false

    init(mode: MedicineDetailViewModel.Mode) {
        _viewModel = State(initialValue: MedicineDetailViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            ScrollView {
                switch viewModel.mode {
                case .add:
                    AddMedicineForm(viewModel: viewModel, onReviewDoses: {
                        Task {
                            guard let result = await viewModel.previewDoses() else {
                                if viewModel.alertMessage != nil { return }
                                return
                            }
                            dosePreviewViewModel = DosePreviewViewModel(doses: result.doses, summary: result.summary, medicineName: viewModel.medicineName, totalQuantity: viewModel.quantity, scheduleInput: viewModel.buildScheduleInput(), onConfirm: { Task { let ok = await viewModel.createMedicine(); if ok { dismiss() } } })
                        }
                    })
                case .edit:
                    EditMedicineDetail(viewModel: viewModel, onDelete: { dismiss() })
                }
            }
        }
        .onAppear {
            viewModel.configure(previewDosesUseCase: previewDosesUseCase, createMedicineUseCase: createMedicineUseCase, getMedicineDosesUseCase: getMedicineDosesUseCase, appSessionStore: AppSessionStore.shared)
        }
        .onChange(of: viewModel.alertMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .sheet(item: $dosePreviewViewModel) { vm in NavigationStack { DosePreviewView(viewModel: vm) } }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { viewModel.alertMessage = nil }
        } message: { Text(viewModel.alertMessage ?? "") }
        .alert("Delete Medicine", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}; Button("Delete", role: .destructive) { dismiss() }
        } message: { Text("This will remove the medicine and stop tracking. This action cannot be undone.") }
    }
}

// MARK: - Add Mode

private struct AddMedicineForm: View {
    @Bindable var viewModel: MedicineDetailViewModel
    let onReviewDoses: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Add Medicine")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.brandTextPrimary)
                .padding(.top, 24)

            // Medicine Name
            FormField(label: "Medicine Name") {
                TextField("Enter medicine name", text: $viewModel.medicineName)
                    .textInputAutocapitalization(.words)
                    .formFieldStyle()
            }

            // Linked Device
            FormField(label: "Linked Device") {
                TextField("Select device", text: $viewModel.selectedDeviceName)
                    .formFieldStyle()
            }

            // Quantity
            FormField(label: "Quantity") {
                Stepper(value: $viewModel.quantity, in: 1...999) {
                    Text("\(viewModel.quantity) units")
                        .font(.system(size: 16))
                        .foregroundColor(.brandTextPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.brandCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
            }

            // Schedule Type
            FormField(label: "Schedule Type") {
                Picker("Frequency", selection: $viewModel.frequency) {
                    ForEach(MedicineFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Schedule Configuration
            FormField(label: "Schedule") {
                scheduleConfigView
                    .padding(16)
                    .background(Color.brandCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
            }

            // Grace Period
            FormField(label: "Grace Period (minutes)") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                        Stepper(value: $viewModel.graceBeforeMinutes, in: 0...120, step: 5) {
                            Text("\(viewModel.graceBeforeMinutes) min")
                                .font(.system(size: 15))
                                .foregroundColor(.brandTextPrimary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("After").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                        Stepper(value: $viewModel.graceAfterMinutes, in: 0...240, step: 5) {
                            Text("\(viewModel.graceAfterMinutes) min")
                                .font(.system(size: 15))
                                .foregroundColor(.brandTextPrimary)
                        }
                    }
                }
                .padding(16)
                .background(Color.brandCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
            }

            // Start Date
            FormField(label: "Start Date") {
                DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(Color.brandAccent)
                    .padding(16)
                    .background(Color.brandCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
            }

            // Save Button
            PrimaryButton("Review Doses", isValid: viewModel.canSave, isLoading: viewModel.isGeneratingPreview, icon: .arrow) {
                onReviewDoses()
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private var scheduleConfigView: some View {
        switch viewModel.frequency {
        case .daily:
            VStack(alignment: .leading, spacing: 8) {
                Text("Times of Day").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                ForEach($viewModel.dailyTimes, id: \.self) { $time in
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .tint(Color.brandAccent)
                }
                Button {
                    viewModel.dailyTimes.append(Date())
                } label: {
                    Label("Add time", systemImage: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.brandAccent)
                }
            }
        case .weekly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekdays").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                FlexibleWeekdayPicker(selected: $viewModel.weeklyDays, days: days)
                Text("Times of Day").font(.system(size: 13)).foregroundColor(.brandTextSecondary).padding(.top, 8)
                ForEach($viewModel.weeklyTimes, id: \.self) { $time in
                    HStack {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .tint(Color.brandAccent)
                        if viewModel.weeklyTimes.count > 1 {
                            Button {
                                if let idx = viewModel.weeklyTimes.firstIndex(of: time) {
                                    viewModel.weeklyTimes.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                }
                Button {
                    viewModel.weeklyTimes.append(Date())
                } label: {
                    Label("Add time", systemImage: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.brandAccent)
                }
            }
        case .hourly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Interval").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                Stepper(value: $viewModel.hourlyInterval, in: 1...24) {
                    Text("Every \(viewModel.hourlyInterval) hour\(viewModel.hourlyInterval == 1 ? "" : "s")")
                        .font(.system(size: 15))
                        .foregroundColor(.brandTextPrimary)
                }
            }
        }
    }
}

// MARK: - Edit Mode

private struct EditMedicineDetail: View {
    @Bindable var viewModel: MedicineDetailViewModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Medicine Detail")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.brandTextPrimary)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Dose History")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.brandTextPrimary)

                if viewModel.isLoadingDoses {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                } else {
                    HStack(spacing: 8) {
                        ForEach(DoseFilter.allCases) { filter in
                            Button { viewModel.doseFilter = filter } label: {
                                Text(filter.displayName).font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(viewModel.doseFilter == filter ? Color.brandAccent : Color.brandCard)
                                    .foregroundColor(viewModel.doseFilter == filter ? .white : .brandTextSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    ForEach(viewModel.filteredDoses) { dose in DoseRow(dose: dose) }
                }
            }

            Button(role: .destructive) { onDelete() } label: {
                HStack { Image(systemName: "trash"); Text("Delete Medicine") }
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.red)
                    .frame(maxWidth: .infinity).frame(height: 50).background(Color.brandCard).cornerRadius(12)
            }.padding(.top, 8)
        }.padding(.horizontal, 24).padding(.bottom, 40)
    }
}

private struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.brandTextPrimary)
            content
        }
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.brandTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.brandTextPrimary)
        }
    }
}

private struct DoseRow: View {
    let dose: DoseItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.scheduledAt, style: .date).font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                Text(dose.scheduledAt, style: .time).font(.system(size: 15, weight: .medium)).foregroundColor(.brandTextPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                DoseStatusBadge(status: dose.status)
                if let takenAt = dose.actualTakenAt { Text("Taken \(takenAt.formatted(date: .omitted, time: .shortened))").font(.system(size: 12)).foregroundColor(.brandTextSecondary) }
            }
        }
        .padding(16).background(Color.brandCard).cornerRadius(12)
    }
}

private struct DoseStatusBadge: View {
    let status: String

    var displayName: String {
        switch status {
        case "taken": return "Taken"; case "missed": return "Missed"
        case "due": return "Due"; case "needs_confirmation": return "Needs Confirmation"
        default: return status.prefix(1).uppercased() + status.dropFirst()
        }
    }

    var body: some View {
        Text(displayName).font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.15))
            .foregroundColor(color).clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case "taken": return Color.brandSuccess; case "missed": return Color.red; case "due": return Color.brandAccent
        case "pending": return Color.brandTextSecondary; case "skipped": return Color.brandTextSecondary
        case "needs_confirmation": return Color.brandAccentStrong
        default: return Color.brandTextSecondary
        }
    }
}

private struct FlexibleWeekdayPicker: View {
    @Binding var selected: Set<String>
    let days: [String]

    var body: some View {
        FlexibleGrid(spacing: 8) {
            ForEach(days, id: \.self) { day in
                Button {
                    if selected.contains(day) {
                        selected.remove(day)
                    } else {
                        selected.insert(day)
                    }
                } label: {
                    Text(String(day.prefix(3)))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(selected.contains(day) ? Color.brandAccent : Color.brandCard)
                        .foregroundColor(selected.contains(day) ? .white : .brandTextSecondary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.brandBorder, lineWidth: selected.contains(day) ? 0 : 1))
                }
            }
        }
    }
}

private struct FlexibleGrid<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 44), spacing: spacing)]
        LazyVGrid(columns: columns, spacing: spacing) {
            content
        }
    }
}

// MARK: - TextField Style Extension

private extension View {
    func formFieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.brandCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
    }
}

// MARK: - Previews
#Preview("Add") {
    MedicineDetailView(mode: .add)
}

#Preview("Edit") {
    MedicineDetailView(mode: .edit(medicineID: "preview-id"))
}
