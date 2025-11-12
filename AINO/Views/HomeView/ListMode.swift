//
//  ListMode.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import SwiftUI
import SwiftData

// MARK: - List Mode Views
extension HomeView {
    
    @ViewBuilder
    func listModeContent(
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
        VStack(spacing: 0) {
            listHeaderRow()
            Divider().background(Color.borderColor)
            
            LazyVStack(spacing: 8) {
                if isAllView {
                    let items = searchQuery.isEmpty ? allItems : allItemsFiltered
                    ForEach(items.indices, id: \.self) { idx in
                        homeItemRow(
                            items[idx],
                            selectedFolderName: selectedFolderName,
                            headerSubtitle: headerSubtitle,
                            noteToRename: noteToRename,
                            renameText: renameText,
                            onNoteSelected: onNoteSelected,
                            modelContext: modelContext
                        )
                        Divider().background(Color.borderColor.opacity(0.6))
                    }
                } else {
                    ForEach(filteredNotes) { note in
                        noteRow(
                            note,
                            noteToRename: noteToRename,
                            renameText: renameText,
                            onNoteSelected: onNoteSelected,
                            modelContext: modelContext
                        )
                        Divider().background(Color.borderColor.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }
    
    @ViewBuilder
    func listHeaderRow() -> some View {
        HStack(spacing: 6) {
            Text("제목")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
            
            Text("강의 길이")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(width: 60, alignment: .trailing)
            
            Text("수강률")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(width: 60, alignment: .trailing)
            
            Text("최근 학습 일시")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.background1)
    }
    
    // MARK: - 🔵 Note Row
    @ViewBuilder
    func noteRow(
        _ note: Note,
        noteToRename: Binding<Note?>,
        renameText: Binding<String>,
        onNoteSelected: ((Note) -> Void)?,
        modelContext: ModelContext
    ) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 12) {
                thumbnailView(for: note)
                    .frame(width: 56, height: 56)
                    .cornerRadius(8)
                
                Text(note.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.text1)
                    .lineLimit(1)
            }
            .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
            
            Text(NoteFormattingUtils.durationText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 60, alignment: .trailing)
            
            Text(NoteFormattingUtils.progressText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 60, alignment: .trailing)
            
            Text(NoteFormattingUtils.lastReadText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onNoteSelected?(note) }
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
    
    // MARK: - 🔵 Home Item Row (폴더/노트 행)
    @ViewBuilder
    func homeItemRow(
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
            Button {
                selectedFolderName.wrappedValue = folder.name
                headerSubtitle.wrappedValue = folder.name
            } label: {
                HStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.text2)
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        Text(folder.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.text1)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                    
                    Text("—").frame(width: 60, alignment: .trailing).foregroundStyle(Color.text3)
                    Text("—").frame(width: 60, alignment: .trailing).foregroundStyle(Color.text3)
                    Text(NoteFormattingUtils.relativeDate(folder.createdAt))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text2)
                        .frame(width: 88, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial.opacity(0.3))
                )
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            
        case .note(let n):
            noteRow(
                n,
                noteToRename: noteToRename,
                renameText: renameText,
                onNoteSelected: onNoteSelected,
                modelContext: modelContext
            )
        }
    }
    
    // MARK: - Thumbnail View
    @ViewBuilder
    func thumbnailView(for note: Note) -> some View {
        if let url = NoteFormattingUtils.thumbnailURL(for: note) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure(_):
                    placeholderThumbnail
                @unknown default:
                    placeholderThumbnail
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        } else {
            placeholderThumbnail
        }
    }
    
    var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(Color.text3)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}
