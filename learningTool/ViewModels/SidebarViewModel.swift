//
//  SidebarViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class SidebarViewModel: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var selectedItem: String?
    
    init() {
        loadFolders()
    }
    
    func sortButtonTapped() {
        print("Sort button tapped")
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