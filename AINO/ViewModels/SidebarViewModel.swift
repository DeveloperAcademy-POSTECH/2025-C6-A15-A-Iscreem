//
//  SidebarViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine
import SwiftData

enum SortOption: String, CaseIterable {
    case nameAscending = "가나다 순(↑)"
    case nameDescending = "가나다 순(↓)"
    case dateAscending = "생성 날짜순 (↑)"
    case dateDescending = "생성 날짜순 (↓)"
}

class SidebarViewModel: ObservableObject {
    @Published var selectedItem: PersistentIdentifier?
    @Published var currentSortOption: SortOption = .dateAscending
    
    @Published var isHelpPresented: Bool = false
    
    init() {    }
    
    func addFolderTapped() { }
    func deleteFolderTapped() { }
    func editFolderTapped() { }
    func sortButtonTapped() { }
    func selectSortOption(_ option: SortOption) { currentSortOption = option }
    func allViewTapped() { selectedItem = nil }
    func recentItemsTapped() { selectedItem = nil }
    func helpTapped() { isHelpPresented = true }
    func settingsTapped() { NotificationCenter.default.post(name: .showSettings, object: nil) }
    func trashTapped() {
        NotificationCenter.default.post(name: .showTrash, object: nil)
    }
}

