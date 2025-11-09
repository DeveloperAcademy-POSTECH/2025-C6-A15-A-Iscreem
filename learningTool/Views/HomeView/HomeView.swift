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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail
    
    let columns = [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)]
    
    @State var isHelpPresented: Bool = false
    @State var isShowingSettings: Bool = false
    @State var isFolderDeletePresented: Bool = false
    @State var folderIDsPendingDelete = Set<PersistentIdentifier>()
    @State var showResetConfirm: Bool = false
    @Namespace private var glassNS
    @AppStorage("hasSeenHomeOnboarding") private var hasSeenHomeOnboarding: Bool = false
    @State private var onboardingStep: OnboardingStep = .makeFolder

    // 휴지통 화면 표시
    @State private var isShowingTrash: Bool = false
    
    init(
        onNoteSelected: ((Note) -> Void)? = nil,
        onNoteCreated: ((Note) -> Void)? = nil
    ) {
        self.onNoteSelected = onNoteSelected
        self.onNoteCreated = onNoteCreated
    }
    
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            SidebarView(onFolderSelected: { name in
                isShowingSettings = false
                isShowingTrash = false
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
                if isShowingTrash {
                    TrashView()
                        .environmentObject(learningLogStore)
                } else {
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
                    }
                }
                if isShowingSettings {
                    SettingsDetailView(showResetConfirm: $showResetConfirm)
                        .transition(.opacity)
                        .background(Color(.systemBackground))
                }
            }
            .navigationBarBackButtonHidden(horizontalSizeClass == .compact)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 20) {
                if !isShowingTrash {
                    historyButton
                    addButton
                }
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
                // 폴더를 휴지통으로 이동
                for id in folderIDsPendingDelete {
                    if let target = folders.first(where: { $0.persistentModelID == id }) {
                        target.isTrashed = true
                        target.trashedAt = Date()
                        // 포함된 노트도 함께 휴지통으로 이동
                        for n in target.notes {
                            n.isTrashed = true
                            n.trashedAt = Date()
                        }
                    }
                }
                try? modelContext.save()
                folderIDsPendingDelete.removeAll()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFolderDeletePresented = false
                }
                // 보수적 안전망: 현재 남아있는 노트로 재동기화
                _ = learningLogStore.reconcileWithNotes(currentNotes: notes)
                // 프리로드(재실행/새로고침 후에도 동일 표시)
                learningLogStore.preloadChapterSummariesFromNotes(currentNotes: notes)
                // 세션은 보존(복원 시 그대로 사용). 영구 삭제 시에만 정리.
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSettings = true
                isShowingTrash = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSettings = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTrash)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingTrash = true
                isShowingSettings = false
            }
        }
        .onAppear {
            // 앱 시작 직후 ‘전체 보기’로 진입 → + 버튼 보이게
            if selectedFolderName == nil {
                selectedFolderName = "__ALL__"
                headerSubtitle = "전체 보기"
            }
            // 1) 세션 생성(없으면)
            _ = learningLogStore.bootstrapSessionsIfNeeded(currentNotes: notes)
            // 2) 세션 보강(빈 필드 채우기)
            _ = learningLogStore.enrichSessionsFromNotes(currentNotes: notes)
            // 3) 고아 세션 정리(노트에 없는 세션 제거)
            _ = learningLogStore.reconcileWithNotes(currentNotes: notes)
            // 4) ✅ 재실행 시에도 동일하게 보이도록, 노트 캐시로 메모리 맵 프리로드
            learningLogStore.preloadChapterSummariesFromNotes(currentNotes: notes)
        }
        .onChange(of: notes) { _, newValue in
            _ = learningLogStore.bootstrapSessionsIfNeeded(currentNotes: newValue)
            _ = learningLogStore.enrichSessionsFromNotes(currentNotes: newValue)
            _ = learningLogStore.reconcileWithNotes(currentNotes: newValue)
            // ✅ 노트 캐시 → 메모리 맵 프리로드
            learningLogStore.preloadChapterSummariesFromNotes(currentNotes: newValue)
        }
        .sheet(isPresented: $showStudyHistory) {
            StudyHistoryView()
                .environmentObject(learningLogStore)
        }
        .overlayPreferenceValue(TargetBoundsKey.self) { map in
            if !hasSeenHomeOnboarding {
                CoachOverlay(step: $onboardingStep, map: map) {
                    hasSeenHomeOnboarding = true
                }
            }
        }
    }
    // MARK: - Header View
        private var headerView: some View {
            HStack(spacing: 12) {
                // 📱 Compact (iPhone / 좁은 폭)일 때: 좌측에 리퀴드 글래스 메뉴 버튼
                if horizontalSizeClass == .compact {
                    sidebarMenuButton
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AIno")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.text1)

                    Text(headerSubtitle)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.text2)
                }

                Spacer()

                HStack(spacing: 12) {
                    // 검색바를 정렬 버튼 바로 옆에 배치 (Liquid Glass)
                    searchBar
                    sortButton
                    ViewModeToggle(selection: $viewModel.selectedViewMode) { mode in
                        viewModel.viewModeButtonTapped(mode)
                    }
                    .frame(width: 116, height: 36)
                }
                .tagTarget(.searchCluster)
            }
            .padding()
        }
        
        // MARK: - 검색바
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
                .glassEffectUnionCompat(id: "search", namespace: glassNS)
            }
        }
        
        private var sortButton: some View {
            Menu {
                // 정렬 기준 선택 (Menu + Picker)
                Picker("정렬 기준", selection: $headerSort) {
                    // HeaderSortOption은 기존 코드와 동일한 케이스명을 사용합니다.
                    Label("가나다 순(↑)", systemImage: "a.circle")
                        .tag(HeaderSortOption.alphabeticalAsc)
                    Label("가나다 순(↓)", systemImage: "a.circle")
                        .tag(HeaderSortOption.alphabeticalDesc)
                    Label("최근 열어본  항목(↑)", systemImage: "clock")
                        .tag(HeaderSortOption.recentlyOpenedAsc)
                    Label("최근 열어본 항목(↓)", systemImage: "clock")
                        .tag(HeaderSortOption.recentlyOpenedDesc)
                    Label("학습 진행률(↑)", systemImage: "progress.indicator")
                        .tag(HeaderSortOption.progressAsc)
                    Label("학습 진행률(↓)", systemImage: "progress.indicator")
                        .tag(HeaderSortOption.progressDesc)
                }

                Divider()

                // 노트 이동하기
                Button {
                    // TODO: 편집 액션 연결(시트/네비/알럿 등)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text("노트 이동하기")
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.secondColor)   // ← 텍스트+아이콘 색상 적용
                    //텍스트 색상 적용 못 시킴 (Menu { ... } 안의 항목 텍스트 색은 iOS에서 시스템이 강제합니다.)
                }
                .tint(Color.secondColor)                   // ← 일부 환경에서 아이콘 색 반영 보조
                .buttonStyle(.plain)
            } label: {
                GlassEffectContainer(spacing: 0) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .glassEffect()
                        .glassEffectUnionCompat(id: "sort", namespace: glassNS)
                }
                .tint(Color.text2)
            }
            // 기존 버튼 그림자 느낌 유지
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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
        
        // Add button visibility: 폴더 내부에서도 노트 추가 가능하도록, 설정 화면에서만 숨김
        private var shouldShowAddButton: Bool {
            return !isShowingSettings
        }
        
        // 추가 버튼
        private var addButton: some View {
            Group {
                if #available(iOS 26.0, *) {
                    // iOS 26.0 이상: 시스템 glass 버튼 스타일 사용
                    Button {
                        viewModel.addButtonTapped()
                        withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = true }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(Color.secondColor)
                    .controlSize(.large)
                } else {
                    // iOS 18+ ~ 25.x: 기존 그라디언트 원형 플로팅 버튼 사용
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
                }
            }
            .tagTarget(.fab)
            .padding(32)
            // 설정 화면에서만 숨김
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
    
    // MARK: - Sidebar Compact Menu Button (Liquid Glass)
    private var sidebarMenuButton: some View {
        Menu {
            // 전체 보기
            Button {
                headerSubtitle = "전체 보기"
                selectedFolderName = "__ALL__"
                isShowingTrash = false
                isShowingSettings = false
            } label: {
                Label("전체 보기", systemImage: "square.grid.2x2")
            }
            
            // 최근 열어본 항목
            Button {
                headerSubtitle = "최근 열어본 항목"
                selectedFolderName = nil
                isShowingTrash = false
                isShowingSettings = false
            } label: {
                Label("최근 열어본 항목", systemImage: "clock")
            }
            
            // 폴더 목록
            if !folders.isEmpty {
                Section("폴더") {
                    ForEach(folders) { folder in
                        Button {
                            headerSubtitle = folder.name
                            selectedFolderName = folder.name
                            isShowingTrash = false
                            isShowingSettings = false
                        } label: {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }
            }
            
            // 도움말 / 설정 / 휴지통
            Section {
                Button {
                    isHelpPresented = true
                } label: {
                    Label("도움말", systemImage: "questionmark.circle")
                }
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingSettings = true
                        isShowingTrash = false
                    }
                } label: {
                    Label("설정", systemImage: "gearshape")
                }
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingTrash = true
                        isShowingSettings = false
                    }
                } label: {
                    Label("휴지통", systemImage: "trash")
                }
            }
        } label: {
            GlassEffectContainer(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .glassEffect()
                    .glassEffectUnionCompat(id: "sidebar-menu", namespace: glassNS)
            }
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

    // MARK: - Glass Effect Compatibility (iOS 18+ fallback)
    extension View {
        /// iOS 26.0 이상에서는 glassEffectUnion을 적용하고,
        /// 그 미만(iOS 18+ 등)에서는 기본 스타일을 유지하는 래퍼
        @ViewBuilder
        func glassEffectUnionCompat(id: String, namespace: Namespace.ID) -> some View {
            if #available(iOS 26.0, *) {
                self.glassEffectUnion(id: id, namespace: namespace)
            } else {
                self
            }
        }
    // ... 이하 기존 내용 동일 (headerView, searchBar, sortButton, contentView, emptyState, addButton, historyButton, createNoteTapped 등)
}

