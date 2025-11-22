//
//  GridMode.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Drag Payload
// SwiftData의 PersistentIdentifier를 안전하게 운반하기 위한 경량 페이로드
struct NoteDragItem: Transferable, Codable, Hashable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

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
        folderToRename: Binding<Folder?>,
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
                        folderToRename: folderToRename,
                        renameText: renameText,
                        onNoteSelected: onNoteSelected,
                        modelContext: modelContext
                    )
                }
            } else {
                ForEach(filteredNotes) { note in
                    NoteComponent(note: note)
                        .onTapGesture { onNoteSelected?(note) }
                        // 드래그 지원: 폴더로 이동시키기 위해 노트의 PersistentIdentifier를 운반
                        .draggable(NoteDragItem(id: note.persistentModelID))
                        .contextMenu {
                            Button {
                                noteToRename.wrappedValue = note
                                renameText.wrappedValue = note.title
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            Button {
                                // 휴지통으로 이동(소프트 삭제)
                                note.isTrashed = true
                                note.trashedAt = Date()
                                try? modelContext.save()
                            } label: {
                                Label("휴지통으로 이동", systemImage: "trash")
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
        folderToRename: Binding<Folder?>,
        renameText: Binding<String>,
        onNoteSelected: ((Note) -> Void)?,
        modelContext: ModelContext
    ) -> some View {
        switch item {
        case .folder(let folder):
            Button {
                // ✅ 폴더 진입 전 상태 스냅샷을 저장하고 선택 적용
                applySelection(folderName: folder.name, subtitle: folder.name)
            } label: {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "folder.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .foregroundStyle(Color.secondColor)
                    Text(folder.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.text1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            // 드롭 타겟: 노트 드롭 시 해당 폴더로 이동
            .dropDestination(for: NoteDragItem.self) { items, _ in
                var handled = false
                for payload in items {
                    // SwiftData에서 식별자로 Note 로드
                    if let moved = try? modelContext.model(for: payload.id) as? Note {
                        // 휴지통 항목은 무시
                        guard !moved.isTrashed, !folder.isTrashed else { continue }
                        // 동일 폴더로 이동하는 경우도 허용(미분류 → 폴더 포함)
                        moved.folder = folder
                        handled = true
                    }
                }
                if handled {
                    do { try modelContext.save() } catch {
                        print("⚠️ Drop save failed: \(error)")
                    }
                }
                return handled
            } isTargeted: { hovering in
                // 필요 시 호버링 시각 효과를 주고 싶다면 여기서 스타일 변경 가능
                // 예: 배경/테두리 강조 등
            }
            .contextMenu {
                Button {
                    // 폴더 이름 변경 시트 표시
                    folderToRename.wrappedValue = folder
                    renameText.wrappedValue = folder.name
                } label: {
                    Label("이름 변경", systemImage: "pencil")
                }

                Button {
                    folder.isTrashed = true
                    folder.trashedAt = Date()
                    try? modelContext.save()
                } label: {
                    Label("휴지통으로 이동", systemImage: "trash")
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            
        case .note(let note):
            NoteComponent(note: note)
                .onTapGesture {
                    onNoteSelected?(note)
                }
                // 드래그 지원: 폴더로 이동시키기 위해 노트의 PersistentIdentifier를 운반
                .draggable(NoteDragItem(id: note.persistentModelID))
                .contextMenu {
                    Button {
                        noteToRename.wrappedValue = note
                        renameText.wrappedValue = note.title
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    Button {
                        note.isTrashed = true
                        note.trashedAt = Date()
                        try? modelContext.save()
                    } label: {
                        Label("휴지통으로 이동", systemImage: "trash")
                    }
                }
        }
    }
}

