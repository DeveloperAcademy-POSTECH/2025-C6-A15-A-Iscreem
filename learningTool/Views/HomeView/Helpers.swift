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
    /// Apply proportional scaling only in compact width environments (e.g., iPhone).
    /// - Parameters:
    ///   - base: Baseline logical size to preserve ratios against (default: 390x844 = iPhone 12/13/14/15 Portrait class).
    ///   - min: Minimum scale clamp to keep tap targets usable.
    ///   - max: Maximum scale clamp (usually 1.0).
    func compactScaled(base: CGSize = CGSize(width: 390, height: 844),
                       min: CGFloat = 0.9,
                       max: CGFloat = 1.0) -> some View {
        self.modifier(CompactScaleModifier(base: base, min: min, max: max))
    }
}

// MARK: - ScaledContainer (Proportional window scaling)
// 창 크기에 따라 전체 UI를 비율 유지하며 축소/확대.
// 기준 해상도(1366x1024) 대비 비율을 구해 0.75~1.0 사이로 클램프.
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
            // 기준 크기 대비 가로/세로 스케일 → 더 작은 쪽 채택
            let sW = geo.size.width / max(baseSize.width, 1)
            let sH = geo.size.height / max(baseSize.height, 1)
            let raw = min(sW, sH)
            let scale = min(max(raw, minScale), maxScale) // 0.75~1.0 클램프

            ZStack(alignment: alignment) {
                content()
                    .scaleEffect(scale, anchor: .topLeading)
                    // 스케일 후 히트영역 불일치 방지를 위해 논리 프레임을 보정
                    .frame(width: geo.size.width / scale,
                           height: geo.size.height / scale,
                           alignment: alignment)
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
    }
 }
