//
//  HomeView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @State var headerSubtitle: String = ""
    @State var selectedFolderName: String? = nil
    @StateObject var viewModel = HomeViewModel()
    @State var showCreateNote = false
    @State var youtubeLink = ""
    @State var noteTitle = ""
    
    @EnvironmentObject private var learningLogStore: LearningLogStore
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var showStudyHistory: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(\.modelContext) var modelContext
    @Query(sort: [SortDescriptor(\Note.lastRead, order: .reverse)]) var notes: [Note]
    @Query var folders: [Folder]
    
    let onNoteSelected: ((Note) -> Void)?
    let onNoteCreated: ((Note) -> Void)?
    
    @State var noteToRename: Note?
    @State var renameText: String = ""
    
    // 새 폴더 생성 모달 (아이폰 전용)
    @State var showNewFolderSheet: Bool = false
    @State var newFolderName: String = ""
    @FocusState private var newFolderFieldFocused: Bool
    
    // 폴더 이름 변경 모달
    @State var showRenameFolderSheet: Bool = false
    @State var folderToRename: Folder?
    @State var folderRenameText: String = ""
    @State var folderOriginalName: String = "" // 변경 전 폴더 이름 저장
    @FocusState private var folderRenameFieldFocused: Bool
    
    @State var isKeyboardVisible: Bool = false
    @State var keyboardHeight: CGFloat = 0
    
    @State var headerSort: HeaderSortOption = .recentlyOpenedDesc
    @State var showNoteSortMenu = false
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail
    // ✅ 사이드바 표시/숨김 제어
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    
    let columns = [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)]
    
    @State var isHelpPresented: Bool = false
    @State var isShowingSettings: Bool = false
    @State var isFolderDeletePresented: Bool = false
    @State var folderIDsPendingDelete = Set<PersistentIdentifier>()
    @State var showResetConfirm: Bool = false
    @Namespace private var glassNS
    @AppStorage("hasSeenHomeOnboarding") private var hasSeenHomeOnboarding: Bool = false
    @State private var onboardingStep: OnboardingStep = .makeFolder
    @AppStorage("hasSeenHomePostNoteOnboarding") private var hasSeenHomePostNoteOnboarding: Bool = false
    @State private var postOnboardingStep: PostHomeOnboardingStep = .list
    @State private var shouldTriggerPostOnboarding: Bool = false
    @AppStorage("hasSeenFolderSidebarOnboarding") private var hasSeenFolderSidebarOnboarding: Bool = false
    @State private var folderSidebarStep: FolderSidebarOnboardingStep = .list
    @State private var showFolderSidebarOnboarding: Bool = false
    @State private var lastFolderCount: Int = 0
    
    // 휴지통 화면 표시
    @State private var isShowingTrash: Bool = false
    
    // ✅ 사이드바 정렬 옵션을 Sidebar와 동일 키로 구독 → 변경 시 즉시 재계산
    @AppStorage("sidebarSortOption") var sidebarSortOptionRaw: String = SortOption.dateAscending.rawValue
    
    // Combine
    @State private var cancellables = Set<AnyCancellable>()
    // 정렬 변경 트리거(뷰 리렌더링 유도용)
    @State private var sortChangeTick: Int = 0
    
    // ✅ ‘되돌아가기’ 스택(컴팩트 뒤로가기 복원용, 깊이 무관)
    @State private var backStack: [SelectionSnapshot] = []
    
    // Removed Environment usage for dynamic metrics; we’ll compute locally per-geometry.
    
    // ✅ 테마 적용을 위한 AppStorage (설정과 동일 키/값 사용)
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"
    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil // 시스템
        }
    }
    
    init(
        onNoteSelected: ((Note) -> Void)? = nil,
        onNoteCreated: ((Note) -> Void)? = nil
    ) {
        self.onNoteSelected = onNoteSelected
        self.onNoteCreated = onNoteCreated
    }
    
    var body: some View {
        mainContentView
            .modifier(notificationModifiers)
            .modifier(lifecycleModifiers)
            .modifier(sheetModifiers)
            .modifier(overlayModifiers)
            .preferredColorScheme(colorScheme)
    }
    
    private var notificationModifiers: NotificationModifiers {
        NotificationModifiers(
            pushCurrentSnapshot: pushCurrentSnapshot,
            handleGoBack: handleGoBack, // ✅ pass go-back handler
            isShowingSettings: $isShowingSettings,
            isShowingTrash: $isShowingTrash,
            headerSubtitle: $headerSubtitle,
            splitVisibility: $splitVisibility,
            hasSeenHomePostNoteOnboarding: hasSeenHomePostNoteOnboarding,
            notes: notes,
            shouldTriggerPostOnboarding: $shouldTriggerPostOnboarding,
            postOnboardingStep: $postOnboardingStep,
            handleYouTubeURLNotification: handleYouTubeURLNotification,
            handleAppWillEnterForeground: handleAppWillEnterForeground,
            handleAppDidBecomeActive: handleAppDidBecomeActive
        )
    }
    
    private var lifecycleModifiers: LifecycleModifiers {
        LifecycleModifiers(
            handleOnAppear: handleOnAppear,
            scenePhase: scenePhase,
            handleScenePhaseChange: handleScenePhaseChange,
            notes: notes,
            handleNotesChange: handleNotesChange,
            folders: folders,
            handleFoldersChange: handleFoldersChange,
            sidebarSortOptionRaw: sidebarSortOptionRaw,
            sortChangeTick: $sortChangeTick
        )
    }
    
    private var sheetModifiers: SheetModifiers {
        SheetModifiers(
            showStudyHistory: $showStudyHistory,
            learningLogStore: learningLogStore,
            showNewFolderSheet: $showNewFolderSheet,
            newFolderName: $newFolderName,
            setNewFolderFieldFocused: { newFolderFieldFocused = $0 },
            showRenameFolderSheet: $showRenameFolderSheet,
            folderToRename: $folderToRename,
            folderRenameText: $folderRenameText,
            folderOriginalName: $folderOriginalName,
            setFolderRenameFieldFocused: { folderRenameFieldFocused = $0 },
            newFolderSheet: AnyView(newFolderSheet),
            renameFolderSheet: AnyView(renameFolderSheet)
        )
    }
    
    private var overlayModifiers: OverlayModifiers {
        OverlayModifiers(
            hasSeenHomeOnboarding: $hasSeenHomeOnboarding,
            onboardingStep: $onboardingStep,
            shouldTriggerPostOnboarding: shouldTriggerPostOnboarding,
            hasSeenHomePostNoteOnboarding: $hasSeenHomePostNoteOnboarding,
            postOnboardingStep: $postOnboardingStep,
            shouldTriggerPostOnboardingBinding: $shouldTriggerPostOnboarding,
            showFolderSidebarOnboarding: showFolderSidebarOnboarding,
            hasSeenFolderSidebarOnboarding: $hasSeenFolderSidebarOnboarding,
            folderSidebarStep: $folderSidebarStep,
            showFolderSidebarOnboardingBinding: $showFolderSidebarOnboarding
        )
    }
    
    private var mainContentView: some View {
        GeometryReader { proxy in
            let scaler = BaseLayoutScaler(proxy: proxy, base: CGSize(width: 1366, height: 1024))
            let sidebarRatio: CGFloat = 256.0 / (256.0 + 762.0)
            let sidebarWidth = scaler.sidebarWidth(ratio: sidebarRatio)
            let metrics = createLayoutMetrics(scaler: scaler)
            
            NavigationSplitView(columnVisibility: $splitVisibility, preferredCompactColumn: $preferredCompactColumn) {
                SidebarView(onFolderSelected: { name in
                    if name == "__ALL__" {
                        applySelection(folderName: "__ALL__", subtitle: LocalizedText(korean: "전체 보기", english: "All Items").text)
                    } else if let name {
                        applySelection(folderName: name, subtitle: name)
                    } else {
                        applySelection(folderName: nil, subtitle: LocalizedText(korean: "최근 열어본 항목", english: "Recently Opened").text)
                    }
                }, isHelpPresented: $isHelpPresented, requestDeleteConfirmation: { ids in
                    folderIDsPendingDelete = ids
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFolderDeletePresented = true
                    }
                }, selectedFolderName: $selectedFolderName,
                            isShowingSettings: $isShowingSettings,
                            isShowingTrash: $isShowingTrash,
                            folderToRename: $folderToRename,
                            folderRenameText: $renameText
                )
                .navigationSplitViewColumnWidth(
                    min: sidebarWidth,
                    ideal: sidebarWidth,
                    max: sidebarWidth
                )
                .toolbar(.hidden, for: .navigationBar)
            } detail: {
                ZStack {
                    if isShowingTrash {
                        TrashView()
                            .environmentObject(learningLogStore)
                    } else {
                        VStack(spacing: 0) {
                            headerView(metrics: metrics)
                            Divider().background(Color.borderColor)
                            contentView(metrics: metrics)
                                .id(sortChangeTick)
                                .tagPostHomeTarget(.homeList)
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
                VStack(spacing: scaler.h(20)) {
                    if !isShowingTrash && !isShowingSettings {
                        historyButton
                            .padding(.bottom, horizontalSizeClass == .compact ? scaler.h(8) : 0)
                        addButton(metrics: metrics)
                    }
                }
                .padding(.leading, metrics.overlayPadding)
                .padding(.top, metrics.overlayPadding)
                .padding(.trailing, metrics.overlayPadding + (horizontalSizeClass == .compact ? metrics.overlayTrailingExtra : 0))
                .padding(.bottom, horizontalSizeClass == .compact ? scaler.h(4) : metrics.overlayPadding)
            }
        }
        .background(backgroundGradient)
        .navigationSplitViewStyle(.balanced)
        .keyboardOverlay()
        .applyOverlays(
            isHelpPresented: $isHelpPresented,
            showResetConfirm: $showResetConfirm,
            isFolderDeletePresented: $isFolderDeletePresented,
            showCreateNote: $showCreateNote,
            noteToRename: $noteToRename,
            folderToRename: $folderToRename,
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
            onFolderDeleteConfirmed: handleFolderDeleteConfirmed
        )
    }
    
    // MARK: - View Modifiers
    private struct NotificationModifiers: ViewModifier {
        let pushCurrentSnapshot: () -> Void
        let handleGoBack: () -> Void // ✅ new closure
        @Binding var isShowingSettings: Bool
        @Binding var isShowingTrash: Bool
        @Binding var headerSubtitle: String
        @Binding var splitVisibility: NavigationSplitViewVisibility
        let hasSeenHomePostNoteOnboarding: Bool
        let notes: [Note]
        @Binding var shouldTriggerPostOnboarding: Bool
        @Binding var postOnboardingStep: PostHomeOnboardingStep
        let handleYouTubeURLNotification: (Notification) -> Void
        let handleAppWillEnterForeground: () -> Void
        let handleAppDidBecomeActive: () -> Void
        
        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
                    pushCurrentSnapshot()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingSettings = true
                        isShowingTrash = false
                        headerSubtitle = LocalizedText(korean: "설정", english: "Settings").text
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .hideSettings)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingSettings = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .showTrash)) { _ in
                    pushCurrentSnapshot()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingTrash = true
                        isShowingSettings = false
                        headerSubtitle = LocalizedText(korean: "휴지통", english: "Trash").text
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .hideTrash)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingTrash = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        splitVisibility = (splitVisibility == .all) ? .detailOnly : .all
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .goBack)) { _ in
                    // ✅ delegate to HomeView via closure
                    handleGoBack()
                }
                .onReceive(NotificationCenter.default.publisher(for: .returnedFromStudyView)) { _ in
                    if !hasSeenHomePostNoteOnboarding && !notes.isEmpty {
                        shouldTriggerPostOnboarding = true
                        postOnboardingStep = .list
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .handleYouTubeURL)) { notification in
                    handleYouTubeURLNotification(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: .appWillEnterForeground)) { _ in
                    handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
                    handleAppDidBecomeActive()
                }
        }
    }
    
    private struct LifecycleModifiers: ViewModifier {
        let handleOnAppear: () -> Void
        let scenePhase: ScenePhase
        let handleScenePhaseChange: (ScenePhase, ScenePhase) -> Void
        let notes: [Note]
        let handleNotesChange: ([Note], [Note]) -> Void
        let folders: [Folder]
        let handleFoldersChange: ([Folder], [Folder]) -> Void
        let sidebarSortOptionRaw: String
        @Binding var sortChangeTick: Int
        
        func body(content: Content) -> some View {
            content
                .onAppear {
                    handleOnAppear()
                }
                .onChange(of: scenePhase) { newPhase in
                    handleScenePhaseChange(scenePhase, newPhase)
                }
                .onChange(of: notes) { newValue in
                    handleNotesChange(notes, newValue)
                }
                .onChange(of: folders) { newValue in
                    handleFoldersChange(folders, newValue)
                }
                .onChange(of: sidebarSortOptionRaw) { _ in
                    sortChangeTick &+= 1
                }
        }
    }
    
    private struct SheetModifiers: ViewModifier {
        @Binding var showStudyHistory: Bool
        let learningLogStore: LearningLogStore
        @Binding var showNewFolderSheet: Bool
        @Binding var newFolderName: String
        let setNewFolderFieldFocused: (Bool) -> Void
        @Binding var showRenameFolderSheet: Bool
        @Binding var folderToRename: Folder?
        @Binding var folderRenameText: String
        @Binding var folderOriginalName: String
        let setFolderRenameFieldFocused: (Bool) -> Void
        let newFolderSheet: AnyView
        let renameFolderSheet: AnyView
        
        func body(content: Content) -> some View {
            content
                .overlay {
                    if showStudyHistory {
                        GeometryReader { proxy in
                            ZStack {
                                // Dimmed background
                                Color.black.opacity(0.35)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            showStudyHistory = false
                                        }
                                    }
                                
                                // Centered modal card
                                StudyHistoryView()
                                    .environmentObject(learningLogStore)
                                    .frame(
                                        width: proxy.size.width * 0.8,
                                        height: proxy.size.height * 0.7
                                    )
                                    .background(Color.background1)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 12)
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                showStudyHistory = false
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .padding(8)
                                                .background(Color.black.opacity(0.35))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(12)
                                    }
                            }
                        }
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(2)
                    }
                }
                .sheet(isPresented: $showNewFolderSheet, onDismiss: {
                    newFolderName = ""
                    setNewFolderFieldFocused(false)
                }) {
                    newFolderSheet
                }
                .onChange(of: showNewFolderSheet) { _, isPresented in
                    if isPresented {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            setNewFolderFieldFocused(true)
                        }
                    }
                }
                .sheet(isPresented: $showRenameFolderSheet, onDismiss: {
                    folderToRename = nil
                    folderRenameText = ""
                    folderOriginalName = ""
                    setFolderRenameFieldFocused(false)
                }) {
                    renameFolderSheet
                }
        }
    }
    
    private struct OverlayModifiers: ViewModifier {
        @Binding var hasSeenHomeOnboarding: Bool
        @Binding var onboardingStep: OnboardingStep
        let shouldTriggerPostOnboarding: Bool
        @Binding var hasSeenHomePostNoteOnboarding: Bool
        @Binding var postOnboardingStep: PostHomeOnboardingStep
        @Binding var shouldTriggerPostOnboardingBinding: Bool
        let showFolderSidebarOnboarding: Bool
        @Binding var hasSeenFolderSidebarOnboarding: Bool
        @Binding var folderSidebarStep: FolderSidebarOnboardingStep
        @Binding var showFolderSidebarOnboardingBinding: Bool
        
        func body(content: Content) -> some View {
            content
                .overlayPreferenceValue(TargetBoundsKey.self) { map in
                    if !hasSeenHomeOnboarding {
                        CoachOverlay(step: $onboardingStep, map: map) {
                            hasSeenHomeOnboarding = true
                            onboardingStep = .done
                        }
                        .transition(.opacity)
                    }
                }
                .overlayPreferenceValue(PostHomeTargetBoundsKey.self) { map in
                    if shouldTriggerPostOnboarding && !hasSeenHomePostNoteOnboarding {
                        PostHomeCoachOverlay(step: $postOnboardingStep, map: map) {
                            hasSeenHomePostNoteOnboarding = true
                            shouldTriggerPostOnboardingBinding = false
                            postOnboardingStep = .done
                        }
                        .transition(.opacity)
                    }
                }
                .overlay {
                    if showFolderSidebarOnboarding && !hasSeenFolderSidebarOnboarding {
                        SidebarCoachOverlay(step: $folderSidebarStep) {
                            hasSeenFolderSidebarOnboarding = true
                            showFolderSidebarOnboardingBinding = false
                            folderSidebarStep = .done
                        }
                        .transition(.opacity)
                    }
                }
        }
    }
    
    // MARK: - Helper Methods
    private func createLayoutMetrics(scaler: BaseLayoutScaler) -> LayoutMetrics {
        LayoutMetrics(
            searchMinWidth: scaler.w(220),
            searchMaxWidth: scaler.w(320),
            searchHeight: scaler.h(36),
            sortButtonSize: scaler.uni(36),
            toggleWidth: scaler.w(116),
            toggleHeight: scaler.h(36),
            addButtonLegacyDiameter: scaler.h(60),
            addButtonLegacyIcon: scaler.h(50),
            addButtonModernSide: scaler.h(60),
            addButtonModernIcon: horizontalSizeClass == .compact ? scaler.h(32) : scaler.h(28),
            overlayPadding: scaler.uni(32),
            menuButtonSide: scaler.h(36),
            controlMinSide: scaler.uni(92),
            controlIconPadding: scaler.uni(6),
            compactHeaderRowSpacing: scaler.h(12),
            compactHeaderBottomPadding: horizontalSizeClass == .compact ? scaler.h(12) : scaler.h(8),
            overlayTrailingExtra: (horizontalSizeClass == .compact ? scaler.w(40) : 0)
        )
    }
    
    private var backgroundGradient: some View {
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
    
    private func handleYouTubeURLNotification(_ notification: Notification) {
        print("📬 [HomeView] ========== handleYouTubeURL notification received ==========")
        print("📬 [HomeView] Notification userInfo: \(notification.userInfo ?? [:])")
        if let urlString = notification.userInfo?["url"] as? String {
            let title = notification.userInfo?["title"] as? String
            print("📬 [HomeView] URL = \(urlString), Title = \(title ?? "nil")")
            print("📬 [HomeView] Current notes count before: \(notes.count)")
            handleYouTubeURL(urlString, title: title)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("📬 [HomeView] Current notes count after: \(notes.count)")
            }
        } else {
            print("❌ [HomeView] No URL in notification userInfo")
        }
        print("📬 [HomeView] ========== handleYouTubeURL notification processed ==========")
    }
    
    // MARK: - Header View
    @ViewBuilder private func headerView(metrics: LayoutMetrics) -> some View {
        if horizontalSizeClass == .compact {
            // 📱 iPhone: 두 줄 레이아웃 (1행: 메뉴/제목/토글, 2행: 검색바 + 정렬)
            VStack(alignment: .leading, spacing: metrics.compactHeaderRowSpacing) {
                // Row 1: (뒤로가기) + 메뉴 버튼 + 제목 + 보기 토글
                HStack(spacing: 8) {
                    if showCompactBackButton {
                        backButton(metrics: metrics)
                    }
                    sidebarMenuButton(metrics: metrics)
                        .layoutPriority(2)
                    
                    Button {
                        // 폴더가 선택되어 있고, 전체 보기나 최근 열어본 항목이 아닐 때만 이름 변경 가능
                        if let folderName = selectedFolderName,
                           folderName != "__ALL__",
                           let folder = folders.first(where: { $0.name == folderName }) {
                            folderToRename = folder
                            folderRenameText = folder.name
                            folderOriginalName = folder.name // 변경 전 이름 저장
                            showRenameFolderSheet = true
                        }
                    } label: {
                        Text(headerSubtitle)
                            .padding(.leading, 6)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.text1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedFolderName == nil || selectedFolderName == "__ALL__" || headerSubtitle == LocalizedText(korean: "최근 열어본 항목", english: "Recently Opened").text || headerSubtitle == LocalizedText(korean: "설정", english: "Settings").text || headerSubtitle == LocalizedText(korean: "휴지통", english: "Trash").text)
                    
                    Spacer()
                    
                    // Place toggle inside a fixed-width column, left-aligned with sort button below
                    HStack {
                        ViewModeToggle(selection: $viewModel.selectedViewMode) { mode in
                            viewModel.viewModeButtonTapped(mode)
                        }
                        .frame(height: metrics.toggleHeight)
                        .frame(width: max(metrics.toggleWidth, metrics.controlMinSide), alignment: .trailing)
                        .layoutPriority(2)
                    }
                }
                
                // Row 2: 검색바 + 정렬 버튼 (정렬 버튼을 검색바 오른쪽에 배치)
                HStack(spacing: 8) {
                    searchBar(metrics: metrics)
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                    
                    // Wrap sort button in a fixed-width trailing column
                    HStack {
                        sortButton(metrics: metrics)
                            .frame(width: max(metrics.toggleWidth, metrics.controlMinSide), alignment: .trailing)
                            .layoutPriority(2)
                    }
                }
                .tagPostHomeTarget(.searchCluster)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, metrics.compactHeaderBottomPadding)
            .safeAreaPadding([.top, .horizontal])
        } else {
            // 💻 iPad/Regular: 기존 단일 행 레이아웃 유지
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if horizontalSizeClass != .compact {
                        
                    }
                    Button {
                        // 폴더가 선택되어 있고, 전체 보기나 최근 열어본 항목이 아닐 때만 이름 변경 가능
                        if let folderName = selectedFolderName,
                           folderName != "__ALL__",
                           let folder = folders.first(where: { $0.name == folderName }) {
                            folderToRename = folder
                            folderRenameText = folder.name
                            folderOriginalName = folder.name // 변경 전 이름 저장
                            showRenameFolderSheet = true
                        }
                    } label: {
                        Text(headerSubtitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.text2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedFolderName == nil || selectedFolderName == "__ALL__" || headerSubtitle == LocalizedText(korean: "최근 열어본 항목", english: "Recently Opened").text || headerSubtitle == LocalizedText(korean: "설정", english: "Settings").text || headerSubtitle == LocalizedText(korean: "휴지통", english: "Trash").text)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // 검색바를 정렬 버튼 바로 옆에 배치 (Liquid Glass)
                    searchBar(metrics: metrics)
                        .layoutPriority(0)
                    
                    // ✅ 사이드바 숨김/펼침 버튼 (정렬 버튼 왼쪽, 간격 5)
                    
                    sortButton(metrics: metrics)
                        .layoutPriority(2)
                    
                    ViewModeToggle(selection: $viewModel.selectedViewMode) { mode in
                        viewModel.viewModeButtonTapped(mode)
                    }
                    .frame(width: metrics.toggleWidth, height: metrics.toggleHeight)
                    .layoutPriority(2)
                }
                .tagTarget(.searchCluster)
                .tagPostHomeTarget(.searchCluster)
            }
            .padding()
            .safeAreaPadding([.top, .horizontal])
        }
    }
    
    // ✅ 컴팩트 뒤로가기 버튼 노출 조건
    private var showCompactBackButton: Bool {
        guard horizontalSizeClass == .compact else { return false }
        // 폴더 내부이거나(최근/전체 제외) 설정/휴지통 화면일 때 노출
        let inFolder = (selectedFolderName != nil && selectedFolderName != "__ALL__")
        //        let inOverlay = (isShowingSettings || isShowingTrash)
        //        // 오버레이(설정/휴지통)는 항상 뒤로가기 노출, 폴더는 스택이 있을 때만 노출
        //        if inOverlay { return true }
        return inFolder && !backStack.isEmpty
    }
    
    // ✅ 컴팩트 뒤로가기 버튼
    private func backButton(metrics: LayoutMetrics) -> some View {
        Button {
            if let snap = backStack.popLast() {
                restore(from: snap)
            } else {
                // 스택이 없으면 오버레이만 닫기 (설정/휴지통에서 뒤로가기 동작 보장)
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isShowingSettings { isShowingSettings = false }
                    if isShowingTrash { isShowingTrash = false }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.background2.opacity(0.96))
                    .frame(width: metrics.controlMinSide, height: metrics.controlMinSide)
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.text2)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("뒤로가기")
    }
    
    // ✅ 현재 화면 상태를 스택에 저장
    private func pushCurrentSnapshot() {
        let snap = SelectionSnapshot(
            folderName: selectedFolderName,
            subtitle: headerSubtitle,
            screen: PreviousScreenState(
                searchText: viewModel.searchText,
                viewMode: viewModel.selectedViewMode,
                headerSort: headerSort,
                splitVisibility: splitVisibility
            )
        )
        backStack.append(snap)
    }
    
    // ✅ 선택 적용 유틸(현재 상태를 push → 새 선택 세팅)
    func applySelection(folderName: String?, subtitle: String) {
        // 현재 화면 상태 스냅샷을 스택에 push
        pushCurrentSnapshot()
        // 새 선택 적용
        setSelection(folderName: folderName, subtitle: subtitle)
    }
    
    // ✅ 스냅샷 복원(스택 push 없이 상태만 복구)
    private func restore(from snap: SelectionSnapshot) {
        selectedFolderName = snap.folderName
        headerSubtitle = snap.subtitle
        viewModel.searchText = snap.screen.searchText
        viewModel.selectedViewMode = snap.screen.viewMode
        headerSort = snap.screen.headerSort
        splitVisibility = snap.screen.splitVisibility
        isShowingTrash = false
        isShowingSettings = false
    }
    
    // ✅ 내부 세터(스택 관여 없이 현재 상태만 세팅)
    private func setSelection(folderName: String?, subtitle: String) {
        selectedFolderName = folderName
        headerSubtitle = subtitle
        isShowingTrash = false
        isShowingSettings = false
    }
    
    // ✅ 사이드바 숨김/펼침 버튼
    private func sidebarToggleButton(metrics: LayoutMetrics) -> some View {
        Group {
            // 컴팩트 사이즈에서는 제외
            if horizontalSizeClass == .compact {
                EmptyView()
            } else {
                GlassEffectContainer(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // .all ↔︎ .detailOnly 토글
                            splitVisibility = (splitVisibility == .all) ? .detailOnly : .all
                        }
                    } label: {
                        // 심볼: 사이드바 토글 느낌
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.text2)
                            .frame(width: metrics.sortButtonSize, height: metrics.sortButtonSize)
                    }
                    .buttonStyle(.plain)
                    .glassEffect()
                    .glassEffectUnionCompat(id: "sidebar-toggle", namespace: glassNS)
                    .accessibilityLabel(splitVisibility == .all ? "사이드바 숨기기" : "사이드바 보이기")
                }
            }
        }
    }
    
    // MARK: - 검색바
    private func searchBar(metrics: LayoutMetrics) -> some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.text3)
                TextField(LocalizedText(korean: "노트 검색", english: "Search Notes").text, text: $viewModel.searchText, axis: .horizontal)
                    .font(.system(size: 16))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(
                minWidth: horizontalSizeClass == .compact ? 0 : metrics.searchMinWidth,
                maxWidth: horizontalSizeClass == .compact ? .infinity : metrics.searchMaxWidth
            )
            .frame(height: metrics.searchHeight)
            .glassEffect()
            .glassEffectUnionCompat(id: "search", namespace: glassNS)
        }
        .layoutPriority(0)
    }
    
    private func sortButton(metrics: LayoutMetrics) -> some View {
        Menu {
            // 정렬 기준 선택 (Menu + Picker)
            Picker("정렬 기준", selection: $headerSort) {
                // HeaderSortOption은 기존 코드와 동일한 케이스명을 사용합니다.
                Label(LocalizedText(korean: "가나다 순(↑)", english: "A-Z (↑)").text, systemImage: "a.circle")
                    .tag(HeaderSortOption.alphabeticalAsc)
                Label(LocalizedText(korean: "가나다 순(↓)", english: "A-Z (↓)").text, systemImage: "a.circle")
                    .tag(HeaderSortOption.alphabeticalDesc)
                Label(LocalizedText(korean: "최근 열어본 항목(↑)", english: "Recently Opened (↑)").text, systemImage: "clock")
                    .tag(HeaderSortOption.recentlyOpenedAsc)
                Label(LocalizedText(korean: "최근 열어본 항목(↓)", english: "Recently Opened (↓)").text, systemImage: "clock")
                    .tag(HeaderSortOption.recentlyOpenedDesc)
                Label(LocalizedText(korean: "학습 진행률(↑)", english: "Progress (↑)").text, systemImage: "progress.indicator")
                    .tag(HeaderSortOption.progressAsc)
                Label(LocalizedText(korean: "학습 진행률(↓)", english: "Progress (↓)").text, systemImage: "progress.indicator")
                    .tag(HeaderSortOption.progressDesc)
            }
        } label: {
            Group {
                if horizontalSizeClass == .compact {
                    // iPhone
                    ZStack {
                        Circle()
                            .fill(Color.background2.opacity(0.96))
                            .frame(width: metrics.controlMinSide, height: metrics.controlMinSide)
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: metrics.controlMinSide * 0.44, weight: .semibold))
                            .foregroundStyle(Color.text2)
                    }
                    .contentShape(Circle())
                } else {
                    // iPad
                    GlassEffectContainer(spacing: 0) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: metrics.sortButtonSize * 0.48, weight: .semibold))
                            .frame(width: metrics.sortButtonSize, height: metrics.sortButtonSize)
                            .glassEffect()
                            .glassEffectUnionCompat(id: "sort", namespace: glassNS)
                    }
                }
            }
        }
        .tint(Color.text2)
        // 기존 버튼 그림자 느낌 유지
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Content View
    private func contentView(metrics: LayoutMetrics) -> some View {
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
                    folderToRename: $folderToRename, // ✅ 누락되었던 인자 추가
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
                    folderToRename: $folderToRename,
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
            Text(LocalizedText(korean: "아직은 노트가 없어요!", english: "No notes yet!").text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.text3)
            
            Text(LocalizedText(korean: "하단 추가 버튼을 눌러서 첫 학습을 시작해 보세요!", english: "Tap the add button at the bottom to start your first learning!").text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.text3)
            
            Spacer()
                .frame(height: 12)
            
            Text(LocalizedText(korean: "사용법을 알고 싶으신가요?", english: "Want to know how to use it?").text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.text3)
            
            HStack(spacing: 4) {
                Text(LocalizedText(korean: "좌측 하단의", english: "Click the").text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.text3)
                
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.text3)
                
                Text(LocalizedText(korean: "도움말 버튼을 클릭해 보세요!", english: "Help button at the bottom left!").text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.text3)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -50)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // Add button visibility: 폴더 내부에서도 노트 추가 가능하도록, 설정 화면에서만 숨김
    private var shouldShowAddButton: Bool {
        return !isShowingSettings
    }
    
    // 추가 버튼
    private func addButton(metrics: LayoutMetrics) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                // iOS 26.0 이상: 시스템 glass 버튼 스타일 사용 (아이콘 크기 메트릭 적용)
                Button {
                    viewModel.addButtonTapped()
                    withAnimation(.easeInOut(duration: 0.2)) { showCreateNote = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: metrics.addButtonModernIcon, weight: .semibold))
                        .frame(width: metrics.addButtonModernSide, height: metrics.addButtonModernSide)
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
                        .font(.system(size: metrics.addButtonLegacyIcon, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: metrics.addButtonLegacyDiameter, height: metrics.addButtonLegacyDiameter)
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
        // Note: outer padding for this button is applied in the overlay above using metrics.overlayPadding
        .opacity(shouldShowAddButton ? 1 : 0)
        .allowsHitTesting(shouldShowAddButton)
        .animation(.easeInOut(duration: 0.2), value: shouldShowAddButton)
        .tagTarget(.fab)
    }
    
    // 학습 기록 버튼 (우측 하단 Add 버튼 위에 위치)
    private var historyButton: some View {
        Button {
            showStudyHistory = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.bodyTextSemibold)
                Text(LocalizedText(korean: "학습 기록", english: "Learning History").text)
                    .font(.bodyTextSemibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    
    // MARK: - Sidebar Compact Menu Button
    private func sidebarMenuButton(metrics: LayoutMetrics) -> some View {
        Menu {
            // 전체 보기
            Button {
                applySelection(folderName: "__ALL__", subtitle: LocalizedText(korean: "전체 보기", english: "All Items").text)
            } label: {
                Label(LocalizedText(korean: "전체 보기", english: "All Items").text, systemImage: "square.grid.2x2")
            }
            
            // 최근 열어본 항목
            Button {
                applySelection(folderName: nil, subtitle: LocalizedText(korean: "최근 열어본 항목", english: "Recently Opened").text)
            } label: {
                Label(LocalizedText(korean: "최근 열어본 항목", english: "Recently Opened").text, systemImage: "clock")
            }
            
            // 폴더 추가
            Button {
                createNewFolderAndSelect()
            } label: {
                Label(LocalizedText(korean: "새 폴더 만들기", english: "New Folder").text, systemImage: "folder.badge.plus")
            }
            
            // 폴더 목록
            if !folders.isEmpty {
                Section(LocalizedText(korean: "폴더", english: "Folders").text) {
                    ForEach(folders) { folder in
                        Button {
                            applySelection(folderName: folder.name, subtitle: folder.name)
                        } label: {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }
            }
            
            // 도움말 / 설정 / 휴지통
            Section {
                Button {
                    // 설정으로 들어가기 직전 push
                    pushCurrentSnapshot()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingSettings = true
                        isShowingTrash = false
                        headerSubtitle = LocalizedText(korean: "설정", english: "Settings").text
                    }
                } label: {
                    Label(LocalizedText(korean: "설정", english: "Settings").text, systemImage: "gearshape")
                }
                
                Button {
                    // 휴지통으로 들어가기 직전 push
                    pushCurrentSnapshot()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingTrash = true
                        isShowingSettings = false
                        headerSubtitle = LocalizedText(korean: "휴지통", english: "Trash").text
                    }
                } label: {
                    Label(LocalizedText(korean: "휴지통", english: "Trash").text, systemImage: "trash")
                }
                
                Button {
                    isHelpPresented = true
                } label: {
                    Label(LocalizedText(korean: "도움말", english: "Help").text, systemImage: "questionmark.circle")
                }
            }
        } label: {
            Group {
                if horizontalSizeClass == .compact {
                    ZStack {
                        Circle()
                            .fill(Color.background2.opacity(0.96))
                            .frame(width: metrics.controlMinSide, height: metrics.controlMinSide)
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.text2)
                    }
                    .contentShape(Circle())
                    .tagTarget(.plusFolder)
                } else {
                    GlassEffectContainer(spacing: 0) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: metrics.menuButtonSide, height: metrics.menuButtonSide)
                            .glassEffect()
                            .glassEffectUnionCompat(id: "sidebar-menu", namespace: glassNS)
                    }
                }
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
    
    // 새 폴더 생성 후 즉시 선택
    private func createNewFolderAndSelect() {
        // 아이폰에서는 모달을 띄우고, 아이패드에서는 기존 방식 유지
        if horizontalSizeClass == .compact {
            // 아이폰: 모달 표시
            newFolderName = ""
            showNewFolderSheet = true
        } else {
            // 아이패드: 기존 방식 (사이드바에 인라인 입력)
            // 중복 방지 이름 생성
            let existing = Set(folders.map { $0.name })
            let base = LocalizedText(korean: "새 폴더", english: "New Folder").text
            var finalName = base
            if existing.contains(finalName) {
                var i = 1
                while existing.contains("\(base) \(i)") { i += 1 }
                finalName = "\(base) \(i)"
            }
            let folder = Folder(name: finalName)
            modelContext.insert(folder)
            try? modelContext.save()
            // 생성 직전 화면 상태 스냅샷 + 선택 적용
            applySelection(folderName: folder.name, subtitle: folder.name)
        }
    }
    
    // 새 폴더 생성 모달에서 폴더 생성
    private func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showNewFolderSheet = false
            newFolderName = ""
            return
        }
        // 중복 방지 이름 생성
        var finalName = trimmed
        let existing = Set(folders.map { $0.name })
        if existing.contains(finalName) {
            var i = 1
            while existing.contains("\(finalName) \(i)") { i += 1 }
            finalName = "\(finalName) \(i)"
        }
        let folder = Folder(name: finalName)
        modelContext.insert(folder)
        try? modelContext.save()
        showNewFolderSheet = false
        newFolderName = ""
        // 생성 직전 화면 상태 스냅샷 + 선택 적용
        applySelection(folderName: folder.name, subtitle: folder.name)
    }
    
    // 폴더 이름 변경
    private func saveFolderRename() {
        guard let folder = folderToRename else {
            showRenameFolderSheet = false
            folderRenameText = ""
            return
        }
        let trimmed = folderRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showRenameFolderSheet = false
            folderRenameText = ""
            return
        }
        // 변경 없음이면 바로 닫기
        if trimmed == folder.name {
            showRenameFolderSheet = false
            folderRenameText = ""
            return
        }
        // 현재 폴더를 제외한 기존 이름 집합
        let otherNames = Set(folders.filter { $0.persistentModelID != folder.persistentModelID }.map { $0.name })
        
        // 중복 방지: 동일 이름이 있으면 숫자 접미사 부여
        var finalName = trimmed
        if otherNames.contains(finalName) {
            var i = 1
            while otherNames.contains("\(finalName) \(i)") { i += 1 }
            finalName = "\(finalName) \(i)"
        }
        
        folder.name = finalName
        try? modelContext.save()
        folderRenameFieldFocused = false
        showRenameFolderSheet = false
        folderRenameText = ""
        // 헤더 제목과 선택된 폴더 이름도 업데이트 (변경 전 이름과 비교)
        if selectedFolderName == folderOriginalName {
            selectedFolderName = finalName
            headerSubtitle = finalName
        }
        folderOriginalName = ""
    }
    
    // MARK: - YouTube URL Handling
    private func handleYouTubeURL(_ urlString: String, title: String? = nil) {
        print("🎯 handleYouTubeURL called with URL: \(urlString), Title: \(title ?? "nil")")
        
        // YouTube URL 정규화 (공백 제거 등)
        let normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📝 Normalized URL: \(normalizedURL)")
        
        // YouTube URL인지 다시 한 번 확인
        guard isYouTubeURL(normalizedURL) else {
            print("❌ URL is not a valid YouTube URL")
            return
        }
        
        // 제목 설정 (전달된 제목이 있으면 사용, 없으면 기본 제목 생성)
        let finalTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? generateDefaultTitle(from: normalizedURL)
        print("📝 Final title: \(finalTitle)")
        
        // 노트 자동 생성
        createNoteFromShare(url: normalizedURL, title: finalTitle)
    }
    
    // Scene Phase 변경 핸들러 (SwiftUI의 직접적인 생명주기 감지)
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        print("🔄 [HomeView] ========== Scene Phase 변경 감지 ==========")
        print("🔄 [HomeView] 이전 Phase: \(oldPhase)")
        print("🔄 [HomeView] 새로운 Phase: \(newPhase)")
        
        switch newPhase {
        case .active:
            print("✅ [HomeView] Scene이 활성화되었습니다 (active)")
            print("📱 [HomeView] ========== 앱이 포그라운드로 돌아옴 (Scene Phase: active) ==========")
            checkForSharedURLInHomeView()
        case .inactive:
            print("⏸️ [HomeView] Scene이 비활성화되었습니다 (inactive)")
        case .background:
            print("🔙 [HomeView] Scene이 백그라운드로 이동했습니다 (background)")
        @unknown default:
            print("❓ [HomeView] 알 수 없는 Scene Phase: \(newPhase)")
        }
    }
    
    // 앱 생명주기 이벤트 핸들러 (UIApplicationDelegate를 통한 감지)
    private func handleAppWillEnterForeground() {
        print("📱 [HomeView] ========== 앱이 포그라운드로 돌아옴 (UIApplicationDelegate: appWillEnterForeground) ==========")
        checkForSharedURLInHomeView()
    }
    
    private func handleAppDidBecomeActive() {
        print("📱 [HomeView] ========== 앱이 활성화됨 (UIApplicationDelegate: appDidBecomeActive) ==========")
        checkForSharedURLInHomeView()
    }
    
    // MARK: - Handler Methods
    private func handleOnAppear() {
        if selectedFolderName == nil {
            setSelection(folderName: "__ALL__", subtitle: LocalizedText(korean: "전체 보기", english: "All Items").text)
        }
        _ = learningLogStore.bootstrapSessionsIfNeeded(currentNotes: notes)
        _ = learningLogStore.enrichSessionsFromNotes(currentNotes: notes)
        _ = learningLogStore.reconcileWithNotes(currentNotes: notes)
        learningLogStore.preloadChapterSummariesFromNotes(currentNotes: notes)
        if !hasSeenHomeOnboarding {
            onboardingStep = (horizontalSizeClass == .compact ? .makeFolderIphone : .makeFolder)
        }
        lastFolderCount = folders.count
        if !hasSeenHomePostNoteOnboarding && !notes.isEmpty {
            shouldTriggerPostOnboarding = true
            postOnboardingStep = .list
        }
        setupCombinePipelines()
    }
    
    private func handleNotesChange(oldValue: [Note], newValue: [Note]) {
        print("🔄 [HomeView] Notes changed: \(oldValue.count) -> \(newValue.count)")
        _ = learningLogStore.bootstrapSessionsIfNeeded(currentNotes: newValue)
        _ = learningLogStore.enrichSessionsFromNotes(currentNotes: newValue)
        _ = learningLogStore.reconcileWithNotes(currentNotes: newValue)
        learningLogStore.preloadChapterSummariesFromNotes(currentNotes: newValue)
        if !hasSeenHomePostNoteOnboarding && oldValue.isEmpty && !newValue.isEmpty {
            shouldTriggerPostOnboarding = true
            postOnboardingStep = .list
        }
    }
    
    private func handleFoldersChange(oldValue: [Folder], newValue: [Folder]) {
        if !hasSeenFolderSidebarOnboarding && newValue.count > oldValue.count {
            showFolderSidebarOnboarding = true
            folderSidebarStep = .list
        }
        lastFolderCount = newValue.count
    }
    
    // 폴더 삭제 확인 핸들러
    private func handleFolderDeleteConfirmed() {
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
    
    // HomeView에서 직접 App Group UserDefaults 확인
    private func checkForSharedURLInHomeView() {
        print("🔍 [HomeView] ========== UserDefaults 확인 시작 ==========")
        print("🔍 [HomeView] App Group UserDefaults를 확인하여 추가할 항목이 있는지 검사합니다...")
        
        let userDefaults = UserDefaults(suiteName: "group.site.eifer.app.learningTool")
        
        if userDefaults == nil {
            print("❌ [HomeView] App Group UserDefaults가 nil입니다. App Group 설정을 확인하세요.")
            print("🔍 [HomeView] ========== UserDefaults 확인 종료 (App Group 없음) ==========")
            return
        }
        
        guard let sharedURL = userDefaults?.string(forKey: "sharedYouTubeURL") else {
            print("🔍 [HomeView] 추가할 항목이 없습니다. (sharedYouTubeURL이 없음)")
            print("🔍 [HomeView] ========== UserDefaults 확인 종료 (항목 없음) ==========")
            return
        }
        
        let sharedTitle = userDefaults?.string(forKey: "sharedYouTubeTitle") ?? ""
        let timestamp = userDefaults?.double(forKey: "sharedYouTubeTimestamp") ?? 0
        let lastProcessed = UserDefaults.standard.double(forKey: "lastProcessedYouTubeTimestamp")
        
        print("✅ [HomeView] 추가할 항목을 발견했습니다!")
        print("📬 [HomeView] URL: \(sharedURL)")
        print("📬 [HomeView] 제목: '\(sharedTitle)'")
        print("📬 [HomeView] 타임스탬프: \(timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : Date())")
        print("📬 [HomeView] 마지막 처리 타임스탬프: \(lastProcessed > 0 ? Date(timeIntervalSince1970: lastProcessed) : Date(timeIntervalSince1970: 0))")
        
        // 중복 처리 방지
        if timestamp > 0 && timestamp <= lastProcessed {
            print("⚠️ [HomeView] 이미 처리된 항목입니다. 건너뜁니다.")
            print("🔍 [HomeView] ========== UserDefaults 확인 종료 (이미 처리됨) ==========")
            return
        }
        
        print("📝 [HomeView] 항목을 추가하는 중...")
        
        // 즉시 UserDefaults에서 삭제 (중복 방지)
        userDefaults?.removeObject(forKey: "sharedYouTubeURL")
        userDefaults?.removeObject(forKey: "sharedYouTubeTitle")
        userDefaults?.removeObject(forKey: "sharedYouTubeTimestamp")
        userDefaults?.synchronize()
        print("🗑️ [HomeView] UserDefaults에서 항목 데이터를 삭제했습니다.")
        
        // 타임스탬프 업데이트
        let newTimestamp = timestamp > 0 ? timestamp : Date().timeIntervalSince1970
        UserDefaults.standard.set(newTimestamp, forKey: "lastProcessedYouTubeTimestamp")
        UserDefaults.standard.synchronize()
        print("📝 [HomeView] 마지막 처리 타임스탬프를 업데이트했습니다.")
        
        // 노트 생성
        let notesCountBefore = notes.count
        print("📝 [HomeView] 노트 생성 전 현재 노트 개수: \(notesCountBefore)")
        handleYouTubeURL(sharedURL, title: sharedTitle)
        
        // 목록 리프레시를 위한 처리
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // ModelContext의 pending changes 처리
            self.modelContext.processPendingChanges()
            print("🔄 [HomeView] ModelContext의 pending changes를 처리했습니다.")
            
            // 노트 개수 확인
            let notesCountAfter = self.notes.count
            print("📝 [HomeView] 노트 생성 후 현재 노트 개수: \(notesCountAfter)")
            
            if notesCountAfter > notesCountBefore {
                print("✅ [HomeView] 노트가 성공적으로 추가되었습니다! (개수: \(notesCountBefore) → \(notesCountAfter))")
                print("🔄 [HomeView] 목록이 자동으로 리프레시됩니다. (@Query가 자동 업데이트)")
            } else {
                print("⚠️ [HomeView] 노트 개수가 변경되지 않았습니다. 확인이 필요합니다.")
            }
            
            print("✅ [HomeView] ========== UserDefaults 확인 및 항목 추가 완료 ==========")
        }
    }
    
    // Share Extension에서 공유받은 URL로 노트 자동 생성
    private func createNoteFromShare(url: String, title: String) {
        print("📝 [HomeView] ========== createNoteFromShare START ==========")
        print("📝 [HomeView] URL: \(url)")
        print("📝 [HomeView] Title: \(title)")
        
        // 메인 스레드에서 실행 보장
        guard Thread.isMainThread else {
            print("⚠️ [HomeView] Not on main thread, dispatching to main thread")
            DispatchQueue.main.async {
                self.createNoteFromShare(url: url, title: title)
            }
            return
        }
        
        // 제목이 비어있으면 기본 제목 생성
        let noteTitle = title.isEmpty ? generateDefaultTitle(from: url) : title
        print("📝 [HomeView] Note title: \(noteTitle)")
        
        let newNote = Note(
            title: noteTitle,
            lastRead: Date(),
            thumbnailURL: url,
            videoURL: url
        )
        print("📝 [HomeView] Note object created: \(newNote.title)")
        
        // 현재 선택된 폴더가 있으면 해당 폴더에 추가
        if let selected = selectedFolderName,
           selected != "__ALL__",
           let target = folders.first(where: { $0.name == selected }) {
            newNote.folder = target
            print("📝 [HomeView] Note assigned to folder: \(selected)")
        } else {
            print("📝 [HomeView] Note assigned to root (no folder selected)")
        }
        
        // ModelContext에 삽입
        modelContext.insert(newNote)
        print("📝 [HomeView] Note inserted into modelContext")
        
        // 저장 시도
        do {
            // Pending changes 처리
            modelContext.processPendingChanges()
            print("📝 [HomeView] Processed pending changes")
            
            // 저장
            try modelContext.save()
            print("✅ [HomeView] Note saved successfully: \(noteTitle)")
            
            // 저장 후 다시 pending changes 처리 (UI 업데이트 보장)
            modelContext.processPendingChanges()
            print("📝 [HomeView] Processed pending changes after save")
            
            // @Query가 업데이트되도록 명시적으로 트리거
            // SwiftData의 @Query는 자동으로 업데이트되어야 하지만, 때로는 명시적 트리거가 필요
            print("📝 [HomeView] Current notes count before callback: \(notes.count)")
            
            // SwiftData의 @Query가 업데이트되도록 약간의 지연 후 콜백 호출
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("📝 [HomeView] Current notes count after delay: \(notes.count)")
                print("📝 [HomeView] Calling onNoteCreated callback")
                self.onNoteCreated?(newNote)
                print("📝 [HomeView] Callback completed")
                
                // 추가 확인: @Query가 업데이트되었는지 확인
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("📝 [HomeView] Final notes count check: \(notes.count)")
                    if !notes.contains(where: { $0.videoURL == url }) {
                        print("⚠️ [HomeView] WARNING: New note not found in @Query!")
                        print("   This might indicate a @Query update issue")
                    } else {
                        print("✅ [HomeView] New note found in @Query - UI should update")
                    }
                }
            }
            
            print("✅ [HomeView] ========== createNoteFromShare END (Success) ==========")
        } catch {
            print("❌ [HomeView] Note save failed: \(error.localizedDescription)")
            print("❌ [HomeView] Error details: \(error)")
            print("❌ [HomeView] ========== createNoteFromShare END (Error) ==========")
        }
    }
    
    // YouTube URL에서 기본 제목 생성
    private func generateDefaultTitle(from url: String) -> String {
        // URL에서 비디오 ID 추출 시도
        if let videoID = extractVideoID(from: url) {
            return "YouTube 노트 - \(videoID)"
        }
        return "YouTube 노트"
    }
    
    // YouTube URL에서 비디오 ID 추출
    private func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        // youtu.be/<id>
        if url.host?.contains("youtu.be") == true {
            return url.lastPathComponent
        }
        
        // youtube.com/watch?v=<id>
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoID
        }
        
        // youtube.com/shorts/<id>
        if url.path.contains("/shorts/") {
            return url.path.components(separatedBy: "/shorts/").last?.components(separatedBy: "/").first
        }
        
        // youtube.com/live/<id>
        if url.path.contains("/live/") {
            return url.path.components(separatedBy: "/live/").last?.components(separatedBy: "/").first
        }
        
        return nil
    }
    
    private func isYouTubeURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("youtube.com") ||
        lowercased.contains("youtu.be") ||
        lowercased.contains("youtube.com/watch") ||
        lowercased.contains("youtube.com/shorts") ||
        lowercased.contains("youtube.com/live")
    }
    
    // MARK: - Combine pipelines
    private func setupCombinePipelines() {
        // 1) UserDefaults.didChange → sidebarSortOption 변경 감지
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: nil)
            .map { _ in
                UserDefaults.standard.string(forKey: "sidebarSortOption") ?? SortOption.dateAscending.rawValue
            }
            .removeDuplicates()
            .sink { _ in
                // 정렬 변경 → 안전한 리렌더 트리거
                sortChangeTick &+= 1
            }
            .store(in: &cancellables)
        
        // 2) Removed: @AppStorage Binding is not a Combine Publisher.
        // Use .onChange(of: sidebarSortOptionRaw) in the view instead.
    }
    
    // MARK: - Modal Sheets
    private var newFolderSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedText(korean: "새 폴더 이름을 입력하세요", english: "Enter folder name").text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.text2)
                    .padding(.top, 8)
                
                TextField(LocalizedText(korean: "폴더 이름", english: "Folder Name").text, text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($newFolderFieldFocused)
                    .onSubmit {
                        commitNewFolder()
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(LocalizedText(korean: "새 폴더 만들기", english: "New Folder").text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedText(korean: "취소", english: "Cancel").text) {
                        showNewFolderSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedText(korean: "완료", english: "Done").text) {
                        commitNewFolder()
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
    
    private var renameFolderSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("폴더 이름을 변경하세요")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.text2)
                    .padding(.top, 8)
                
                TextField("폴더 이름", text: $folderRenameText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($folderRenameFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            folderRenameFieldFocused = true
                        }
                    }
                    .onSubmit {
                        saveFolderRename()
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("폴더 이름 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        showRenameFolderSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveFolderRename()
                    }
                    .disabled(folderRenameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
    
    // ✅ Centralized go-back handler used by NotificationModifiers
    private func handleGoBack() {
        // 직전 화면 스냅샷이 있으면 복원
        if let snap = backStack.popLast() {
            restore(from: snap)
        } else {
            // 스냅샷이 없으면 설정/휴지통 오버레이만 닫기
            withAnimation(.easeInOut(duration: 0.2)) {
                if isShowingSettings { isShowingSettings = false }
                if isShowingTrash { isShowingTrash = false }
            }
        }
    }
}

// MARK: - Dynamic metrics simple container (no Environment)
extension HomeView {
    struct LayoutMetrics {
        var searchMinWidth: CGFloat = 220
        var searchMaxWidth: CGFloat = 320
        var searchHeight: CGFloat = 36
        var sortButtonSize: CGFloat = 36
        var toggleWidth: CGFloat = 116
        var toggleHeight: CGFloat = 36
        var addButtonLegacyDiameter: CGFloat = 60
        var addButtonLegacyIcon: CGFloat = 30
        var addButtonModernSide: CGFloat = 44
        var addButtonModernIcon: CGFloat = 22
        var overlayPadding: CGFloat = 32
        var menuButtonSide: CGFloat = 100
        var controlMinSide: CGFloat = 44
        var controlIconPadding: CGFloat = 6
        var compactHeaderRowSpacing: CGFloat = 8
        var compactHeaderBottomPadding: CGFloat = 8
        var overlayTrailingExtra: CGFloat = 0
    }
    
    // 폴더 진입 직전 화면 스냅샷
    struct PreviousScreenState {
        var searchText: String
        var viewMode: HomeViewModel.ViewMode
        var headerSort: HeaderSortOption
        var splitVisibility: NavigationSplitViewVisibility
    }
    
    // ✅ 선택 + 화면 상태를 함께 보관하는 스냅샷(되돌아가기 스택 요소)
    struct SelectionSnapshot {
        var folderName: String?
        var subtitle: String
        var screen: PreviousScreenState
    }
}

// MARK: - Consolidated App Root (moved from ContentView)
extension HomeView {
    struct AppRootView: View {
        @State private var selectedNote: Note?
        @State private var showStudyView = false
        
        // ✅ 설정 테마를 AppRoot에도 적용(StudyView 포함 전체에 반영)
        @AppStorage("selectedTheme") private var selectedTheme: String = "system"
        private var colorScheme: ColorScheme? {
            switch selectedTheme {
            case "light": return .light
            case "dark":  return .dark
            default:      return nil
            }
        }
        
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        
        var body: some View {
            Group {
                if horizontalSizeClass == .compact {
                    // 📱 iPhone / compact width: 기존처럼 ScaledContainer 사용
                    ScaledContainer(baseSize: CGSize(width: 1366, height: 1024),
                                    minScale: 0.78,  // 터치 최소 44pt 근사 유지용
                                    maxScale: 1.0,
                                    alignment: .topLeading) {
                        ZStack {
                            if showStudyView, let note = selectedNote {
                                StudyView(note: note) {
                                    showStudyView = false
                                    selectedNote = nil
                                    // 홈으로 복귀 알림 → HomeView에서 포스트 온보딩 재무장
                                    NotificationCenter.default.post(name: .returnedFromStudyView, object: nil)
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
                } else {
                    // 💻 iPad / regular width / Mac: 전체 화면에 NavigationSplitView를 그대로 사용
                    ZStack {
                        if showStudyView, let note = selectedNote {
                            StudyView(note: note) {
                                showStudyView = false
                                selectedNote = nil
                                NotificationCenter.default.post(name: .returnedFromStudyView, object: nil)
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
            }
            .keyboardOverlay()
            .preferredColorScheme(colorScheme)
            .onOpenURL { url in
                print("🔗 [HomeView] ========== onOpenURL CALLED ==========")
                print("🔗 [HomeView] URL: \(url.absoluteString)")
                print("🔗 [HomeView] Scheme: \(url.scheme ?? "nil")")
                print("🔗 [HomeView] Host: \(url.host ?? "nil")")
                handleIncomingURL(url)
            }
        }
        
        // MARK: - URL Handling
        private func handleIncomingURL(_ url: URL) {
            print("🔗 [HomeView] handleIncomingURL called with: \(url.absoluteString)")
            var urlString: String?
            var titleString: String?
            
            // aino://share?url=... 형식 처리
            if url.scheme == "aino" && url.host == "share" {
                print("✅ [HomeView] URL matches aino://share pattern")
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    if let sharedURL = queryItems.first(where: { $0.name == "url" })?.value {
                        urlString = sharedURL.removingPercentEncoding ?? sharedURL
                        print("✅ [HomeView] Extracted URL: \(urlString ?? "nil")")
                    }
                    if let sharedTitle = queryItems.first(where: { $0.name == "title" })?.value {
                        titleString = sharedTitle.removingPercentEncoding ?? sharedTitle
                        print("✅ [HomeView] Extracted Title: \(titleString ?? "nil")")
                    }
                }
            } else {
                // 일반 URL 처리
                urlString = url.absoluteString
                print("🔗 [HomeView] Treating as direct URL: \(urlString ?? "nil")")
            }
            
            guard let finalURL = urlString, isYouTubeURL(finalURL) else {
                print("❌ [HomeView] URL is not valid YouTube URL: \(urlString ?? "nil")")
                return
            }
            
            print("✅ [HomeView] Valid YouTube URL, posting notification")
            var userInfo: [String: Any] = ["url": finalURL]
            if let title = titleString {
                userInfo["title"] = title
            }
            
            // YouTube URL을 NotificationCenter를 통해 HomeView에 전달
            NotificationCenter.default.post(
                name: .handleYouTubeURL,
                object: nil,
                userInfo: userInfo
            )
            print("📤 [HomeView] Notification posted with userInfo: \(userInfo)")
        }
        
        private func isYouTubeURL(_ urlString: String) -> Bool {
            let lowercased = urlString.lowercased()
            return lowercased.contains("youtube.com") ||
            lowercased.contains("youtu.be") ||
            lowercased.contains("youtube.com/watch") ||
            lowercased.contains("youtube.com/shorts") ||
            lowercased.contains("youtube.com/live")
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
}

// 라우팅용 노티피케이션 추가
extension Notification.Name {
    static let showSettings = Notification.Name("ShowSettings")
    static let hideSettings = Notification.Name("HideSettings")
    static let showTrash = Notification.Name("ShowTrash")
    static let hideTrash = Notification.Name("HideTrash")
    static let returnedFromStudyView = Notification.Name("ReturnedFromStudyView")
    static let goBack = Notification.Name("GoBack")
    static let handleYouTubeURL = Notification.Name("HandleYouTubeURL")
}
// MARK: - Onboarding (Coach Marks)

enum OnboardingStep: Int, CaseIterable {
    case makeFolder           // (iPad 등) 좌상단 + 버튼 소개
    case makeFolderIphone     // (iPhone compact) 메뉴 → 새 폴더 만들기 안내
    case fab                  // 우하단 플로팅(노트 생성/학습 기록)
    case searchCluster        // 우상단 검색/정렬/보기 전환
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
            // ✅ 강조 영역을 타깃보다 조금 더 크게
            let highlightPadding: CGFloat = 12
            let highlightRect = rect.insetBy(dx: -highlightPadding, dy: -highlightPadding)
            
            // Bubble position and clamping logic
            let bubbleWidth: CGFloat = min(360.0, proxy.size.width - 40.0)
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
                // ✅ 내부는 뚫고(회색 제외), 크기는 highlightRect 사용
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: highlightRect.width, height: highlightRect.height)
                            .position(x: highlightRect.midX, y: highlightRect.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
                
                // ✅ 테두리도 highlightRect 기준
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.clear, lineWidth: 2)
                    .frame(width: highlightRect.width, height: highlightRect.height)
                    .position(x: highlightRect.midX, y: highlightRect.midY)
                
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
        case .makeFolder, .makeFolderIphone:
            step = .fab
        case .fab:
            step = .searchCluster
        case .searchCluster, .done:
            onFinish()
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
        case .makeFolder, .makeFolderIphone: return "폴더 만들기"
        case .fab: return LocalizedText(korean: "노트 생성 · 학습 기록", english: "Create Note · Learning History").text
        case .searchCluster: return LocalizedText(korean: "검색 · 정렬 · 보기 전환", english: "Search · Sort · View Toggle").text
        case .done: return ""
        }
    }
    
    private var message: String {
        switch step {
        case .makeFolder:
            return "+ 버튼을 누르면 학습노트를 담을 수 있는 폴더를 생성할 수 있습니다."
        case .makeFolderIphone:
            return "새 폴더 만들기  메뉴를 누르면 학습노트를 담을 수 있는 폴더를 생성할 수 있습니다."
        case .fab:
            return LocalizedText(korean: "우하단 버튼을 누르면 '노트 생성'과 '학습 기록'이 나타나요. 첫 노트를 만들어 보세요.", english: "Tap the bottom right button to see 'Create Note' and 'Learning History'. Create your first note!").text
        case .searchCluster:
            return LocalizedText(korean: "이름으로 검색하고, 노트 정렬과 리스트/그리드 보기로 여기서 바꿔요.", english: "Search by name, and change note sorting and list/grid view here.").text
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
        case .makeFolder:       return rect(for: .plusFolder)    ?? fallbackRect(proxy)
        case .makeFolderIphone: return rect(for: .plusFolder)    ?? fallbackRect(proxy)
        case .fab:              return rect(for: .fab)           ?? fallbackRect(proxy)
        case .searchCluster:    return rect(for: .searchCluster) ?? fallbackRect(proxy)
        case .done:             return fallbackRect(proxy)
        }
    }
    
    private func fallbackRect(_ proxy: GeometryProxy) -> CGRect {
        CGRect(x: proxy.size.width/2 - 80, y: proxy.size.height/2 - 40, width: 160, height: 80)
    }
}


// MARK: - Post-First-Note Onboarding (Home)

enum PostHomeOnboardingStep: Int, CaseIterable {
    case list        // 노트 목록 안내
    case controls    // 검색/정렬/보기 전환 안내
    case done
}

enum PostHomeCoachTarget: Hashable {
    case homeList
    case searchCluster
}

struct PostHomeTargetBoundsKey: PreferenceKey {
    static var defaultValue: [PostHomeCoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [PostHomeCoachTarget: Anchor<CGRect>], nextValue: () -> [PostHomeCoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func tagPostHomeTarget(_ target: PostHomeCoachTarget) -> some View {
        anchorPreference(key: PostHomeTargetBoundsKey.self, value: .bounds) { [target: $0] }
    }
}

struct PostHomeCoachOverlay: View {
    @Binding var step: PostHomeOnboardingStep
    let map: [PostHomeCoachTarget: Anchor<CGRect>]
    let onFinish: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            let rect = targetRect(in: proxy)
            
            // ✅ 강조 영역 확장
            let highlightPadding: CGFloat = 12
            let highlightRect = rect.insetBy(dx: -highlightPadding, dy: -highlightPadding)
            
            // bubble size & smart position
            let bubbleWidth: CGFloat = min(360.0, proxy.size.width - 40.0)
            
            // 기본 위치 계산(controls 단계 등)
            let nearRight = rect.maxX > proxy.size.width - 60
            let placeLeft = (step == .controls && nearRight)
            
            let xBelow = min(max(rect.midX, bubbleWidth/2 + 20), proxy.size.width - bubbleWidth/2 - 20)
            let xLeft  = max(bubbleWidth/2 + 20, rect.minX - 16 - bubbleWidth/2)
            
            let yBelow = min(rect.maxY + 90, proxy.size.height - 80)
            let yAbove = max(rect.minY - 90, 100)
            
            // 📱 .list 단계에서는 homeList 하이라이트 중앙에 버블을 배치
            let (bubbleX, bubbleY): (CGFloat, CGFloat) = {
                if step == .list {
                    return (highlightRect.midX, highlightRect.midY)
                } else {
                    // 목록은 상단 공간 충분하면 위, 아니면 아래 / 컨트롤은 기본 아래
                    let x = placeLeft ? xLeft : xBelow
                    let y = (step == .controls) ? yBelow : (rect.minY < 140 ? yBelow : yAbove)
                    return (x, y)
                }
            }()
            
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: highlightRect.width, height: highlightRect.height)
                            .position(x: highlightRect.midX, y: highlightRect.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.clear, lineWidth: 2)
                    .frame(width: highlightRect.width, height: highlightRect.height)
                    .position(x: highlightRect.midX, y: highlightRect.midY)
                
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text(message)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .list:     step = .controls
        case .controls, .done:
            onFinish()
        }
    }
    
    private var nextButtonTitle: String {
        switch step {
        case .controls, .done: return "완료"
        default: return "다음"
        }
    }
    
    private var title: String {
        switch step {
        case .list:     return "노트 목록"
        case .controls: return LocalizedText(korean: "검색 · 정렬 · 보기 전환", english: "Search · Sort · View Toggle").text
        case .done:     return ""
        }
    }
    
    private var message: String {
        switch step {
        case .list:
            return "방금 만든 노트가 여기 목록에 표시돼요. 목록에서 노트를 눌러 학습을 이어가요."
        case .controls:
            return LocalizedText(korean: "여기서 이름으로 검색하고, 정렬을 바꾸고, 리스트/그리드 보기로 전환할 수 있어요.", english: "Here you can search by name, change sorting, and switch between list/grid view.").text
        case .done:
            return ""
        }
    }
    
    private func targetRect(in proxy: GeometryProxy) -> CGRect {
        func rect(for key: PostHomeCoachTarget) -> CGRect? {
            guard let anchor = map[key] else { return nil }
            return proxy[anchor]
        }
        switch step {
        case .list:     return rect(for: .homeList)      ?? fallback(proxy)
        case .controls: return rect(for: .searchCluster) ?? fallback(proxy)
        case .done:     return fallback(proxy)
        }
    }
    
    private func fallback(_ proxy: GeometryProxy) -> CGRect {
        CGRect(x: proxy.size.width/2 - 80, y: proxy.size.height/2 - 40, width: 160, height: 80)
    }
}


// MARK: - Sidebar (Folder/List/Sort) Onboarding

enum FolderSidebarOnboardingStep: Int, CaseIterable {
    case list           // 생성된 폴더가 좌측 목록에 표시됨
    case recentButton   // '최근 열어본 항목' 버튼 (폴더 목록 아래)
    case sort           // 사이드바 정렬 아이콘 안내
    case tips           // 탭/스와이프 팁
    case done
}

struct SidebarCoachOverlay: View {
    @Binding var step: FolderSidebarOnboardingStep
    let onFinish: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            // 좌측 사이드바 영역 (NavigationSplitView 설정: min 280, ideal 320, max 400)
            let leftWidth = min(max(proxy.size.width * 0.24, 280), 400)
            let sidebarTop = proxy.safeAreaInsets.top + 8
            let headerHeight: CGFloat = 44
            let itemHeight: CGFloat = 40
            let pad: CGFloat = 12
            
            // 1) 전체 사이드바(기본)
            let fullSidebarRect = CGRect(x: 0,
                                         y: sidebarTop - 4,
                                         width: leftWidth,
                                         height: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 8)
                .insetBy(dx: -pad, dy: -pad)
            
            // 2) '최근 열어본 항목' 버튼 영역(폴더 목록 아래에 고정된 버튼 영역을 근사)
            let recentButtonRect = CGRect(x: 8,
                                          y: sidebarTop + headerHeight + 6,
                                          width: max(leftWidth - 16, 120),
                                          height: itemHeight)
                .insetBy(dx: -8, dy: -6)
            
            // 3) 정렬 아이콘(+ 오른쪽 상단)
            let sortIconSize: CGFloat = 32
            let sortIconRect = CGRect(x: max(8, leftWidth - sortIconSize - 12),
                                      y: sidebarTop,
                                      width: sortIconSize,
                                      height: sortIconSize)
                .insetBy(dx: -6, dy: -6)
            
            // 단계별 하이라이트 대상
            let highlightRect: CGRect = {
                switch step {
                case .list:         return fullSidebarRect
                case .recentButton: return recentButtonRect
                case .sort:         return sortIconRect
                case .tips, .done:  return fullSidebarRect
                }
            }()
            
            // 말풍선 가로폭과 위치(사이드바 오른쪽 공간에 배치)
            let bubbleWidth: CGFloat = min(360.0, proxy.size.width - 40.0)
            let bubbleX = min(leftWidth + bubbleWidth/2 + 24, proxy.size.width - bubbleWidth/2 - 20)
            let bubbleY: CGFloat = {
                switch step {
                case .list:          return max(120, proxy.safeAreaInsets.top + 100)
                case .recentButton:  return max(180, proxy.safeAreaInsets.top + 140)
                case .sort:          return max(220, proxy.safeAreaInsets.top + 160)
                case .tips, .done:   return max(260, proxy.safeAreaInsets.top + 180)
                }
            }()
            
            ZStack {
                // Dim background with a "hole" over the sidebar area
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: highlightRect.width, height: highlightRect.height)
                            .position(x: highlightRect.midX, y: highlightRect.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
                
                // Bubble
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(message)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if step == .tips {
                        VStack(alignment: .leading, spacing: 8) {
                            // 이름 변경(우측으로 스와이프)
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 36)
                                HStack(spacing: 10) {
                                    Image(systemName: "folder")
                                    Text("예시 폴더")
                                        .font(.system(size: 14))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .foregroundStyle(.white.opacity(0.9))
                                // Leading action preview (이름 변경)
                                Capsule()
                                    .fill(Color.blue.opacity(0.85))
                                    .frame(width: 88, height: 26)
                                    .overlay(Text("이름 변경").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
                                    .shadow(radius: 2, y: 1)
                                    .offset(x: -((bubbleWidth/2) - 68)) // 좌측에 고정 미리보기 느낌
                            }
                            
                            // 삭제(좌측으로 스와이프)
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 36)
                                HStack(spacing: 10) {
                                    Image(systemName: "folder")
                                    Text("예시 폴더")
                                        .font(.system(size: 14))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .foregroundStyle(.white.opacity(0.9))
                                // Trailing action preview (삭제)
                                Capsule()
                                    .fill(Color.red.opacity(0.9))
                                    .frame(width: 64, height: 26)
                                    .overlay(Text("삭제").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
                                    .shadow(radius: 2, y: 1)
                                    .offset(x: ((bubbleWidth/2) - 52)) // 우측에 고정 미리보기 느낌
                            }
                        }
                        .padding(.top, 6)
                    }
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
        case .list:          step = .recentButton
        case .recentButton:  step = .sort
        case .sort:          step = .tips
        case .tips, .done:   onFinish()
        }
    }
    
    private var nextButtonTitle: String {
        switch step {
        case .tips, .done: return "완료"
        default: return "다음"
        }
    }
    
    private var title: String {
        switch step {
        case .list:          return LocalizedText(korean: "폴더 목록", english: "Folder List").text
        case .recentButton:  return LocalizedText(korean: "최근 열어본 항목", english: "Recently Opened").text
        case .sort:          return LocalizedText(korean: "정렬 바꾸기", english: "Change Sort").text
        case .tips:          return LocalizedText(korean: "빠른 사용 팁", english: "Quick Tips").text
        case .done:          return ""
        }
    }
    
    private var message: String {
        switch step {
        case .list:
            return LocalizedText(korean: "생성된 폴더는 좌측에 **목록으로 표시**됩니다. 폴더를 탭하면 해당 폴더 안의 노트를 볼 수 있어요.", english: "Created folders are **displayed as a list** on the left. Tap a folder to view notes inside it.").text
        case .recentButton:
            return LocalizedText(korean: "'최근 열어본 항목'은 **폴더 목록 바로 아래에 있는 버튼**이에요. 여기에는 **최근에 열어본 노트만** 표시됩니다. '전체 보기'로 이동하면 **노트와 폴더를 함께** 볼 수 있어요. (정렬과는 **별개** 동작입니다.)", english: "'Recently Opened' is a **button right below the folder list**. It shows **only recently opened notes**. Go to 'All Items' to see **notes and folders together**. (This is **separate** from sorting.)").text
        case .sort:
            return LocalizedText(korean: "사이드바 상단 **+ 버튼의 오른쪽에 있는 정렬 아이콘**을 누르면 메뉴가 열려요. 여기서 **가나다 순(↑/↓)**, **생성일(↑/↓)** 중 선택해 **폴더/노트 표시 순서**를 바꿀 수 있어요. (※ '최근 열어본 항목' 버튼과는 **별개**입니다.)", english: "Tap the **sort icon to the right of the + button** at the top of the sidebar to open the menu. Choose from **A-Z (↑/↓)**, **Date (↑/↓)** to change the **folder/note display order**. (※ This is **separate** from the 'Recently Opened' button.)").text
        case .tips:
            return LocalizedText(korean: "폴더 이름을 **오른쪽으로 스와이프 → 이름 변경**, **왼쪽으로 스와이프 → 삭제** 할 수 있어요.", english: "Swipe folder names **right → rename**, **left → delete**.").text
        case .done:
            return ""
        }
    }
}

