//
//  TaskListView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import SwiftUI

struct TaskListView: View {
    @State private var viewModel: TaskListViewModel
    @Environment(HomeTabRouter.self) private var tabRouter

    init(viewModel: TaskListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List(viewModel.tasks) { task in
            Button(action: { tabRouter.navigate(to: .taskDetail(id: task.id), in: .home) }) {
                HStack {
                    Text(task.title).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                }
            }
        }
        .navigationTitle("Tasks Workspace")
        .refreshable { await viewModel.loadData() }
        .task { await viewModel.loadData() }
    }
}
