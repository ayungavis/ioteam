import Domain
import SwiftUI

public enum AppTab: Hashable { case home, medicine, profile }

public enum HomeNavigationDestination: Hashable {
    case deviceDetail(id: UUID)
    case medicineDetail(medicineID: String)
}

@Observable
public final class HomeTabRouter {
    @MainActor public static let shared = HomeTabRouter()
    public var selectedTab: AppTab = .home
    public var homePath = NavigationPath()
    public var medicinePath = NavigationPath()
    public var profilePath = NavigationPath()
    private init() {}

    @MainActor func navigate(to destination: HomeNavigationDestination, in tab: AppTab) {
        switch tab {
        case .home: homePath.append(destination)
        case .medicine: medicinePath.append(destination)
        case .profile: profilePath.append(destination)
        }
    }
}
