//
//  MediaView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import OSLog

struct MediaView: View {
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    /// 현재 재생/요약 세션에 바인딩할 노트 (캐시 재활용/저장 목적)
    let note: Note?
    /// Note에서 내려받는 YouTube 링크 (없으면 플레이스홀더 유지)
    let videoURL: String?

    @State private var representable: YouTubeWebViewRepresentable?
    @State private var loadedURL: String?

    var body: some View {
        ZStack {
            if let rep = representable, let url = videoURL, !url.isEmpty {
                rep
                    .aspectRatio(16/9, contentMode: .fit)
                    .background(Color.background3)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear { loadIfNeeded(url) }
                    .onChange(of: videoURL) { _, newValue in
                        if let u = newValue, !u.isEmpty { loadIfNeeded(u) }
                    }
            } else {
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            if representable == nil {
                // YouTubePane의 역할을 이 View에서 수행: 캡션 분석기와 연결된 WebView 브리지 준비
                representable = YouTubeWebViewRepresentable(captionAnalyzer: captionAnalyzer)
            }
            if let url = videoURL, !url.isEmpty {
                DispatchQueue.main.async {
                    loadIfNeeded(url)
                }
            }
        }
        .task(id: videoURL) {
            if let u = videoURL, !u.isEmpty {
                if representable == nil {
                    representable = YouTubeWebViewRepresentable(captionAnalyzer: captionAnalyzer)
                }
                DispatchQueue.main.async {
                    loadIfNeeded(u)
                }
            }
        }
    }

    // MARK: - Helpers
    private func loadIfNeeded(_ url: String) {
        guard loadedURL != url else { return }
        loadedURL = url
        if let n = note {
            // 노트 바인딩 + 로드 (캐시 선반영/후저장에 필요)
            representable?.load(url, for: n)
        } else {
            representable?.load(url)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    MediaView(
        note: Note(title: "미리보기 노트", lastRead: Date()),
        videoURL: "https://youtu.be/LBqJwmFMQHI?si=G1aD3hiMw5-ZSdWk"
    )
    .environmentObject(CaptionAnalyzer())
}
