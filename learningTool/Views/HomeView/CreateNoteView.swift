//
//  CreateNoteView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData

struct CreateNoteView: View {
    @Binding var youtubeLink: String
    @Binding var noteTitle: String

    var body: some View {
        VStack(spacing: 0) {
            // YouTube 링크
            TextField("", text: $youtubeLink, prompt: Text("YouTube 링크를 입력하세요!")
                .foregroundColor(Color.text3), axis: .horizontal)
                .font(.system(size: 16))
                .foregroundStyle(Color.text1)
                .lineLimit(1)
                .padding(.horizontal, 24)
                .frame(height: 60)
            
            Divider()
                .background(Color.borderColor)
            
            // 제목
            TextField("", text: $noteTitle, prompt: Text("저장할 노트 제목을 입력하세요!")
                .foregroundColor(Color.text3), axis: .horizontal)
                .font(.system(size: 16))
                .foregroundStyle(Color.text1)
                .lineLimit(1)
                .padding(.horizontal, 24)
                .frame(height: 60)
        }
        .frame(width: 663)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.background1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

#Preview(traits: .landscapeLeft) {
    CreateNoteView(youtubeLink: .constant(""), noteTitle: .constant(""))
        .background(Color.background1)
        .cornerRadius(20)
        .padding()
}
