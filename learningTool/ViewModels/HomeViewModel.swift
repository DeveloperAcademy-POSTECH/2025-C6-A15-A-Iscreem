//
//  HomeViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText = ""
    @Published var selectedViewMode = ViewMode.grid
    
    enum ViewMode {
        case list
        case grid
        case compact
    }
    
    init() {
        loadMockData()
    }
    
    func addButtonTapped() {
        print("Add button tapped")
    }
    
    func viewModeButtonTapped(_ mode: ViewMode) {
        selectedViewMode = mode
    }
    
    private func loadMockData() {
        notes = (0..<12).map { index in
            Note(
                title: "YouTube 제목",
                lastRead: Date()
                    .addingTimeInterval(-Double(index) * 3600)
            )
        }
    }
}