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

    init(
        onFolderSelected: ((String?) -> Void)? = nil,
        isHelpPresented: Binding<Bool> = .constant(false),
        requestDeleteConfirmation: ((Set<PersistentIdentifier>) -> Void)? = nil
    ) {
        self.onFolderSelected = onFolderSelected
        self._isHelpPresented = isHelpPresented
        self.requestDeleteConfirmation = requestDeleteConfirmation
    }
    
    @StateObject private var viewModel = SidebarViewModel()
    @State private var showSortMenu = false

    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]

    @State private var folderToRename: Folder?
    @State private var folderRenameText: String = ""
    @State private var isRenamingSheet = false
    @State private var isAddingFolder = false
    @State private var newFolderName = ""
    @FocusState private var newFolderFieldFocused: Bool
    @FocusState private var renameFieldFocused: Bool
    @State private var isDeletingFolders = false
    @State private var selectedFolderIDs = Set<PersistentIdentifier>()

    // 256:762 비율 유지 (사이드바:메인)
    private let sidebarRatio: CGFloat = 256.0 / (256.0 + 762.0) // ≈ 0.2514
    
    private var bottomBar: some View {
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

            Button { viewModel.settingsTapped() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill").foregroundStyle(Color.text2).font(.system(size: 20))
                    Text("설정").foregroundStyle(Color.text2).font(.buttonText)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Button { viewModel.trashTapped() } label: {
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
        .padding(.bottom, 30)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }


    var body: some View {
        VStack(spacing: 0) {
            // 상단 폴더 섹션
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // 폴더 추가
                    Button {
                        isDeletingFolders = false
                        selectedFolderIDs.removeAll()
                        isAddingFolder = true
                        newFolderName = ""
                        DispatchQueue.main.async { newFolderFieldFocused = true }
                    } label: {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle().fill(.white).frame(width: 12, height: 12)
                                Image(systemName: "plus")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    .buttonStyle(.plain)

                    // 폴더 삭제 (선택된 폴더)
                    Button {
                        if isDeletingFolders {
                            if !selectedFolderIDs.isEmpty {
                                // 선택이 있으면 부모에 삭제 확인 오버레이 요청
                                requestDeleteConfirmation?(selectedFolderIDs)
                            } else {
                                // 선택이 없으면 삭제 모드 종료
                                isDeletingFolders = false
                            }
                        } else {
                            // 삭제 선택 모드로 진입
                            isDeletingFolders = true
                            selectedFolderIDs.removeAll()
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle().fill(.white).frame(width: 12, height: 12)
                                Image(systemName: "minus")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    .buttonStyle(.plain)

                    // 폴더 이름 변경(선택된 폴더)
                    Button {
                        // 다른 모드 종료
                        isDeletingFolders = false
                        isAddingFolder = false
                        newFolderFieldFocused = false

                        if let selectedID = viewModel.selectedItem,
                           let target = folders.first(where: { $0.persistentModelID == selectedID }) {
                            folderToRename = target
                            folderRenameText = target.name
                            isRenamingSheet = true
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle().fill(.white).frame(width: 12, height: 12)
                                Image(systemName: "gearshape.fill")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 7))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // 정렬 버튼
                    Button { showSortMenu.toggle() } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color.secondColor)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSortMenu, arrowEdge: .top) {
                        sortMenuView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)

                // 구분선
                HStack { Rectangle().fill(Color.borderColor).frame(height: 1) }
                    .padding(.horizontal, 20)
            }
            .background(Color.clear)

            // 중간 스크롤 영역
            List {
                // 전체 보기
                Section {
                    Button {
                        viewModel.allViewTapped()
                        onFolderSelected?("__ALL__")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill").foregroundStyle(Color.text2).font(.system(size: 20))
                            Text("전체 보기").foregroundStyle(Color.text2).font(.buttonText)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }

                // 폴더 목록
                Section {
                    ForEach(sortedFolders, id: \.persistentModelID) { folder in
                        if isDeletingFolders {
                            Button {
                                let id = folder.persistentModelID
                                if selectedFolderIDs.contains(id) {
                                    selectedFolderIDs.remove(id)
                                } else {
                                    selectedFolderIDs.insert(id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    // Checkbox on the LEFT
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
                        } else {
                            Button {
                                viewModel.selectedItem = folder.persistentModelID
                                onFolderSelected?(folder.name)
                            } label: {
                                HStack(spacing: 12) {
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
                            .listRowInsets(EdgeInsets(top: 6, leading: 32, bottom: 6, trailing: 20))
                        }
                    }
                    if isAddingFolder {
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
                }

                // 최근 열어본 항목
                Section {
                    Button {
                        viewModel.recentItemsTapped()
                        onFolderSelected?(nil)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill").foregroundStyle(Color.secondColor).font(.system(size: 20))
                            Text("최근 열어본 항목").foregroundStyle(Color.secondColor).font(.buttonText)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            // 하단 구분선
            HStack { Rectangle().fill(Color.borderColor).frame(height: 1) }
                .padding(.horizontal, 20)

            // 하단 고정 메뉴 (이전 VStack 삭제, 아래에서 overlay로 대체)
        }
        .background(Color.background2)
        .overlay(alignment: .bottom) {
            bottomBar
                .zIndex(1)
        }
        .onChange(of: viewModel.isHelpPresented) { _, newValue in
            isHelpPresented = newValue
        }
        .onChange(of: isHelpPresented) { _, newValue in
            if newValue == false, viewModel.isHelpPresented {
                viewModel.isHelpPresented = false
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // 폴더 이름 변경 시트
        .sheet(isPresented: $isRenamingSheet, onDismiss: {
            // 닫힐 때 편집 상태 초기화
            folderToRename = nil
            folderRenameText = ""
        }) {
            VStack(alignment: .leading, spacing: 16) {
                Text("폴더 이름 변경").font(.title3)
                TextField("폴더 이름", text: $folderRenameText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($renameFieldFocused)
                    .onAppear { renameFieldFocused = true }
                    .onSubmit { saveRename() }
                HStack {
                    Spacer()
                    Button("취소") {
                        isRenamingSheet = false
                    }
                    Button("저장") {
                        saveRename()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 320)
        }
    }
    
    @ViewBuilder
    private var sortMenuView: some View {
        VStack(spacing: 0) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.currentSortOption = option
                    showSortMenu = false
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(viewModel.currentSortOption == option ? Color.text1 : Color.text3, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                            if viewModel.currentSortOption == option {
                                Circle().fill(Color.text1).frame(width: 10, height: 10)
                            }
                            if option == .nameAscending || option == .nameDescending {
                                Text("A")
                                    .foregroundStyle(viewModel.currentSortOption == option ? Color.text1 : Color.text3)
                                    .font(.system(size: 10, weight: .semibold))
                            } else {
                                Image(systemName: "clock")
                                    .foregroundStyle(viewModel.currentSortOption == option ? Color.text1 : Color.text3)
                                    .font(.system(size: 10))
                            }
                        }
                        Text(option.rawValue)
                            .foregroundStyle(viewModel.currentSortOption == option ? Color.text1 : Color.text3)
                            .font(.buttonText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if option != SortOption.allCases.last {
                    Divider().background(Color.borderColor).padding(.horizontal, 16)
                }
            }
        }
        .frame(width: 204, height: 145)
        .background(Color.background1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.borderColor, lineWidth: 1)
        )
        .presentationCompactAdaptation(.popover)
    }


    private var sortedFolders: [Folder] {
        switch viewModel.currentSortOption {
        case .nameAscending:
            return folders.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return folders.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .dateAscending:
            return folders.sorted { $0.createdAt < $1.createdAt }
        case .dateDescending:
            return folders.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func saveRename() {
        guard let folder = folderToRename else {
            isRenamingSheet = false
            return
        }
        let trimmed = folderRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isRenamingSheet = false
            return
        }
        // 변경 없음이면 바로 닫기
        if trimmed == folder.name {
            isRenamingSheet = false
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
        renameFieldFocused = false
        isRenamingSheet = false
    }

    
    private func commitNewFolder() {
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

    private func cancelAdd() {
        isAddingFolder = false
        newFolderName = ""
        newFolderFieldFocused = false
        isDeletingFolders = false
    }

    
    private func nextFolderName(existing: [String]) -> String {
        let base = "새 폴더"
        if !existing.contains(base) { return base }
        var i = 1
        while existing.contains("\(base) \(i)") { i += 1 }
        return "\(base) \(i)"
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        let sidebarWidth = geometry.size.width * (256.0 / (256.0 + 762.0))
        NavigationSplitView {
            SidebarView(isHelpPresented: .constant(false))
                .navigationSplitViewColumnWidth(
                    min: sidebarWidth * 0.9,
                    ideal: sidebarWidth,
                    max: sidebarWidth * 1.1
                )
        } detail: {
            Color.background1.ignoresSafeArea()
        }
        .navigationSplitViewStyle(.balanced)
    }
}
