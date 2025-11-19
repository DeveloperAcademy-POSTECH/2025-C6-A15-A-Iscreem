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
import UIKit

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
    
    // iPhone / iPad 런타임 판별 헬퍼 (디버그 출력용)
    private static var isIPhone: Bool {
#if os(iOS)
#if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
#else
        return false
#endif
#else
        return false
#endif
    }
    private static var isIPad: Bool {
#if os(iOS)
#if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
#else
        return false
#endif
#else
        return false
#endif
    }
    
    init() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // iPhone / iPad 공통: FoundationModels 사용 시도
            let device = CaptionAnalyzer.isIPhone ? "iPhone" : (CaptionAnalyzer.isIPad ? "iPad" : "iOS-Other")
            log.info("FM: attempting AppleFMSummarizer on \(device)")
            do {
                self.summarizer = try AppleFMSummarizer()
                log.info("FM: AppleFMSummarizer initialized successfully.")
            } catch {
                let ns = error as NSError
                self.summarizer = nil
                log.error("FM: AppleFMSummarizer init failed: \(ns.localizedDescription, privacy: .public)")
            }
            if self.summarizer == nil {
                log.info("FM: Summarizer unavailable at runtime; will use heuristic fallback.")
            }
        } else {
            // iOS 26 미만: 공통 폴백
            self.summarizer = nil
            log.info("FM: Unavailable on this OS; using heuristic fallback.")
        }
