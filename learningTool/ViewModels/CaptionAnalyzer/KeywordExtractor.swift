//
//  KeywordExtractor.swift
//  learningTool
//
//  Created by 이혜빈 on 11/4/25.
//

import Foundation
import NaturalLanguage
import OSLog

/// 텍스트에서 키워드를 추출하는 엔진
final class KeywordExtractor {
    private let log: Logger
    
    init(logger: Logger) {
        self.log = logger
    }
    
    // MARK: - 챕터별 키워드 추출
    func extractChapterKeywords(
        from text: String,
        summarizer: Summarizer?
    ) async -> [String] {
        print("🟦 extractChapterKeywords called, text length=\(text.count)")
        
        var candidateKeywords: [String] = []
        
        if #available(iOS 26.0, *), let summarizer = summarizer {
            do {
                let rawKeywords = try await summarizer.summarizeChunk(
                    text: text,
                    instruction: """
                    다음 챕터에서 핵심 개념을 나타내는 명사나 고유명사를 5~15개 추출하세요.
                    
                    **규칙:**
                    - 한글 용어를 최우선으로 추출 (예: 데이터베이스, 인공지능, 머신러닝)
                    - 영어는 Swift, API, DBMS, JSON처럼 한글로 번역하기 어려운 기술 용어만 포함
                    - 동사, 형용사, 조사는 제외
                    - 쉼표로 구분
                    
                    **예시:**
                    입력: "Swift는 iOS 앱 개발에 사용되는 프로그래밍 언어입니다. 데이터베이스 설계와 SQL 쿼리를 배웁니다."
                    출력: Swift, iOS, 앱 개발, 프로그래밍 언어, 데이터베이스, 설계, SQL, 쿼리
                    """
                )
                candidateKeywords = rawKeywords
                    .components(separatedBy: CharacterSet(charactersIn: ".,;、/\n\t "))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            } catch {
                candidateKeywords = text.components(separatedBy: .whitespacesAndNewlines)
            }
        } else {
            candidateKeywords = text.components(separatedBy: .whitespacesAndNewlines)
        }
        
        print("🟦 candidateKeywords count=\(candidateKeywords.count), preview=\(candidateKeywords.prefix(20))")
        
        // ✅ 강화된 전처리: 오타 보정 + 불용어 제거
        let preprocessed = preprocessKeywords(candidateKeywords)
        print("🟧 preprocessed keywords count=\(preprocessed.count), preview=\(preprocessed.prefix(20))")
        
        // 정규식 및 불용어 기반 정제
        let refined = refineKeywords(preprocessed)
        print("🟨 refined keywords count=\(refined.count), preview=\(refined.prefix(20))")
        
        // 중복 제거, 순서 유지
        var seen: Set<String> = []
        let finalKeywords = refined.filter { seen.insert($0).inserted }
        
