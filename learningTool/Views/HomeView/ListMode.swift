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
        HStack {
            Text("제목")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            
            Text("강의 길이")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 72, alignment: .trailing)
            
            Text("수강률")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 72, alignment: .trailing)
            
            Text("최근 학습 일시")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.background1)
    }
    
    @ViewBuilder
    func noteRow(
        _ note: Note,
        noteToRename: Binding<Note?>,
        renameText: Binding<String>,
        onNoteSelected: ((Note) -> Void)?,
        modelContext: ModelContext
    ) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                thumbnailView(for: note)
                    .frame(width: 56, height: 56)
                    .cornerRadius(8)
                
                Text(note.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.text1)
                    .lineLimit(1)
            }
            .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            
            Text(NoteFormattingUtils.durationText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 72, alignment: .trailing)
            
            Text(NoteFormattingUtils.progressText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 72, alignment: .trailing)
            
            Text(NoteFormattingUtils.lastReadText(for: note))
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onNoteSelected?(note) }
        .contextMenu {
            Button("이름 변경") {
                noteToRename.wrappedValue = note
                renameText.wrappedValue = note.title
            }
            Button("삭제", role: .destructive) {
                modelContext.delete(note)
                try? modelContext.save()
            }
        }
    }
    
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
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.text2)
                            .frame(width: 56, height: 56)
                            .background(Color.background2)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.borderColor, lineWidth: 1))
                        
                        Text(folder.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.text1)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                    
                    Text("—").frame(width: 72, alignment: .trailing).foregroundStyle(Color.text3)
                    Text("—").frame(width: 72, alignment: .trailing).foregroundStyle(Color.text3)
                    Text(NoteFormattingUtils.relativeDate(folder.createdAt))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text2)
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
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
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
        } else {
            placeholderThumbnail
        }
    }
    
    var placeholderThumbnail: some View {
        ZStack {
            Rectangle()
                .fill(Color.background2)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(Color.text3)
        }
    }
}
