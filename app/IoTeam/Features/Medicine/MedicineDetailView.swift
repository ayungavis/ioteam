import DesignSystem
import Domain
import SwiftUI

struct MedicineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.previewDosesUseCase) private var previewDosesUseCase
    @Environment(\.createMedicineUseCase) private var createMedicineUseCase
    @Environment(\.getMedicineDosesUseCase) private var getMedicineDosesUseCase
    @Environment(\.listFamilyDevicesUseCase) private var listFamilyDevicesUseCase
    @Environment(\.registerDeviceUseCase) private var registerDeviceUseCase
    @Environment(\.getMedicineDetailUseCase) private var getMedicineDetailUseCase
    @Environment(\.updateMedicineUseCase) private var updateMedicineUseCase
    @Environment(\.deleteMedicineUseCase) private var deleteMedicineUseCase
    @Environment(\.reschedulePreviewUseCase) private var reschedulePreviewUseCase
    @Environment(\.rescheduleMedicineUseCase) private var rescheduleMedicineUseCase
    @Environment(\.markDoseTakenUseCase) private var markDoseTakenUseCase
    @State private var viewModel: MedicineDetailViewModel
    @State private var isDeleteAlertPresented = false
    @State private var dosePreviewViewModel: DosePreviewViewModel?
    @State private var historyDose: DoseItem?
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
                    EditMedicineDetail(
                        viewModel: viewModel,
                        onSave: { Task { _ = await viewModel.saveChanges() } },
                        onReviewReschedule: {
                            Task {
                                guard let result = await viewModel.previewReschedule() else { return }
                                dosePreviewViewModel = DosePreviewViewModel(doses: result.doses, summary: result.summary, medicineName: viewModel.medicineName, totalQuantity: viewModel.remainingQuantity, scheduleInput: viewModel.buildScheduleInput(), onConfirm: { Task { _ = await viewModel.applyReschedule() } })
                            }
                        },
                        onDelete: { isDeleteAlertPresented = true },
                        onSelectDose: { historyDose = $0 }
                    )
                }
            }
        }
        .onAppear {
            viewModel.configure(
                useCases: MedicineDetailUseCases(
                    previewDoses: previewDosesUseCase,
                    createMedicine: createMedicineUseCase,
                    getDoses: getMedicineDosesUseCase,
                    listFamilyDevices: listFamilyDevicesUseCase,
                    registerDevice: registerDeviceUseCase,
                    getDetail: getMedicineDetailUseCase,
                    update: updateMedicineUseCase,
                    delete: deleteMedicineUseCase,
                    reschedulePreview: reschedulePreviewUseCase,
                    reschedule: rescheduleMedicineUseCase,
                    markDoseTaken: markDoseTakenUseCase
                ),
                appSessionStore: AppSessionStore.shared
            )
        }
        .onChange(of: viewModel.alertMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .sheet(item: $dosePreviewViewModel) { vm in NavigationStack { DosePreviewView(viewModel: vm) } }
        .sheet(item: $historyDose) { dose in
            DoseDetailSheet(dose: scheduleUIDose(from: dose), onMarkTaken: {
                Task { _ = await viewModel.markDoseTaken(doseId: dose.id) }
                historyDose = nil
            })
            .presentationDetents([.medium])
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { viewModel.alertMessage = nil }
        } message: { Text(viewModel.alertMessage ?? "") }
        .alert("Delete Medicine", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { if await viewModel.deleteMedicine() { dismiss() } }
            }
        } message: { Text("This will remove the medicine and stop tracking. This action cannot be undone.") }
    }

    /// Adapts a history DoseItem to the shared DoseDetailSheet model used by the Schedule tab.
    private func scheduleUIDose(from item: DoseItem) -> ScheduleUIDose {
        ScheduleUIDose(
            id: item.id,
            scheduledAt: item.scheduledAt,
            windowStartAt: item.windowStartAt,
            windowEndAt: item.windowEndAt,
            time: item.scheduledAt.formatted(date: .omitted, time: .shortened),
            medicineName: viewModel.medicineName,
            deviceName: viewModel.selectedDeviceName.isEmpty ? "—" : viewModel.selectedDeviceName,
            amount: item.doseAmount,
            status: DoseStatus(rawValue: item.status) ?? .pending,
            actualTakenAt: item.actualTakenAt,
            takenSource: item.takenSource
        )
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
                DevicePickerField(viewModel: viewModel)
            }

            // Quantity
            FormField(label: "Quantity") {
                QuantityInputField(value: $viewModel.quantity, range: 1...999, unit: "units")
            }

            ScheduleEditorFields(viewModel: viewModel)

            // Save Button
            PrimaryButton("Review Doses", isValid: viewModel.canSave, isLoading: viewModel.isGeneratingPreview, icon: .arrow) {
                onReviewDoses()
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

// MARK: - Shared schedule editor (Add + Edit)

private struct ScheduleEditorFields: View {
    @Bindable var viewModel: MedicineDetailViewModel

    var body: some View {
        Group {
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
        }
    }

    @ViewBuilder
    private var scheduleConfigView: some View {
        switch viewModel.frequency {
        case .daily:
            VStack(alignment: .leading, spacing: 8) {
                Text("Times of Day").font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                ForEach($viewModel.dailyTimes, id: \.self) { $time in
                    HStack {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .tint(Color.brandAccent)
                        if viewModel.dailyTimes.count > 1 {
                            Button {
                                if let idx = viewModel.dailyTimes.firstIndex(of: time) {
                                    viewModel.dailyTimes.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red).font(.system(size: 18))
                            }
                        }
                    }
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
    let onSave: () -> Void
    let onReviewReschedule: () -> Void
    let onDelete: () -> Void
    let onSelectDose: (DoseItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Medicine Detail")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.brandTextPrimary)
                .padding(.top, 24)

            if viewModel.isLoadingDetail {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
            } else {
                // Medicine Name
                FormField(label: "Medicine Name") {
                    TextField("Enter medicine name", text: $viewModel.medicineName)
                        .textInputAutocapitalization(.words)
                        .formFieldStyle()
                }

                // Linked Device
                FormField(label: "Linked Device") {
                    DevicePickerField(viewModel: viewModel)
                }

                // Enabled / Disabled
                FormField(label: "Status") {
                    Toggle(isOn: Binding(
                        get: { viewModel.medicineStatus == .active },
                        set: { viewModel.medicineStatus = $0 ? .active : .disabled }
                    )) {
                        Text(viewModel.medicineStatus == .active ? String(localized: "Enabled") : String(localized: "Disabled"))
                            .font(.system(size: 16)).foregroundColor(.brandTextPrimary)
                    }
                    .tint(Color.brandSuccess)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.brandCard).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                }

                // Stock
                FormField(label: "Stock") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Remaining").font(.system(size: 14)).foregroundColor(.brandTextSecondary)
                            Spacer()
                            Text("\(viewModel.remainingQuantity) / \(viewModel.totalQuantity)")
                                .font(.system(size: 15, weight: .medium)).foregroundColor(.brandTextPrimary)
                        }
                        Divider()
                        HStack(spacing: 12) {
                            Text("Adjust by").font(.system(size: 14)).foregroundColor(.brandTextSecondary)
                            TextField("0", value: $viewModel.adjustQuantityDelta, format: .number)
                                .keyboardType(.numbersAndPunctuation)
                                .font(.system(size: 16))
                                .foregroundColor(viewModel.adjustQuantityDelta >= 0 ? .brandTextPrimary : .red)
                                .frame(maxWidth: 70)
                            Spacer()
                            Stepper("", value: $viewModel.adjustQuantityDelta, in: -viewModel.remainingQuantity...999).labelsHidden()
                        }
                        Text("Positive adds pills (refill), negative removes them.")
                            .font(.system(size: 12)).foregroundColor(.brandTextTertiary)
                    }
                    .padding(16).background(Color.brandCard).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                }

                PrimaryButton("Save Changes", isValid: viewModel.hasDetailChanges && viewModel.canSave, isLoading: viewModel.isSaving, icon: .checkmark) {
                    onSave()
                }

                // Schedule (applied separately via reschedule preview)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Change Schedule")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.brandTextPrimary)
                    Text("Replaces upcoming doses with a new plan. Past doses are kept.")
                        .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                }
                ScheduleEditorFields(viewModel: viewModel)
                PrimaryButton("Review New Schedule", isValid: true, isLoading: viewModel.isGeneratingPreview, icon: .arrow) {
                    onReviewReschedule()
                }
            }

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
                    // Fixed-height box with its own scrolling so a long dose history
                    // doesn't stretch the whole screen.
                    Group {
                        if viewModel.filteredDoses.isEmpty {
                            Text("No doses here yet.")
                                .font(.system(size: 14)).foregroundColor(.brandTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(viewModel.filteredDoses) { dose in
                                        DoseRow(dose: dose)
                                            .contentShape(Rectangle())
                                            .onTapGesture { onSelectDose(dose) }
                                    }
                                }
                                .padding(12)
                            }
                            .frame(height: 320)
                        }
                    }
                    .background(Color.brandSurface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandBorder, lineWidth: 1))
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

