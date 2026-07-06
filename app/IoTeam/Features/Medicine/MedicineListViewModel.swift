import Domain
import SwiftUI

@Observable
final class MedicineListViewModel {
    var medicines: [MedicineItem] = []
    var alertMessage: String?
    var isLoading = false
    private let getMedicinesUseCase: GetMedicinesUseCase

    init(getMedicinesUseCase: GetMedicinesUseCase) {
        self.getMedicinesUseCase = getMedicinesUseCase
    }

    func loadMedicines() async {
        isLoading = true; alertMessage = nil
        do { medicines = try await getMedicinesUseCase.execute() }
        catch { alertMessage = error.localizedDescription }
        isLoading = false
    }
}
