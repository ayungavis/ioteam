import DesignSystem
import Domain
import SwiftUI

struct ScheduleUIDose: Identifiable { let id = UUID(); let time: String; let medicineName: String; let deviceName: String; let amount: Int; var status: Domain.DoseStatus }
struct DayItem: Identifiable { let id = UUID(); let date: Date; let dayString: String; let dateString: String }

struct ScheduleView: View {
    @State private var selectedDate = Date()
    @State private var weekDays: [DayItem] = []
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
                                        dose: Binding(get: { dose }, set: { newDose in
                                            viewModel.toggleDose(dose)
                                        })
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 100)
                    }
                }
            }
        }
        .onAppear { generateWeek(); Task { await viewModel.loadDoses() } }
        .alert("Error", isPresented: Binding(get: { viewModel.alertMessage != nil }, set: { _ in viewModel.alertMessage = nil })) {
            Button("OK") {}
        } message: { Text(viewModel.alertMessage ?? "") }
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
    @Binding var dose: ScheduleUIDose
    var body: some View {
        HStack(spacing: 16) {
            Button(action: { dose.status = dose.status == .taken ? .pending : .taken }) {
                ZStack {
                    Circle().stroke(dose.status == .taken ? Color.brandSuccess : Color.brandBorder, lineWidth: 2).frame(width: 28, height: 28)
                    if dose.status == .taken { Circle().fill(Color.brandSuccess).frame(width: 28, height: 28)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
                }
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.time).font(.system(size: 16, weight: .semibold)).foregroundColor(dose.status == .taken ? Color.brandTextTertiary : .brandTextPrimary)
                Text(dose.medicineName).font(.system(size: 14)).foregroundColor(dose.status == .taken ? Color.brandTextTertiary : .brandTextPrimary)
                Text(dose.deviceName).font(.system(size: 12)).foregroundColor(Color.brandTextTertiary)
            }
            Spacer()
            Text("\(dose.amount) pill\(dose.amount == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .medium)).foregroundColor(dose.status == .taken ? Color.brandTextTertiary : Color.brandAccent)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(dose.status == .taken ? Color.brandDisabledFill : Color.brandAccent.opacity(0.12)).clipShape(Capsule())
                .overlay(Capsule().stroke(dose.status == .taken ? Color.brandBorder : Color.brandAccent.opacity(0.2), lineWidth: 0.5))
        }
        .padding(16).background(Color.brandCard).cornerRadius(16)
    }
}
