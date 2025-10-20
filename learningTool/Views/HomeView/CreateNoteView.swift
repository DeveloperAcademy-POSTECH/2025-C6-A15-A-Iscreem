//
//  CreateNoteView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct CreateNoteView: View {
    @State private var youtubeLink = ""
    @State private var noteTitle = ""
    
    let onNoteCreated: (Note) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                /// YouTube 링크 입력
                TextField(
                    "YouTube 링크를 입력하세요!",
                    text: $youtubeLink,
                    axis: .horizontal
                )
                .font(.system(size: 15))
                .foregroundStyle(Color.text1)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(10)
                
                /// 제목 입력
                TextField(
                    "저장할 노트 제목을 입력하세요!",
                    text: $noteTitle,
                    axis: .horizontal
                )
                .font(.system(size: 15))
                .foregroundStyle(Color.text1)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            /// 노트 생성 버튼
            Button(action: {
                createNoteTapped()
            }) {
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
                    isFormValid ?
                        Color.secondColor : Color.text3.opacity(0.5)
                )
                .cornerRadius(20)
            }
            .disabled(!isFormValid)
            .padding(.bottom, 50)
        }
    }
    
    private var isFormValid: Bool {
        !youtubeLink.isEmpty && !noteTitle.isEmpty
    }
    
    private func createNoteTapped() {
        let newNote = Note(
            title: noteTitle,
            lastRead: Date(),
            thumbnailURL: youtubeLink
        )
        onNoteCreated(newNote)
    }
}

#Preview {
    CreateNoteView { _ in
        print("Note created")
    }
    .background(Color.background1)
    .cornerRadius(20)
    .padding()
}