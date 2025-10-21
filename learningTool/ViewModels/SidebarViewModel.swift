//
//  SidebarViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

enum SortOption: String, CaseIterable {
    case nameAscending = "가나다 순(↑)"
    case nameDescending = "가나다 순(↓)"
    case dateAscending = "생성 날짜순 (↑)"
    case dateDescending = "생성 날짜순 (↓)"
}

class SidebarViewModel: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var selectedItem: String?
    @Published var currentSortOption: SortOption = .dateAscending
    
    init() {
        loadFolders()
    }
    
    func addFolderTapped() {
        print("Add folder tapped")
    }
    
    func deleteFolderTapped() {
        print("Delete folder tapped")
    }
    
    func editFolderTapped() {
        print("Edit folder tapped")
    }
    
    func sortButtonTapped() {
        print("Sort button tapped")
    }
    
    func selectSortOption(_ option: SortOption) {
        currentSortOption = option
        sortFolders()
    }
    
    private func sortFolders() {
        switch currentSortOption {
        case .nameAscending:
            folders.sort { $0.name < $1.name }
        case .nameDescending:
            folders.sort { $0.name > $1.name }
        case .dateAscending:
            // 생성 날짜순 오름차순 (현재는 기본 순서 유지)
            break
        case .dateDescending:
            // 생성 날짜순 내림차순
            folders.reverse()
        }
    }
    
    func allViewTapped() {
        selectedItem = "all"
    }
    
    func folderTapped(_ folder: Folder) {
        selectedItem = folder.id.uuidString
    }
    
    func recentItemsTapped() {
        selectedItem = "recent"
    }
    
    func helpTapped() {
        print("Help tapped")
    }
    
    func settingsTapped() {
        print("Settings tapped")
    }
    
    func trashTapped() {
        print("Trash tapped")
    }
    
    private func loadFolders() {
        folders = [
            Folder(name: "정보처리기사"),
            Folder(name: "소프트웨어공학및설계"),
            Folder(name: "운영체제"),
        ]
    }
}