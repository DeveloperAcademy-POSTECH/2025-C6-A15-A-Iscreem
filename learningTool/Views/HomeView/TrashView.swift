// TrashView.swift
import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var learningLogStore: LearningLogStore
    
    @Query private var allNotes: [Note]
    @Query private var allFolders: [Folder]
    
    @State private var selectedNotes = Set<PersistentIdentifier>()
    @State private var selectedFolders = Set<PersistentIdentifier>()
    @State private var selectionMode = false
    
    @State private var showConfirm = false
    @State private var confirmAction: (() -> Void)?
    @State private var confirmTitle = "삭제를 진행합니다"
    @State private var confirmMessage = "이 작업은 실행 이후 복구할 수 없습니다."
    @State private var confirmButtonTitle = "영구 삭제"
    
    private var trashedNotes: [Note] { allNotes.filter { $0.isTrashed } }
    private var trashedFolders: [Folder] { allFolders.filter { $0.isTrashed } }
    
    private var service: TrashService {
        TrashService(context: context, learningLogStore: learningLogStore)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.borderColor)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !trashedFolders.isEmpty {
                        sectionHeader("폴더")
                        LazyVStack(spacing: 8) {
                            ForEach(trashedFolders) { f in
                                trashedFolderRow(f)
                            }
                        }
                    }
                    if !trashedNotes.isEmpty {
                        sectionHeader("노트")
                        LazyVStack(spacing: 8) {
                            ForEach(trashedNotes) { n in
                                trashedNoteRow(n)
                            }
                        }
                    }
                    if trashedNotes.isEmpty && trashedFolders.isEmpty {
                        Text("휴지통이 비어 있습니다.")
                            .foregroundStyle(Color.text3)
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(16)
            }
        }
        .overlay {
            if showConfirm {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showConfirm = false } }
                DestructiveConfirmAlertView(
                    title: confirmTitle,
                    message: confirmMessage,
                    confirmTitle: confirmButtonTitle,
                    onConfirm: {
                        confirmAction?()
                        withAnimation { showConfirm = false }
                    },
                    onCancel: {
                        withAnimation { showConfirm = false }
                    }
                )
                .frame(maxWidth: 360)
            }
        }
        .onAppear {
            // 선택: 7일 지난 항목 자동 영구 삭제
            service.purgeExpired(days: 7)
        }
    }
    
    private var header: some View {
        HStack {
            Text("휴지통")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.text1)
            Spacer()
            if selectionMode {
                Button("선택 해제") { selectionMode = false; selectedNotes.removeAll(); selectedFolders.removeAll() }
                Button("선택 삭제") {
                    guard !(selectedNotes.isEmpty && selectedFolders.isEmpty) else { return }
                    confirm(title: "삭제를 진행합니다", message: "선택한 항목을 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다.", button: "영구 삭제") {
                        let notes = trashedNotes.filter { selectedNotes.contains($0.persistentModelID) }
                        let folders = trashedFolders.filter { selectedFolders.contains($0.persistentModelID) }
                        service.deletePermanently(notes: notes)
                        for f in folders { service.deletePermanently(f) }
                        selectedNotes.removeAll()
                        selectedFolders.removeAll()
                    }
                }
                .tint(Color.errorColor)
            } else {
                Button("선택") { selectionMode = true }
                Button("전체 삭제") {
                    confirm(title: "삭제를 진행합니다", message: "휴지통의 모든 항목을 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다.", button: "모두 영구 삭제") {
                        service.deleteAllPermanently()
                    }
                }
                .tint(Color.errorColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.background1)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.text2)
            Spacer()
        }
    }
    
    private func trashedFolderRow(_ f: Folder) -> some View {
        HStack {
            if selectionMode {
                Image(systemName: selectedFolders.contains(f.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedFolders.contains(f.persistentModelID) ? Color.secondColor : Color.text3)
                    .onTapGesture {
                        toggleSelectionFolder(f)
                    }
            }
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.text2)
            Text(f.name)
                .foregroundStyle(Color.text1)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.background1))
        .contextMenu {
            Button("복원") { service.restore(f) }
            Button(role: .destructive) {
                confirm(title: "삭제를 진행합니다", message: "이 폴더를 영구 삭제합니다. 되돌릴 수 없습니다.", button: "영구 삭제") {
                    service.deletePermanently(f)
                }
            } label: {
                Label("영구 삭제", systemImage: "trash")
            }
        }
        .onTapGesture {
            if selectionMode { toggleSelectionFolder(f) }
        }
    }
    
    private func trashedNoteRow(_ n: Note) -> some View {
        HStack {
            if selectionMode {
                Image(systemName: selectedNotes.contains(n.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedNotes.contains(n.persistentModelID) ? Color.secondColor : Color.text3)
                    .onTapGesture {
                        toggleSelectionNote(n)
                    }
            }
            Image(systemName: "doc.text")
                .foregroundStyle(Color.text2)
            Text(n.title)
                .foregroundStyle(Color.text1)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.background1))
        .contextMenu {
            Button("복원") { service.restore(n) }
            Button(role: .destructive) {
                confirm(title: "삭제를 진행합니다", message: "이 노트를 영구 삭제합니다. 되돌릴 수 없습니다.", button: "영구 삭제") {
                    service.deletePermanently(n)
                }
            } label: {
                Label("영구 삭제", systemImage: "trash")
            }
        }
        .onTapGesture {
            if selectionMode { toggleSelectionNote(n) }
        }
    }
    
    private func toggleSelectionNote(_ n: Note) {
        let id = n.persistentModelID
        if selectedNotes.contains(id) { selectedNotes.remove(id) } else { selectedNotes.insert(id) }
    }
    private func toggleSelectionFolder(_ f: Folder) {
        let id = f.persistentModelID
        if selectedFolders.contains(id) { selectedFolders.remove(id) } else { selectedFolders.insert(id) }
    }
    
    private func confirm(title: String, message: String, button: String, action: @escaping () -> Void) {
        confirmTitle = title
        confirmMessage = message
        confirmButtonTitle = button
        confirmAction = action
        withAnimation(.easeInOut(duration: 0.2)) { showConfirm = true }
    }
}
