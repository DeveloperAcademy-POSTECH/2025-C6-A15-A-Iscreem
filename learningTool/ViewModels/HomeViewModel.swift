//
//  HomeViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedViewMode = ViewMode.grid
    
    enum ViewMode {
        case list
        case grid
        case compact
    }
    
    init() {}
    
    func addButtonTapped() {
        print("Add button tapped")
    }
    
    func viewModeButtonTapped(_ mode: ViewMode) {
        selectedViewMode = mode
    }
}
