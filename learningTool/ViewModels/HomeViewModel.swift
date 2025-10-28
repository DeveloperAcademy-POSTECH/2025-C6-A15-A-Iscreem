//
//  HomeViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {

    // ✅ HomeViewModel 안에 중첩 타입으로 선언
    enum ViewMode: String, CaseIterable, Equatable {
        case grid
        case list
    }

    @Published var searchText = ""
    @Published var selectedViewMode: ViewMode = .grid

    init() {}

    func addButtonTapped() {
        print("Add button tapped")
    }

    func viewModeButtonTapped(_ mode: ViewMode) {
        selectedViewMode = mode
    }
}
