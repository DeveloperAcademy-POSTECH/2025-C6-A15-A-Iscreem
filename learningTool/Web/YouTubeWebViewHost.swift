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

    // 🔹 재생 상태 콜백(일시정지/종료 시 현재 시간 전달)
    var onPause: ((Double) -> Void)?

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

        // 레이아웃/인터랙션 제한을 위한 CSS/JS 주입
        let lockdownScript = YouTubeWebViewHost.lockdownStyleAndInteractionScript()
        let lockdownUserScript = WKUserScript(source: lockdownScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        ucc.addUserScript(lockdownUserScript)

        // 🔹 HTML5 <video> pause/ended 이벤트 리스너 주입
        let playbackScript = YouTubeWebViewHost.playbackListenerScript()
        let playbackUserScript = WKUserScript(source: playbackScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(playbackUserScript)

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        // JS → Native 브릿지 채널 (super.init() 이후에 self 사용)
        ucc.add(WeakScriptMessageHandler(self), name: "ytcfg")
        ucc.add(WeakScriptMessageHandler(self), name: "tracks")
        ucc.add(WeakScriptMessageHandler(self), name: "playback")
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.backgroundColor = .clear
        self.webView.isOpaque = false

        // 스크롤/줌/바운스/인디케이터 비활성화
        let sv = self.webView.scrollView
        sv.isScrollEnabled = false
        sv.bounces = false
        sv.alwaysBounceVertical = false
        sv.alwaysBounceHorizontal = false
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.decelerationRate = .fast
        sv.pinchGestureRecognizer?.isEnabled = false

        // 제스처 중 롱프레스/패닝에 의한 화면 이동 차단 (플레이어 내부 제스처는 HTML 내부에서 처리되므로 영향 없음)
        sv.gestureRecognizers?.forEach { gr in
            if gr is UILongPressGestureRecognizer || gr is UIPanGestureRecognizer {
                gr.isEnabled = false
            }
        }
    }

    // MARK: - Public
    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // ✅ reset을 동기 메인에서 즉시 수행 (지연 Task 제거)
        if Thread.isMainThread {
            self.captionAnalyzer?.resetForNewVideo()
        } else {
            DispatchQueue.main.async { self.captionAnalyzer?.resetForNewVideo() }
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        log.info("WKNav allow → \(url.host ?? "-")")
        // Reset bridge flags for a fresh navigation
        didProcessCfg = false
        didProcessTracks = false
        webView.load(req)
    }
    
    // 현재 로드/요약 세션을 특정 노트에 연결(요약 캐시 저장/재활용 용도)
    @MainActor
    func bind(note: Note) {
        self.captionAnalyzer?.bind(note: note)
    }
    
    // ✅ 현재 재생 시간을 JS로 질의
    @MainActor
    func getCurrentTime(completion: @escaping (Double?) -> Void) {
        let js = "(function(){var v=document.querySelector('video'); if(!v) return null; return v.currentTime || 0; })();"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                self.log.error("getCurrentTime JS error: \(error.localizedDescription, privacy: .public)")
                completion(nil)
                return
            }
            if let t = result as? Double {
                completion(t)
            } else if let n = result as? NSNumber {
                completion(n.doubleValue)
            } else {
                completion(nil)
            }
        }
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

    // MARK: - Lockdown CSS/JS
    private static func lockdownStyleAndInteractionScript() -> String {
        // 1) 스타일: 여백 제거, 오버플로우 숨김, 플레이어만 전체 채우기
        // 2) 선택/롱프레스/텍스트 호출 비활성화
        // 3) 스크롤/터치 무시(플레이어 외 영역)
        // 4) viewport 고정(확대/축소 방지)
        let css = """
        html, body {
          margin: 0 !important;
          padding: 0 !important;
          overflow: hidden !important;
          height: 100% !important;
          background-color: #000 !important;
          -webkit-user-select: none !important;
          -webkit-touch-callout: none !important;
        }
        /* 유튜브 페이지에서 플레이어 이외의 UI 숨김 */
        #masthead-container, #masthead, #header, #guide, #guide-content,
        ytd-mini-guide-renderer, #footer, ytd-comments, ytd-merch-shelf-renderer,
        ytd-watch-metadata, ytd-watch-flexy #below, ytd-watch-flexy #secondary,
        ytd-watch-flexy ytd-video-secondary-info-renderer,
        ytd-watch-flexy ytd-video-primary-info-renderer { display: none !important; }
        ytd-app, ytd-page-manager, ytd-watch-flexy { height: 100% !important; }
        /* 플레이어를 화면 전체로 고정 */
        ytd-watch-flexy #player, #player-container, .html5-video-player {
          position: fixed !important;
          inset: 0 !important;
          width: 100% !important;
          height: 100% !important;
          max-width: 100% !important;
          max-height: 100% !important;
        }
        * { -webkit-user-drag: none !important; }
        """

        let js = """
        (function() {
          try {
            // viewport 강제
            var vp = document.querySelector('meta[name=viewport]');
            if (!vp) {
              vp = document.createElement('meta');
              vp.name = 'viewport';
              document.head.appendChild(vp);
            }
            vp.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no');
          } catch (e) {}

          try {
            // 스타일 주입
            var style = document.createElement('style');
            style.type = 'text/css';
            style.appendChild(document.createTextNode(`\(css.replacingOccurrences(of: "`", with: "\\`"))`));
            document.documentElement.appendChild(style);
          } catch (e) {}

          // 스크롤 방지
          try {
            window.addEventListener('scroll', function(){ window.scrollTo(0,0); }, {passive:false});
            document.addEventListener('touchmove', function(e){ e.preventDefault(); }, {passive:false});
            document.addEventListener('gesturestart', function(e){ e.preventDefault(); }, {passive:false});
          } catch (e) {}
        })();
        """

        return js
    }

    // MARK: - Playback listener (pause/ended → post currentTime)
    private static func playbackListenerScript() -> String {
        return """
        (function() {
          if (window._ytlex_playback_wired) return;
          window._ytlex_playback_wired = true;

          function post(payload) {
            try { window.webkit.messageHandlers.playback.postMessage(payload); } catch (e) {}
          }

          function findVideo() {
            try {
              var v = document.querySelector('video');
              return v || null;
            } catch (e) { return null; }
          }

          function wire() {
            var v = findVideo();
            if (!v) { setTimeout(wire, 400); return; }
            if (v._ytlex_wired) return;
            v._ytlex_wired = true;

            function send(ev) {
              post({ event: ev.type, currentTime: v.currentTime || 0, paused: !!v.paused });
            }
            ['pause','ended'].forEach(function(name) {
              try { v.addEventListener(name, send, { passive: true }); } catch(e) {}
            });
          }

          // 초기 시도 + DOM 변경 감시(플레이어 교체 대응)
          wire();
          try {
            var mo = new MutationObserver(function(){ wire(); });
            mo.observe(document.documentElement, { childList: true, subtree: true });
          } catch (e) {}
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
        } else if message.name == "playback" {
            guard let d = message.body as? [String: Any] else { return }
            let ev = (d["event"] as? String) ?? ""
            let t = (d["currentTime"] as? Double) ?? 0.0
            host.log.info("playback event=\(ev, privacy: .public) t=\(t, privacy: .public)")
            if ev == "pause" || ev == "ended" {
                host.onPause?(t)
            }
        }
    }
}

// MARK: - WK delegates
extension YouTubeWebViewHost: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 초기 로드 외 링크 탭 등으로 인한 화면 이동 차단
        if action.navigationType == .linkActivated || action.navigationType == .formSubmitted {
            log.error("WKNav cancel (link/form blocked)")
            decisionHandler(.cancel)
            return
        }
        // 유튜브 도메인만 허용(서브리소스 포함)
        if let host = action.request.url?.host?.lowercased(),
           host.contains("youtube.com") || host.contains("youtu.be") {
            decisionHandler(.allow); return
        }
        log.error("WKNav cancel (blocked host)")
        decisionHandler(.cancel)
    }
}
