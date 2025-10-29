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
    @State private var isFolderDeletePresented: Bool = false
    @State private var folderIDsPendingDelete = Set<PersistentIdentifier>()

    var body: some View {
        NavigationSplitView {
            SidebarView(onFolderSelected: { name in
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
                            Image(systemName: "magnifyingglass").foregroundStyle(Color.text3)
                            TextField("노트 검색", text: $viewModel.searchText, axis: .horizontal)
                                .font(.system(size: 16))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 200, maxWidth: 300)
                        .background(Color.background2)
                        .cornerRadius(8)
                        
                        Button(action: { viewModel.viewModeButtonTapped(.compact) }) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(Color.text3)
                        }
                        Button(action: { viewModel.viewModeButtonTapped(.grid) }) {
                            Image(systemName: "square.grid.2x2").foregroundStyle(Color.text3)
                        }
                        Button(action: { viewModel.viewModeButtonTapped(.list) }) {
                            Image(systemName: "list.bullet").foregroundStyle(Color.text3)
                        }
                    }
                }
                .padding()
                
                
                Divider().background(Color.borderColor)
                
                
                // 노트 그리드
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        if isAllView {
                            let items = searchQuery.isEmpty ? allItems : allItemsFiltered
                            
                            ForEach(items.indices, id: \.self) { idx in
                                let item = items[idx]
                                homeItemView(item)
                                
                            }
                        } else {
                            ForEach(filteredNotes) { note in
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
                    }
                    .padding()
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
        guard !q.isEmpty else { return base }
        return base.filter { matches($0.title, query: q) }
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
}

#Preview(traits: .landscapeLeft) {
    HomeView()
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


