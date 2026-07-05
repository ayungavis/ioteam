import DesignSystem
import Domain
import SwiftUI

struct DosePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DosePreviewViewModel
    init(viewModel: DosePreviewViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let summaryData = viewModel.summary {
                            SummaryCard(summary: summaryData, total: viewModel.totalQuantity, exceeds: viewModel.exceedsQuantity)
                        }
                        ForEach(viewModel.groupedDoses) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.brandTextPrimary)
                                ForEach(group.doses) { dose in
                                    DosePreviewRow(dose: dose)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 120)
                }
                VStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Text("Back to Edit").font(.system(size: 17, weight: .bold)).foregroundColor(.brandTextPrimary)
                            .frame(maxWidth: .infinity).frame(height: 54).background(Color.brandCard).clipShape(Capsule())
                    }
                    PrimaryButton("Confirm and Save", icon: .checkmark, tint: .success) {
                        viewModel.confirmAndSave(); dismiss()
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 30).background(Color.brandSurface)
            }
        }
        .navigationTitle("Review Doses").navigationBarTitleDisplayMode(.inline)
    }
}

private struct SummaryCard: View {
    let summary: DoseSummary; let total: Int; let exceeds: Bool
    var body: some View {
        VStack(spacing: 12) {
            HStack { Text("\(summary.totalDoses) doses").font(.system(size: 20, weight: .bold)).foregroundColor(.brandTextPrimary); Spacer() }
            SummaryRowView(title: "First dose", value: summary.firstDoseAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
            SummaryRowView(title: "Last dose", value: summary.lastDoseAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
            SummaryRowView(title: "Pills used", value: "\(summary.pillsUsed) of \(total)")
            if exceeds {
                HStack(spacing: 6) { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13))
                    Text("Adjust quantity — preview capped at \(summary.pillsUsed) pills").font(.system(size: 13)) }
                    .foregroundColor(.brandAccentStrong).padding(.top, 4)
            }
        }
        .padding(20).background(Color.brandCard).cornerRadius(16)
    }
}

private struct SummaryRowView: View {
    let title: String; let value: String
    var body: some View {
        HStack { Text(title).font(.system(size: 15)).foregroundColor(.brandTextSecondary); Spacer(); Text(value).font(.system(size: 15, weight: .medium)).foregroundColor(.brandTextPrimary) }
    }
}

private struct DosePreviewRow: View {
    let dose: GeneratedDose
    private var timeFormatter: DateFormatter { let formatter = DateFormatter(); formatter.dateStyle = .none; formatter.timeStyle = .short; return formatter }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: dose.scheduledAt)).font(.system(size: 16, weight: .semibold)).foregroundColor(.brandTextPrimary)
                Text("Window: \(timeFormatter.string(from: dose.windowStartAt)) – \(timeFormatter.string(from: dose.windowEndAt))").font(.system(size: 12)).foregroundColor(.brandTextSecondary)
            }
            Spacer()
            Text("\(dose.doseAmount) pill\(dose.doseAmount == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .medium)).foregroundColor(.brandAccent)
                .padding(.horizontal, 10).padding(.vertical, 5).background(Color.brandAccent.opacity(0.12)).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.brandAccent.opacity(0.2), lineWidth: 0.5))
        }
        .padding(16).background(Color.brandCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
    }
}