// 라우팅용 노티피케이션 추가
extension Notification.Name {
    static let showSettings = Notification.Name("ShowSettings")
    static let hideSettings = Notification.Name("HideSettings")
    static let showTrash = Notification.Name("ShowTrash")
}
// MARK: - Onboarding (Coach Marks)

enum OnboardingStep: Int, CaseIterable {
    case makeFolder    // 좌상단 + 버튼 소개
    case fab           // 우하단 플로팅(노트 생성/학습 기록)
    case searchCluster // 우상단 검색/정렬/보기 전환
    case done
}

enum CoachTarget: Hashable {
    case plusFolder
    case fab
    case searchCluster
}

/// PreferenceKey to bubble up spotlight targets
struct TargetBoundsKey: PreferenceKey {
    static var defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>], nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Attach an anchor for spotlighting
    func tagTarget(_ target: CoachTarget) -> some View {
        anchorPreference(key: TargetBoundsKey.self, value: .bounds) { [target: $0] }
    }
}

/// Simple spotlight overlay
struct CoachOverlay: View {
    @Binding var step: OnboardingStep
    let map: [CoachTarget: Anchor<CGRect>]
    let onFinish: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let rect = targetRect(in: proxy)
            // Bubble position and clamping logic
            let bubbleWidth: CGFloat = min(360.0, proxy.size.width - 40.0) // 20pt horizontal margins
            let isRightEdge = rect.maxX > proxy.size.width - 60
            // Preferred X when placing bubble to the LEFT of the target
            let bubbleLeftPreferred = rect.minX - 16 - bubbleWidth / 2
            let bubbleXForLeft = max(bubbleWidth / 2 + 20, bubbleLeftPreferred)
            // Preferred X when placing bubble BELOW the target (clamped to screen)
            let bubbleXForBelow = min(max(rect.midX, bubbleWidth / 2 + 20), proxy.size.width - bubbleWidth / 2 - 20)
            let bubbleX = (step == .fab || isRightEdge) ? bubbleXForLeft : bubbleXForBelow
            // Y: below for normal, vertically centered for left placement, clamped to safe bounds
            let bubbleYBelow = min(rect.maxY + 90, proxy.size.height - 80)
            let bubbleYCentered = min(max(rect.midY, 100), proxy.size.height - 100)
            let bubbleY = (step == .fab || isRightEdge) ? bubbleYCentered : bubbleYBelow
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.95), lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                    HStack {
                        Button("건너뛰기") { onFinish() }
                        Spacer()
                        Button(nextButtonTitle) { next() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(width: bubbleWidth)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .position(x: bubbleX, y: bubbleY)
            }
        }
    }

    private func next() {
        switch step {
        case .makeFolder: step = .fab
        case .fab: step = .searchCluster
        case .searchCluster, .done: onFinish()
        }
    }

    private var nextButtonTitle: String {
        switch step {
        case .searchCluster, .done: return "완료"
        default: return "다음"
        }
    }

    private var title: String {
        switch step {
        case .makeFolder: return "폴더 만들기"
        case .fab: return "노트 생성 · 학습 기록"
        case .searchCluster: return "검색 · 정렬 · 보기 전환"
        case .done: return ""
        }
    }

    private var message: String {
        switch step {
        case .makeFolder:
            return "+ 버튼으로 폴더를 만들어요. 이름은 스와이프로 수정/삭제할 수 있어요."
        case .fab:
            return "' ' 버튼을 누르면 ‘노트 생성’과 ‘학습 기록’이 나타나요. 첫 노트를 만들어 보세요."
        case .searchCluster:
            return "이름으로 검색하고, 노트 정렬과 리스트/그리드를 여기서 바꿔요."
        case .done:
            return ""
        }
    }

    private func targetRect(in proxy: GeometryProxy) -> CGRect {
        func rect(for key: CoachTarget) -> CGRect? {
            guard let anchor = map[key] else { return nil }
            return proxy[anchor]
        }
        switch step {
        case .makeFolder:    return rect(for: .plusFolder)    ?? fallbackRect(proxy)
        case .fab:           return rect(for: .fab)           ?? fallbackRect(proxy)
        case .searchCluster: return rect(for: .searchCluster) ?? fallbackRect(proxy)
        case .done:          return fallbackRect(proxy)
        }
    }

    private func fallbackRect(_ proxy: GeometryProxy) -> CGRect {
        CGRect(x: proxy.size.width/2 - 80, y: proxy.size.height/2 - 40, width: 160, height: 80)
    }
}
