//
//  CaptionAnalyzerViewModel.swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import NaturalLanguage
import Foundation
import Combine
import OSLog
import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

final class CaptionAnalyzer: ObservableObject {
    
    private let log = Logger(subsystem: "learningTool", category: "CaptionAnalyzer")
    private weak var boundNote: Note?
    private func short(_ s: String, max: Int = 120) -> String { s.count > max ? (String(s.prefix(max)) + "…") : s }
    
    enum VTTStatus: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }
    
    struct VTTCue: Identifiable, Hashable {
        let id = UUID()
        let start: Double
        let end: Double
        let text: String
    }
    
    @Published var vttStatus: VTTStatus = .idle
    @Published var vttCues: [VTTCue] = []
    
    // MARK: - Summarization (Auto Prefetch)
    enum SummaryStatus: Equatable {
        case idle
        case summarizing
        case ready
        case failed(String)
    }
    
    struct Chapter: Identifiable, Hashable {
        let id = UUID()
        let start: Double
        let end: Double
        var title: String
        var gist: String
    }
    
    @Published var summaryStatus: SummaryStatus = .idle
    @Published var summaryText: String = ""
    @Published var chapters: [Chapter] = []
    @Published var chapterTexts: [UUID: String] = [:]
    @Published var chapterBullets: [UUID: [String]] = [:]
    @Published var chapterKeywords: [UUID: [String]] = [:]
    @Published var displayKeywords: [String] = []
    
    var autoSummarizeEnabled: Bool = false
    @Published var finalSummary: String = ""
    @Published var isMergingFinal: Bool = false
    @Published var extractedKeywords: [String] = []
    @Published var accumulatedKeywords: [String] = []
    
    struct SummaryDebug {
        var runId = UUID()
        var processed = 0
        var total = 0
        var lastUpdate = Date()
    }
    @Published var summaryDebug = SummaryDebug()
    
    private var summarizer: Summarizer?
    private var isFetchingCaptions = false
    private var lastPrefetchKey: String?
    private var sessionId = UUID()
    
    // 분리된 모듈들
    private let summarizerEngine: SummarizerEngine
    private let keywordExtractor: KeywordExtractor
    
    init() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            self.summarizer = try? AppleFMSummarizer()
        } else {
            self.summarizer = nil
        }
        if summarizer != nil {
            log.info("Summarizer available (AppleFM or HTTP)")
        } else {
            log.info("Summarizer unavailable; summaries will be disabled unless HTTP is wired")
        }
#else
        self.summarizer = nil
