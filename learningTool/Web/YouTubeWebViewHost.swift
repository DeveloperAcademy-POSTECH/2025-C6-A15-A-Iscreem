//
//  YouTubeWebViewHost.swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import SwiftUI
import WebKit
import Combine
import OSLog

final class YouTubeWebViewHost: NSObject, ObservableObject {
    fileprivate let log = Logger(subsystem: "learningTool", category: "YouTubeWebViewHost")
    
    let webView: WKWebView
    fileprivate weak var captionAnalyzer: CaptionAnalyzer?
    
    // Flags to ensure each bridge message is only processed once per navigation
    fileprivate var didProcessCfg = false
    fileprivate var didProcessTracks = false

    init(captionAnalyzer: CaptionAnalyzer?) {
        self.captionAnalyzer = captionAnalyzer

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [] // 자동 재생 허용(소리없는 재생)
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let ucc = WKUserContentController()
        config.userContentController = ucc

        // 유저 스크립트 주입 (ytcfg/자막 트랙 수집)
        let script = YouTubeWebViewHost.youtubeBootstrapScript()
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(userScript)

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        // JS → Native 브릿지 채널 (super.init() 이후에 self 사용)
        ucc.add(WeakScriptMessageHandler(self), name: "ytcfg")
        ucc.add(WeakScriptMessageHandler(self), name: "tracks")
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.scrollView.bounces = true
        self.webView.allowsBackForwardNavigationGestures = false
        self.webView.backgroundColor = .clear
        self.webView.isOpaque = false
    }

    // MARK: - Public
    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        log.info("WKNav allow → \(url.host ?? "-")")
        // Reset bridge flags for a fresh navigation
        didProcessCfg = false
        didProcessTracks = false
        webView.load(req)
    }

    // MARK: - JS Bootstrap
    private static func youtubeBootstrapScript() -> String {
        return """
        (function() {
          if (window._ytlex_bootstrapped) return;
          window._ytlex_bootstrapped = true;

          var postedCfg = false;
          var postedTracks = false;

          function post(name, payload) {
            try { window.webkit.messageHandlers[name].postMessage(payload); } catch (e) {}
          }
          function getCfg(key, fallback) {
            try { return (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get(key) : fallback; } catch (e) { return fallback; }
          }
          function extractTracksFromPR(pr) {
            try {
              var tl = pr && pr.captions && pr.captions.playerCaptionsTracklistRenderer;
              var tracks = (tl && tl.captionTracks) ? tl.captionTracks : [];
              var mapped = tracks.map(function(t) {
                var name = "";
                if (t.name && t.name.simpleText) name = t.name.simpleText;
                else if (t.name && t.name.runs) name = (t.name.runs || []).map(function(r){return r.text||""}).join("");
                return { baseUrl: t.baseUrl, lang: (t.languageCode || ""), kind: (t.kind || ""), name: name };
              });
              if (mapped && mapped.length > 0 && !postedTracks) { postedTracks = true; post('tracks', { tracks: mapped }); }
            } catch(e) {}
          }
          function trySendYtcfg() {
            if (postedCfg) return;
            var apiKey = getCfg('INNERTUBE_API_KEY', null);
            var ctx = getCfg('INNERTUBE_CONTEXT', {}) || {};
            var clientName = (ctx.client && ctx.client.clientName) || 'WEB';
            var clientVersion = (ctx.client && ctx.client.clientVersion) || '';
            var sts = getCfg('STS', null);
            var videoId = null;
            try {
              if (window.ytplayer && window.ytplayer.config && window.ytplayer.config.args) {
                videoId = window.ytplayer.config.args.video_id || window.ytplayer.config.args.videoId || null;
              }
              var pv = getCfg('PLAYER_VARS', null);
              if (!videoId && pv) { videoId = pv.video_id || pv.videoId || null; }
            } catch(e) {}
            if (apiKey && videoId) {
              postedCfg = true;
              post('ytcfg', { videoId: videoId, apiKey: apiKey, clientName: clientName, clientVersion: clientVersion, sts: sts });
            }
          }
          function trySendTracks() {
            if (postedTracks) return;
            if (window.ytInitialPlayerResponse) { extractTracksFromPR(window.ytInitialPlayerResponse); return; }
            if (window.ytplayer && window.ytplayer.config && window.ytplayer.config.args && window.ytplayer.config.args.player_response) {
              var pr = window.ytplayer.config.args.player_response;
              if (typeof pr === 'string') { try { pr = JSON.parse(pr); } catch(e) {} }
              extractTracksFromPR(pr);
            }
          }
          function tick() {
            trySendYtcfg();
            trySendTracks();
            if (postedCfg && postedTracks) { clearInterval(timer); }
          }
          // Kick once then poll briefly to cover late population
          tick();
          var timer = setInterval(tick, 150);
          setTimeout(function(){ clearInterval(timer); }, 2500);
        })();
        """
    }
}

// MARK: - WKScriptMessage handling (weak bridge)
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: YouTubeWebViewHost?
    init(_ target: YouTubeWebViewHost) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let host = target else { return }
        if message.name == "ytcfg" {
            guard let d = message.body as? [String: Any] else { return }
            // Only process the first valid ytcfg message per navigation
            if host.didProcessCfg { return }
            let videoId = (d["videoId"] as? String) ?? ""
            let apiKey = (d["apiKey"] as? String) ?? ""
            let clientName = (d["clientName"] as? String) ?? "WEB"
            let clientVersion = (d["clientVersion"] as? String) ?? ""
            let sts = d["sts"] as? Int
            host.log.info("ytcfg → youtubei prefetch; videoId=\(videoId) client=\(clientName)/\(clientVersion)")
            if !videoId.isEmpty, !apiKey.isEmpty {
                host.didProcessCfg = true
                Task {
                    await host.captionAnalyzer?.prefetchViaYouTubei(
                        videoID: videoId,
                        apiKey: apiKey,
                        clientName: clientName,
                        clientVersion: clientVersion,
                        sts: sts
                    )
                }
            }
        } else if message.name == "tracks" {
            guard let d = message.body as? [String: Any],
                  let arr = d["tracks"] as? [[String: Any]] else { return }
            // Only process the first valid tracks message per navigation
            if host.didProcessTracks { return }
            host.didProcessTracks = true
            host.log.info("JS tracks → \(arr.count)")
            Task { await host.captionAnalyzer?.prefetchFromTracks(arr) }
        }
    }
}

// MARK: - WK delegates
extension YouTubeWebViewHost: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = action.request.url?.host?.lowercased(),
           host.contains("youtube.com") || host.contains("youtu.be") {
            decisionHandler(.allow); return
        }
        log.error("WKNav cancel (blocked host)")
        decisionHandler(.cancel)
    }
}
