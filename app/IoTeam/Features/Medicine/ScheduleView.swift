import DesignSystem
import Domain
import SwiftUI

struct ScheduleUIDose: Identifiable {
    let id: String
    let scheduledAt: Date
    let windowStartAt: Date
    let windowEndAt: Date
    let time: String
    let medicineName: String
    let deviceName: String
    let amount: Int
    var status: Domain.DoseStatus
    var actualTakenAt: Date?
    let takenSource: String?

    var graceBeforeMinutes: Int { max(0, Int(scheduledAt.timeIntervalSince(windowStartAt) / 60)) }
    var graceAfterMinutes: Int { max(0, Int(windowEndAt.timeIntervalSince(scheduledAt) / 60)) }
}
struct DayItem: Identifiable { let id = UUID(); let date: Date; let dayString: String; let dateString: String }

struct ScheduleView: View {
    @Environment(AppNotificationManager.self) private var notificationManager
    @State private var selectedDate = Date()
    @State private var weekDays: [DayItem] = []
    @State private var detailDose: ScheduleUIDose?
    @State private var viewModel: ScheduleViewModel

    init(viewModel: ScheduleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule").font(.system(size: 32, weight: .regular)).foregroundColor(.brandTextPrimary)
                    Text(currentDateFormatted()).font(.system(size: 16)).foregroundColor(Color.brandTextSecondary)
                }.padding(.top, 16).padding(.horizontal, 24).padding(.bottom, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(weekDays) { day in
                            DayStripCell(day: day, isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate))
                                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDate = day.date } }
                        }
                    }.padding(.horizontal, 24)
                }.padding(.bottom, 24)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Doses").font(.system(size: 18, weight: .semibold)).foregroundColor(.brandTextPrimary).padding(.bottom, 4)
                            let todayDoses = viewModel.dosesForDate(selectedDate)
                            if todayDoses.isEmpty {
                                Text("No doses scheduled for this day.")
                                    .font(.system(size: 15)).foregroundColor(.brandTextSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 20)
                            } else {
                                ForEach(todayDoses) { dose in
                                    DoseTaskRow(
                                        dose: dose,
                                        onMarkTaken: { Task { await viewModel.markTaken(dose) } },
                                        onShowDetail: { detailDose = dose }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(item: $detailDose) { dose in
            DoseDetailSheet(dose: dose, onMarkTaken: {
                Task { await viewModel.markTaken(dose) }
                detailDose = nil
            })
            .presentationDetents([.medium])
        }
        .onAppear { generateWeek(); consumeNotificationRoute(); Task { await viewModel.loadDoses() } }
        .onChange(of: notificationManager.pendingRoute) { _, newRoute in
            guard newRoute != nil else { return }
            consumeNotificationRoute()
            Task { await viewModel.loadDoses() }
        }
        .alert("Error", isPresented: Binding(get: { viewModel.alertMessage != nil }, set: { _ in viewModel.alertMessage = nil })) {
            Button("OK") {}
        } message: { Text(viewModel.alertMessage ?? "") }
        .alert(
            "Time for your medication",
            isPresented: Binding(
                get: { viewModel.doseAwaitingConfirmation != nil },
                set: { if !$0 { viewModel.doseAwaitingConfirmation = nil } }
            )
        ) {
            Button("Not yet", role: .cancel) {}
            Button("Mark as Taken") {
                if let dose = viewModel.doseAwaitingConfirmation {
                    Task { await viewModel.markTaken(dose) }
                }
            }
        } message: {
            if let dose = viewModel.doseAwaitingConfirmation {
                Text("Mark \(dose.medicineName) (\(dose.amount) pill\(dose.amount == 1 ? "" : "s"), \(dose.time)) as taken?")
            }
        }
    }

    private func consumeNotificationRoute() {
        if let route = notificationManager.takePendingDoseRoute() {
            viewModel.requestConfirmation(forDoseId: route.doseId)
        }
    }

    private func currentDateFormatted() -> String { let formatter = DateFormatter(); formatter.dateFormat = "EEEE, MMMM d"; return formatter.string(from: Date()) }
    private func generateWeek() {
        let cal = Calendar.current; let today = Date(); var days: [DayItem] = []
        for offset in 0..<7 {
            if let date = cal.date(byAdding: .day, value: offset, to: today) {
                let formatter = DateFormatter(); formatter.dateFormat = "EEE"; let ds = formatter.string(from: date).prefix(1).description
                formatter.dateFormat = "d"; let dn = formatter.string(from: date)
                days.append(DayItem(date: date, dayString: ds, dateString: dn))
            }
        }
        weekDays = days
    }
}

struct DayStripCell: View {
    let day: DayItem; let isSelected: Bool
    var body: some View {
        VStack(spacing: 8) {
            Text(day.dayString).font(.system(size: 14, weight: .medium)).foregroundColor(isSelected ? .white : Color.brandTextSecondary)
            Text(day.dateString).font(.system(size: 18, weight: .bold)).foregroundColor(isSelected ? .white : .brandTextPrimary)
        }
        .frame(width: 54, height: 72).background(isSelected ? Color.brandAccent : Color.brandCard).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandBorder, lineWidth: isSelected ? 0 : 1))
    }
}

