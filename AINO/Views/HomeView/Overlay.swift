//
//  Overlay.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import SwiftUI
import SwiftData

// MARK: - Overlay Modifier
extension View {
    func applyOverlays(
        isHelpPresented: Binding<Bool>,
        showResetConfirm: Binding<Bool>,
        isFolderDeletePresented: Binding<Bool>,
        showCreateNote: Binding<Bool>,
        noteToRename: Binding<Note?>,
        folderToRename: Binding<Folder?>,
        renameText: Binding<String>,
        youtubeLink: Binding<String>,
        noteTitle: Binding<String>,
        isKeyboardVisible: Binding<Bool>,
        keyboardHeight: Binding<CGFloat>,
        notes: [Note],
        folders: [Folder],
        folderIDsPendingDelete: Set<PersistentIdentifier>,
        modelContext: ModelContext,
        isFormValid: Bool,
        createNoteTapped: @escaping () -> Void,
        onFolderDeleteConfirmed: @escaping () -> Void
    ) -> some View {
        self
            .overlay {
                if isHelpPresented.wrappedValue {
                    HelpOverlay(isHelpPresented: isHelpPresented)
                }
            }
            .overlay {
                if showResetConfirm.wrappedValue {
                    ResetConfirmOverlay(
                        showResetConfirm: showResetConfirm,
                        notes: notes,
                        modelContext: modelContext
                    )
                }
            }
            .overlay {
                if isFolderDeletePresented.wrappedValue {
                    FolderDeleteView(
                        onDelete: onFolderDeleteConfirmed,
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFolderDeletePresented.wrappedValue = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .overlay {
                if showCreateNote.wrappedValue {
                    CreateNoteOverlay(
                        showCreateNote: showCreateNote,
                        youtubeLink: youtubeLink,
                        noteTitle: noteTitle,
                        isKeyboardVisible: isKeyboardVisible,
                        keyboardHeight: keyboardHeight,
                        isFormValid: isFormValid,
                        createNoteTapped: createNoteTapped
                    )
                }
            }
            // 🔵 배경 dim 없이 카드만 보이도록 overlay로 교체 + 가로 폭 축소(반응형)
            .overlay {
                if let note = noteToRename.wrappedValue {
                    GeometryReader { geometry in
                        let cardWidth = min(320, geometry.size.width - 32) // 좌우 16씩 여백 고려
                        RenameNoteSheet(
                            note: note,
                            noteToRename: noteToRename,
                            renameText: renameText,
                            modelContext: modelContext
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .frame(width: cardWidth)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .overlay {
                if let folder = folderToRename.wrappedValue {
                    GeometryReader { geometry in
                        let cardWidth = min(320, geometry.size.width - 32) // 좌우 16씩 여백 고려
                        RenameFolderSheet(
                            folder: folder,
                            folderToRename: folderToRename,
                            renameText: renameText,
                            modelContext: modelContext
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .frame(width: cardWidth)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
    }
}

// MARK: - Help Overlay
struct HelpOverlay: View {
    @Binding var isHelpPresented: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHelpPresented = false
                        }
                    }
                HelpView(onClose: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHelpPresented = false
                    }
                })
                .frame(
                    width: min(680, geometry.size.width * 0.70),
                    height: min(620, geometry.size.height * 0.78)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale))
        }
    }
}

// MARK: - Reset Confirm Overlay
struct ResetConfirmOverlay: View {
    @Binding var showResetConfirm: Bool
    let notes: [Note]
    let modelContext: ModelContext
    @EnvironmentObject private var learningLogStore: LearningLogStore

    // 키보드 상태 추적
    @State private var isKeyboardVisible: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            // 화면 크기에 따라 카드 크기를 계산: 작은 기기에서는 비율로 줄이고, 큰 화면에서는 상한으로 제한
            let cardWidth = min(420, geo.size.width * 0.70)
            let cardHeight = min(280, geo.size.height * 0.60)
            
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = false
                        }
                    }
                
                // 카드
                ResetConfirmAlertView(
                    isPresented: $showResetConfirm,
                    onConfirm: {
                        // 모든 노트 삭제
                        for note in notes {
                            modelContext.delete(note)
                        }
                        do {
                            try modelContext.save()
                        } catch {
                            print("⚠️ Failed to delete all notes: \(error)")
                        }
                        // 🔴 학습 로그도 함께 초기화
                        learningLogStore.resetAllSessions()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = false
                        }
                    }
                )
                .frame(width: cardWidth, height: cardHeight)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
                // 키보드 상태에 따라 중앙 ↔ 하단 정렬 전환
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isKeyboardVisible ? .bottom : .center)
                .padding(.bottom, isKeyboardVisible ? (keyboardHeight + 24) : 0)
                .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)
                .animation(.easeInOut(duration: 0.25), value: keyboardHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale))
        }
        // 키보드 노티 감지
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            if let rect = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = rect.height
                    isKeyboardVisible = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
                keyboardHeight = 0
            }
        }
    }
}

// MARK: - 🔵 Create Note Overlay (노트 생성 오버레이)
struct CreateNoteOverlay: View {
    @Binding var showCreateNote: Bool
    @Binding var youtubeLink: String
    @Binding var noteTitle: String
    @Binding var isKeyboardVisible: Bool
    @Binding var keyboardHeight: CGFloat
    let isFormValid: Bool
    let createNoteTapped: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCreateNote = false
                    }
                }
            
            // CreateNoteView 내부로 버튼을 이동
            CreateNoteView(
                youtubeLink: $youtubeLink,
                noteTitle: $noteTitle,
                isFormValid: isFormValid,
                onCreate: createNoteTapped
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isKeyboardVisible ? .bottom : .center)
            .padding(.horizontal, 24)
            .padding(.bottom, isKeyboardVisible ? (keyboardHeight + 24) : 0)
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                if let rect = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        keyboardHeight = rect.height
                        isKeyboardVisible = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isKeyboardVisible = false
                    keyboardHeight = 0
                }
            }
        }
    }
}

// MARK: - 🔵 Rename Note Sheet (이름 변경 시트)
struct RenameNoteSheet: View {
    let note: Note
    @Binding var noteToRename: Note?
    @Binding var renameText: String
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedText(korean: "노트 이름 변경", english: "Rename Note").text)
                .font(.title3.weight(.semibold))
            
            TextField(LocalizedText(korean: "제목", english: "Title").text, text: $renameText)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                Spacer()
                
                // 🔵 취소 버튼 (Liquid Glass)
                Button(LocalizedText(korean: "취소", english: "Cancel").text) {
                    noteToRename = nil
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                
                // 🔵 저장 버튼 (Liquid Glass + Accent)
                Button {
                    note.title = renameText
                    try? modelContext.save()
                    noteToRename = nil
                } label: {
                    Text(LocalizedText(korean: "저장", english: "Save").text)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.secondColor)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 🔵 Rename Folder Sheet (폴더 이름 변경 시트)
struct RenameFolderSheet: View {
    let folder: Folder
    @Binding var folderToRename: Folder?
    @Binding var renameText: String
    let modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("폴더 이름 변경")
                .font(.title3.weight(.semibold))
            
            TextField("폴더 이름", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                Spacer()
                Button("취소") {
                    folderToRename = nil
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                
                Button {
                    folder.name = renameText
                    try? modelContext.save()
                    folderToRename = nil
                } label: {
                    Text(LocalizedText(korean: "저장", english: "Save").text)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.secondColor)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }
}
