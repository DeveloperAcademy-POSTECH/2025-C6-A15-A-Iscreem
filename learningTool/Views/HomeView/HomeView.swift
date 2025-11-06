//
//  HomeView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @State var headerSubtitle: String = "최근 열어본 항목"
    @State var selectedFolderName: String? = nil
    @StateObject var viewModel = HomeViewModel()
    @State var showCreateNote = false
    @State var youtubeLink = ""
    @State var noteTitle = ""
    
    @EnvironmentObject private var learningLogStore: LearningLogStore
    @State private var showStudyHistory: Bool = false
    
    @Environment(\.modelContext) var modelContext
    @Query(sort: [SortDescriptor(\Note.lastRead, order: .reverse)]) var notes: [Note]
    @Query var folders: [Folder]
    
    let onNoteSelected: ((Note) -> Void)?
    let onNoteCreated: ((Note) -> Void)?
    
    @State var noteToRename: Note?
    @State var renameText: String = ""
    
    @State var isKeyboardVisible: Bool = false
    @State var keyboardHeight: CGFloat = 0
    
    @State var headerSort: HeaderSortOption = .recentlyOpenedDesc
    @State var showNoteSortMenu = false
    
    let columns = [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)]
    
    @State var isHelpPresented: Bool = false
    @State var isShowingSettings: Bool = false
    @State var isFolderDeletePresented: Bool = false
    @State var folderIDsPendingDelete = Set<PersistentIdentifier>()
    @State var showResetConfirm: Bool = false
    @Namespace private var glassNS
    
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
                    headerView
                    
                    Divider().background(Color.borderColor)
                    
                    // 노트 그리드/리스트
                    contentView
                        .overlay {
                            if shouldShowEmptyState {
                                emptyStateView
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            addButton
                        }
                }
                if isShowingSettings {
                    SettingsDetailView(showResetConfirm: $showResetConfirm)
                        .transition(.opacity)
                        .background(Color(.systemBackground))
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 20) {
                historyButton
                addButton
            }
        }
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.blue.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .backgroundExtensionEffect()
        }
        .navigationSplitViewStyle(.balanced)
        .keyboardOverlay()
        .applyOverlays(
            isHelpPresented: $isHelpPresented,
            showResetConfirm: $showResetConfirm,
            isFolderDeletePresented: $isFolderDeletePresented,
            showCreateNote: $showCreateNote,
            noteToRename: $noteToRename,
            renameText: $renameText,
            youtubeLink: $youtubeLink,
            noteTitle: $noteTitle,
            isKeyboardVisible: $isKeyboardVisible,
            keyboardHeight: $keyboardHeight,
            notes: notes,
            folders: folders,
            folderIDsPendingDelete: folderIDsPendingDelete,
            modelContext: modelContext,
            isFormValid: isFormValid,
            createNoteTapped: createNoteTapped,
            onFolderDeleteConfirmed: {
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
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSettings = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSettings = false
            }
        }
        .onAppear {
            // 앱 시작 직후 ‘전체 보기’로 진입 → + 버튼 보이게
            if selectedFolderName == nil {
                selectedFolderName = "__ALL__"
                headerSubtitle = "전체 보기"
            }
        }
        .sheet(isPresented: $showStudyHistory) {
            StudyHistoryView()
                .environmentObject(learningLogStore)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
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
            
            HStack(spacing: 12) {
                searchBar
                sortButton
                ViewModeToggle(selection: $viewModel.selectedViewMode) { mode in
                    viewModel.viewModeButtonTapped(mode)
                }
                .frame(width: 116, height: 36)
            }
        }
        .padding()
    }
    
    // MARK: - 🔵 검색바 (Liquid Glass)
    private var searchBar: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.text3)
                TextField("노트 검색", text: $viewModel.searchText, axis: .horizontal)
                    .font(.system(size: 16))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 220, maxWidth: 320)
            .frame(height: 36)
            .glassEffect()
            .glassEffectUnion(id: "search", namespace: glassNS)
        }
    }
    
    // MARK: - 🔵 정렬 버튼 (Liquid Glass)
    private var sortButton: some View {
        Button {
            showNoteSortMenu.toggle()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.text2)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .popover(isPresented: $showNoteSortMenu, arrowEdge: .top) {
            PopoverMenuContent(
                selectedSort: $headerSort,
                onEditNote: {
                    showNoteSortMenu = false
                }
            )
            .frame(width: 255, height: 270)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        }
        .onChange(of: headerSort) { _ in
            showNoteSortMenu = false
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            if viewModel.selectedViewMode == .list {
                listModeContent(
                    isAllView: isAllView,
                    allItems: allItems,
                    allItemsFiltered: allItemsFiltered,
                    filteredNotes: filteredNotes,
                    searchQuery: searchQuery,
                    selectedFolderName: $selectedFolderName,
                    headerSubtitle: $headerSubtitle,
                    noteToRename: $noteToRename,
                    renameText: $renameText,
                    onNoteSelected: onNoteSelected,
                    modelContext: modelContext
                )
            } else {
                gridModeContent(
                    columns: columns,
                    isAllView: isAllView,
                    allItems: allItems,
                    allItemsFiltered: allItemsFiltered,
                    filteredNotes: filteredNotes,
                    searchQuery: searchQuery,
                    selectedFolderName: $selectedFolderName,
                    headerSubtitle: $headerSubtitle,
                    noteToRename: $noteToRename,
                    renameText: $renameText,
                    onNoteSelected: onNoteSelected,
                    modelContext: modelContext
                )
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
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
    
    // Add button visibility: hide on Settings, show on Home (전체 보기)
    private var shouldShowAddButton: Bool {
        // isAllView is true when selectedFolderName == "__ALL__"
        // Hide when Settings overlay is showing
        return !isShowingSettings && isAllView
    }
    
    // 🔵 추가 버튼 (Gradient + Floating)
    private var addButton: some View {
        Button {
            viewModel.addButtonTapped()
            withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [Color.secondColor, Color.secondColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(32)
        // Hide when Settings is open, show again on Home (전체 보기)
        .opacity(shouldShowAddButton ? 1 : 0)
        .allowsHitTesting(shouldShowAddButton)
        .animation(.easeInOut(duration: 0.2), value: shouldShowAddButton)
    }
    
    // 학습 기록 버튼 (우측 하단 Add 버튼 위에 위치)
    private var historyButton: some View {
        Button {
            showStudyHistory = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                Text("학습 기록")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Color.background2
                    .opacity(0.96)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
            )
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    private func createNoteTapped() {
        let newNote = Note(
            title: noteTitle,
            lastRead: Date(),
            thumbnailURL: youtubeLink
        )
        if let selected = selectedFolderName,
           selected != "__ALL__",
           let target = folders.first(where: { $0.name == selected }) {
            newNote.folder = target
        }
        modelContext.insert(newNote)
        onNoteCreated?(newNote)
        
        youtubeLink = ""
        noteTitle = ""
        
        withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = false }
    }
}

// MARK: - Consolidated App Root (moved from ContentView)
extension HomeView {
    struct AppRootView: View {
        @State private var selectedNote: Note?
        @State private var showStudyView = false
        
        var body: some View {
            ScaledContainer(baseSize: CGSize(width: 1366, height: 1024),
                            minScale: 0.78,  // 터치 최소 44pt 근사 유지용(원하면 0.75~0.85 사이 조절)
                            maxScale: 1.0,
                            alignment: .topLeading) {
                ZStack {
                    if showStudyView, let note = selectedNote {
                        StudyView(note: note) {
                            showStudyView = false
                            selectedNote = nil
                        }
                    } else {
                        HomeView(
                            onNoteSelected: { note in
                                selectedNote = note
                                withAnimation { showStudyView = true }
                            },
                            onNoteCreated: { note in
                                selectedNote = note
                                withAnimation { showStudyView = true }
                            }
                        )
                    }
                }
            }
                            .keyboardOverlay()
        }
    }
}

extension Notification.Name {
    static let showSettings = Notification.Name("ShowSettings")
    static let hideSettings = Notification.Name("HideSettings")
}


