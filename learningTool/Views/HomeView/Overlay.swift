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
            .sheet(item: noteToRename) { note in
                RenameNoteSheet(
                    note: note,
                    noteToRename: noteToRename,
                    renameText: renameText,
                    modelContext: modelContext
                )
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
                .background(Color.background1)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
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
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = false
                        }
                    }
                ResetConfirmAlertView(
                    isPresented: $showResetConfirm,
                    onConfirm: {
                        for note in notes {
                            modelContext.delete(note)
                        }
                        do {
                            try modelContext.save()
                        } catch {
                            print("⚠️ Failed to delete all notes: \(error)")
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = false
                        }
                    }
                )
                .frame(
                    width: min(420, geo.size.width * 0.70),
                    height: 340
                )
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale))
        }
    }
}

// MARK: - Create Note Overlay
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
            
            VStack(alignment: .trailing, spacing: 20) {
                CreateNoteView(youtubeLink: $youtubeLink, noteTitle: $noteTitle)
                
                // 노트 생성 버튼 (Liquid Glass + Gradient)
                Button(action: createNoteTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("노트 생성")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.secondColor)
                    .cornerRadius(20)
                }
                .disabled(!isFormValid)
            }
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

// MARK: - Rename Note Sheet
struct RenameNoteSheet: View {
    let note: Note
    @Binding var noteToRename: Note?
    @Binding var renameText: String
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("노트 이름 변경").font(.title3)
            TextField("제목", text: $renameText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("취소") { noteToRename = nil }
                Button("저장") {
                    note.title = renameText
                    try? modelContext.save()
                    noteToRename = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
