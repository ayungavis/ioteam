import DesignSystem
import Domain
import SwiftUI

/// Home-screen section for doses that need the user's action right now:
/// `due` (window open, not yet taken) and `needs_confirmation` (box opened, unconfirmed —
/// only occurs once physical devices report events).
@Observable
@MainActor
final class DoseAttentionViewModel {
    struct AttentionDose: Identifiable, Equatable {
        let id: String
        let medicineName: String
        let time: String
        let amount: Int
        let status: String
        let scheduledAt: Date
    }

    var attentionDoses: [AttentionDose] = []
    var alertMessage: String?
    var isWorking = false

    // Local-only: POST /doses/{id}/mark-skipped is 501 Not implemented on the backend.
    // When the team implements it, replace this set with a real API call in dismiss().
    private var dismissedDoseIds: Set<String> = []

    private let getMedicinesUseCase: GetMedicinesUseCase
    private let getMedicineDosesUseCase: GetMedicineDosesUseCase
    private let markDoseTakenUseCase: MarkDoseTakenUseCase

    init(
        getMedicinesUseCase: GetMedicinesUseCase,
        getMedicineDosesUseCase: GetMedicineDosesUseCase,
        markDoseTakenUseCase: MarkDoseTakenUseCase
    ) {
        self.getMedicinesUseCase = getMedicinesUseCase
        self.getMedicineDosesUseCase = getMedicineDosesUseCase
        self.markDoseTakenUseCase = markDoseTakenUseCase
    }

    func load() async {
        do {
            let medicines = try await getMedicinesUseCase.execute()
            var found: [AttentionDose] = []
            for medicine in medicines {
                let items = try await getMedicineDosesUseCase.execute(
                    medicineId: medicine.id,
                    statuses: ["due", "needs_confirmation"]
                )
                for item in items where !dismissedDoseIds.contains(item.id) {
                    found.append(AttentionDose(
                        id: item.id,
                        medicineName: medicine.name,
                        time: Self.timeFormatter.string(from: item.scheduledAt),
                        amount: item.doseAmount,
                        status: item.status,
                        scheduledAt: item.scheduledAt
                    ))
                }
            }
            attentionDoses = found.sorted { $0.scheduledAt < $1.scheduledAt }
        } catch {
            // Home stays quiet if this fails; the Schedule tab surfaces load errors.
            attentionDoses = []
        }
    }

    /// Called after a dose is successfully marked taken here, so sibling views
    /// (e.g. the Home schedule list) can refresh and show the checkmark.
    @ObservationIgnored var onDoseTaken: (() async -> Void)?

    func markTaken(_ dose: AttentionDose) async {
        isWorking = true
        do {
            _ = try await markDoseTakenUseCase.execute(doseId: dose.id)
            attentionDoses.removeAll { $0.id == dose.id }
            await onDoseTaken?()
        } catch {
            alertMessage = error.localizedDescription
        }
        isWorking = false
    }

    /// Postpones a `due` card for this app session — the dose keeps its real status on the
    /// backend and becomes `missed` when its window expires, so nothing is lost.
    /// `needs_confirmation` cards cannot be postponed: the backend never resolves them on
    /// its own, so the card stays until the user confirms (a "No, I didn't" answer needs
    /// the backend's POST /doses/{id}/confirm, currently unimplemented).
    func dismiss(_ dose: AttentionDose) {
        guard dose.status != "needs_confirmation" else { return }
        dismissedDoseIds.insert(dose.id)
        attentionDoses.removeAll { $0.id == dose.id }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "hh:mm a"; return formatter
    }()
}

/// Renders the attention cards. Loading is triggered by the parent (HomeView) —
/// this view is only inserted when there is something to show, so it must not
/// own the load: a not-rendered view never fires `.task`.
struct DoseAttentionSection: View {
    let viewModel: DoseAttentionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Needs attention")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.brandTextPrimary)
            ForEach(viewModel.attentionDoses) { dose in
                AttentionDoseCard(
                    dose: dose,
                    isWorking: viewModel.isWorking,
                    onTake: { Task { await viewModel.markTaken(dose) } },
                    onDismiss: { withAnimation { viewModel.dismiss(dose) } }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("OK") {}
        } message: { Text(viewModel.alertMessage ?? "") }
    }
}

private struct AttentionDoseCard: View {
    let dose: DoseAttentionViewModel.AttentionDose
    let isWorking: Bool
    let onTake: () -> Void
    let onDismiss: () -> Void

    private var isConfirmation: Bool { dose.status == "needs_confirmation" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isConfirmation ? "questionmark.circle.fill" : "bell.badge.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isConfirmation ? .brandAccentStrong : .brandAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isConfirmation ? "Did you take \(dose.medicineName)?" : "Time to take \(dose.medicineName)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.brandTextPrimary)
                    Text("\(dose.time) · \(dose.amount) pill\(dose.amount == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundColor(.brandTextSecondary)
                    if isConfirmation {
                        Text("The pill box was opened, but this dose wasn't confirmed.")
                            .font(.system(size: 12))
                            .foregroundColor(.brandTextSecondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button(action: onTake) {
                    HStack(spacing: 6) {
                        if isWorking { ProgressView().controlSize(.small) }
                        Image(systemName: "checkmark")
                        Text(isConfirmation ? "Yes, I took it" : "Mark as Taken")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandSuccess)
                    .clipShape(Capsule())
                }
                .disabled(isWorking)
                if !isConfirmation {
                    Button(action: onDismiss) {
                        Text("Later")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandTextSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.brandSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.brandBorder, lineWidth: 1))
                    }
                }
            }
            if isConfirmation {
                Text("This stays here until you confirm.")
                    .font(.system(size: 11))
                    .foregroundColor(.brandTextTertiary)
            }
        }
        .padding(16)
        .background(Color.brandCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke((isConfirmation ? Color.brandAccentStrong : Color.brandAccent).opacity(0.35), lineWidth: 1)
        )
    }
}
