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
        // 휴지통 제외
        let nonTrashed = notes.filter { !$0.isTrashed }
        
        let base: [Note]
        if let selected = selectedFolderName, selected != "__ALL__" {
            base = nonTrashed.filter { $0.folder?.name == selected }
        } else {
            base = nonTrashed
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
        // 휴지통 제외
        let folderItems = folders.filter { !$0.isTrashed }.map { HomeItem.folder($0) }
        let unfiledNotes = notes.filter { !$0.isTrashed && $0.folder == nil }.map { HomeItem.note($0) }
        let combined = folderItems + unfiledNotes
        return combined.sorted { createdDate(for: $0) > createdDate(for: $1) }
    }
    
    var allItemsFiltered: [HomeItem] {
        let q = searchQuery
        guard !q.isEmpty else { return allItems }
        
        let matchedFolders = folders
            .filter { !$0.isTrashed && KoreanSearchUtils.matches($0.name, query: q) }
            .map { HomeItem.folder($0) }
        
        let matchedNotes = notes
            .filter { !$0.isTrashed && KoreanSearchUtils.matches($0.title, query: q) }
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

// MARK: - CompactScaleModifier (iPhone-only proportional scaling)
private struct CompactScaleModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize
    let base: CGSize
    let min: CGFloat
    let max: CGFloat
    
    func body(content: Content) -> some View {
        Group {
            if hSize == .compact {
                ScaledContainer(baseSize: base, minScale: min, maxScale: max, alignment: .topLeading) {
                    content
                }
            } else {
                content
            }
        }
    }
}

extension View {
    func compactScaled(base: CGSize = CGSize(width: 390, height: 844),
                       min: CGFloat = 0.9,
                       max: CGFloat = 1.0) -> some View {
        self.modifier(CompactScaleModifier(base: base, min: min, max: max))
    }
}

// MARK: - ScaledContainer
struct ScaledContainer<Content: View>: View {
    let baseSize: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat
    let alignment: Alignment
    @ViewBuilder var content: () -> Content
    
    init(
        baseSize: CGSize = CGSize(width: 1366, height: 1024),
        minScale: CGFloat = 0.75,
        maxScale: CGFloat = 1.0,
        alignment: Alignment = .topLeading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.baseSize = baseSize
        self.minScale = minScale
        self.maxScale = maxScale
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let sW = geo.size.width / max(baseSize.width, 1)
            let sH = geo.size.height / max(baseSize.height, 1)
            let raw = min(sW, sH)
            let scale = min(max(raw, minScale), maxScale)
            
            ZStack(alignment: alignment) {
                content()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: geo.size.width / scale,
                           height: geo.size.height / scale,
                           alignment: alignment)
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
    }
}
