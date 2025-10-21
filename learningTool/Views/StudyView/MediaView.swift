//
//  MediaView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct MediaView: View {
    var body: some View {
        /// 웹뷰가 표시될 영역 (YouTube 등)
        Rectangle()
            .fill(Color.background3)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("웹뷰 영역")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
            )
    }
}

#Preview(traits: .landscapeLeft) {
    MediaView()
}