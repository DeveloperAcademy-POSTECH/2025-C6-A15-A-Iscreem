//
//  HomeView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var headerSubtitle: String = "최근 열어본 항목"
    @State private var selectedFolderName: String? = nil
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCreateNote = false
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Note.lastRead, order: .reverse)]) private var notes: [Note]
    @Query private var folders: [Folder]
    
    // 노트 선택/생성 콜백 (필요시 외부로 전달)
    let onNoteSelected: ((Note) -> Void)?
    let onNoteCreated: ((Note) -> Void)?
    
    @State private var noteToRename: Note?
    @State private var renameText: String = ""
    
    enum NoteSortOption: String, CaseIterable {
        case dateDescending = "최신순"
        case dateAscending = "오래된순"
        case nameAscending = "제목 A→Z"
        case nameDescending = "제목 Z→A"
    }

    @State private var noteSort: NoteSortOption = .dateDescending
    @State private var showNoteSortMenu = false
    
    // 적응형 그리드
    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)]
    
    
    init(
        onNoteSelected: ((Note) -> Void)? = nil,
        onNoteCreated: ((Note) -> Void)? = nil
    ) {
        self.onNoteSelected = onNoteSelected
        self.onNoteCreated = onNoteCreated
    }

    @State private var isHelpPresented: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var isFolderDeletePresented: Bool = false
    @State private var folderIDsPendingDelete = Set<PersistentIdentifier>()

    var body: some View {
        NavigationSplitView {
            SidebarView(onFolderSelected: { name in
                isShowingSettings = false
                if name == "__ALL__" {
                    headerSubtitle = "전체 보기"
                    selectedFolderName = "__ALL__"
                } else if let name {
                    headerSubtitle = name
                    selectedFolderName = name
                } else {
                    headerSubtitle = "최근 열어본 항목"
                    selectedFolderName = nil
                }
            }, isHelpPresented: $isHelpPresented, requestDeleteConfirmation: { ids in
                folderIDsPendingDelete = ids
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFolderDeletePresented = true
                }
            })
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            .toolbar(.hidden, for: .navigationBar)
        } detail: {
            ZStack {
                VStack(spacing: 0) {
                    // 헤더
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("{$app_name}")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.text1)
                            
                            Text(headerSubtitle)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.text2)
                        }
                        
                        Spacer()
                        
                        // 검색 + 뷰모드 버튼들
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.text3)
                                TextField("노트 검색", text: $viewModel.searchText, axis: .horizontal)
                                    .font(.system(size: 16))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 220, maxWidth: 320)
                            .background(Color.background2)
                            .cornerRadius(8)
                            
                            
                            Button {
                                showNoteSortMenu.toggle()
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.text2)
                                    .frame(width: 36, height: 36)
                                    .background(Color.background2)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showNoteSortMenu, arrowEdge: .top) {
                                VStack(spacing: 0) {
                                    ForEach(NoteSortOption.allCases, id: \.self) { option in
                                        Button {
                                            noteSort = option
                                            showNoteSortMenu = false
                                        } label: {
                                            HStack(spacing: 10) {
                                                if noteSort == option {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 12, weight: .bold))
                                                } else {
                                                    Color.clear.frame(width: 12, height: 12)
                                                }
                                                Text(option.rawValue)
                                                    .font(.system(size: 14))
                                                Spacer()
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if option != NoteSortOption.allCases.last {
                                            Divider().background(Color.borderColor)
                                        }
                                    }
                                }
                                .frame(width: 180)
                                .background(Color.background1)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderColor, lineWidth: 1))
                            }
                            
                            
                            // ▼ 토글 버튼 (오른쪽)
                            ViewModeToggle(selection: $viewModel.selectedViewMode) { mode in
                                viewModel.viewModeButtonTapped(mode)
                            }
                            .frame(width: 116, height: 36)
                        }
                    }
                    .padding()
                    
                    
                    Divider().background(Color.borderColor)
                    
                    
                    // 노트 그리드
                    ScrollView {
                        if viewModel.selectedViewMode == .list {// ✅ 리스트 모드 (테이블 형태)
                            VStack(spacing: 0) {
                                listHeaderRow() // 헤더
                                Divider().background(Color.borderColor)
                                
                                LazyVStack(spacing: 8) {
                                    if isAllView {
                                        let items = searchQuery.isEmpty ? allItems : allItemsFiltered
                                        ForEach(items.indices, id: \.self) { idx in
                                            homeItemRow(items[idx]) // 폴더/노트 한 줄씩
                                            Divider().background(Color.borderColor.opacity(0.6))
                                        }
                                    } else {
                                        ForEach(filteredNotes) { note in
                                            noteRow(note) // 노트 한 줄
                                            Divider().background(Color.borderColor.opacity(0.6))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            }
                            
                        } else {
                            // ✅ 기존 그리드 모드 (네 코드 그대로)
                            LazyVGrid(columns: columns, spacing: 16) {
                                if isAllView {
                                    let items = searchQuery.isEmpty ? allItems : allItemsFiltered
                                    ForEach(items.indices, id: \.self) { idx in
                                        homeItemView(items[idx])     // 기존 타일 UI
                                    }
                                } else {
                                    ForEach(filteredNotes) { note in
                                        NoteComponent(note: note)
                                            .onTapGesture { onNoteSelected?(note) }
                                            .contextMenu {
                                                Button("이름 변경") {
                                                    noteToRename = note
                                                    renameText = note.title
                                                }
                                                Button("삭제", role: .destructive) {
                                                    modelContext.delete(note)
                                                    try? modelContext.save()
                                                }
                                            }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .overlay {
                        // 노트가 없을 때 기본 텍스트 표시
                        if shouldShowEmptyState {
                            VStack(spacing: 4) {
                                Text("아직은 노트가 없어요!")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Color.text3)
                                
                                Text("하단 추가 버튼을 눌러서 첫 학습을 시작해 보세요!")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Color.text3)
                                
                                Spacer()
                                    .frame(height: 12)
                                
                                Text("사용법을 알고 싶으신가요?")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Color.text3)
                                
                                HStack(spacing: 4) {
                                    Text("좌측 하단의")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color.text3)
                                    
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.text3)
                                    
                                    Text("도움말 버튼을 클릭해 보세요!")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color.text3)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(y: -50)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            viewModel.addButtonTapped()
                            withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = true }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.secondColor)
                                .clipShape(Circle())
                                .shadow(color: Color.secondColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(32)
                    }
                }
                if isShowingSettings {
                    SettingsDetailView()
                        .transition(.opacity)
                        .background(Color(.systemBackground))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .keyboardOverlay()
        .overlay {
            if isHelpPresented {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isHelpPresented = false } }
                        HelpView(onClose: { withAnimation(.easeInOut(duration: 0.2)) { isHelpPresented = false } })
                            .frame(
                                width: min(680, geometry.size.width * 0.70),
                                height: min(620, geometry.size.height * 0.78)
                            )
                            .background(Color.background1)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .overlay {
            if isFolderDeletePresented {
                FolderDeleteView(
                    onDelete: {
                        // 실제 삭제 수행
                        for id in folderIDsPendingDelete {
                            if let target = folders.first(where: { $0.persistentModelID == id }) {
                                modelContext.delete(target)
                            }
                        }
                        try? modelContext.save()
                        folderIDsPendingDelete.removeAll()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFolderDeletePresented = false
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFolderDeletePresented = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        // 노트 생성 시트
        .overlay {
            if showCreateNote {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = false }
                            }
                        
                        CreateNoteView { note in
                            onNoteCreated?(note)
                            withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = false }
                        }
                        .frame(
                            width: min(500, geometry.size.width * 0.6),
                            height: min(380, geometry.size.height * 0.5)
                        )
                        .background(Color.background1)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        .keyboardShift(10)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
        }
        // 이름 변경 시트
        .sheet(item: $noteToRename) { note in
            VStack(alignment: .leading, spacing: 16) {
                Text("노트 이름 변경").font(.title3)
                TextField("제목", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("취소") { noteToRename = nil }
                    Button("저장") {
                        note.title = renameText
                        try? modelContext.save()
                        noteToRename = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 320)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSettings = true
            }
        }
    }
    
    private var searchQuery: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // 빈 상태 표시 여부
    private var shouldShowEmptyState: Bool {
        if isAllView {
            let items = searchQuery.isEmpty ? allItems : allItemsFiltered
            return items.isEmpty
        } else {
            return filteredNotes.isEmpty
        }
    }
    
    private var filteredNotes: [Note] {
        // 1) 폴더 선택 필터
        let base: [Note]
        if let selected = selectedFolderName, selected != "__ALL__" {
            base = notes.filter { $0.folder?.name == selected }
        } else {
            base = notes
        }
        // 2) 검색어 필터 (노트 제목만)
        let q = searchQuery
        let filtered = q.isEmpty ? base : base.filter { matches($0.title, query: q) }
        // 3) 정렬 적용
        return sortNotes(filtered, by: noteSort)
    }
    
    
    // 전체 보기 모드 여부
    private var isAllView: Bool { selectedFolderName == "__ALL__" }
    
    // 전체 보기에서 사용할 항목 타입 (폴더 + 노트)
    private enum HomeItem {
        case folder(Folder)
        case note(Note)
    }
    
    // 전체 보기: 폴더 + (폴더에 속하지 않은) 노트들을 최신 등록순으로 정렬
    private var allItems: [HomeItem] {
        let folderItems = folders.map { HomeItem.folder($0) }
        let unfiledNotes = notes.filter { $0.folder == nil }.map { HomeItem.note($0) }
        let combined = folderItems + unfiledNotes
        return combined.sorted { createdDate(for: $0) > createdDate(for: $1) }
    }
    
    // 전체 보기에서 검색 시: 폴더 이름 + 미분류 노트 제목을 대상으로 필터링
    private var allItemsFiltered: [HomeItem] {
        let q = searchQuery
        guard !q.isEmpty else { return allItems }
        
        
        let matchedFolders = folders
            .filter { matches($0.name, query: q) }
            .map { HomeItem.folder($0) }
        
        let matchedNotes = notes
            .filter { matches($0.title, query: q) }
            .map { HomeItem.note($0) }
        
        let combined = matchedFolders + matchedNotes
        return combined.sorted { createdDate(for: $0) > createdDate(for: $1) }
    }
    
    
    // 정렬 기준이 되는 생성일(노트에 createdAt이 없으면 lastRead를 보조로 사용)
    private func createdDate(for item: HomeItem) -> Date {
        switch item {
        case .folder(let f):
            return f.createdAt
        case .note(let n):
            // KVC 금지: SwiftData @Model은 KVC 미지원. 직접 프로퍼티를 사용.
            return n.createdAt
        }
    }
    
    // HomeItem을 실제 뷰로 렌더링
    @ViewBuilder
    private func homeItemView(_ item: HomeItem) -> some View {
        switch item {
        case .folder(let folder):
            Button {
                // 폴더 타일 탭 시 해당 폴더로 전환
                selectedFolderName = folder.name
                headerSubtitle = folder.name
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.text2)
                    Text(folder.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.text1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.background2)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
            }
        case .note(let note):
            NoteComponent(note: note)
                .onTapGesture {
                    // 노트 진입 시 StudyView로 이동 → StudyView/MediaView에서 load(url) 호출 직전에 resetForNewVideo()가 실행되어
                    // 이전 노트의 요약/자막 상태가 남지 않도록 함.
                    onNoteSelected?(note)
                }
                .contextMenu {
                    Button("이름 변경") {
                        noteToRename = note
                        renameText = note.title
                    }
                    Button("삭제", role: .destructive) {
                        modelContext.delete(note)
                        try? modelContext.save()
                    }
                }
        }
    }

    // MARK: - List Thumbnail Helpers
    @ViewBuilder
    private func thumbnailView(for note: Note) -> some View {
        if let url = thumbnailURL(for: note) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure(_):
                    placeholderThumbnail
                @unknown default:
                    placeholderThumbnail
                }
            }
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
        } else {
            placeholderThumbnail
        }
    }
    
    @ViewBuilder
    private func listHeaderRow() -> some View {
        HStack {
            Text("제목")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)

            Text("강의 길이")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 72, alignment: .trailing)

            Text("수강률")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 72, alignment: .trailing)

            Text("최근 학습 일시")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.background1)
    }

    private var placeholderThumbnail: some View {
        ZStack {
            Rectangle()
                .fill(Color.background2)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(Color.text3)
        }
    }

    /// Try to resolve a thumbnail URL for a note:
    /// 1) If the model has `thumbnailURL`/`thumbnailUrl` (String), use it directly.
    /// 2) Else, try to find a YouTube-like link property (`youtubeURL`, `videoURL`, `url`, `link`, ...),
    ///    then generate `https://img.youtube.com/vi/<id>/hqdefault.jpg` using `YouTubeThumbnail.thumbnailURL(from:)`.
    private func thumbnailURL(for note: Note) -> URL? {
        let mirror = Mirror(reflecting: note)
        var thumbString: String?
        var linkString: String?
        var youtubeId: String?

        for child in mirror.children {
            guard let label = child.label else { continue }

            // 직접 썸네일 URL을 저장하는 경우
            if thumbString == nil,
               (label == "thumbnailURL" || label == "thumbnailUrl"),
               let s = child.value as? String, !s.isEmpty {
                thumbString = s
            }

            // 임의의 문자열 필드에 유튜브 링크가 들어있는 경우 (heurstics)
            if linkString == nil,
               let s = child.value as? String,
               s.lowercased().contains("youtu") {
                linkString = s
            }

            // 영상 id만 저장하는 경우
            if youtubeId == nil,
               ["youtubeID","youtubeId","videoID","videoId"].contains(label),
               let s = child.value as? String, !s.isEmpty {
                youtubeId = s
            }
        }

        if let t = thumbString, let u = URL(string: t) { return u }
        if let id = youtubeId, let u = URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg") { return u }
        if let l = linkString, let u = YouTubeThumbnail.thumbnailURL(from: l) { return u }
        return nil
    }

    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: 12) {
            // 1) 제목/썸네일 (좌측 가변)
            HStack(spacing: 12) {
                thumbnailView(for: note)
                    .frame(width: 56, height: 56)
                    .cornerRadius(8)

                Text(note.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.text1)
                    .lineLimit(1)
            }
            .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)

            // 2) 강의 길이
            Text(durationText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 72, alignment: .trailing)

            // 3) 수강률
            Text(progressText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 72, alignment: .trailing)

            // 4) 최근 학습 일시
            Text(lastReadText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onNoteSelected?(note) }
        .contextMenu {
            Button("이름 변경") {
                noteToRename = note
                renameText = note.title
            }
            Button("삭제", role: .destructive) {
                modelContext.delete(note)
                try? modelContext.save()
            }
        }
    }

    @ViewBuilder
    private func homeItemRow(_ item: HomeItem) -> some View {
        switch item {
        case .folder(let folder):
            Button {
                selectedFolderName = folder.name
                headerSubtitle = folder.name
            } label: {
                HStack(spacing: 12) {
                    // 제목 영역
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.text2)
                            .frame(width: 56, height: 56)
                            .background(Color.background2)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.borderColor, lineWidth: 1))

                        Text(folder.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.text1)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)

                    // 우측 컬럼 (폴더는 표시값 없음)
                    Text("—").frame(width: 72, alignment: .trailing).foregroundStyle(Color.text3)
                    Text("—").frame(width: 72, alignment: .trailing).foregroundStyle(Color.text3)
                    Text(relativeDate(folder.createdAt))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text2)
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

        case .note(let n):
            noteRow(n)
        }
    }
}

