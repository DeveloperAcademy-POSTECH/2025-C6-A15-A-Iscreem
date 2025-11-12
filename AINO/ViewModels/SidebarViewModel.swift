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

// 현재 사이드바 선택 상태
enum SidebarSelection: Equatable {
    case all
    case recent
    case folder(PersistentIdentifier)
}

class SidebarViewModel: ObservableObject {
    // 기존 selectedItem을 대체하는 선택 상태
    @Published var selection: SidebarSelection = .all

    @Published var currentSortOption: SortOption = .dateAscending
    @Published var isHelpPresented: Bool = false
    
    init() { }

    // 선택 액션
    func allViewTapped() { selection = .all }
    func recentItemsTapped() { selection = .recent }
    func selectFolder(_ id: PersistentIdentifier) { selection = .folder(id) }

    // 정렬
    func selectSortOption(_ option: SortOption) { currentSortOption = option }

    // 기타 액션(현재 사용처 유지)
    func addFolderTapped() { }
    func deleteFolderTapped() { }
    func editFolderTapped() { }
    func sortButtonTapped() { }
    func helpTapped() { isHelpPresented = true }
    func settingsTapped() { NotificationCenter.default.post(name: .showSettings, object: nil) }
    func trashTapped() {
        NotificationCenter.default.post(name: .showTrash, object: nil)
    }

    // ✅ HomeView의 선택 상태를 사이드바 하이라이트와 동기화
    func syncFromHomeSelection(selectedFolderName: String?, folders: [Folder]) {
        // "__ALL__" → 전체 보기
        if selectedFolderName == "__ALL__" {
            if selection != .all { selection = .all }
            return
        }
        // nil → 최근 항목
        if selectedFolderName == nil {
            if selection != .recent { selection = .recent }
            return
        }
        // 특정 폴더 이름 → 해당 폴더 ID 선택
        if let name = selectedFolderName,
           let folder = folders.first(where: { $0.name == name }) {
            let id = folder.persistentModelID
            if case .folder(let current) = selection, current == id {
                return
            }
            selection = .folder(id)
        } else {
            // 폴더가 더 이상 없거나 이름이 매칭되지 않으면 안전하게 전체 보기로
            if selection != .all { selection = .all }
        }
    }
}
