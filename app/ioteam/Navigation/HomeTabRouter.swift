//
//  HomeTabRouter.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import SwiftUI

public enum AppTab: Hashable { case home, profile }
public enum HomeNavigationDestination: Hashable {
    case deviceDetail(id: UUID)
}

@Observable
public final class HomeTabRouter {
    public var selectedTab: AppTab = .home
    public var homePath = NavigationPath()
    public var profilePath = NavigationPath()
    public init() {}

    @MainActor func navigate(to destination: HomeNavigationDestination, in tab: AppTab) {
        if tab == .home { homePath.append(destination) } else { profilePath.append(destination) }
    }
}
