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

    // 마지막 사용 ViewMode를 저장하기 위한 UserDefaults 키
    private let viewModePersistenceKey = "HomeView.isListMode"

    @Published var searchText = ""
    @Published var selectedViewMode: ViewMode = .grid

    init() {
        // 저장된 값이 있으면 불러와서 selectedViewMode를 복원
        if UserDefaults.standard.object(forKey: viewModePersistenceKey) != nil {
            let wasListMode = UserDefaults.standard.bool(forKey: viewModePersistenceKey)
            selectedViewMode = wasListMode ? .list : .grid
        }
    }

    func addButtonTapped() {
        print("Add button tapped")
    }

    func viewModeButtonTapped(_ mode: ViewMode) {
        selectedViewMode = mode
        // 변경될 때마다 마지막 사용 모드로 저장
        UserDefaults.standard.set(mode == .list, forKey: viewModePersistenceKey)
    }
}
