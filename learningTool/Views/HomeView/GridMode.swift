//
//  GridMode.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import SwiftUI
import SwiftData

// MARK: - Grid Mode Views
extension HomeView {
    
    @ViewBuilder
    func gridModeContent(
        columns: [GridItem],
        isAllView: Bool,
        allItems: [HomeItem],
        allItemsFiltered: [HomeItem],
        filteredNotes: [Note],
        searchQuery: String,
        selectedFolderName: Binding<String?>,
        headerSubtitle: Binding<String>,
        noteToRename: Binding<Note?>,
        renameText: Binding<String>,
        onNoteSelected: ((Note) -> Void)?,
        modelContext: ModelContext
    ) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            if isAllView {
                let items = searchQuery.isEmpty ? allItems : allItemsFiltered
                ForEach(items.indices, id: \.self) { idx in
                    homeItemView(
                        items[idx],
                        selectedFolderName: selectedFolderName,
                        headerSubtitle: headerSubtitle,
                        noteToRename: noteToRename,
                        renameText: renameText,
                        onNoteSelected: onNoteSelected,
                        modelContext: modelContext
                    )
                }
            } else {
                ForEach(filteredNotes) { note in
                    NoteComponent(note: note)
                        .onTapGesture { onNoteSelected?(note) }
                        .contextMenu {
                            // 🔵 컨텍스트 메뉴 버튼들
                            Button {
                                noteToRename.wrappedValue = note
                                renameText.wrappedValue = note.title
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(note)
                                try? modelContext.save()
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding()
    }
    
    // MARK: - 🔵 Grid Item View (폴더/노트 타일)
    @ViewBuilder
    func homeItemView(
        _ item: HomeItem,
        selectedFolderName: Binding<String?>,
        headerSubtitle: Binding<String>,
        noteToRename: Binding<Note?>,
        renameText: Binding<String>,
        onNoteSelected: ((Note) -> Void)?,
        modelContext: ModelContext
    ) -> some View {
        switch item {
        case .folder(let folder):
            // 🔵 폴더 타일 버튼 (Liquid Glass)
            Button {
                selectedFolderName.wrappedValue = folder.name
                headerSubtitle.wrappedValue = folder.name
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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            
        case .note(let note):
            NoteComponent(note: note)
                .onTapGesture {
                    onNoteSelected?(note)
                }
                .contextMenu {
                    // 🔵 컨텍스트 메뉴 버튼들
                    Button {
                        noteToRename.wrappedValue = note
                        renameText.wrappedValue = note.title
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(note)
                        try? modelContext.save()
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
        }
    }
}