/// Menu-based picker over the family's registered devices (from GET /devices).
/// Shows an explanatory placeholder while the family has no device yet — in that
/// case medicine creation falls back to auto-registering one.
private struct DevicePickerField: View {
    @Bindable var viewModel: MedicineDetailViewModel

    var body: some View {
        if viewModel.availableDevices.isEmpty {
            Text("No device yet — one will be set up automatically.")
                .font(.system(size: 14))
                .foregroundColor(.brandTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .formFieldStyle()
        } else {
            Menu {
                ForEach(viewModel.availableDevices) { device in
                    Button {
                        viewModel.selectDevice(device)
                    } label: {
                        if device.id == viewModel.selectedDeviceId {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                HStack {
                    if let name = viewModel.selectedDeviceDisplayName {
                        Text(name).font(.system(size: 16)).foregroundColor(.brandTextPrimary)
                    } else {
                        Text("Select device").font(.system(size: 16)).foregroundColor(.brandTextTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13))
                        .foregroundColor(.brandTextTertiary)
                }
                .formFieldStyle()
            }
        }
    }
}

/// Number field with direct keyboard entry plus a stepper for small adjustments.
private struct QuantityInputField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .font(.system(size: 16))
                .foregroundColor(.brandTextPrimary)
                .frame(maxWidth: 80)
            Text(unit).font(.system(size: 14)).foregroundColor(.brandTextSecondary)
            Spacer()
            Stepper("", value: $value, in: range).labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.brandCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
        .onChange(of: value) { _, newValue in
            if newValue < range.lowerBound { value = range.lowerBound }
            if newValue > range.upperBound { value = range.upperBound }
        }
    }
}

private struct FormField<Content: View>: View {
    let label: LocalizedStringKey
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
    let title: LocalizedStringKey
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
        case "taken": return String(localized: "Taken"); case "missed": return String(localized: "Missed")
        case "due": return String(localized: "Due"); case "needs_confirmation": return String(localized: "Needs Confirmation")
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
