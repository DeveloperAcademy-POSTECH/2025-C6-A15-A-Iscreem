//
//  MediaView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import OSLog
import SwiftData

struct MediaView: View {
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    @EnvironmentObject private var learningLogStore: LearningLogStore
    @Environment(\.modelContext) private var modelContext
    
    /// 현재 재생/요약 세션에 바인딩할 노트 (캐시 재활용/저장 목적)
    let note: Note?
    /// Note에서 내려받는 YouTube 링크 (없으면 플레이스홀더 유지)
    let videoURL: String?

    @State private var representable: YouTubeWebViewRepresentable?
    @State private var loadedURL: String?
    // ✅ pause 외에도 기억해 둘 마지막 비-제로 위치
    @State private var lastKnownPosition: Double?

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
        // ▶︎ 뒤로가기 직전 저장 요청(Notification) 수신 시 즉시 현재 시간 저장
        .onReceive(NotificationCenter.default.publisher(for: .persistPlaybackPosition)) { _ in
            guard let rep = representable else { return }
            Task { @MainActor in
                rep.getCurrentTime { t in
                    let candidate = max(t ?? 0, self.lastKnownPosition ?? 0)
                    self.persistPositionIfValid(candidate)
                    // ✅ 현재 시점까지의 요약 스냅샷도 함께 저장
                    self.persistChapterSnapshotUpToCurrent(at: candidate)
                }
            }
        }
        // ▶︎ 재생 중지 요청 수신 시 즉시 pause/stop
        .onReceive(NotificationCenter.default.publisher(for: .pausePlaybackRequested)) { _ in
            Task { @MainActor in
                // 저장은 StudyView에서 이미 요청됨. 여기서는 즉시 정지.
                representable?.pause()
                representable?.stop()
            }
        }
        .onAppear {
            if representable == nil {
                // YouTubePane의 역할을 이 View에서 수행: 캡션 분석기와 연결된 WebView 브리지 준비
                representable = YouTubeWebViewRepresentable(
                    captionAnalyzer: captionAnalyzer,
                    onPause: { t in
                        handlePause(at: t)
                    }
                )
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
                    representable = YouTubeWebViewRepresentable(
                        captionAnalyzer: captionAnalyzer,
                        onPause: { t in
                            handlePause(at: t)
                        }
                    )
                }
                DispatchQueue.main.async {
                    loadIfNeeded(u)
                }
            }
        }
        .onDisappear {
            // ✅ 화면 이탈 시점에 현재 재생 시간을 질의하여 백업 저장
            guard let rep = representable else { return }
            Task { @MainActor in
                rep.getCurrentTime { t in
                    let queried = (t ?? 0)
                    let candidate = max(queried, self.lastKnownPosition ?? 0)
                    self.persistPositionIfValid(candidate)
                    // ✅ 현재 시점까지의 요약 스냅샷도 함께 저장
                    self.persistChapterSnapshotUpToCurrent(at: candidate)
                }
                // 안전하게 정지
                rep.pause()
                rep.stop()
            }
        }
    }

    // MARK: - Pause Handler
    private func handlePause(at time: TimeInterval) {
        // 0초 근처(초기 잡음) 필터링
        let t = time
        guard t > 0.5 else { return }
        // 기억해 두기
        lastKnownPosition = max(lastKnownPosition ?? 0, t)
        // 1) 노트에 저장(진행된 경우만)
        if let note = note {
            if (note.lastPositionSeconds ?? 0) < t {
                note.lastPositionSeconds = t
                try? modelContext.save()
            }
        }
        // 2) 학습 로그에 기록(진행된 경우만)
        if let n = note {
            learningLogStore.recordProgress(
                folderName: n.folder?.name,
                noteTitle: n.title,
                noteIdentifier: String(describing: n.id),
                videoURL: n.videoURL ?? videoURL,
                position: t
            )
        }
        // 3) ✅ 현재 시점까지의 챕터 요약/키워드 스냅샷 저장
        persistChapterSnapshotUpToCurrent(at: t)
    }
    
    // ✅ onDisappear 등에서 호출: 유효한 값만 저장
    private func persistPositionIfValid(_ time: TimeInterval) {
        let t = time
        guard t > 0.5 else { return } // 0초 근처 무시
        // 이전 값 대비 진행된 값만 반영
        var shouldSave = true
        if let prev = note?.lastPositionSeconds, prev >= t {
            shouldSave = false
        }
        if shouldSave {
            if let note = note {
                note.lastPositionSeconds = t
                try? modelContext.save()
            }
            if let n = note {
                learningLogStore.recordProgress(
                    folderName: n.folder?.name,
                    noteTitle: n.title,
                    noteIdentifier: String(describing: n.id),
                    videoURL: n.videoURL ?? videoURL,
                    position: t
                )
            }
        }
    }

    // MARK: - ✅ “현재 시점까지” 챕터 스냅샷 저장
    private func persistChapterSnapshotUpToCurrent(at time: TimeInterval) {
        guard let n = note else { return }
        // CaptionAnalyzer가 만든 챕터/불릿/키워드에서 현재 시점까지 포함
        let snapshot = buildUpToCurrentChapters(at: time)
        guard !snapshot.isEmpty else { return }
        // Note에도 저장하고, LearningLogStore의 메모리 맵도 갱신
        learningLogStore.updateChapterSummariesUpToCurrent(for: n, chapters: snapshot)
    }
    
    private func buildUpToCurrentChapters(at time: TimeInterval) -> [CachedChapter] {
        // 챕터가 없으면 빈 배열 반환
        let chapters = captionAnalyzer.chapters
        guard !chapters.isEmpty else { return [] }
        
        // time 이전(포함) 챕터만 수집: start <= time 인 챕터를 포함
        let included = chapters
            .sorted(by: { $0.start < $1.start })
            .filter { $0.start <= time }
        
        // bullets/keywords를 map에서 꺼내어 CachedChapter 구성
        var out: [CachedChapter] = []
        for ch in included {
            let bullets = captionAnalyzer.chapterBullets[ch.id] ?? []
            let keywords = captionAnalyzer.chapterKeywords[ch.id] ?? []
            // 4개까지만 저장(모델 규약)
            let trimmedBullets = Array(bullets.prefix(4))
            out.append(
                CachedChapter(title: ch.title, bullets: trimmedBullets, keywords: keywords)
            )
        }
        return out
    }

    // MARK: - Helpers
    private func loadIfNeeded(_ url: String) {
        // 이어보기: 재개 시간이 있으면 URL에 붙여서 로드
        let resume = bestResumePosition()
        let finalURL = (resume ?? 0) > 0.5 ? urlByEmbeddingStart(url, seconds: resume!) : url
        
        guard loadedURL != finalURL else { return }
        loadedURL = finalURL
        
        if let n = note {
            // 노트 바인딩 + 로드 (캐시 선반영/후저장에 필요)
            representable?.load(finalURL, for: n)
        } else {
            representable?.load(finalURL)
        }
        // 보강: 일부 케이스에서 URL 파라미터가 무시될 수 있으므로 JS로 한 번 더 정확히 시킹
        if let resume, resume > 0.5 {
            representable?.seek(to: resume, autoPlay: true)
        }
    }
    
    // 학습 로그 → 노트 순으로 재개 위치를 결정
    private func bestResumePosition() -> Double? {
        // 메모리에 방금 업데이트된 값이 있다면 그 값을 우선 사용
        if let mem = lastKnownPosition, mem > 0.5 {
            return mem
        }
        // 1) 학습 로그에 저장된 마지막 재생 위치(식별자 우선, 없으면 제목+URL 규칙)
        if let n = note {
            let nid = String(describing: n.id)
            let url = n.videoURL ?? videoURL
            if let s = learningLogStore.sessions.first(where: { sess in
                if let sid = sess.noteIdentifier, sid == nid { return true }
                if sess.noteTitle == n.title {
                    if let v1 = sess.videoURL, let v2 = url, v1 == v2 { return true }
                    if url == nil { return true }
                }
                return false
            }) {
                if let lp = s.lastPosition, lp > 0.5 { return lp }
            }
            // 2) 노트에 저장된 위치
            if let lp = n.lastPositionSeconds, lp > 0.5 { return lp }
        }
        return nil
    }
    
    // ✅ URL에 시작 시간을 붙여주는 유틸
    // - youtu.be, youtube.com/watch, shorts 등: t=80s 사용
    // - youtube.com/embed: start=80 사용
    // - 기존 t/start 및 프래그먼트(#t=80s, #start=80) 제거
    // - shorts는 watch?v=<id>로 표준화(시작 파라미터 인식률 향상)
    private func urlByEmbeddingStart(_ urlString: String, seconds: Double) -> String {
        guard var url = URL(string: urlString), seconds > 0.5 else { return urlString }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        let _ = (comps.host ?? "").lowercased()
        var path = comps.path
        
        // shorts → watch로 정규화
        if path.lowercased().contains("/shorts/"),
           let id = path.components(separatedBy: "/shorts/").last?.components(separatedBy: "/").first,
           !id.isEmpty {
            path = "/watch"
            comps.path = path
            var items = comps.queryItems ?? []
            if !items.contains(where: { $0.name == "v" }) {
                items.append(URLQueryItem(name: "v", value: id))
            }
            comps.queryItems = items
        }
        
        // 기존 t/start 제거
        var q = comps.queryItems ?? []
        q.removeAll { item in
            let name = item.name.lowercased()
            return name == "t" || name == "start"
        }
        comps.queryItems = q
        
        // 프래그먼트(#t=80s 등) 제거
        comps.fragment = nil
        
        let secInt = Int(seconds.rounded())
        if comps.path.lowercased().contains("/embed/") {
            // 임베드 경로는 start=초
            q.append(URLQueryItem(name: "start", value: "\(secInt)"))
        } else {
            // 일반/shorts/짧은 주소 → t=80s 형태가 가장 호환성 좋음
            q.append(URLQueryItem(name: "t", value: "\(secInt)s"))
        }
        comps.queryItems = q
        
        if let u = comps.url {
            url = u
        }
        return url.absoluteString
    }
}

// MARK: - Playback Persist/Pause Notifications
extension Notification.Name {
    static let persistPlaybackPosition = Notification.Name("PersistPlaybackPosition")
    static let pausePlaybackRequested = Notification.Name("PausePlaybackRequested")
}

#Preview(traits: .landscapeLeft) {
    MediaView(
        note: Note(title: "미리보기 노트", lastRead: Date()),
        videoURL: "https://youtu.be/LBqJwmFMQHI?si=G1aD3hiMw5-ZSdWk"
    )
    .environmentObject(CaptionAnalyzer())
}
