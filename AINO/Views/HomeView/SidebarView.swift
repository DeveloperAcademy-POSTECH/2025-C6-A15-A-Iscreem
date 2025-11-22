//
//  SidebarView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    // ✅ 폴더 선택을 부모(HomeView)에 알려줄 콜백
    let onFolderSelected: ((String?) -> Void)?
    @Binding var isHelpPresented: Bool
    /// 부모(HomeView)에서 전체화면 오버레이로 삭제 확인을 띄우기 위한 콜백
    let requestDeleteConfirmation: ((Set<PersistentIdentifier>) -> Void)?
    // ✅ 홈에서 현재 선택된 카테고리(전체/최근/특정 폴더 이름)를 바인딩으로 전달받아 동기화
    @Binding var selectedFolderName: String?

    init(
        onFolderSelected: ((String?) -> Void)? = nil,
        isHelpPresented: Binding<Bool> = .constant(false),
        requestDeleteConfirmation: ((Set<PersistentIdentifier>) -> Void)? = nil,
        selectedFolderName: Binding<String?> = .constant(nil),
        folderToRename: Binding<Folder?> = .constant(nil),
            folderRenameText: Binding<String> = .constant("")
    ) {
        self.onFolderSelected = onFolderSelected
        self._isHelpPresented = isHelpPresented
        self.requestDeleteConfirmation = requestDeleteConfirmation
        self._selectedFolderName = selectedFolderName
        self._folderToRename = folderToRename
            self._folderRenameText = folderRenameText
    }
    
    @StateObject private var viewModel = SidebarViewModel()

    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]

    // Non-trashed folders only for sidebar display
    private var activeFolders: [Folder] { folders.filter { !$0.isTrashed } }

    @Binding var folderToRename: Folder?
    @Binding var folderRenameText: String
    @State private var isAddingFolder = false
    @State private var newFolderName = ""
    @FocusState private var newFolderFieldFocused: Bool
    @State private var isDeletingFolders = false
    @State private var selectedFolderIDs = Set<PersistentIdentifier>()
    @State private var showDeleteAlert = false
    @State private var pendingDeleteFolderIDs = Set<PersistentIdentifier>()

    // Glass 효과 유니온용 네임스페이스 (HomeView와 동일 스타일)
    @Namespace private var glassNS

    // 256:762 비율 유지 (사이드바:메인)
    private let sidebarRatio: CGFloat = 256.0 / (256.0 + 762.0) // ≈ 0.2514

    // ✅ 사이드바 정렬 옵션을 AppStorage로 공유(홈뷰에서 읽어 사용)
    @AppStorage("sidebarSortOption") private var sidebarSortOptionRaw: String = SortOption.dateAscending.rawValue

    // ✅ 드롭 호버링 시각 효과용 상태
    @State private var dropHoveringFolderID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            allItemsRow

            listArea

            // 하단 구분선
            HStack { Rectangle().fill(Color.borderColor).frame(height: 1) }
                .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .onChange(of: viewModel.isHelpPresented) { _, newValue in
            isHelpPresented = newValue
        }
        .onChange(of: isHelpPresented) { _, newValue in
            if newValue == false, viewModel.isHelpPresented {
                viewModel.isHelpPresented = false
            }
        }
        // ✅ 홈의 선택 상태/폴더 목록 변경 시 사이드바 하이라이트 동기화
        .onAppear {
            // 정렬 옵션 복원(AppStorage → ViewModel)
            if let saved = SortOption(rawValue: sidebarSortOptionRaw) {
                viewModel.currentSortOption = saved
            }
            viewModel.syncFromHomeSelection(selectedFolderName: selectedFolderName, folders: activeFolders)
        }
        .onChange(of: selectedFolderName) { _, newValue in
            viewModel.syncFromHomeSelection(selectedFolderName: newValue, folders: folders)
        }
        .onChange(of: folders) { _, newValue in
            viewModel.syncFromHomeSelection(selectedFolderName: selectedFolderName, folders: newValue.filter { !$0.isTrashed })
        }
        // ✅ 정렬 옵션 변경 시 AppStorage에 저장(홈뷰에서 동일 기준 사용)
        .onChange(of: viewModel.currentSortOption) { _, newValue in
            sidebarSortOptionRaw = newValue.rawValue
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        //.compactScaled(base: CGSize(width: 390, height: 844), min: 0.9, max: 1.0)
        .alert(isPresented: $showDeleteAlert) {
            let count = pendingDeleteFolderIDs.count
            let title = Text("삭제를 진행합니다")
            let message: Text = {
                if count <= 1 { return Text("선택한 폴더를 삭제합니다. 되돌릴 수 없습니다.") }
                else { return Text("선택한 \(count)개의 폴더를 삭제합니다. 되돌릴 수 없습니다.") }
            }()
            return Alert(
                title: title,
                message: message,
                primaryButton: .destructive(Text("삭제")) {
                    // 실제 삭제 처리: 휴지통으로 이동 또는 즉시 삭제 정책에 맞게 구현
                    for id in pendingDeleteFolderIDs {
                        if let folder = folders.first(where: { $0.persistentModelID == id }) {
                            // 기본 정책: 휴지통으로 이동 (isTrashed = true)
                            folder.isTrashed = true
                        }
                    }
                    try? modelContext.save()
                    pendingDeleteFolderIDs.removeAll()
                    isDeletingFolders = false
                },
                secondaryButton: .cancel(Text("취소")) {
                    pendingDeleteFolderIDs.removeAll()
                }
            )
        }
    }
}

