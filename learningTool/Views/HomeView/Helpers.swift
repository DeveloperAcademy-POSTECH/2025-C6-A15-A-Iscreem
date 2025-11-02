//
//  Helpers.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import SwiftUI
import SwiftData

// MARK: - HomeView Helpers
extension HomeView {
    
    var searchQuery: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    var shouldShowEmptyState: Bool {
        if isAllView {
            let items = searchQuery.isEmpty ? allItems : allItemsFiltered
            return items.isEmpty
        } else {
            return filteredNotes.isEmpty
        }
    }
    
    var isFormValid: Bool {
        !youtubeLink.isEmpty && !noteTitle.isEmpty
    }
    
    var filteredNotes: [Note] {
        let base: [Note]
        if let selected = selectedFolderName, selected != "__ALL__" {
            base = notes.filter { $0.folder?.name == selected }
        } else {
            base = notes
        }
        
        let q = searchQuery
        let filtered = q.isEmpty ? base : base.filter { KoreanSearchUtils.matches($0.title, query: q) }
        
        return NoteFormattingUtils.sortNotes(filtered, by: headerSort)
    }
    
    var isAllView: Bool {
        selectedFolderName == "__ALL__"
    }
    
    enum HomeItem {
        case folder(Folder)
        case note(Note)
    }
    
    var allItems: [HomeItem] {
        let folderItems = folders.map { HomeItem.folder($0) }
        let unfiledNotes = notes.filter { $0.folder == nil }.map { HomeItem.note($0) }
        let combined = folderItems + unfiledNotes
        return combined.sorted { createdDate(for: $0) > createdDate(for: $1) }
    }
    
    var allItemsFiltered: [HomeItem] {
        let q = searchQuery
        guard !q.isEmpty else { return allItems }
        
        let matchedFolders = folders
            .filter { KoreanSearchUtils.matches($0.name, query: q) }
            .map { HomeItem.folder($0) }
        
        let matchedNotes = notes
            .filter { KoreanSearchUtils.matches($0.title, query: q) }
            .map { HomeItem.note($0) }
        
        let combined = matchedFolders + matchedNotes
        return combined.sorted { createdDate(for: $0) > createdDate(for: $1) }
    }
    
    func createdDate(for item: HomeItem) -> Date {
        switch item {
        case .folder(let f):
            return f.createdAt
        case .note(let n):
            return n.createdAt
        }
    }
}
