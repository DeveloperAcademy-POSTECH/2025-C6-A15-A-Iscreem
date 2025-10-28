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
#if canImport(FoundationModels)
import FoundationModels
#endif

final class CaptionAnalyzer: ObservableObject {
    
    private let log = Logger(subsystem: "learningTool", category: "CaptionAnalyzer")
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
    
    /// Full raw text per chapter (keyed by Chapter.id)
    @Published var chapterTexts: [UUID: String] = [:]
    
    /// 각 챕터의 4줄 요약 (불릿 없이 한 문장씩)
    @Published var chapterBullets: [UUID: [String]] = [:]
    
    /// 챕터별 키워드 (chapter id → [String])
    @Published var chapterKeywords: [UUID: [String]] = [:]
    
    /// 누적 챕터 키워드(챕터 요약이 생성될 때마다 순차적으로 모은다)
    @Published var displayKeywords: [String] = []
    
    /// Turn this on to automatically kick off summarization once transcript is ready.
    var autoSummarizeEnabled: Bool = false
    /// 통합(최종) 요약 텍스트
    @Published var finalSummary: String = ""
    /// 통합 요약 진행 여부 (UI 스피너용)
    @Published var isMergingFinal: Bool = false
    
    /// 추출된 키워드 (최종 요약 기반)
    @Published var extractedKeywords: [String] = []
    /// 챕터별 누적 키워드
    @Published var accumulatedKeywords: [String] = []
    
    struct SummaryDebug {
        var runId = UUID()
        var processed = 0
        var total = 0
        var lastUpdate = Date()
    }
    @Published var summaryDebug = SummaryDebug()
    
