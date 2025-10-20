//
//  NoteComponent.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct NoteComponent: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            /// 썸네일 이미지
            Rectangle()
                .fill(Color.background2)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.text3)
                )
                .cornerRadius(8)
            
            /// 제목
            Text(note.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.text1)
                .lineLimit(2)
            
            /// 시간 정보
            Text("최근 읽음 : \(timeAgoString)")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.text2)
        }
        .padding(12)
        .background(Color.background1)
        .cornerRadius(12)
        .shadow(color: Color.text1.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var timeAgoString: String {
        let interval = Date().timeIntervalSince(note.lastRead)
        let hours = Int(interval / 3600)
        
        if hours < 1 {
            return "방금 전"
        } else if hours < 24 {
            return "\(hours)시간 전"
        } else {
            let days = hours / 24
            return "\(days)일 전"
        }
    }
}

#Preview(traits: .landscapeLeft) {
    NoteComponent(
        note: Note(
            title: "YouTube 제목",
            lastRead: Date().addingTimeInterval(-43200)
        )
    )
    .padding()
}