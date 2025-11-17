//
//  Helpers.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import SwiftUI
import SwiftData

// MARK: - Global Duration Formatting
func formatDurationString(_ seconds: Double?) -> String {
    guard let s = seconds, s > 0 else { return "—" }
    let total = Int(s.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let sec = total % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, sec)
    } else {
        return String(format: "%d:%02d", m, sec)
    }
}

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
    
    // ✅ 사이드바 정렬 옵션(AppStorage)을 읽어옵니다.
    private func currentSidebarSortOption() -> SortOption {
        let key = "sidebarSortOption"
        let raw = UserDefaults.standard.string(forKey: key) ?? SortOption.dateAscending.rawValue
        return SortOption(rawValue: raw) ?? .dateAscending
    }
    
    // ✅ 폴더 정렬(사이드바와 동일 기준)
    private func sortFolders(_ input: [Folder], by option: SortOption) -> [Folder] {
        switch option {
        case .nameAscending:
            return input.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return input.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .dateAscending:
            return input.sorted { $0.createdAt < $1.createdAt }
        case .dateDescending:
            return input.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var allItems: [HomeItem] {
        // 휴지통 제외
        let sidebarOption = currentSidebarSortOption()
        let foldersSorted = sortFolders(folders.filter { !$0.isTrashed }, by: sidebarOption)
            .map { HomeItem.folder($0) }
        
        // ‘전체 보기’에서는 기존 정책대로 “폴더 + 폴더에 속하지 않은 노트”를 보여줍니다.
        let unfiledNotes = notes.filter { !$0.isTrashed && $0.folder == nil }
        let notesSorted = NoteFormattingUtils.sortNotes(unfiledNotes, by: headerSort)
            .map { HomeItem.note($0) }
        
        // ✅ 폴더 먼저 → 노트 다음
        return foldersSorted + notesSorted
    }
    
    var allItemsFiltered: [HomeItem] {
        let q = searchQuery
        guard !q.isEmpty else { return allItems }
        
        let sidebarOption = currentSidebarSortOption()
        
        // 검색 매칭된 폴더/노트를 각각 정렬한 뒤 결합
        let matchedFolders = folders
            .filter { !$0.isTrashed && KoreanSearchUtils.matches($0.name, query: q) }
        let foldersSorted = sortFolders(matchedFolders, by: sidebarOption)
            .map { HomeItem.folder($0) }
        
        let matchedNotes = notes
            .filter { !$0.isTrashed && KoreanSearchUtils.matches($0.title, query: q) }
        let notesSorted = NoteFormattingUtils.sortNotes(matchedNotes, by: headerSort)
            .map { HomeItem.note($0) }
        
        // ✅ 폴더 먼저 → 노트 다음
        return foldersSorted + notesSorted
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

// MARK: - CompactScaleModifier (Landscape-only proportional scaling, all devices)
private struct CompactScaleModifier: ViewModifier {
    // base: .zero → 첫 레이아웃 시점의 화면 크기를 기준으로 동적 캡처
    let base: CGSize
    let min: CGFloat
    let max: CGFloat
    let alignment: Alignment
    
    @State private var inferredBase: CGSize?
    
    func body(content: Content) -> some View {
        GeometryReader { geo in
            let size = geo.size
            let isLandscape = size.width > size.height
            
            // 동적 기준 적용: base == .zero 이면 첫 레이아웃 크기를 기준으로 캡처
            let effectiveBase: CGSize = {
                if let b = inferredBase { return b }
                if base == .zero { return size }
                return base
            }()
            
            Group {
                if isLandscape {
                    ScaledContainer(
                        baseSize: effectiveBase,
                        minScale: min,
                        maxScale: max,
                        alignment: alignment
                    ) {
                        content
                    }
                    // base == .zero일 때만 최초 한 번 캡처
                    .onAppear {
                        if inferredBase == nil, base == .zero {
                            inferredBase = size
                        }
                    }
                    .onChange(of: size) { _, _ in
                        // 필요 시 회전 대응 조정 가능
                    }
                } else {
                    // 세로 모드에서는 스케일 미적용
                    content
                }
            }
            .frame(width: size.width, height: size.height, alignment: alignment)
        }
    }
}

extension View {
    /// 가로 모드에서만 비율 스케일을 적용하는 보조 수정자.
    /// - base: .zero를 주면 “기기 한대의 고정 기준 없이” 현재 화면 크기를 기준으로 동적 캡처합니다.
    ///         특정 기준(예: 1366x1024 등)이 필요하면 명시적으로 전달하세요.
    /// - min/max: 스케일 클램프 범위
    /// - alignment: 스케일 기준 정렬
    func compactScaled(base: CGSize = .zero,
                       min: CGFloat = 0.9,
                       max: CGFloat = 1.0,
                       alignment: Alignment = .topLeading) -> some View {
        self.modifier(CompactScaleModifier(base: base, min: min, max: max, alignment: alignment))
    }
}

// MARK: - ScaledContainer
struct ScaledContainer<Content: View>: View {
    let baseSize: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat
    let alignment: Alignment
    @ViewBuilder var content: () -> Content
    
    // baseSize == .zero 이면 “현재 가용 크기”를 최초 한 번 캡처하여 기준으로 사용
    @State private var inferredBase: CGSize?
    
    init(
        baseSize: CGSize = .zero,
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
            let containerSize = geo.size
            
            // 동적 기준: baseSize == .zero 이면 첫 레이아웃의 크기를 캡처해서 사용
            let effectiveBase: CGSize = {
                if let captured = inferredBase { return captured }
                if baseSize == .zero { return containerSize }
                return baseSize
            }()
            
            let sW = containerSize.width / max(effectiveBase.width, 1)
            let sH = containerSize.height / max(effectiveBase.height, 1)
            let raw = min(sW, sH)
            let scale = min(max(raw, minScale), maxScale)
            
            ZStack(alignment: alignment) {
                content()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(
                        width: containerSize.width / max(scale, .leastNonzeroMagnitude),
                        height: containerSize.height / max(scale, .leastNonzeroMagnitude),
                        alignment: alignment
                    )
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .onAppear {
                if inferredBase == nil, baseSize == .zero {
                    inferredBase = containerSize
                }
            }
        }
    }
}

