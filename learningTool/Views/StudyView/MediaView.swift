//
//  MediaView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import OSLog
import WebKit

struct MediaView: View {
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    /// Note에서 내려받는 YouTube 링크 (없으면 플레이스홀더 유지)
    let videoURL: String?
    let scaleFactor: CGFloat

    @State private var host: YouTubeWebViewHost?
    @State private var loadedURL: String?

    var body: some View {
        ZStack {
            if let host = host, let url = videoURL, !url.isEmpty {
                YouTubeWebViewContainer(host: host)
                    .background(Color.background3)
                    .onChange(of: videoURL) { _, newValue in
                        if let u = newValue, !u.isEmpty {
                            loadIfNeeded(u)
                        }
                    }
            } else {
                /// 웹뷰가 표시될 영역 (YouTube 등)
                Rectangle()
                    .fill(Color.background3)
                    .overlay(
                        VStack(spacing: ScaleCalculator.scaled(8, with: scaleFactor)) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: ScaleCalculator.scaled(60, with: scaleFactor)))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("웹뷰 영역")
                                .font(.system(size: ScaleCalculator.scaled(14, with: scaleFactor)))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    )
            }
        }
        .frame(
            width: ScaleCalculator.scaled(800, with: scaleFactor),
            height: ScaleCalculator.scaled(450, with: scaleFactor)
        )
        .onAppear {
            if host == nil {
                host = YouTubeWebViewHost(captionAnalyzer: captionAnalyzer)
            }
            if let url = videoURL, !url.isEmpty {
                loadIfNeeded(url)
            }
        }
    }

    // MARK: - Helpers
    private func loadIfNeeded(_ url: String) {
        guard loadedURL != url else { return }
        loadedURL = url
        host?.load(urlString: url)
    }
}

// MARK: - Container for UIViewRepresentable
private struct YouTubeWebViewContainer: UIViewRepresentable {
    let host: YouTubeWebViewHost
    
    func makeUIView(context: Context) -> WKWebView {
        host.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // no-op
    }
}

#Preview(traits: .landscapeLeft) {
    // 미리보기에서는 샘플 URL을 전달하거나 nil로 플레이스홀더를 볼 수 있습니다.
    MediaView(videoURL: nil, scaleFactor: 1.0)
        .environmentObject(CaptionAnalyzer())
}