        return finalKeywords
    }
    
    // MARK: - 최종 요약 기반 키워드 추출 (빈도 기반)
    func extractKeywords(from text: String, topN: Int = 10) -> [String] {
        let tokens = preprocessForFrequency(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }
        
        var freq: [String: Int] = [:]
        for token in tokens {
            freq[token, default: 0] += 1
        }
        
        let sorted = freq.sorted { $0.value > $1.value }.map { $0.key }
        
        // 포함 관계 필터링
        var filtered: [String] = []
        for word in sorted {
            if !filtered.contains(where: { $0.contains(word) && $0 != word }) {
                filtered.append(word)
            }
        }
        
        return Array(filtered.prefix(topN))
    }
    
    // MARK: - 컨텍스트 기반 키워드 추출 (NLEmbedding 활용)
    @MainActor
    func extractChapterKeywordsContextual(from text: String) async -> [String] {
        guard !text.isEmpty else { return [] }
        
        let cleanedText = preprocessForFrequency(text)
        guard !cleanedText.isEmpty else { return [] }
        
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
        
        tagger.enumerateTags(in: cleanedText.startIndex..<cleanedText.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(cleanedText[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard word.count > 1 else { return true }
                candidateWords[word, default: 0] += 2
            }
            return true
        }
        
        guard !candidateWords.isEmpty else { return [] }
        
        var wordScores: [(word: String, score: Double)] = []
        
        if let embedding = NLEmbedding.wordEmbedding(for: .korean) {
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
            
            for (word, freq) in candidateWords {
                if let vec = embedding.vector(for: word), !textVector.isEmpty {
                    let sim = cosineSimilarity(vec1: vec, vec2: textVector)
                    let freqNorm = min(Double(freq) / 5.0, 1.0)
                    let score = sim * 0.7 + freqNorm * 0.3
                    wordScores.append((word, score))
                } else {
                    let freqNorm = min(Double(freq) / 5.0, 1.0)
                    wordScores.append((word, freqNorm * 0.3))
                }
            }
        } else {
            for (word, freq) in candidateWords {
                wordScores.append((word, Double(freq)))
            }
        }
        
        let sorted = wordScores.sorted { $0.score > $1.score || ($0.score == $1.score && $0.word < $1.word) }
        
        var filtered: [String] = []
        for (word, _) in sorted {
            if !filtered.contains(where: { $0.contains(word) && $0 != word }) {
                filtered.append(word)
            }
        }
        
        return Array(filtered.prefix(8))
    }
    
    // MARK: - Private Helpers
    
    /// ✅ NEW: 오타 보정 및 유사 단어 통합 (컴활 ≠ 코마)
    private func preprocessKeywords(_ candidates: [String]) -> [String] {
        // 일반적인 오타 패턴 보정 사전
        let typoCorrections: [String: String] = [
            "코마": "컴활",
            "데타": "데이터",
            "프로그램잉": "프로그래밍",
            "알고리듬": "알고리즘",
            "데이타베이스": "데이터베이스",
            "웹사이트": "웹사이트",
            "프레임웍": "프레임워크",
            // 필요시 추가
        ]
        
        return candidates.map { word in
            typoCorrections[word] ?? word
        }
    }
    
    /// 키워드 정제: 정규식 기반 불용어·조사·어미 제거
    private func refineKeywords(_ candidates: [String]) -> [String] {
        // 한국어·영어 불용어 (정규식으로 매칭 가능한 것은 정규식 활용)
        let stopwords: Set<String> = [
            // 한국어 조사·어미
            "이","그","저","것","등","및","의","에","를","을","로","에서","으로","와","과","도","는","은","가",
            "그리고","그러나","그러면서","그런데","또는","또","또한","하지만","만약","즉","혹은","때문에","위해","까지","처럼","같이",
            "중","등등","각","모든","이런","그런","저런","이러한","저러한",
            // 영어 불용어
            "the","and","or","of","to","in","on","for","with","a","an","is","are","was","were","be","been","being",
            "this","that","these","those","it","its","at","by","as","from","but","about","into","over","after","so","such",
            "if","then","because","therefore","thus","however","while","when","where","which","who","whose","whom",
            "different","various","several","other","many","much","some","any","every","each","good","bad","great","small","big","large",
            "specific","general","main","important","necessary","possible","typical","common","simple","complex",
            // 추가 한국어 불용어
            "합니다", "있습니다", "해야", "됩니다", "같습니다", "있어요", "입니다", "해요"
        ]
        
        // 정규식: 한국어 어미 패턴 (듯, 하는, 되는, 적인, 하며, 같은, 하는데 등)
        let koreanSuffixPattern = try! NSRegularExpression(pattern: "(듯|하는|되는|적인|하며|같은|하는데)$", options: [])
        
        // 특수문자 및 따옴표 제거용 CharacterSet
        let quoteCharacters = CharacterSet(charactersIn: "\"'`")
        let unwantedCharacters = CharacterSet.punctuationCharacters.union(.symbols).union(quoteCharacters)
        
        let refined = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 1 } // 1글자 제거
            .filter { word in
                // 불용어 필터
                !stopwords.contains(word.lowercased())
            }
            .filter { word in
                // 어미 패턴 필터 (정규식)
                let range = NSRange(location: 0, length: word.utf16.count)
                return koreanSuffixPattern.firstMatch(in: word, options: [], range: range) == nil
            }
            .map { $0.trimmingCharacters(in: unwantedCharacters) } // 특수문자 제거
            .filter { !$0.isEmpty && !stopwords.contains($0) } // 재확인
        
        return refined
    }
    
    /// 빈도 기반 전처리 (간단한 불용어 제거)
    private func preprocessForFrequency(_ text: String) -> String {
        let stopwords: Set<String> = [
            "이", "그", "저", "것", "등", "및", "의", "에", "를", "을", "로", "에서", "으로", "와", "과", "도", "는", "은", "가", "한", "하다", "되다", "있다"
        ]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { !stopwords.contains($0) }
        return filtered.joined(separator: " ")
    }
    
    /// 코사인 유사도 계산
    private func cosineSimilarity(vec1: [Double], vec2: [Double]) -> Double {
        guard vec1.count == vec2.count, !vec1.isEmpty else { return 0 }
        let dot = zip(vec1, vec2).map(*).reduce(0, +)
        let norm1 = sqrt(vec1.map { $0 * $0 }.reduce(0, +))
        let norm2 = sqrt(vec2.map { $0 * $0 }.reduce(0, +))
        guard norm1 > 0, norm2 > 0 else { return 0 }
        return dot / (norm1 * norm2)
    }
}

