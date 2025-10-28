//
//  YouTubeWebViewRepresentable..swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import SwiftUI
import WebKit

struct YouTubeWebViewRepresentable: UIViewRepresentable {
    let host: YouTubeWebViewHost

    init(captionAnalyzer: CaptionAnalyzer) {
        self.host = YouTubeWebViewHost(captionAnalyzer: captionAnalyzer)
    }

    func makeUIView(context: Context) -> WKWebView {
        host.webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // no-op
    }

    // Helper: 외부에서 로드 트리거
    
    @MainActor
    func load(_ urlString: String) {
        host.load(urlString: urlString)
    }
    
    // Helper: 노트와 함께 로드(요약 캐시 재활용 + 세션 바인딩)
    @MainActor
    func load(_ urlString: String, for note: Note) {
        // ✅ 먼저 로드(내부에서 reset 즉시 실행)
        host.load(urlString: urlString)
        // ✅ 그 다음 노트 바인딩(캐시 복원)
        host.bind(note: note)
    }
}