// MARK: - Korean-aware fuzzy search (Hangul Jamo subsequence)
private func matches(_ text: String, query: String) -> Bool {
    let t = text.lowercased()
    let q = query.lowercased()
    // 1) Plain substring (fast path)
    if t.contains(q) { return true }
    // 2) Jamo key subsequence match (handles cases like "개발" vs "갭")
    let tk = jamoKey(t)
    let qk = jamoKey(q)
    if tk.contains(qk) { return true }
    return isSubsequence(qk, in: tk)
}

/// Convert a string to a Hangul Jamo key: each syllable → L(ᄀ..ᄒ) + V(ᅡ..ᅵ) + [T(ᆨ..ᇂ)]
/// Also maps compatibility Jamo (ㄱㅏㅂ etc.) to modern Jamo, removes spaces/punctuation.
private func jamoKey(_ s: String) -> String {
    let SBase: UInt32 = 0xAC00, SCount: UInt32 = 11172
    let LBase: UInt32 = 0x1100/*, LCount: UInt32 = 19*/
    let VBase: UInt32 = 0x1161, VCount: UInt32 = 21
    let TBase: UInt32 = 0x11A7, TCount: UInt32 = 28
//    let NCount: UInt32 = VCount * TCount // 588
    
    // Compatibility Jamo → Modern Jamo (subset: initials & vowels)
    let compToModern: [UInt32: UInt32] = [
        // Initials (ㄱ..ㅎ)
        0x3131: 0x1100, // ㄱ → ᄀ
        0x3132: 0x1101, // ㄲ → ᄁ
        0x3134: 0x1102, // ㄴ → ᄂ
        0x3137: 0x1103, // ㄷ → ᄃ
        0x3138: 0x1104, // ㄸ → ᄄ
        0x3139: 0x1105, // ㄹ → ᄅ
        0x3141: 0x1106, // ㅁ → ᄆ
        0x3142: 0x1107, // ㅂ → ᄇ
        0x3143: 0x1108, // ㅃ → ᄈ
        0x3145: 0x1109, // ㅅ → ᄉ
        0x3146: 0x110A, // ㅆ → ᄊ
        0x3147: 0x110B, // ㅇ → ᄋ
        0x3148: 0x110C, // ㅈ → ᄌ
        0x3149: 0x110D, // ㅉ → ᄍ
        0x314A: 0x110E, // ㅊ → ᄎ
        0x314B: 0x110F, // ㅋ → ᄏ
        0x314C: 0x1110, // ㅌ → ᄐ
        0x314D: 0x1111, // ㅍ → ᄑ
        0x314E: 0x1112, // ㅎ → ᄒ
        // Vowels (ㅏ..ㅣ)
        0x314F: 0x1161, // ㅏ → ᅡ
        0x3150: 0x1162, // ㅐ → ᅢ
        0x3151: 0x1163, // ㅑ → ᅣ
        0x3152: 0x1164, // ㅒ → ᅤ
        0x3153: 0x1165, // ㅓ → ᅥ
        0x3154: 0x1166, // ㅔ → ᅦ
        0x3155: 0x1167, // ㅕ → ᅧ
        0x3156: 0x1168, // ㅖ → ᅨ
        0x3157: 0x1169, // ㅗ → ᅩ
        0x3158: 0x116A, // ㅘ → ᅪ
        0x3159: 0x116B, // ㅙ → ᅫ
        0x315A: 0x116C, // ㅚ → ᅬ
        0x315B: 0x116D, // ㅛ → ᅭ
        0x315C: 0x116E, // ㅜ → ᅮ
        0x315D: 0x116F, // ㅝ → ᅯ
        0x315E: 0x1170, // ㅞ → ᅰ
        0x315F: 0x1171, // ㅟ → ᅱ
        0x3160: 0x1172, // ㅠ → ᅲ
        0x3161: 0x1173, // ㅡ → ᅳ
        0x3162: 0x1174, // ㅢ → ᅴ
        0x3163: 0x1175  // ㅣ → ᅵ
    ]
    
    var out = String.UnicodeScalarView()
    let lower = s.lowercased()
    
    for scalar in lower.unicodeScalars {
        let v = scalar.value
        // Hangul syllables (가..힣)
        if v >= SBase && v <= SBase + SCount - 1 {
            let sIndex = v - SBase
            let lIndex = sIndex / (VCount * TCount)
            let vIndex = (sIndex % (VCount * TCount)) / TCount
            let tIndex = sIndex % TCount
            if let L = UnicodeScalar(LBase + lIndex) { out.append(L) }
            if let V = UnicodeScalar(VBase + vIndex) { out.append(V) }
            if tIndex > 0, let T = UnicodeScalar(TBase + tIndex) { out.append(T) }
            continue
        }
        // Compatibility jamo → modern jamo
        if let mapped = compToModern[v], let u = UnicodeScalar(mapped) {
            out.append(u); continue
        }
        // ASCII letters/digits: keep
        if ("0"..."9").contains(String(scalar)) || ("a"..."z").contains(String(scalar)) {
            out.append(scalar); continue
        }
        // Skip spaces/punctuations/others
    }
    return String(out)
}

