//
//  NoteComponent.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct NoteComponent: View {
    let note: Note
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let isDark = (colorScheme == .dark)
        
        VStack(alignment: .center, spacing: 8) {
            // 썸네일 이미지 (YouTube 링크에서 자동 추출)
            if let url = YouTubeThumbnail.thumbnailURL(from: note.thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderThumbnail(isDark: isDark).overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        placeholderThumbnail(isDark: isDark)
                    @unknown default:
                        placeholderThumbnail(isDark: isDark)
                    }
                }
            } else {
                placeholderThumbnail(isDark: isDark)
            }
            
            // 제목
            Text(note.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? Color.white : Color.text1)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // 시간 정보
            Text("최근 읽음 : \(timeAgoString)")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isDark ? Color.white : Color.text1)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(isDark ? Color.background3 : Color.background1)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.1)),
                radius: 4, x: 0, y: 2)
    }

    private func placeholderThumbnail(isDark: Bool) -> some View {
        Rectangle()
            .fill(isDark ? Color.black.opacity(0.35) : Color.background2)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isDark ? Color.white.opacity(0.8) : Color.text3)
            )
            .cornerRadius(8)
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
            lastRead: Date().addingTimeInterval(-43200),
            thumbnailURL: "https://youtu.be/dQw4w9WgXcQ"
        )
    )
    .padding()
}