#else
        // 빌드 타임에 FoundationModels가 링크되지 않은 경우
        self.summarizer = nil
        log.info("FM: FoundationModels not available at build time; using heuristic fallback.")
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
            
            var rebuilt: [Chapter] = []
            var bulletsMap: [UUID:[String]] = [:]
            var keywordsMap: [UUID:[String]] = [:]
            var allKeywords: [String] = []
            
            for ch in note.cachedChapters {
                let c = Chapter(start: 0, end: 0, title: ch.title, gist: ch.bullets.joined(separator: " "))
                rebuilt.append(c)
                bulletsMap[c.id] = ch.bullets
                keywordsMap[c.id] = ch.keywords
                
                for kw in ch.keywords where !allKeywords.contains(kw) {
                    allKeywords.append(kw)
                }
            }
            
            self.chapters = rebuilt
            self.chapterBullets = bulletsMap
            self.chapterKeywords = keywordsMap
            self.displayKeywords = allKeywords
            self.accumulatedKeywords = allKeywords
            self.summaryStatus = .ready
            
            if Self.isIPhone {
                print("✅ bind() → 캐시 복원 완료: 챕터 \(rebuilt.count)개, 키워드 \(allKeywords.count)개")
            }
        } else {
            self.summaryText = ""
            self.finalSummary = ""
            self.extractedKeywords = []
            self.displayKeywords = []
            self.chapters = []
            self.chapterBullets = [:]
            self.chapterKeywords = [:]
            self.accumulatedKeywords = []
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
        var keywordsMap: [UUID: [String]] = [:]
        var allKeywords: [String] = []
        
        for ch in cachedChapters {
            let c = Chapter(start: 0, end: 0,
                            title: ch.title.isEmpty ? "제목" : ch.title,
                            gist: (ch.bullets.first ?? ""))
            built.append(c)
            bulletsMap[c.id] = Array(ch.bullets.prefix(7))
            keywordsMap[c.id] = ch.keywords
            
            for kw in ch.keywords where !allKeywords.contains(kw) {
                allKeywords.append(kw)
            }
        }
        
        self.chapters = built
        self.chapterBullets = bulletsMap
        self.chapterKeywords = keywordsMap
        self.displayKeywords = allKeywords
        self.accumulatedKeywords = allKeywords
        
        if !note.cachedSummaryLines.isEmpty {
            self.summaryText = note.cachedSummaryLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
        }
        if let fs = note.cachedFinalSummary {
            self.finalSummary = fs
        }
        self.extractedKeywords = note.cachedKeywords
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
              summaryStatus == .idle else { return }
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
        
        // Summarizer가 존재하면 기기와 무관하게 AppleFM 경로 사용
        if let summarizer = self.summarizer {
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
                    self.setChapterTitle(id: id, title: title)
                },
                onChapterGistUpdate: { [weak self] id, gist in
                    guard let self else { return }
                    self.setChapterGist(id: id, gist: gist)
                },
                onChapterBulletsUpdate: { [weak self] id, bullets in
                    guard let self else { return }
                    await MainActor.run {
                        self.setChapterBullets(id: id, bullets: bullets)
                    }
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
            return
        }
        
        // Summarizer가 없을 때: 휴리스틱 폴백 경로
        log.info("summarizeFromCues() fallback → using heuristic summarization (Summarizer unavailable)")
        await fallbackSummarizeFromCues(cues, sid: sid, runId: runId)
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
                // 병합 실패 → 폴백 텍스트로 대체
                await MainActor.run {
                    guard sid == self.sessionId else { return }
                    self.isMergingFinal = false
                    if self.finalSummary.isEmpty {
                        self.finalSummary = self.summaryText
                    }
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
        // 아이폰 전용 디버그 로그
        if Self.isIPhone {
            print("🟦 setChapterBullets called for \(id), bullets count=\(bullets.count)")
        }
        chapterBullets[id] = bullets
        
        // gist도 포함하여 더 풍부한 맥락으로 키워드 추출
        let chapterGist = chapters.first(where: { $0.id == id })?.gist ?? ""
        let combinedText = ([chapterGist] + bullets).joined(separator: " ")
        
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
                    
                    // 아이폰 전용 디버그 로그
                    if Self.isIPhone {
                        print("✅ Chapter \(id) keywords updated → 총 \(allKeywords.count)개 단어 누적됨")
                        print("🧩 현재 displayKeywords: \(self.displayKeywords)")
                    }
                    
                    // 키워드가 업데이트될 때마다 즉시 저장
                    self.persistCacheToBoundNoteIfPossible()
                }
            }
            
            // 요약 텍스트 기반으로 키워드 추출
            let finalKeywords = await self.keywordExtractor.extractChapterKeywords(
                from: combinedText,  // gist + bullets 조합
                summarizer: self.summarizer
            )
            
            await MainActor.run {
                updateKeywords(finalKeywords)
                // 아이폰 전용 디버그 로그
                if Self.isIPhone {
                    print("🟨 refined keywords -> \(finalKeywords)")
                }
            }
        }
    }
    
    @MainActor
    private func persistCacheToBoundNoteIfPossible() {
        guard let note = self.boundNote else { return }
        
        var snapshot: [CachedChapter] = []
        for ch in self.chapters {
            let bullets = self.chapterBullets[ch.id] ?? []
            let keywords = self.chapterKeywords[ch.id] ?? []
            snapshot.append(CachedChapter(
                title: ch.title,
                bullets: Array(bullets.prefix(7)),
                keywords: keywords
            ))
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
        
        if Self.isIPhone {
            print("💾 persistCacheToBoundNoteIfPossible: 챕터 \(snapshot.count)개 저장, 총 키워드 \(self.accumulatedKeywords.count)개")
        }
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
    // MARK: - Fallback Summarization (iOS 18+ without Apple Intelligence)
    /// Summarizer(AppleFMSummarizer 등)를 사용할 수 없는 환경에서
    /// 자막 텍스트만으로 간단한 챕터/요약/키워드 정보를 생성하여
    /// iOS 18+ 사용자에게도 유사한 UX를 제공한다.
    private func fallbackSummarizeFromCues(_ cues: [VTTCue], sid: UUID, runId: UUID) async {
        let fullText = cues
            .map { $0.text }
            .joined(separator: " ")
            .replacingOccurrences(of: "\n", with: " ")
        
        guard !fullText.isEmpty else {
            await MainActor.run {
                guard sid == self.sessionId else { return }
                self.summaryStatus = .failed("요약할 자막 데이터가 없습니다.")
            }
            return
        }
        
        // 자막 길이에 따라 2~6개 사이의 챕터로 단순 분할
        let estimatedChapterCount = max(2, min(6, max(1, fullText.count / 800)))
        let chapterCount = min(estimatedChapterCount, max(1, cues.count))
        let chunkSize = max(1, cues.count / chapterCount)
        
        var chapters: [Chapter] = []
        var bulletsMap: [UUID: [String]] = [:]
        
        let sentenceDelimiters = CharacterSet(charactersIn: ".?!。！？")
        let sentences = fullText
            .components(separatedBy: sentenceDelimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for (index, startIndex) in stride(from: 0, to: cues.count, by: chunkSize).enumerated() {
            let endIndex = min(startIndex + chunkSize, cues.count)
            let slice = cues[startIndex..<endIndex]
            guard let first = slice.first, let last = slice.last else { continue }
            
            let sliceText = slice
                .map { $0.text }
                .joined(separator: " ")
            
            let sliceSentences = sliceText
                .components(separatedBy: sentenceDelimiters)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let titleBase = sliceSentences.first ?? "챕터 \(index + 1)"
            let title = String(titleBase.prefix(40))
            let gist = sliceSentences.prefix(2).joined(separator: " / ")
            let bullets = Array(sliceSentences.prefix(4))
            
            let chapter = Chapter(
                start: first.start,
                end: last.end,
                title: title.isEmpty ? "챕터 \(index + 1)" : title,
                gist: gist.isEmpty ? title : gist
            )
            
            chapters.append(chapter)
            bulletsMap[chapter.id] = bullets
        }
        
        let summarySentences = Array(sentences.prefix(10))
        let simpleSummary = summarySentences.joined(separator: " ")
        
        // 키워드는 KeywordExtractor의 빈도 기반 로직 사용
        let keywords = self.keywordExtractor.extractKeywords(from: fullText, topN: 10)
        
        await MainActor.run {
            guard sid == self.sessionId else { return }
            
            self.chapters = chapters
            self.chapterBullets = bulletsMap
            self.chapterTexts = [:] // 휴리스틱 경로에서는 원문 맵을 사용하지 않음
            self.summaryText = simpleSummary.isEmpty ? fullText : simpleSummary
            self.finalSummary = self.summaryText
            self.summaryStatus = .ready
            
            self.extractedKeywords = keywords
            self.displayKeywords = keywords
            self.accumulatedKeywords = keywords
            
            self.summaryDebug = SummaryDebug(
                runId: runId,
                processed: summarySentences.count,
                total: sentences.count,
                lastUpdate: Date()
            )
            
            self.persistCacheToBoundNoteIfPossible()
            self.log.info("fallbackSummarizeFromCues() done; chapters=\(chapters.count), keywords=\(keywords.count)")
        }
    }
}