/// Returns true if `small`'s scalars appear in order inside `big` (not necessarily contiguously).
private func isSubsequence(_ small: String, in big: String) -> Bool {
    if small.isEmpty { return true }
    var it = small.unicodeScalars.makeIterator()
    var need = it.next()
    for s in big.unicodeScalars {
        if s == need {
            need = it.next()
            if need == nil { return true }
        }
    }
    return false
}

private func sortNotes(_ input: [Note], by option: HomeView.NoteSortOption) -> [Note] {
    switch option {
    case .dateDescending:
        return input.sorted { $0.createdAt > $1.createdAt }
    case .dateAscending:
        return input.sorted { $0.createdAt < $1.createdAt }
    case .nameAscending:
        return input.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    case .nameDescending:
        return input.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
    }
}

private func durationText(for note: Note) -> String {
    let m = Mirror(reflecting: note)

    if let secs = m.children.first(where: { $0.label == "duration" || $0.label == "length" })?.value as? TimeInterval {
        let mm = Int(secs) / 60
        let ss = Int(secs) % 60
        return String(format: "%d:%02d", mm, ss)
    }
    if let s = m.children.first(where: { $0.label == "durationText" || $0.label == "lengthText" })?.value as? String, !s.isEmpty {
        return s
    }
    return "—"
}

private func progressText(for note: Note) -> String {
    let m = Mirror(reflecting: note)

    if let p = m.children.first(where: { $0.label == "progress" || $0.label == "percentage" })?.value as? Double {
        // 0.0~1.0 또는 0~100 모두 허용
        let v = p <= 1.0 ? (p * 100.0) : p
        return String(format: "%.0f%%", v)
    }
    if let pInt = m.children.first(where: { $0.label == "progressPercent" })?.value as? Int {
        return "\(pInt)%"
    }
    return "—"
}

private func lastReadText(for note: Note) -> String {
    relativeDate(note.lastRead)
}

private func relativeDate(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f.localizedString(for: date, relativeTo: Date())
}

extension Notification.Name {
    static let showSettings = Notification.Name("ShowSettings")
}
