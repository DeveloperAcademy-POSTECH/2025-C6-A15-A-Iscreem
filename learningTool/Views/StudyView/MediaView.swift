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
        // 2) 현재 자막에서 스니펫 추출(선택)
        let snippet = snippet(at: t)
        // 3) 학습 로그에 기록(진행된 경우만)
        if let n = note {
            learningLogStore.recordProgress(
                folderName: n.folder?.name,
                noteTitle: n.title,
                noteIdentifier: String(describing: n.id),
                videoURL: n.videoURL ?? videoURL,
                position: t,
                snippet: snippet
            )
        }
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
                let snippet = snippet(at: t)
                learningLogStore.recordProgress(
                    folderName: n.folder?.name,
                    noteTitle: n.title,
                    noteIdentifier: String(describing: n.id),
                    videoURL: n.videoURL ?? videoURL,
                    position: t,
                    snippet: snippet
                )
            }
        }
    }

    private func snippet(at t: TimeInterval) -> String? {
        let cues = captionAnalyzer.vttCues
        guard !cues.isEmpty else { return nil }
        // 해당 시간에 걸친 cue 또는 가장 가까운 이전 cue 선택
        if let exact = cues.first(where: { t >= $0.start && t <= $0.end }) {
            return exact.text
        }
        // 앞쪽에서 가장 가까운 것
        let prev = cues
            .filter { $0.start <= t }
            .max(by: { $0.start < $1.start })
        return prev?.text
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
