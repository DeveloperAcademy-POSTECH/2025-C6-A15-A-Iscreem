//
//  SidebarView.swift
//  learningtool
//
//  Created by 이헤빈 on 11/3/25.
//

import SwiftUI
import SwiftData

@available(iOS 18.0, *)
struct SidebarView: View {
    let onFolderSelected: ((String?) -> Void)?
    @Binding var isHelpPresented: Bool
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

    // 이제 외부에서 주입된 viewModel 사용
    @EnvironmentObject var viewModel: SidebarViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name, order: .forward) private var folders: [Folder]

    @State private var isAddingFolder = false
    @State private var isDeletingFolders = false
    @State private var selectedFolderIDs = Set<PersistentIdentifier>()
    @State private var newFolderName = ""
    @FocusState private var newFolderFieldFocused: Bool
    @State private var showSortMenu = false

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            Color.background1.ignoresSafeArea()
        }
        .navigationSplitViewStyle(.balanced)
        .backgroundExtensionEffect()
    }
}

// MARK: - Sidebar Content
@available(iOS 18.0, *)
private extension SidebarView {
    var sidebarContent: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 0)
                .fill(.thinMaterial)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 0))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                folderList
                Divider().padding(.horizontal, 20)
                if isDeletingFolders {
                    deleteControls
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bottomBar
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: Header
    var headerSection: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation {
                    isAddingFolder.toggle()
                    isDeletingFolders = false
                    if isAddingFolder { DispatchQueue.main.async { newFolderFieldFocused = true } }
                }
            } label: {
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondColor)
            }

            Button {
                withAnimation {
                    isDeletingFolders.toggle()
                    if !isDeletingFolders { selectedFolderIDs.removeAll() }
                }
            } label: {
                Image(systemName: "folder.fill.badge.minus")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondColor)
            }

            Button {
                viewModel.settingsTapped()
            } label: {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondColor)
            }

            Spacer()

            Button {
                showSortMenu.toggle()
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondColor)
            }
            .popover(isPresented: $showSortMenu) { sortMenuView }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: Folder List
    var folderList: some View {
        List {
            Section {
                Button {
                    onFolderSelected?("__ALL__")
                } label: {
                    Label("전체 보기", systemImage: "square.grid.2x2.fill")
                        .font(.buttonText)
                        .foregroundStyle(Color.text2)
                        .listRowBackground(Color.clear)
                }
                .buttonStyle(.plain)

                if isAddingFolder {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill").foregroundStyle(Color.text2)
                        TextField("새 폴더 이름", text: $newFolderName)
                            .focused($newFolderFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { commitNewFolder() }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(folders, id: \.persistentModelID) { folder in
                    HStack {
                        if isDeletingFolders {
                            Image(systemName: selectedFolderIDs.contains(folder.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedFolderIDs.contains(folder.persistentModelID) ? .blue : .gray)
                                .onTapGesture {
                                    toggleFolderSelection(folder)
                                }
                        }

                        Button {
                            if !isDeletingFolders {
                                onFolderSelected?(folder.name)
                            } else {
                                toggleFolderSelection(folder)
                            }
                        } label: {
                            Label(folder.name, systemImage: "folder.fill")
                                .font(.buttonText)
                                .foregroundStyle(Color.text2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    onFolderSelected?(nil)
                } label: {
                    Label("최근 열어본 항목", systemImage: "clock.fill")
                        .font(.buttonText)
                        .foregroundStyle(Color.text2)
                        .listRowBackground(Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: 삭제/취소 버튼
    var deleteControls: some View {
        VStack(spacing: 8) {
            Divider().padding(.horizontal, 20)
            HStack {
                Button("삭제") { requestDeleteConfirmation?(selectedFolderIDs) }
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer()

                Button("취소") {
                    withAnimation {
                        isDeletingFolders = false
                        selectedFolderIDs.removeAll()
                    }
                }
                .font(.headline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: Bottom Bar
    var bottomBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { viewModel.helpTapped() } label: {
                Label("도움말", systemImage: "questionmark.circle.fill")
            }
            Button { viewModel.settingsTapped() } label: {
                Label("설정", systemImage: "gearshape.fill")
            }
            Button { viewModel.trashTapped() } label: {
                Label("휴지통", systemImage: "trash")
                    .foregroundStyle(Color.errorColor)
            }
        }
        .font(.buttonText)
        .foregroundStyle(Color.text2)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Sort Menu
    var sortMenuView: some View {
        VStack(spacing: 0) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.currentSortOption = option
                    showSortMenu = false
                } label: {
                    HStack {
                        Text(option.rawValue)
                        Spacer()
                        if viewModel.currentSortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
            }
        }
        .frame(width: 180)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: Helpers
    private func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isAddingFolder = false
            return
        }

        let newFolder = Folder(name: trimmed)
        modelContext.insert(newFolder)
        try? modelContext.save()
        newFolderName = ""
        isAddingFolder = false
    }

    private func toggleFolderSelection(_ folder: Folder) {
        if selectedFolderIDs.contains(folder.persistentModelID) {
            selectedFolderIDs.remove(folder.persistentModelID)
        } else {
            selectedFolderIDs.insert(folder.persistentModelID)
        }
    }
}