    //
    private var summarizer: Summarizer?
    private var isFetchingCaptions = false
    private var lastPrefetchKey: String?
    
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
    }
    
    
    // MARK: - Summarization Orchestration
    
    /// Public entry to manually trigger summarization of the current transcript.
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
    
    private struct CueChunk {
        let start: Double
        let end: Double
        let text: String
    }
    
    private func chunkCues(_ cues: [VTTCue], maxSeconds: Double = 300) -> [CueChunk] {
        var out: [CueChunk] = []
        var accText = ""
        var startT: Double = cues.first?.start ?? 0
        var lastT: Double = startT
        for c in cues {
            if (c.end - startT) > maxSeconds, !accText.isEmpty {
                out.append(CueChunk(start: startT, end: lastT, text: accText.trimmingCharacters(in: .whitespacesAndNewlines)))
                accText = ""
                startT = c.start
            }
            if !accText.isEmpty { accText.append("\n") }
            accText.append(c.text)
            lastT = c.end
        }
        if !accText.isEmpty {
            out.append(CueChunk(start: startT, end: lastT, text: accText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return out
    }
    
    private func firstLine(_ s: String) -> String {
        s.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? s
    }
    
    private func summarizeFromCues(_ cues: [VTTCue]) async {
        let runId = UUID()
        await MainActor.run {
            self.summaryStatus = .summarizing
            self.summaryText = ""
            self.chapters = []
            self.chapterTexts = [:]
            self.summaryDebug = SummaryDebug(runId: runId, processed: 0, total: 0, lastUpdate: Date())
        }
        let t0 = Date()
        let runTag = runId.uuidString.prefix(8)
        self.log.info("sum[\(runTag)] start; cues=\(cues.count)")
        // 0) 청크 분할 (약 5분 단위)
        let chunks = chunkCues(cues, maxSeconds: 300)
        
        // 1) 챕터/원문을 즉시 구성하여 UI에 먼저 표시
        var built: [Chapter] = []
        var bodies: [UUID: String] = [:]
        for ch in chunks {
            let chapter = Chapter(
                start: ch.start,
                end: ch.end,
                title: "제목 생성 중…",
                gist: "요약 생성 중…"
            )
            built.append(chapter)
        }
        await MainActor.run {
            self.chapters = built
            for (i, ch) in chunks.enumerated() {
                bodies[built[i].id] = ch.text
            }
            self.chapterTexts = bodies
        }
        
        // 챕터 본문에서 한 줄 제목 비동기 생성 (UI 비막음)
        func startPerChapterTitleSummaries(using summarizer: Summarizer, runTag: Substring) {
            Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                for (idx, ch) in built.enumerated() {
                    if Task.isCancelled { return }
                    let body = chunks[idx].text
                    // 길이 제한 (토큰 과다 방지)
                    let sample = body.count > 2000 ? String(body.prefix(2000)) : body
                    do {
                        // 1) Gist: 2~3문장 요약 (영상 맥락 유지)
                        let gist = try await summarizer.summarizeChunk(
                            text: sample,
                            instruction: "다음 챕터의 전체 내용을 한국어로 2~3문장으로 요약. 영상의 흐름을 고려해 핵심 포인트를 연결해서 설명. 불릿/머리말/따옴표 금지."
                        )
                        let cleanedGist = gist.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                        await MainActor.run { self.setChapterGist(id: ch.id, gist: cleanedGist) }
                        
                        // 2) Title: 위 gist를 바탕으로 목차형 한 문장 제목 생성
                        let title = try await summarizer.summarizeChunk(
                            text: cleanedGist,
                            instruction: "위 요약을 바탕으로 이 영상의 목차 항목에 어울리는 한국어 제목 1문장 작성. 20~28자 내외, 핵심 키워드 포함, 군더더기/따옴표/마침표 금지."
                        )
                        let cleanedTitle = title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                        await MainActor.run { self.setChapterTitle(id: ch.id, title: cleanedTitle) }
                        
                        // Bullets: 4개의 핵심 포인트 생성 (불릿 기호 없이 한 문장씩)
                        do {
                            let bulletsRaw = try await summarizer.summarizeChunk(
                                text: sample, // body가 너무 길면 sample(최대 2,000자) 사용
                                instruction: "다음 챕터 내용을 한국어로 4개의 핵심 포인트로 요약. 각 항목은 1문장, 불릿/숫자/머리말 없이, 간결하게. 줄바꿈으로 항목을 구분."
                            )
                            // 줄 단위로 분해하여 앞의 4개만 사용
                            let lines = bulletsRaw
                                .replacingOccurrences(of: "\r\n", with: "\n")
                                .replacingOccurrences(of: "\r", with: "\n")
                                .components(separatedBy: "\n")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            let top4 = Array(lines.prefix(4))
                            await MainActor.run { self.setChapterBullets(id: ch.id, bullets: top4) }
                        } catch {
                            // 실패 시 gist를 문장 단위로 잘라 최대 4개까지 사용 (간단 폴백)
                            let fallback = cleanedGist
                                .replacingOccurrences(of: "•", with: "")
                            //                                .replacingOccurrences(of: "-", with: "")
                                .split(whereSeparator: { ".!?".contains($0) })
                                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            let top4 = Array(fallback.prefix(4)).filter { !$0.isEmpty }
                            await MainActor.run { self.setChapterBullets(id: ch.id, bullets: top4) }
                        }
                        
                        self.log.info("sum[\(runTag)] chapter gist+title ok for \(idx+1)/\(built.count)")
                    } catch {
                        let ns = error as NSError
                        self.log.error("sum[\(runTag)] chapter gist/title error: \(ns.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
        
        // 2) 실제 요약기 확인 (없으면 실패)
        guard let summarizer = self.summarizer else {
            await MainActor.run {
                self.summaryStatus = .failed("요약 모델 자산이 없습니다. (iOS 26+ 지원 기기·언어·지역 필요)")
            }
            return
        }
        
        startPerChapterTitleSummaries(using: summarizer, runTag: runTag)
        
        
        // 3) 문단 단위(Map) → 통합은 생략하고 누적 표시(줄단위 완성)
        //    - 한 번에 전체 텍스트를 보내지 않아 컨텍스트 초과 방지
        //    - 각 문단은 400~600자 내외로 재조립하여 과도한 길이를 피함
        func makeParagraphs(from chunks: [CueChunk], targetChars: Int = 600) -> [String] {
            var paragraphs: [String] = []
            for ch in chunks {
                // cue 줄 단위로 쪼개고 공백 라인은 제거
                let lines = ch.text
                    .replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n")
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                var acc = ""
                for line in lines {
                    if acc.isEmpty { acc = line }
                    else if acc.count + line.count + 1 <= targetChars {
                        acc += " " + line
                    } else {
                        paragraphs.append(acc)
                        acc = line
                    }
                }
                if !acc.isEmpty { paragraphs.append(acc) }
            }
            return paragraphs
        }
        
        let paragraphs = makeParagraphs(from: chunks, targetChars: 600)
        self.log.info("sum[\(runTag)] paragraphs=\(paragraphs.count)")
        await MainActor.run {
            self.summaryDebug.total = paragraphs.count
            self.summaryDebug.lastUpdate = Date()
        }
        
        var lastFlush = Date.distantPast
        
        var linesOut: [String] = []
        for (i, p) in paragraphs.enumerated() {
            if Task.isCancelled { return }
            let trimmed = p.trimmingCharacters(in: .whitespacesAndNewlines)
            self.log.info("sum[\(runTag)] step \(i+1)/\(paragraphs.count) begin (len=\(trimmed.count))")
            guard !trimmed.isEmpty else { continue }
            do {
                let one = try await summarizer.summarizeChunk(
                    text: trimmed,
                    instruction: "아래 문단을 한국어로 한 문장 핵심 요약. 고유명사/숫자 유지. 군더더기 없이."
                ).replacingOccurrences(of: "\n", with: " ")
                linesOut.append("• " + one.trimmingCharacters(in: .whitespacesAndNewlines))
                self.log.info("sum[\(runTag)] step \(i+1) ok")
                await MainActor.run {
                    self.summaryDebug.processed = i + 1
                    self.summaryDebug.lastUpdate = Date()
                }
            } catch {
                let ns = error as NSError
                self.log.error("sum[\(runTag)] step \(i+1) error: \(ns.localizedDescription, privacy: .public)")
                // 실패 시 해당 문단의 첫 줄로 폴백하여 진행 중단 없이 계속
                linesOut.append("• " + firstLine(trimmed))
            }
            
            // UI에 간헐적으로 누적 반영 (시간 스로틀: 0.8s)
            let now = Date()
            if now.timeIntervalSince(lastFlush) > 0.8 {
                lastFlush = now
                let current = linesOut.joined(separator: "\n")
                self.log.info("sum[\(runTag)] flush lines=\(linesOut.count)")
                await MainActor.run { withAnimation(.none) { self.summaryText = current } }
            }
        }
        let elapsed = Date().timeIntervalSince(t0)
        self.log.info("sum[\(runTag)] done in \(elapsed)s; lines=\(linesOut.count)")
        await MainActor.run {
            withAnimation(.none) {
                self.summaryText = linesOut.joined(separator: "\n")
                self.summaryStatus = .ready
            }
            self.summaryDebug.lastUpdate = Date()
        }
        // 통합(최종) 요약은 메인 스레드를 막지 않도록 백그라운드에서 수행
        self.mergeFinalAsync(pieces: linesOut, runTag: runTag, summarizer: summarizer)
    }
    
    /// 최종 통합 요약을 백그라운드에서 수행하여 UI 인터랙션을 막지 않도록 함
    private func mergeFinalAsync(pieces: [String], runTag: Substring, summarizer: Summarizer) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            self.log.info("sum[\(runTag)] merge begin; pieces=\(pieces.count)")
            await MainActor.run { self.isMergingFinal = true }
            do {
                let merged = try await summarizer.mergeSummaries(pieces)
                await MainActor.run {
                    self.finalSummary = merged.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isMergingFinal = false
                    // finalSummary 기반 키워드 추출
                    self.extractedKeywords = self.extractKeywords()
                }
                self.log.info("sum[\(runTag)] merge done")
            } catch {
                let ns = error as NSError
                self.log.error("sum[\(runTag)] merge error: \(ns.localizedDescription, privacy: .public)")
                await MainActor.run { self.isMergingFinal = false }
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
    
    /// 챕터 불릿을 설정하고, 컨텍스트 기반 키워드 추출 또는 LLM 기반 추출을 트리거합니다.
    @MainActor
    private func setChapterBullets(id: UUID, bullets: [String]) {
        chapterBullets[id] = bullets
        let chapterText = bullets.joined(separator: " ")
        Task {
            let updateDisplayKeywords: ([String]) -> Void = { newKeywords in
                self.chapterKeywords[id] = newKeywords
                // Gather keywords for all chapters in order, as they're available
                let allChapterIDs = self.chapters.map { $0.id }
                var keywords: [String] = []
                for cid in allChapterIDs {
                    if let kws = self.chapterKeywords[cid] {
                        for kw in kws where !keywords.contains(kw) {
                            keywords.append(kw)
                        }
                    }
                }
                self.displayKeywords = keywords // 개수 제한 제거
            }
            if #available(iOS 26.0, *), let summarizer = self.summarizer {
                do {
                    let keywordsText = try await summarizer.summarizeChunk(
                        text: chapterText,
                        instruction: """
                        - 주어진 요약본에서 **컴퓨터공학 분야의 맥락에서 사용되는 핵심 용어와 개념**을 모두 추출하세요.
                        - 단, 단순히 '컴퓨터공학 관련 용어'라는 문구 자체를 결과에 포함하지 마세요.
                        - 각 단어는 **컴퓨터공학, 소프트웨어, 인공지능, 알고리즘, 시스템, 데이터, 네트워크, 프로그래밍 등** 기술적 주제와 관련된 단어를 중심으로 추출하세요.
                        - 단어가 다른 분야에서도 쓰이더라도, **컴퓨터공학에서의 의미로 사용되는 경우만** 포함하세요.
                        - 문맥상 중요하거나 자주 언급되는 단어는 **중복되더라도 모두 포함**하세요. (절대 생략하지 마세요)
                        - 불필요한 조사, 접속사, 감탄사(예: 그러나, 그리고, 과감하게, 넘어가야 등)는 제외하세요.
                        - 형용사나 동사보다는 **명사 중심의 핵심 키워드**를 선택하세요.
                        - 키워드는 **짧고 명료하게** 표현하세요.
                        - **출력 형식:** 각 키워드를 구분자로 구분하여 출력하세요.  
                          허용되는 구분자: 세미콜론( ; ), 쉼표( , ), 온점( . ), 슬래시( / ), 줄바꿈(\n), 탭(\t)
                        - 결과는 **한국어로만** 작성하세요. (영문 단어는 꼭 필요한 기술 용어일 경우만 유지)
                        """
                    )
                    // 온점(.), 쉼표(,), 세미콜론(;), 줄바꿈(\n), 슬래시(/), 탭 등 다양한 구분자 처리
                    let separators = CharacterSet(charactersIn: ".,;／/\n\t ")
                    let keywords = keywordsText
                        .components(separatedBy: separators)
                        .map {
                            $0
                                .replacingOccurrences(of: "**", with: "") // ✅ 별표 제거
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .filter { !$0.isEmpty && $0.count > 1 } // 한 글자 제거
                    await MainActor.run {
                        updateDisplayKeywords(keywords)
                    }
                } catch {
                    // Fallback to contextual extraction if summarizer fails
                    let keywords = await extractChapterKeywordsContextual(from: chapterText)
                    await MainActor.run {
                        updateDisplayKeywords(keywords)
                    }
                }
            } else {
                let keywords = await extractChapterKeywordsContextual(from: chapterText)
                await MainActor.run {
                    updateDisplayKeywords(keywords)
                }
            }
        }
    }
    
    /// 주어진 텍스트에서 NaturalLanguage 프레임워크와 NLEmbedding(가능한 경우)을 활용하여 컨텍스트 기반 키워드를 추출합니다.
    @MainActor
    func extractChapterKeywordsContextual(from text: String) async -> [String] {
        guard !text.isEmpty else { return [] }
        // 1. 텍스트 전처리 (불용어 제거, 정규화)
        let cleanedText = preprocess(text)
        guard !cleanedText.isEmpty else { return [] }
        
        // 2. NLTagger의 .lexicalClass와 .nameType을 모두 활용하여 명사/고유명사 후보 수집
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = cleanedText
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        var candidateWords: [String: Int] = [:]
        tagger.enumerateTags(in: cleanedText.startIndex..<cleanedText.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag, tag == .noun {
                let word = String(cleanedText[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard word.count > 1 else { return true }
                candidateWords[word, default: 0] += 1
            }
            return true
        }
        // 고유명사(인명, 지명, 조직 등)도 추가 수집
        tagger.enumerateTags(in: cleanedText.startIndex..<cleanedText.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(cleanedText[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard word.count > 1 else { return true }
                candidateWords[word, default: 0] += 2 // Give a little more weight to named entities
            }
            return true
        }
        guard !candidateWords.isEmpty else { return [] }
        
        // 3. NLEmbedding이 지원되는 경우 의미적 유사도 활용
        var wordScores: [(word: String, score: Double)] = []
        if let embedding = NLEmbedding.wordEmbedding(for: .korean) {
            // 전체 텍스트의 벡터 계산 (각 단어 벡터의 평균)
            let allWords = cleanedText.components(separatedBy: .whitespacesAndNewlines)
            let textVectors = allWords.compactMap { embedding.vector(for: $0) }
            let textVector: [Double]
            if !textVectors.isEmpty {
                let dim = textVectors.first!.count
                textVector = (0..<dim).map { i in
                    textVectors.map { $0[i] }.reduce(0, +) / Double(textVectors.count)
                }
            } else {
                textVector = []
            }
            // 각 후보 단어에 대해 벡터, 유사도 계산 및 빈도와 결합
            for (word, freq) in candidateWords {
                if let vec = embedding.vector(for: word), !textVector.isEmpty {
                    let sim = cosineSimilarity(vec1: vec, vec2: textVector)
                    // 유사도(70%)와 정규화된 빈도(30%)를 결합
                    let freqNorm = min(Double(freq) / 5.0, 1.0) // scale freq
                    let score = sim * 0.7 + freqNorm * 0.3
                    wordScores.append((word, score))
                } else {
                    // 벡터가 없으면 빈도 기반 점수만 사용 (낮은 점수)
                    let freqNorm = min(Double(freq) / 5.0, 1.0)
                    wordScores.append((word, freqNorm * 0.3))
                }
            }
        } else {
            // 4. 폴백: 빈도 기반 정렬만 사용
            for (word, freq) in candidateWords {
                wordScores.append((word, Double(freq)))
            }
        }
        // 5. 점수 내림차순 정렬 후, 동일 점수는 가나다순
        let sorted = wordScores.sorted { $0.score > $1.score || ($0.score == $1.score && $0.word < $1.word) }
        // 중복 또는 포함 관계(예: "데이터"가 "데이터베이스"에 포함되면 제거)
        var filtered: [String] = []
        for (word, _) in sorted {
            if !filtered.contains(where: { $0.contains(word) && $0 != word }) {
                filtered.append(word)
            }
        }
        // 상위 8개 반환
        return Array(filtered.prefix(8))
    }
    
    /// 두 벡터 간 코사인 유사도 계산
    func cosineSimilarity(vec1: [Double], vec2: [Double]) -> Double {
        guard vec1.count == vec2.count, !vec1.isEmpty else { return 0 }
        let dot = zip(vec1, vec2).map(*).reduce(0, +)
        let norm1 = sqrt(vec1.map { $0 * $0 }.reduce(0, +))
        let norm2 = sqrt(vec2.map { $0 * $0 }.reduce(0, +))
        guard norm1 > 0, norm2 > 0 else { return 0 }
        return dot / (norm1 * norm2)
    }
    /// 텍스트에서 불용어를 제거하는 간단한 전처리 함수
    func preprocess(_ text: String) -> String {
        // 한국어 불용어 예시 (간단 버전)
        let stopwords: Set<String> = [
            "이", "그", "저", "것", "등", "및", "의", "에", "를", "을", "로", "에서", "으로", "와", "과", "도", "는", "은", "가", "한", "하다", "되다", "있다"
        ]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { !stopwords.contains($0) }
        return filtered.joined(separator: " ")
    }
    
    func extractKeywords(topN: Int = 10) -> [String] {
        let tokens = preprocess(finalSummary)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }
        
        var freq: [String: Int] = [:]
        for token in tokens {
            freq[token, default: 0] += 1
        }
        
        // 빈도순 정렬
        let sorted = freq.sorted { $0.value > $1.value }.map { $0.key }
        
        // ✅ 포함 관계 필터링 (예: '데이터'가 '데이터베이스'에 포함되면 제거)
        var filtered: [String] = []
        for word in sorted {
            if !filtered.contains(where: { $0.contains(word) && $0 != word }) {
                filtered.append(word)
            }
        }
        
        return Array(filtered.prefix(topN))
    }
    
    // MARK: - youtubei (player API) Prefetch
    func prefetchViaYouTubei(videoID: String, apiKey: String, clientName: String, clientVersion: String, sts: Int?) async {
        let key = "\(videoID)#\(clientName)#\(clientVersion)#\(sts ?? -1)"
        if lastPrefetchKey == key, (vttStatus == .loading || vttStatus == .ready) { return }
        if self.isFetchingCaptions { return }              // 중복 요청 가드
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
            
            let cues = try await Self.fetchFromBaseUrl(chosen.baseUrl)
            await MainActor.run {
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
    
    // MARK: - Helpers
    
    private static func parseWebVTT(_ vtt: String) -> [VTTCue] {
        var lines = vtt.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        if let first = lines.first, first.uppercased().contains("WEBVTT") {
            lines.removeFirst()
        }
        
        var cues: [VTTCue] = []
        var i = 0
        func parseTime(_ s: String) -> Double? {
            let ss = s.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: ".")
            let parts = ss.split(separator: ":").map(String.init)
            guard parts.count >= 2 else { return nil }
            let h: Double
            let m: Double
            let secStr: String
            if parts.count == 3 {
                h = Double(parts[0]) ?? 0
                m = Double(parts[1]) ?? 0
                secStr = parts[2]
            } else {
                h = 0
                m = Double(parts[0]) ?? 0
                secStr = parts[1]
            }
            // seconds(.fraction) handling
            let secParts = secStr.split(whereSeparator: { $0 == "." || $0 == "," }).map(String.init)
            let sVal = Double(secParts.first ?? "0") ?? 0
            let fracStr = secParts.count > 1 ? secParts[1] : "0"
            let frac = Double("0." + fracStr) ?? 0
            return h * 3600 + m * 60 + sVal + frac
        }
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { i += 1; continue }
            // Optional cue identifier
            var tline = line
            if !tline.contains("-->"), i + 1 < lines.count, lines[i + 1].contains("-->") {
                i += 1
                tline = lines[i]
            }
            if tline.contains("-->") {
                let comps = tline.components(separatedBy: "-->")
                if comps.count == 2, let start = parseTime(comps[0].trimmingCharacters(in: .whitespaces)),
                   let end = parseTime(comps[1].split(separator: " ").first.map(String.init) ?? "") {
                    i += 1
                    var textLines: [String] = []
                    while i < lines.count {
                        let l = lines[i]
                        if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
                        textLines.append(l)
                        i += 1
                    }
                    let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    cues.append(VTTCue(start: start, end: end, text: text))
                }
            }
            i += 1
        }
        return cues
    }
    
    
    // MARK: - Prefetch via JS-provided captionTracks (signed baseUrl)
    func prefetchFromTracks(_ jsTracks: [[String: Any]]) async {
        log.info("tracks(begin) rawCount=\(jsTracks.count)")
        // 이미 성공했다면 재시도 안 함
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
            let cues = try await Self.fetchFromBaseUrl(chosen.baseUrl)
            await MainActor.run {
                self.log.info("tracks(success) cues=\(cues.count)")
                self.vttCues = cues
                self.vttStatus = cues.isEmpty ? .failed("자막이 비어 있습니다.") : .ready
                if !cues.isEmpty { self.startAutoSummarizeIfNeeded() }
            }
        } catch {
            await MainActor.run {
                self.log.error("tracks(error) \(error.localizedDescription, privacy: .public)")
                self.vttStatus = .failed(error.localizedDescription) }
        }
    }
    
    private static func fetchFromBaseUrl(_ baseUrl: String) async throws -> [VTTCue] {
        print("fetchFromBaseUrl: trying raw baseUrl=\(baseUrl)")
        // Validate scheme to avoid attempting "ew?fmt=vtt" etc.
        guard baseUrl.lowercased().hasPrefix("http") else {
            throw NSError(domain: "VTT", code: -11, userInfo: [NSLocalizedDescriptionKey: "잘못된 자막 URL"])
        }
        // 1) 그대로 시도
        if let url = URL(string: baseUrl) {
            if let cues = try? await Self._downloadAndParse(url: url) { return cues }
        }
        // 2) fmt 강제 변경 시도
        func withParam(_ key: String, _ val: String) -> URL? {
            guard var c = URLComponents(string: baseUrl) else { return nil }
            var items = c.queryItems ?? []
            if !items.contains(where: { $0.name == key }) {
                items.append(.init(name: key, value: val))
            } else {
                items = items.map { $0.name == key ? .init(name: key, value: val) : $0 }
            }
            c.queryItems = items
            return c.url
        }
        print("fetchFromBaseUrl: trying fmt=vtt")
        if let u1 = withParam("fmt", "vtt"), let cues = try? await Self._downloadAndParse(url: u1) { return cues }
        
        print("fetchFromBaseUrl: trying fmt=json3")
        if let u2 = withParam("fmt", "json3"), let cues = try? await Self._downloadAndParse(url: u2) { return cues }
        
        print("fetchFromBaseUrl: trying fmt=srv3")
        if let u3 = withParam("fmt", "srv3"), let cues = try? await Self._downloadAndParse(url: u3) { return cues }
        throw NSError(domain: "VTT", code: -9, userInfo: [NSLocalizedDescriptionKey: "서명된 자막 URL에서 데이터를 가져오지 못했습니다."])
    }
    
    private static func _downloadAndParse(url: URL) async throws -> [VTTCue] {
        let (data, _) = try await URLSession.shared.data(from: url)
        print("_downloadAndParse: url=\(url.absoluteString)")
        
        if let text = String(data: data, encoding: .utf8) {
            if text.contains("WEBVTT") {
                print("_downloadAndParse: detected WEBVTT")
                return Self.parseWebVTT(text)
            }
            // JSON3 / SRV3 with possible XSSI guard
            var raw = text
            if raw.hasPrefix(")]}'") {
                if let nl = raw.firstIndex(of: "\n") { raw = String(raw[raw.index(after: nl)...]) }
            }
            if let jd = raw.data(using: .utf8),
               let cues = try? Self._parseJSON3(jd) {
                print("_downloadAndParse: detected JSON3/SRV3")
                return cues
            }
        }
        // TimedText XML (<transcript><text start= dur=>)
        if let cues = Self._parseTimedTextXML(data) {
            print("_downloadAndParse: detected TimedText XML")
            return cues
        }
        throw NSError(domain: "VTT", code: -10,
                      userInfo: [NSLocalizedDescriptionKey: "알 수 없는 자막 포맷입니다."])
    }
    
    private static func _parseJSON3(_ data: Data) throws -> [VTTCue] {
        struct JSON3: Decodable {
            struct Seg: Decodable { let utf8: String? }
            struct Event: Decodable {
                let tStartMs: Int?
                let dDurationMs: Int?
                let segs: [Seg]?
            }
            let events: [Event]?
        }
        let json = try JSONDecoder().decode(JSON3.self, from: data)
        var cues: [VTTCue] = []
        for ev in json.events ?? [] {
            let start = Double(ev.tStartMs ?? 0) / 1000.0
            let dur = Double(ev.dDurationMs ?? 0) / 1000.0
            let end = start + (dur > 0 ? dur : 2.0)
            let text = (ev.segs ?? []).compactMap { $0.utf8 }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { cues.append(VTTCue(start: start, end: end, text: text)) }
        }
        return cues
    }
    
    private final class TimedTextXMLParser: NSObject, XMLParserDelegate {
        var cues: [VTTCue] = []
        private var currText: String = ""
        private var currStart: Double = 0
        private var currDur: Double = 0
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName == "text" {
                currText = ""
                currStart = Double(attributeDict["start"] ?? "0") ?? 0
                currDur = Double(attributeDict["dur"] ?? "0") ?? 0
            }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { currText += string }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "text" {
                let end = currStart + (currDur > 0 ? currDur : 2.0)
                let text = currText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { cues.append(VTTCue(start: currStart, end: end, text: text)) }
            }
        }
    }
    private static func _parseTimedTextXML(_ data: Data) -> [VTTCue]? {
        let p = TimedTextXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        guard parser.parse(), !p.cues.isEmpty else { return nil }
        return p.cues
    }
}
