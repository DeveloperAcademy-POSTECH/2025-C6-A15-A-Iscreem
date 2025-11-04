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
    
    // 디바이스 타입 감지
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        GeometryReader { geometry in
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
            .frame(
                width: min(isIPad ? 663 : geometry.size.width * 0.9, geometry.size.width - 48),
                height: 120
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.background1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.borderColor, lineWidth: 1)
                    )
                )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
