import Domain
import SwiftUI

public enum AppTab: Hashable { case home, medicine, schedule, profile }

public enum HomeNavigationDestination: Hashable {
    case deviceDetail(id: UUID)
    case medicineDetail(medicineID: String)
}

@Observable
public final class HomeTabRouter {
    public var selectedTab: AppTab = .home
    public var homePath = NavigationPath()
    public var medicinePath = NavigationPath()
    public var schedulePath = NavigationPath()
    public var profilePath = NavigationPath()
    public init() {}

    @MainActor func navigate(to destination: HomeNavigationDestination, in tab: AppTab) {
        switch tab {
        case .home: homePath.append(destination)
        case .medicine: medicinePath.append(destination)
        case .schedule: schedulePath.append(destination)
        case .profile: profilePath.append(destination)
        }
    }
}