struct DoseTaskRow: View {
    let dose: ScheduleUIDose
    let onMarkTaken: () -> Void
    let onShowDetail: () -> Void
    private var isMissed: Bool { dose.status == .missed }
    private var circleColor: Color {
        switch dose.status {
        case .taken: return .brandSuccess
        case .missed: return .red
        default: return .brandBorder
        }
    }
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onMarkTaken) {
                ZStack {
                    Circle().stroke(circleColor, lineWidth: 2).frame(width: 28, height: 28)
                    if dose.status == .taken { Circle().fill(Color.brandSuccess).frame(width: 28, height: 28)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
                    if isMissed {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                    }
                }
            }.buttonStyle(.plain).disabled(dose.status == .taken || isMissed)
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.time).font(.system(size: 16, weight: .semibold)).foregroundColor(dose.status == .taken ? Color.brandTextTertiary : .brandTextPrimary)
                Text(dose.medicineName).font(.system(size: 14)).foregroundColor(dose.status == .taken ? Color.brandTextTertiary : .brandTextPrimary)
                Text(dose.deviceName).font(.system(size: 12)).foregroundColor(Color.brandTextTertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture { onShowDetail() }
            Spacer().contentShape(Rectangle()).onTapGesture { onShowDetail() }
            if isMissed {
                Text("Missed")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.red)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red.opacity(0.1)).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 0.5))
            } else {
                Text("\(dose.amount) pill\(dose.amount == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(dose.status == .taken ? Color.brandTextTertiary : Color.brandAccent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(dose.status == .taken ? Color.brandDisabledFill : Color.brandAccent.opacity(0.12)).clipShape(Capsule())
                    .overlay(Capsule().stroke(dose.status == .taken ? Color.brandBorder : Color.brandAccent.opacity(0.2), lineWidth: 0.5))
            }
        }
        .padding(16).background(Color.brandCard).cornerRadius(16)
    }
}

/// Detail sheet for a single dose — everything comes from the already-fetched dose record;
/// the window bounds are the medicine's grace period materialized per dose.
struct DoseDetailSheet: View {
    let dose: ScheduleUIDose
    let onMarkTaken: () -> Void

    private var isActionable: Bool { dose.status == .pending || dose.status == .due || dose.status == .missed }
    private var isLate: Bool { dose.status == .missed }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicineName)
                    .font(.system(size: 24, weight: .bold)).foregroundColor(.brandTextPrimary)
                Text(dose.deviceName)
                    .font(.system(size: 14)).foregroundColor(.brandTextSecondary)
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                DoseDetailRow(label: "Status", value: dose.status.displayName)
                DoseDetailRow(label: "Scheduled", value: dose.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                DoseDetailRow(label: "Amount", value: "\(dose.amount) pill\(dose.amount == 1 ? "" : "s")")
                DoseDetailRow(
                    label: "Window",
                    value: "\(dose.windowStartAt.formatted(date: .omitted, time: .shortened)) – \(dose.windowEndAt.formatted(date: .omitted, time: .shortened))"
                )
                DoseDetailRow(label: "Grace period", value: "\(dose.graceBeforeMinutes) min before · \(dose.graceAfterMinutes) min after")
                if let takenAt = dose.actualTakenAt {
                    DoseDetailRow(label: "Taken at", value: takenAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let source = dose.takenSource {
                    DoseDetailRow(label: "Recorded by", value: source == "device_event" ? "Pill box" : "Manually in app")
                }
            }
            .padding(16)
            .background(Color.brandCard)
            .cornerRadius(16)

            if isActionable {
                if isLate {
                    Text("This dose was missed. You can still record it — the actual time you took it will be saved.")
                        .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                }
                PrimaryButton(isLate ? "Take Late" : "Mark as Taken", icon: .checkmark, tint: .success) { onMarkTaken() }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurface)
    }
}

private struct DoseDetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(.brandTextSecondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(.brandTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