#endif
        
        self.summarizerEngine = SummarizerEngine(logger: log)
        self.keywordExtractor = KeywordExtractor(logger: log)
    }
    
    // MARK: - Reset per new video/note
    @MainActor
    func resetForNewVideo() {
        self.sessionId = UUID()
        self.vttStatus = .idle
        self.vttCues = []
        self.isFetchingCaptions = false
        self.lastPrefetchKey = nil
        
        self.summaryStatus = .idle
        self.summaryText = ""
        self.chapters = []
        self.chapterTexts = [:]
        self.chapterBullets = [:]
        self.chapterKeywords = [:]
        self.displayKeywords = []
        self.finalSummary = ""
        self.isMergingFinal = false
        self.extractedKeywords = []
        self.accumulatedKeywords = []
        self.summaryDebug = SummaryDebug()
    }
    
    // MARK: - Bind & Preload (SwiftData Note)
    @MainActor
    func bind(note: Note) {
        self.boundNote = note
        
        let hasCache =
        !(note.cachedSummaryLines.isEmpty) ||
        (note.cachedFinalSummary?.isEmpty == false) ||
        !(note.cachedKeywords.isEmpty) ||
        !(note.cachedChapters.isEmpty)
        
        if hasCache {
            self.summaryText = note.cachedSummaryLines.joined(separator: "\n")
            self.finalSummary = note.cachedFinalSummary ?? ""
            self.extractedKeywords = note.cachedKeywords
            self.displayKeywords = Array(note.cachedKeywords.prefix(40))
            
            var rebuilt: [Chapter] = []
            var bulletsMap: [UUID:[String]] = [:]
            for ch in note.cachedChapters {
                let c = Chapter(start: 0, end: 0, title: ch.title, gist: ch.bullets.joined(separator: " "))
                rebuilt.append(c)
                bulletsMap[c.id] = ch.bullets
            }
            self.chapters = rebuilt
            self.chapterBullets = bulletsMap
            self.summaryStatus = .ready
        } else {
            self.summaryText = ""
            self.finalSummary = ""
            self.extractedKeywords = []
            self.displayKeywords = []
            self.chapters = []
            self.chapterBullets = [:]
            self.summaryStatus = .idle
        }
    }
    
    @MainActor
    func preloadFromNoteIfAvailable(_ note: Note) {
        let cachedChapters = note.cachedChapters
        let hasCache = (!cachedChapters.isEmpty)
        || !(note.cachedSummaryLines.isEmpty)
        || (note.cachedFinalSummary != nil)
        || !(note.cachedKeywords.isEmpty)
        
        guard hasCache else { return }
        
        self.summaryStatus = .ready
        
        var built: [Chapter] = []
        var bulletsMap: [UUID: [String]] = [:]
        for ch in cachedChapters {
            let c = Chapter(start: 0, end: 0,
                            title: ch.title.isEmpty ? "제목" : ch.title,
                            gist: (ch.bullets.first ?? ""))
            built.append(c)
            bulletsMap[c.id] = Array(ch.bullets.prefix(4))
        }
        self.chapters = built
        self.chapterBullets = bulletsMap
        
        if !note.cachedSummaryLines.isEmpty {
            self.summaryText = note.cachedSummaryLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
        }
        if let fs = note.cachedFinalSummary {
            self.finalSummary = fs
        }
        self.extractedKeywords = note.cachedKeywords
        self.displayKeywords = Array(note.cachedKeywords.prefix(40))
    }
    
    // MARK: - Summarization Orchestration
    func summarizeNow() async {
        log.info("summarizeNow() invoked; vttStatus=\(String(describing: self.vttStatus)), cues=\(self.vttCues.count)")
        guard case .ready = vttStatus, !vttCues.isEmpty else { return }
        await summarizeFromCues(vttCues)
    }
    
    private func startAutoSummarizeIfNeeded() {
        guard autoSummarizeEnabled,
              case .ready = vttStatus,
              !vttCues.isEmpty,
              summaryStatus == .idle,
              summarizer != nil else { return }
        log.info("startAutoSummarizeIfNeeded → firing (autoSummarizeEnabled=\(self.autoSummarizeEnabled), cues=\(self.vttCues.count))")
        Task { await summarizeFromCues(self.vttCues) }
    }
    
    private func summarizeFromCues(_ cues: [VTTCue]) async {
        let sid = self.sessionId
        let runId = UUID()
        await MainActor.run {
            guard sid == self.sessionId else { return }
            self.summaryStatus = .summarizing
            self.summaryText = ""
            self.chapters = []
            self.chapterTexts = [:]
            self.summaryDebug = SummaryDebug(runId: runId, processed: 0, total: 0, lastUpdate: Date())
        }
        
        if sid != self.sessionId { return }
        
        guard let summarizer = self.summarizer else {
            await MainActor.run {
                self.summaryStatus = .failed("요약 모델 자산이 없습니다. (iOS 26+ 지원 기기·언어·지역 필요)")
            }
            return
        }
        
        // SummarizerEngine에 위임
        await summarizerEngine.processCues(
            cues: cues,
            sessionId: sid,
            summarizer: summarizer,
            runId: runId,
            onChaptersBuilt: { [weak self] chapters, chapterTexts in
                guard let self else { return }
                await MainActor.run {
                    self.chapters = chapters
                    self.chapterTexts = chapterTexts
                }
            },
            onChapterTitleUpdate: { [weak self] id, title in
                guard let self else { return }
                await self.setChapterTitle(id: id, title: title)
            },
            onChapterGistUpdate: { [weak self] id, gist in
                guard let self else { return }
                await self.setChapterGist(id: id, gist: gist)
            },
            onChapterBulletsUpdate: { [weak self] id, bullets in
                guard let self else { return }
                await self.setChapterBullets(id: id, bullets: bullets)
            },
            onSummaryProgress: { [weak self] processed, total in
                guard let self else { return }
                await MainActor.run {
                    self.summaryDebug.processed = processed
                    self.summaryDebug.total = total
                    self.summaryDebug.lastUpdate = Date()
                }
            },
            onSummaryTextUpdate: { [weak self] text in
                guard let self else { return }
                await MainActor.run {
                    withAnimation(.none) { self.summaryText = text }
                }
            },
            onComplete: { [weak self] summaryLines in
                guard let self else { return }
                await MainActor.run {
                    withAnimation(.none) {
                        self.summaryText = summaryLines.joined(separator: "\n")
                        self.summaryStatus = .ready
                    }
                    self.summaryDebug.lastUpdate = Date()
                }
                self.mergeFinalAsync(pieces: summaryLines, runTag: runId.uuidString.prefix(8), summarizer: summarizer, sessionId: sid)
            }
        )
    }
    
    private func mergeFinalAsync(pieces: [String], runTag: Substring, summarizer: Summarizer, sessionId sid: UUID) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let sid = sid
            self.log.info("sum[\(runTag)] merge begin; pieces=\(pieces.count)")
            await MainActor.run {
                guard sid == self.sessionId else { return }
                self.isMergingFinal = true
            }
            do {
                let merged = try await summarizer.mergeSummaries(pieces)
                await MainActor.run {
                    guard sid == self.sessionId else { return }
                    self.finalSummary = merged.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isMergingFinal = false
                    self.extractedKeywords = self.keywordExtractor.extractKeywords(from: self.finalSummary, topN: 10)
                    self.persistCacheToBoundNoteIfPossible()
                }
                self.log.info("sum[\(runTag)] merge done")
            } catch {
                let ns = error as NSError
                self.log.error("sum[\(runTag)] merge error: \(ns.localizedDescription, privacy: .public)")
                await MainActor.run {
                    guard sid == self.sessionId else { return }
                    self.isMergingFinal = false
                }
            }
        }
    }
    
    @MainActor
    private func setChapterTitle(id: UUID, title: String) {
        if let idx = chapters.firstIndex(where: { $0.id == id }) {
            chapters[idx].title = title
        }
    }
    
    @MainActor
    private func setChapterGist(id: UUID, gist: String) {
        if let idx = chapters.firstIndex(where: { $0.id == id }) {
            chapters[idx].gist = gist
        }
    }
    
    @MainActor
    private func setChapterBullets(id: UUID, bullets: [String]) {
        print("🟦 setChapterBullets called for \(id), bullets count=\(bullets.count)")
        chapterBullets[id] = bullets
        let chapterText = bullets.joined(separator: " ")

        Task {
            let updateKeywords: ([String]) -> Void = { newKeywords in
                Task { @MainActor in
                    self.chapterKeywords[id] = newKeywords

                    var allKeywords: [String] = []
                    for cid in self.chapters.map({ $0.id }) {
                        if let kws = self.chapterKeywords[cid] {
                            for kw in kws where !allKeywords.contains(kw) {
                                allKeywords.append(kw)
                            }
                        }
                    }

                    self.displayKeywords = allKeywords
                    self.accumulatedKeywords = allKeywords

                    print("✅ Chapter \(id) keywords updated → 총 \(allKeywords.count)개 단어 누적됨")
                    print("🧩 현재 displayKeywords: \(self.displayKeywords)")
                }
            }

            // KeywordExtractor에 위임
            let finalKeywords = await self.keywordExtractor.extractChapterKeywords(
                from: chapterText,
                summarizer: self.summarizer
            )
            
            await MainActor.run {
                updateKeywords(finalKeywords)
                print("🟨 refined keywords -> \(finalKeywords)")
            }
        }
    }
    
    @MainActor
    private func persistCacheToBoundNoteIfPossible() {
        guard let note = self.boundNote else { return }
        
        var snapshot: [CachedChapter] = []
        for ch in self.chapters {
            let bullets = self.chapterBullets[ch.id] ?? []
            snapshot.append(CachedChapter(title: ch.title,
                                          bullets: Array(bullets.prefix(4))))
        }
        note.cachedChapters = snapshot
        
        note.cachedSummaryLines = self.summaryText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        note.cachedFinalSummary = self.finalSummary.isEmpty ? nil : self.finalSummary
        note.cachedKeywords = self.extractedKeywords
    }
    
    // MARK: - youtubei (player API) Prefetch
    func prefetchViaYouTubei(videoID: String, apiKey: String, clientName: String, clientVersion: String, sts: Int?) async {
        let sid = self.sessionId
        let key = "\(videoID)#\(clientName)#\(clientVersion)#\(sts ?? -1)"
        if lastPrefetchKey == key, (vttStatus == .loading || vttStatus == .ready) { return }
        if self.isFetchingCaptions { return }
        self.isFetchingCaptions = true
        self.lastPrefetchKey = key
        defer { self.isFetchingCaptions = false }
        
        await MainActor.run { if self.vttStatus == .idle { self.vttStatus = .loading } }
        log.info("youtubei(begin) videoID=\(videoID, privacy: .public) client=\(clientName, privacy: .public)/\(clientVersion, privacy: .public) sts=\(String(describing: sts), privacy: .public)")
        do {
            guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(apiKey)") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = [
                "context": [
                    "client": [
                        "hl": "ko",
                        "gl": "KR",
                        "clientName": clientName,
                        "clientVersion": clientVersion
                    ]
                ],
                "videoId": videoID,
                "racyCheckOk": true,
                "contentCheckOk": true
            ]
            if let s = sts {
                body["playbackContext"] = ["contentPlaybackContext": ["signatureTimestamp": s]]
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw NSError(domain: "VTT", code: -30, userInfo: [NSLocalizedDescriptionKey: "youtubei 응답 오류"])
            }
            struct PlayerResp: Decodable {
                struct Captions: Decodable {
                    struct TL: Decodable {
                        struct Name: Decodable { let simpleText: String?; let runs: [Run]? }
                        struct Run: Decodable { let text: String? }
                        struct Track: Decodable {
                            let baseUrl: String
                            let languageCode: String?
                            let kind: String?
                            let name: Name?
                        }
                        let captionTracks: [Track]?
                    }
                    let playerCaptionsTracklistRenderer: TL?
                }
                let captions: Captions?
            }
            let pr = try JSONDecoder().decode(PlayerResp.self, from: data)
            let tl = pr.captions?.playerCaptionsTracklistRenderer
            let tracks = tl?.captionTracks ?? []
            log.info("youtubei(tracks) count=\(tracks.count)")
            
            struct JTrack { let baseUrl: String; let lang: String; let kind: String?; let name: String? }
            let mapped: [JTrack] = tracks.map { t in
                let nm: String
                if let st = t.name?.simpleText { nm = st }
                else if let rs = t.name?.runs { nm = rs.compactMap { $0.text }.joined() }
                else { nm = "" }
                return JTrack(baseUrl:  t.baseUrl, lang: t.languageCode ?? "", kind: t.kind, name: nm)
            }
            guard !mapped.isEmpty else {
                throw NSError(domain: "VTT", code: -31, userInfo: [NSLocalizedDescriptionKey: "youtubei에 자막 트랙 없음"])
            }
            let prefs = ["ko","ko-KR","en","en-US"]
            func pick(_ cond: (JTrack)->Bool) -> JTrack? {
                for p in prefs {
                    if let t = mapped.first(where: { $0.lang == p && cond($0) }) { return t }
                }
                return mapped.first(where: cond)
            }
            let manual = pick { ($0.kind ?? "").lowercased() != "asr" }
            let asr = pick { ($0.kind ?? "").lowercased() == "asr" }
            let chosen = manual ?? asr ?? mapped[0]
            log.info("youtubei(chosen) lang=\(chosen.lang, privacy: .public) kind=\(String(describing: chosen.kind), privacy: .public) name=\(String(describing: chosen.name), privacy: .public) base=\(self.short(chosen.baseUrl), privacy: .public)")
            
            let cues = try await VTTParser.fetchFromBaseUrl(chosen.baseUrl)
            await MainActor.run {
                guard sid == self.sessionId else { return }
                self.log.info("youtubei(success) cues=\(cues.count)")
                self.vttCues = cues
                self.vttStatus = cues.isEmpty ? .failed("자막이 비어 있습니다.") : .ready
                if !cues.isEmpty { self.startAutoSummarizeIfNeeded() }
            }
        } catch {
            await MainActor.run {
                if case .loading = self.vttStatus {
                    self.log.error("youtubei(error) \(error.localizedDescription, privacy: .public)")
                    self.vttStatus = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    func prefetchFromTracks(_ jsTracks: [[String: Any]]) async {
        let sid = self.sessionId
        log.info("tracks(begin) rawCount=\(jsTracks.count)")
        if case .ready = vttStatus, !vttCues.isEmpty { return }
        await MainActor.run {
            if self.vttStatus == .idle { self.vttStatus = .loading }
        }
        if self.isFetchingCaptions { return }
        self.isFetchingCaptions = true
        defer { self.isFetchingCaptions = false }
        struct JTrack { let baseUrl: String; let lang: String; let name: String?; let kind: String? }
        let tracks: [JTrack] = jsTracks.compactMap { d in
            guard let base = d["baseUrl"] as? String else { return nil }
            let lang = (d["lang"] as? String) ?? ""
            let name = d["name"] as? String
            let kind = d["kind"] as? String
            return JTrack(baseUrl: base, lang: lang, name: name, kind: kind)
        }
        log.info("tracks(mapped) count=\(tracks.count) langs=\(tracks.map { $0.lang }.joined(separator: ","), privacy: .public)")
        guard !tracks.isEmpty else { return }
        let prefs = ["ko","ko-KR","en","en-US"]
        
        func pick(_ cond: (JTrack)->Bool) -> JTrack? {
            for p in prefs {
                if let t = tracks.first(where: { $0.lang == p && cond($0) }) { return t }
            }
            return tracks.first(where: cond)
        }
        let manual = pick { ($0.kind ?? "").lowercased() != "asr" }
        let asr = pick { ($0.kind ?? "").lowercased() == "asr" }
        let chosen = manual ?? asr ?? tracks.first!
        log.info("tracks(chosen) lang=\(chosen.lang, privacy: .public) kind=\(String(describing: chosen.kind), privacy: .public) name=\(String(describing: chosen.name), privacy: .public) base=\(self.short(chosen.baseUrl), privacy: .public)")
        do {
            let cues = try await VTTParser.fetchFromBaseUrl(chosen.baseUrl)
            await MainActor.run {
                guard sid == self.sessionId else { return }
                self.log.info("tracks(success) cues=\(cues.count)")
                self.vttCues = cues
                self.vttStatus = cues.isEmpty ? .failed("자막이 비어 있습니다.") : .ready
                if !cues.isEmpty { self.startAutoSummarizeIfNeeded() }
            }
        } catch {
            await MainActor.run {
                self.log.error("tracks(error) \(error.localizedDescription, privacy: .public)")
                self.vttStatus = .failed(error.localizedDescription)
            }
        }
    }
}