// MARK: - Pieces

private extension SidebarView {
    // 상단 헤더(+ 버튼, 정렬 메뉴, 구분선)
    var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                addFolderButton

                Spacer()

                // ✅ 숨김 버튼을 정렬 버튼 왼쪽에, 5pt 간격으로 항상 표시
                hideSidebarButton
                    .padding(.trailing, 5)

                sortMenu
            }
            .padding(.horizontal, 20)
            // 고정 50 → 안전영역을 고려한 top 패딩
            .safeAreaPadding(.top, 12)
            .padding(.bottom, 16)
            .contentShape(Rectangle())

            // 구분선
            HStack { Rectangle().fill(Color.borderColor).frame(height: 1) }
                .padding(.horizontal, 20)
                .padding(.bottom, 12) // ← 전체 보기와의 간격 확대
        }
        .background(Color.clear)
    }

    var addFolderButton: some View {
        Button {
            isDeletingFolders = false
            selectedFolderIDs.removeAll()
            isAddingFolder = true
            newFolderName = ""
            DispatchQueue.main.async { newFolderFieldFocused = true }
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(Color.secondColor)
                .font(.system(size: 20, weight: .bold))
        }
        .buttonStyle(.plain)
        .tagTarget(.plusFolder)
    }

    // ✅ 사이드바 숨김 버튼 (정렬 버튼과 동일한 높이/스타일 느낌)
    var hideSidebarButton: some View {
        Button {
            // 부모(HomeView)에서 이 노티를 받아 실제 사이드바 토글 처리
            NotificationCenter.default.post(name: .toggleSidebar, object: nil)
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 16, weight: .semibold))
                .padding(8)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
                .clipShape(Circle())
                .tint(Color.text2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사이드바 숨기기")
    }

    var sortMenu: some View {
        Menu {
            Picker("정렬 기준", selection: $viewModel.currentSortOption) {
                Label("가나다 순(↑)", systemImage: "a.circle")
                    .tag(SortOption.nameAscending)
                Label("가나다 순(↓)", systemImage: "a.circle")
                    .tag(SortOption.nameDescending)
                Label("생성일(↑)", systemImage: "clock")
                    .tag(SortOption.dateAscending)
                Label("생성일(↓)", systemImage: "clock")
                    .tag(SortOption.dateDescending)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .padding(8)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
                .clipShape(Circle())
                .tint(Color.text2)
        }
    }

    // 고정 '전체 보기' 행
    var allItemsRow: some View {
        Button {
            viewModel.allViewTapped()
            onFolderSelected?("__ALL__")
            // 설정 오버레이 닫기 → 홈의 + 버튼 다시 보이게
            NotificationCenter.default.post(name: .hideSettings, object: nil)
        } label: {
            let isSelected = (viewModel.selection == .all)
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(isSelected ? Color.secondColor : Color.text2)
                    .font(.system(size: 20))
                Text("전체 보기")
                    .foregroundStyle(isSelected ? Color.secondColor : Color.text2)
                    .font(.buttonText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // 중간 스크롤 영역(List)
    var listArea: some View {
        List {
            foldersSection
            recentSection
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        //.padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    var foldersSection: some View {
        Section {
            ForEach(sortedFolders, id: \.persistentModelID) { folder in
                if isDeletingFolders {
                    deletingFolderRow(folder)
                } else {
                    normalFolderRow(folder)
                }
            }
            if isAddingFolder {
                addingFolderRow
            }
            if isDeletingFolders, !selectedFolderIDs.isEmpty {
                Button {
                    pendingDeleteFolderIDs = selectedFolderIDs
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("선택 삭제")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.errorColor)
                            .padding(.vertical, 6)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    func deletingFolderRow(_ folder: Folder) -> some View {
        Button {
            let id = folder.persistentModelID
            if selectedFolderIDs.contains(id) {
                selectedFolderIDs.remove(id)
            } else {
                selectedFolderIDs.insert(id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedFolderIDs.contains(folder.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selectedFolderIDs.contains(folder.persistentModelID) ? Color.secondColor : Color.text3)
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.text2)
                    .font(.system(size: 20))
                Text(folder.name)
                    .foregroundStyle(Color.text2)
                    .font(.buttonText)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }

    func normalFolderRow(_ folder: Folder) -> some View {
        Button {
            viewModel.selectFolder(folder.persistentModelID)
            onFolderSelected?(folder.name)
        } label: {
            let isSelected: Bool = {
                if case .folder(let id) = viewModel.selection {
                    return id == folder.persistentModelID
                }
                return false
            }()
            let isHoveringDrop = dropHoveringFolderID == folder.persistentModelID
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundStyle((isSelected || isHoveringDrop) ? Color.secondColor : Color.text2)
                    .font(.system(size: 20))
                Text(folder.name)
                    .foregroundStyle((isSelected || isHoveringDrop) ? Color.secondColor : Color.text2)
                    .font(.buttonText)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 32, bottom: 6, trailing: 20))
        .contextMenu {
            Button {
                folderToRename = folder
                folderRenameText = folder.name
            } label: {
                Label("이름 변경", systemImage: "pencil")
            }
            Button(role: .destructive) {
                let id = folder.persistentModelID
                pendingDeleteFolderIDs = Set([id])
                showDeleteAlert = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                folderToRename = folder
                folderRenameText = folder.name
            } label: {
                Label("이름 변경", systemImage: "pencil")
            }
            .tint(Color.secondColor)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let id = folder.persistentModelID
                pendingDeleteFolderIDs = Set([id])
                showDeleteAlert = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        // ✅ 노트 드롭을 받아서 해당 폴더로 이동
        .dropDestination(for: NoteDragItem.self) { items, _ in
            var handled = false
            for payload in items {
                if let moved = try? modelContext.model(for: payload.id) as? Note {
                    guard !moved.isTrashed, !folder.isTrashed else { continue }
                    moved.folder = folder
                    handled = true
                }
            }
            if handled {
                do { try modelContext.save() } catch {
                    print("⚠️ Sidebar drop save failed: \(error)")
                }
            }
            return handled
        } isTargeted: { hovering in
            dropHoveringFolderID = hovering ? folder.persistentModelID : nil
        }
    }

    var addingFolderRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.text2)
                .font(.system(size: 20))
            TextField("새 폴더 이름", text: $newFolderName)
                .font(.buttonText)
                .textFieldStyle(.plain)
                .focused($newFolderFieldFocused)
                .submitLabel(.done)
                .onSubmit { commitNewFolder() }
                .onAppear { newFolderFieldFocused = true }
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 32, bottom: 6, trailing: 20))
    }

    var recentSection: some View {
        Section {
            Button {
                viewModel.recentItemsTapped()
                onFolderSelected?(nil)
            } label: {
                let isSelected = (viewModel.selection == .recent)
                HStack/*(spacing: 12)*/ {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(isSelected ? Color.secondColor : Color.text2)
                        .font(.system(size: 20))
                    Text("최근 열어본 항목")
                        .foregroundStyle(isSelected ? Color.secondColor : Color.text2)
                        .font(.buttonText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 20))
        }
    }
    
    var bottomBar: some View {
        VStack(spacing: 0) {
            Button { viewModel.helpTapped() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(Color.text2).font(.system(size: 20))
                    Text("도움말").foregroundStyle(Color.text2).font(.buttonText)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Button { NotificationCenter.default.post(name: .showSettings, object: nil) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill").foregroundStyle(Color.text2).font(.system(size: 20))
                    Text("설정").foregroundStyle(Color.text2).font(.buttonText)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Button { NotificationCenter.default.post(name: .showTrash, object: nil) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash").foregroundStyle(Color.errorColor).font(.system(size: 20))
                    Text("휴지통").foregroundStyle(Color.errorColor).font(.buttonText)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        // 고정 30 → 안전영역 포함 하단 패딩
        .safeAreaPadding(.bottom, 16)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Helpers
private extension SidebarView {
    var sortedFolders: [Folder] {
        switch viewModel.currentSortOption {
        case .nameAscending:
            return activeFolders.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return activeFolders.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .dateAscending:
            return activeFolders.sorted { $0.createdAt < $1.createdAt }
        case .dateDescending:
            return activeFolders.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelAdd()
            return
        }
        // Ensure uniqueness by suffixing an index if needed
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
        cancelAdd()
    }

    func cancelAdd() {
        isAddingFolder = false
        newFolderName = ""
        newFolderFieldFocused = false
        isDeletingFolders = false
    }

    func nextFolderName(existing: [String]) -> String {
        let base = "새 폴더"
        if !existing.contains(base) { return base }
        var i = 1
        while existing.contains("\(base) \(i)") { i += 1 }
        return "\(base) \(i)"
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        let w = geometry.size.width
        let insets = geometry.safeAreaInsets
        let h = geometry.size.height - insets.top - insets.bottom
        
        NavigationSplitView {
            SidebarView(isHelpPresented: .constant(false), selectedFolderName: .constant("__ALL__"))
                .frame(height: h)
                .navigationSplitViewColumnWidth(
                    min: w * 0.25,
                    ideal: w * 0.25,
                    max: w * 0.25
                )
        } detail: {
            Color.background1.ignoresSafeArea()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/*
// MARK: - Sidebar Glass Effect Compatibility
extension View {
    /// iOS 26.0 이상에서는 시스템 glassEffect를 사용하고,
    /// 그 미만(iOS 18+ 등)에서는 불투명 카드 + 그림자 스타일로 대체
    @ViewBuilder
    func sidebarMenuGlassCompat() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            self
                .background(
                    Color.background2.opacity(0.98),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }
}
*/
// 라우팅용 노티(사이드바 토글)
extension Notification.Name {
    static let toggleSidebar = Notification.Name("ToggleSidebar")
}
