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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
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
    
    var body: some View {
        GeometryReader { geo in
            // 화면 크기에 따라 카드 크기를 계산: 작은 기기에서는 비율로 줄이고, 큰 화면에서는 상한으로 제한
            let cardWidth = min(420, geo.size.width * 0.70)
            let cardHeight = min(380, geo.size.height * 0.60)
            
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
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale))
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
            
            VStack(alignment: .trailing, spacing: 20) {
                CreateNoteView(youtubeLink: $youtubeLink, noteTitle: $noteTitle)
                
                // 🔵 노트 생성 버튼 (Liquid Glass + Gradient)
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
                    .background(
                        ZStack {
                            // Gradient background
                            LinearGradient(
                                colors: [
                                    Color.secondColor,
                                    Color.secondColor.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            // Glass overlay
                            Color.white.opacity(0.1)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
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

// MARK: - 🔵 Rename Note Sheet (이름 변경 시트)
struct RenameNoteSheet: View {
    let note: Note
    @Binding var noteToRename: Note?
    @Binding var renameText: String
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("노트 이름 변경")
                .font(.title3.weight(.semibold))
            
            TextField("제목", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                Spacer()
                
                // 🔵 취소 버튼 (Liquid Glass)
                Button("취소") {
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
                    Text("저장")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.secondColor)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .background(.ultraThinMaterial)
    }
}
