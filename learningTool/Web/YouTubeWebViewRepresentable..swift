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
}
