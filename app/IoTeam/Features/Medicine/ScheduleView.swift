import DesignSystem
import Domain
import SwiftUI

struct ScheduleUIDose: Identifiable {
    let id: String
    let medicineId: String
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

    /// Safeguard against accidental early checks: a dose can only be marked taken
    /// once its window has opened (due/missed/needs-confirmation are past by definition).
    var canMarkTakenNow: Bool {
        switch status {
        case .due, .missed, .needsConfirmation: return true
        case .pending: return windowStartAt <= Date()
        default: return false
        }
    }
}
struct DayItem: Identifiable { let id = UUID(); let date: Date; let dayString: String; let dateString: String }

/// Compact schedule embedded in the Home tab, below the devices grid.
/// The parent provides the scrolling container and horizontal padding.
struct ScheduleSection: View {
    @Environment(AppNotificationManager.self) private var notificationManager
    @State private var selectedDate = Date()
    @State private var weekDays: [DayItem] = []
    @State private var detailDose: ScheduleUIDose?
    @State private var earlyConfirmDose: ScheduleUIDose?
    @State private var todayScrollTrigger = 0
    @State private var viewModel: ScheduleViewModel

    init(viewModel: ScheduleViewModel) {
        _viewModel = State(initialValue: viewModel)
        // Built in init, not onAppear: mutating state during the first layout pass of a
        // nested ScrollView triggers AttributeGraph re-entrancy (EXC_BAD_ACCESS).
        _weekDays = State(initialValue: Self.makeWeek())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedule").font(.system(size: 18, weight: .semibold)).foregroundColor(.brandTextPrimary)
                    Text(selectedDateText).font(.system(size: 13)).foregroundColor(Color.brandTextSecondary)
                }
                Spacer()
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDate = Date() }
                        todayScrollTrigger += 1
                    } label: {
                        Text("Today")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.brandAccent)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.brandAccent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(weekDays) { day in
                            DayStripCell(
                                day: day,
                                isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate),
                                isToday: Calendar.current.isDateInToday(day.date)
                            )
                            .id(day.id)
                            .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDate = day.date } }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    // Deferred one tick: scrolling during the initial layout of a
                    // nested ScrollView crashes AttributeGraph.
                    Task { @MainActor in scrollToToday(proxy) }
                }
                .onChange(of: todayScrollTrigger) { _, _ in
                    withAnimation { scrollToToday(proxy) }
                }
            }

            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                let todayDoses = viewModel.dosesForDate(selectedDate)
                if todayDoses.isEmpty {
                    Text("No doses scheduled for this day.")
                        .font(.system(size: 14)).foregroundColor(.brandTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(todayDoses) { dose in
                            DoseTaskRow(
                                dose: dose,
                                onMarkTaken: {
                                    // Friction for early checks: not-yet-due doses confirm first.
                                    if dose.canMarkTakenNow {
                                        Task { await viewModel.markTaken(dose) }
                                    } else {
                                        earlyConfirmDose = dose
                                    }
                                },
                                onShowDetail: { detailDose = dose }
                            )
                        }
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
        .onAppear { consumeNotificationRoute(); Task { await viewModel.loadDoses() } }
        .onChange(of: notificationManager.pendingRoute) { _, newRoute in
            guard newRoute != nil else { return }
            consumeNotificationRoute()
        }
        .alert("Error", isPresented: Binding(get: { viewModel.alertMessage != nil }, set: { _ in viewModel.alertMessage = nil })) {
            Button("OK") {}
        } message: { Text(viewModel.alertMessage ?? "") }
        .alert(
            "Not due yet",
            isPresented: Binding(
                get: { earlyConfirmDose != nil },
                set: { if !$0 { earlyConfirmDose = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Mark Anyway") {
                if let dose = earlyConfirmDose {
                    Task { await viewModel.markTaken(dose) }
                }
            }
        } message: {
            if let dose = earlyConfirmDose {
                Text("\(dose.medicineName) isn't scheduled until \(dose.scheduledAt.formatted(date: .abbreviated, time: .shortened)). Mark it as taken now anyway?")
            }
        }
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

    /// Routes a tapped push notification to the right experience for its kind:
    /// due → one-tap confirm dialog here; missed → the medicine's Missed history tab;
    /// needs_confirmation → the dose sheet with "Yes, I took it".
    private func consumeNotificationRoute() {
        guard let route = notificationManager.takePendingDoseRoute() else { return }
        Task { @MainActor in
            await viewModel.loadDoses()
            handleNotificationRoute(route)
        }
    }

    @MainActor
    private func handleNotificationRoute(_ route: PendingNotificationRoute) {
        guard let dose = viewModel.doses.first(where: { $0.id == route.doseId }) else {
            // Dose outside the ±7-day window or fetch failed — Home with the fresh
            // schedule is still a sensible landing spot.
            return
        }
        switch route.kind {
        case "missed":
            let router = HomeTabRouter.shared
            router.selectedTab = .medicine
            router.medicinePath = NavigationPath()
            router.navigate(
                to: .medicineDetail(medicineID: dose.medicineId, doseFilter: DoseFilter.missed.rawValue),
                in: .medicine
            )
        case "needs_confirmation":
            detailDose = dose
        default: // "due" reminder
            viewModel.requestConfirmation(forDoseId: route.doseId)
        }
    }

    /// Header subtitle follows the selected day (locale-aware), with a "Today" prefix when applicable.
    private var selectedDateText: String {
        let formatted = selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return Calendar.current.isDateInToday(selectedDate)
            ? String(localized: "Today · \(formatted)")
            : formatted
    }

    private func scrollToToday(_ proxy: ScrollViewProxy) {
        if let today = weekDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            proxy.scrollTo(today.id, anchor: .center)
        }
    }
    // 7 days back through 7 days forward; the strip auto-scrolls to today.
    private static func makeWeek() -> [DayItem] {
        let cal = Calendar.current; let today = Date(); var days: [DayItem] = []
        for offset in -7...7 {
            if let date = cal.date(byAdding: .day, value: offset, to: today) {
                let formatter = DateFormatter(); formatter.dateFormat = "EEE"; let ds = formatter.string(from: date).prefix(1).description
                formatter.dateFormat = "d"; let dn = formatter.string(from: date)
                days.append(DayItem(date: date, dayString: ds, dateString: dn))
            }
        }
        return days
    }
}

struct DayStripCell: View {
    let day: DayItem; let isSelected: Bool
    var isToday = false
    var body: some View {
        VStack(spacing: 6) {
            Text(day.dayString).font(.system(size: 14, weight: .medium)).foregroundColor(isSelected ? .white : Color.brandTextSecondary)
            Text(day.dateString).font(.system(size: 18, weight: .bold)).foregroundColor(isSelected ? .white : .brandTextPrimary)
            Circle()
                .fill(isToday ? (isSelected ? Color.white : Color.brandAccent) : Color.clear)
                .frame(width: 5, height: 5)
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
    private var isNotYetDue: Bool { dose.status == .pending && !dose.canMarkTakenNow }
    private var circleColor: Color {
        switch dose.status {
        case .taken: return .brandSuccess
        case .missed: return .red
        case .needsConfirmation: return .brandAccentStrong
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
                    if dose.status == .needsConfirmation {
                        Image(systemName: "questionmark").font(.system(size: 12, weight: .bold)).foregroundColor(.brandAccentStrong)
                    }
                }
                .opacity(isNotYetDue ? 0.4 : 1)
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

    private var isActionable: Bool { dose.canMarkTakenNow }
    private var isLate: Bool { dose.status == .missed }
    private var isConfirmation: Bool { dose.status == .needsConfirmation }
    private var isNotYetDue: Bool { dose.status == .pending && !dose.canMarkTakenNow }

    private var actionTitle: LocalizedStringResource {
        if isLate { return "Take Late" }
        if isConfirmation { return "Yes, I took it" }
        return "Mark as Taken"
    }

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
                    DoseDetailRow(label: "Recorded by", value: source == "device_event" ? String(localized: "Pill box") : String(localized: "Manually in app"))
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
                if isConfirmation {
                    Text("The pill box was opened, but this dose wasn't confirmed.")
                        .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                }
                PrimaryButton(actionTitle, icon: .checkmark, tint: .success) { onMarkTaken() }
            } else if isNotYetDue {
                Text("This dose isn't due until \(dose.scheduledAt.formatted(date: .abbreviated, time: .shortened)). You can still mark it if you're taking it early.")
                    .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                PrimaryButton("Mark as Taken Anyway", icon: .checkmark) { onMarkTaken() }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurface)
    }
}

private struct DoseDetailRow: View {
    let label: LocalizedStringKey
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
