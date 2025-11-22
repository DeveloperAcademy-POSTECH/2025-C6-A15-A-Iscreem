//
//  SummaizerEngine.swift
//  learningTool
//
//  Created by 이혜빈 on 11/4/25.
//

import Foundation
import OSLog

/// 자막 기반 요약 처리를 담당하는 엔진
final class SummarizerEngine {
    private let log: Logger
    
    struct CueChunk {
        let start: Double
        let end: Double
        let text: String
    }
    
    init(logger: Logger) {
        self.log = logger
    }
    
    func processCues(
        cues: [CaptionAnalyzer.VTTCue],
        sessionId: UUID,
        summarizer: Summarizer,
        runId: UUID,
        onChaptersBuilt: @MainActor ([CaptionAnalyzer.Chapter], [UUID: String]) async -> Void,
        onChapterTitleUpdate: @MainActor @escaping (UUID, String) async -> Void,
        onChapterGistUpdate: @MainActor @escaping (UUID, String) async -> Void,
        onChapterBulletsUpdate: @MainActor @escaping (UUID, [String]) async -> Void,
        onSummaryProgress: @MainActor (Int, Int) async -> Void,
        onSummaryTextUpdate: @MainActor (String) async -> Void,
        onComplete: @MainActor ([String]) async -> Void
    ) async {
        let t0 = Date()
        let runTag = runId.uuidString.prefix(8)
        self.log.info("sum[\(runTag)] start; cues=\(cues.count)")
        
        // 0) 청크 분할 (약 5분 단위)
        let chunks = chunkCues(cues, maxSeconds: 300)
        
        // 1) 챕터/원문을 즉시 구성하여 UI에 먼저 표시
        var built: [CaptionAnalyzer.Chapter] = []
        var bodies: [UUID: String] = [:]
        for ch in chunks {
            let chapter = CaptionAnalyzer.Chapter(
                start: ch.start,
                end: ch.end,
                title: "제목 생성 중…",
                gist: "요약 생성 중…"
            )
            built.append(chapter)
            bodies[chapter.id] = ch.text
        }
        
        await onChaptersBuilt(built, bodies)
        
        // 챕터 본문에서 한 줄 제목 비동기 생성 (UI 비막음)
        startPerChapterTitleSummaries(
            chunks: chunks,
            chapters: built,
            summarizer: summarizer,
            runTag: runTag,
            onTitleUpdate: onChapterTitleUpdate,
            onGistUpdate: onChapterGistUpdate,
            onBulletsUpdate: onChapterBulletsUpdate
        )
        
        // 2) 문단 단위 요약 생성
        let paragraphs = makeParagraphs(from: chunks, targetChars: 600)
        self.log.info("sum[\(runTag)] paragraphs=\(paragraphs.count)")
        await onSummaryProgress(0, paragraphs.count)
        
        var lastFlush = Date.distantPast
        var linesOut: [String] = []
        
        for (i, p) in paragraphs.enumerated() {
            if Task.isCancelled { return }
            let trimmed = p.trimmingCharacters(in: .whitespacesAndNewlines)
            self.log.info("sum[\(runTag)] step \(i+1)/\(paragraphs.count) begin (len=\(trimmed.count))")
            guard !trimmed.isEmpty else { continue }
            
            do {
                let raw = try await summarizer.summarizeChunk(
                    text: trimmed,
                    instruction: "아래 문단을 한국어로 한 문장 핵심 요약. 고유명사/숫자 유지. 군더더기 없이."
                ).replacingOccurrences(of: "\n", with: " ")
                let clean = stripBulletPrefix(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                linesOut.append("• " + clean)
                self.log.info("sum[\(runTag)] step \(i+1) ok")
                await onSummaryProgress(i + 1, paragraphs.count)
            } catch {
                let ns = error as NSError
                self.log.error("sum[\(runTag)] step \(i+1) error: \(ns.localizedDescription, privacy: .public)")
                linesOut.append("• " + stripBulletPrefix(firstLine(trimmed)))
            }
            
            // UI에 간헐적으로 누적 반영 (시간 스로틀: 0.8s)
            let now = Date()
            if now.timeIntervalSince(lastFlush) > 0.8 {
                lastFlush = now
                let current = linesOut.joined(separator: "\n")
                self.log.info("sum[\(runTag)] flush lines=\(linesOut.count)")
                await onSummaryTextUpdate(current)
            }
        }
        
        let elapsed = Date().timeIntervalSince(t0)
        self.log.info("sum[\(runTag)] done in \(elapsed)s; lines=\(linesOut.count)")
        await onComplete(linesOut)
    }
    
    private func chunkCues(_ cues: [CaptionAnalyzer.VTTCue], maxSeconds: Double = 300) -> [CueChunk] {
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

    /// Remove any leading bullet/dash so we can add a single "• " in step 4 only.
    private func stripBulletPrefix(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["•", "-", "–", "—", "∙", "·", "●", "*"]
        if let p = prefixes.first(where: { t.hasPrefix($0) }) {
            t.removeFirst(p.count)
            t = t.trimmingCharacters(in: .whitespaces)
        }
        return t
    }
    
    /// Remove leading list markers like "1.", "1)", "(1)", "[1]", "a)", roman numerals, circled digits, etc.
    private func stripLeadingListMarker(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove known bullet/dash first
        t = stripBulletPrefix(t)
        
        // Patterns for common list markers at the start of the line
        let patterns: [String] = [
            #"^\(?\d{1,3}\)?[.)]\s*"#,   // 1. / 1) / (1).
            #"^\d{1,3}[:\-]\s*"#,        // 1: / 1-
            #"^\[\d{1,3}\]\s*"#,         // [1]
            #"^[IVXLCMivxlcm]{1,5}[.)]\s*"#, // I. / iv)
            #"^[a-zA-Z][.)]\s*"#,        // a) / A.
            #"^\([a-zA-Z]\)\s*"#,        // (a)
            #"^[①-⑳]\s*"#                // circled digits 1~20
        ]
        
        var changed = true
        while changed {
            changed = false
            let before = t
            t = stripBulletPrefix(t)
            if t != before { changed = true }
            
            for p in patterns {
                if let r = t.range(of: p, options: .regularExpression) {
                    t.removeSubrange(r)
                    t = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                    break
                }
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Normalize raw lines: remove any numbering/bullets and prefix a single "• ".
    private func normalizeBulletedLines(_ lines: [String], maxCount: Int = 7) -> [String] {
        var out: [String] = []
        for line in lines {
            var t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            t = stripLeadingListMarker(t)
            guard !t.isEmpty else { continue }
            out.append("• " + t)
            if out.count >= maxCount { break }
        }
        return out
    }
    
    private func makeParagraphs(from chunks: [CueChunk], targetChars: Int = 600) -> [String] {
        var paragraphs: [String] = []
        for ch in chunks {
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
    
    private func startPerChapterTitleSummaries(
        chunks: [CueChunk],
        chapters: [CaptionAnalyzer.Chapter],
        summarizer: Summarizer,
        runTag: Substring,
        onTitleUpdate: @MainActor @escaping (UUID, String) async -> Void,
        onGistUpdate: @MainActor @escaping (UUID, String) async -> Void,
        onBulletsUpdate: @MainActor @escaping (UUID, [String]) async -> Void
    ) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            for (idx, ch) in chapters.enumerated() {
                if Task.isCancelled { return }
                let body = chunks[idx].text
                let sample = body.count > 2000 ? String(body.prefix(2000)) : body
                
                do {
                    // 1) Gist: 2~3문장 요약
                    let gist = try await summarizer.summarizeChunk(
                        text: sample,
                        instruction: "다음 챕터의 전체 내용을 한국어로 2~3문장으로 요약. 영상의 흐름을 고려해 핵심 포인트를 연결해서 설명. 불릿/머리말/따옴표 금지."
                    )
                    let cleanedGist = gist.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    await onGistUpdate(ch.id, cleanedGist)
                    
                    // 2) Title: 위 gist를 바탕으로 목차형 한 문장 제목 생성
                    let title = try await summarizer.summarizeChunk(
                        text: cleanedGist,
                        instruction: "위 요약을 바탕으로 이 영상의 목차 항목에 어울리는 한국어 제목 1문장 작성. 20~28자 내외, 핵심 키워드 포함, 군더더기/따옴표/마침표 금지."
                    )
                    let cleanedTitle = title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    await onTitleUpdate(ch.id, cleanedTitle)
                    
                    // 3) chapter gist: 6~7개의 핵심 포인트 생성
                    do {
                        let bulletsRaw = try await summarizer.summarizeChunk(
                            text: sample,
                            instruction: "다음 챕터 내용을 한국어로 6~7개의 핵심 포인트로 요약. 각 항목은 1문장, 반드시 '• '로 시작. 숫자/머리말/번호/따옴표 금지. 줄바꿈으로 항목을 구분."
                        )
                        let lines = bulletsRaw
                            .replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
                            .components(separatedBy: "\n")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        let bullets = normalizeBulletedLines(lines, maxCount: 7)
                        await onBulletsUpdate(ch.id, bullets)
                    } catch {
                        // 프롬프트 실패 시 gist 문장을 나눠 불릿으로 정규화
                        let fallbackLines = cleanedGist
                            .split(whereSeparator: { ".!?".contains($0) })
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        let bullets = normalizeBulletedLines(fallbackLines, maxCount: 7)
                        await onBulletsUpdate(ch.id, bullets)
                    }
                    self.log.info("sum[\(runTag)] chapter gist+title ok for \(idx+1)/\(chapters.count)")
                } catch {
                    let ns = error as NSError
                    self.log.error("sum[\(runTag)] chapter gist/title error: \(ns.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    func preprocess(_ text: String) -> String {
        let stopwords: Set<String> = [
            "이", "그", "저", "것", "등", "및", "의", "에", "를", "을", "로", "에서", "으로", "와", "과", "도", "는", "은", "가", "한", "하다", "되다", "있다"
        ]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { !stopwords.contains($0) }
        return filtered.joined(separator: " ")
    }
}
