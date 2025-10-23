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
                            ForEach(allItems.indices, id: \.self) { idx in
                                let item = allItems[idx]
                                homeItemView(item)
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

    private var filteredNotes: [Note] {
        // 1) 폴더 선택 필터
        let base: [Note]
        if let selected = selectedFolderName {
            base = notes.filter { $0.folder?.name == selected }
        } else {
            base = notes
        }
        // 2) 검색어 필터
        let q = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { $0.title.lowercased().contains(q) }
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

#Preview(traits: .landscapeLeft) {
    HomeView()
}
